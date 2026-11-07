import Foundation
import SwiftUI
import UIKit

struct Player: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var score: Int
    /// Empty means "use the tag taken from the start of the name".
    var tagOverride: String = ""
}

struct Team: Identifiable {
    let tag: String
    let members: [Player]
    let total: Int
    var id: String { tag + members.map(\.id.uuidString).joined() }
}

enum PlayerCount: Int, CaseIterable, Codable, Identifiable {
    case twelve = 12
    case twentyFour = 24

    var id: Int { rawValue }
    var label: String { "\(rawValue) players" }

    /// Team sizes that divide the lobby evenly. 1 = FFA.
    var formats: [Int] {
        switch self {
        case .twelve: return [1, 2, 3, 4, 6]
        case .twentyFour: return [1, 2, 3, 4, 6, 8, 12]
        }
    }
}

func formatLabel(_ size: Int) -> String { size == 1 ? "FFA" : "\(size)v\(size)" }

@MainActor
final class ScoreStore: ObservableObject {
    @Published var playerCount: PlayerCount = .twelve { didSet { fixFormat(); save() } }
    @Published var teamSize: Int = 2 { didSet { save() } }
    @Published var tagLength: Int = 2 { didSet { save() } }
    @Published var players: [Player] = [] { didSet { save() } }
    @Published var lastUpdated: Set<UUID> = []
    @Published var isScanning = false
    @Published var status = ""

    private let storeKey = "mk-lounge-team-scores-v1"
    private var loading = false

    private struct Saved: Codable {
        var playerCount: PlayerCount
        var teamSize: Int
        var tagLength: Int
        var players: [Player]
    }

    init() { load() }

    // MARK: Persistence

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        playerCount = saved.playerCount
        teamSize = saved.teamSize
        tagLength = min(4, max(1, saved.tagLength))
        players = saved.players
        fixFormat()
    }

    private func save() {
        guard !loading else { return }
        let saved = Saved(playerCount: playerCount, teamSize: teamSize, tagLength: tagLength, players: players)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func fixFormat() {
        if !playerCount.formats.contains(teamSize) { teamSize = 2 }
    }

    // MARK: Tags & teams

    func autoTag(for name: String) -> String {
        let stripped = name.drop { !$0.isLetter && !$0.isNumber }
        return String(stripped.prefix(tagLength)).uppercased()
    }

    func tag(for player: Player) -> String {
        let t = player.tagOverride.isEmpty ? autoTag(for: player.name) : player.tagOverride
        return t.isEmpty ? "?" : t
    }

    func setTag(_ value: String, for id: UUID) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        let v = value.trimmingCharacters(in: .whitespaces).uppercased()
        players[i].tagOverride = (v.isEmpty || v == autoTag(for: players[i].name)) ? "" : v
    }

    var activePlayers: [Player] {
        players.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var teams: [Team] {
        let list = activePlayers
        var result: [Team]
        if teamSize == 1 {
            result = list.map { Team(tag: $0.name, members: [$0], total: $0.score) }
        } else {
            var order: [String] = []
            var groups: [String: [Player]] = [:]
            for p in list {
                let t = tag(for: p)
                if groups[t] == nil { order.append(t) }
                groups[t, default: []].append(p)
            }
            result = order.map { t in
                let members = groups[t]!.sorted { $0.score > $1.score }
                return Team(tag: t, members: members, total: members.reduce(0) { $0 + $1.score })
            }
        }
        return result.sorted { $0.total != $1.total ? $0.total > $1.total : $0.tag < $1.tag }
    }

    var warnings: [String] {
        let count = activePlayers.count
        guard count > 0 else { return [] }
        var w: [String] = []
        if count != playerCount.rawValue {
            w.append("\(count) players found, expected \(playerCount.rawValue).")
        }
        if teamSize > 1 {
            let expected = playerCount.rawValue / teamSize
            let found = teams.count
            if found != expected {
                w.append("\(found) tags found, expected \(expected) teams for \(formatLabel(teamSize)). Check the tag length or fix tags below.")
            }
        }
        return w
    }

    var shareText: String {
        var lines = ["\(formatLabel(teamSize)) · \(playerCount.rawValue) players"]
        for (i, t) in teams.enumerated() {
            var line = "\(i + 1). \(t.tag) — \(t.total)"
            if teamSize > 1 {
                line += " (" + t.members.map { "\($0.name) \($0.score)" }.joined(separator: ", ") + ")"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Editing

    func addPlayer() { players.append(Player(name: "", score: 0)) }

    func sortByScore() { players.sort { $0.score > $1.score } }

    func newEvent() {
        players = []
        lastUpdated = []
        status = ""
    }

    // MARK: Scanning

    /// Merge a scan into the list: matching names get the new running total, new names are added.
    func apply(_ rows: [ParsedRow]) -> (updated: Int, added: Int) {
        var updated = 0, added = 0
        var touched: Set<UUID> = []
        for row in rows {
            let key = ScoreParser.normKey(row.name)
            var best: Int? = nil
            var bestSim = 0.0
            for (i, p) in players.enumerated() {
                let s = ScoreParser.similarity(ScoreParser.normKey(p.name), key)
                if s > bestSim { bestSim = s; best = i }
            }
            if let i = best, bestSim >= 0.75 {
                players[i].score = row.score
                touched.insert(players[i].id)
                updated += 1
            } else {
                let p = Player(name: row.name, score: row.score)
                players.append(p)
                touched.insert(p.id)
                added += 1
            }
        }
        lastUpdated = touched
        return (updated, added)
    }

    func scan(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        isScanning = true
        defer { isScanning = false }
        var all: [ParsedRow] = []
        for (i, image) in images.enumerated() {
            status = "Reading photo \(i + 1) of \(images.count)…"
            do {
                let lines = try await TextRecognizer.recognizeLines(in: image)
                all += ScoreParser.parse(lines: lines)
            } catch {
                status = "Couldn't read photo \(i + 1): \(error.localizedDescription)"
            }
        }
        let rows = ScoreParser.dedupe(all)
        if rows.isEmpty {
            status = "No names and scores found. Try a straighter, closer photo of the results list, or add players by hand."
        } else {
            let r = apply(rows)
            status = "Read \(rows.count) player\(rows.count == 1 ? "" : "s"): \(r.updated) updated, \(r.added) new. Check the highlighted scores."
        }
    }
}
