import Foundation
import CoreGraphics

struct ParsedRow: Equatable {
    var name: String
    var score: Int
}

/// One word read from the photo, with its position (normalised 0–1, y grows downwards).
struct OCRWord {
    var text: String
    var x0: CGFloat
    var x1: CGFloat
    var y: CGFloat
}

/// Turns rows of words read from a results screen into player names and running totals.
///
/// Each results row looks like:  [position] [character icon] NAME  [▲/▼/• movement]  SCORE
/// Only NAME and the score on the far right are kept. The position number and the character icon
/// (which the text reader can turn into junk letters) are dropped by column position.
enum ScoreParser {

    static func parse(rows: [[OCRWord]]) -> [ParsedRow] {
        // 1. Score = rightmost number on the row.
        struct Pre { var left: [OCRWord]; var score: Int; var y: CGFloat }
        var pre: [Pre] = []
        for words in rows {
            let words = words.sorted { $0.x0 < $1.x0 }
            guard let idx = words.lastIndex(where: { readScore($0.text) != nil }), idx >= 1,
                  let score = readScore(words[idx].text) else { continue }
            let left = Array(words[..<idx])
            guard left.contains(where: { letterCount($0.text) >= 2 }) else { continue }
            pre.append(Pre(left: left, score: score, y: words[idx].y))
        }
        guard !pre.isEmpty else { return [] }

        // 2. Find the name column: names are left-aligned, so the x where words with letters start
        //    on the most rows is where names begin.
        let letterWords = pre.flatMap { $0.left.filter(isNameLike) }
        let charW = median(letterWords.map { ($0.x1 - $0.x0) / CGFloat(max(1, $0.text.count)) }) ?? 0.01
        let tol = charW * 1.6
        var nameX: ((CGFloat) -> CGFloat)? = nil
        if pre.count >= 3 {
            struct Pt { var x: CGFloat; var y: CGFloat; var row: Int }
            var pts: [Pt] = []
            for (r, p) in pre.enumerated() {
                for w in p.left where isNameLike(w) { pts.append(Pt(x: w.x0, y: p.y, row: r)) }
            }
            var best: (rows: Int, members: [Pt])? = nil
            for pt in pts {
                let members = pts.filter { abs($0.x - pt.x) <= tol }
                let hit = Set(members.map(\.row)).count
                if best == nil || hit > best!.rows { best = (hit, members) }
            }
            if let best, Double(best.rows) >= max(2, Double(pre.count) * 0.4) {
                // Fit x = a + b*y so a slightly tilted photo still lines up.
                let m = best.members, n = CGFloat(m.count)
                let my = m.reduce(0) { $0 + $1.y } / n, mx = m.reduce(0) { $0 + $1.x } / n
                let vy = m.reduce(0) { $0 + ($1.y - my) * ($1.y - my) }
                let b = vy > 0 ? m.reduce(0) { $0 + ($1.y - my) * ($1.x - mx) } / vy : 0
                nameX = { y in mx + b * (y - my) }
            }
        }

        // 3. Keep words from the name column up to the score, then drop trailing arrows/dots.
        var out: [ParsedRow] = []
        for p in pre {
            var words = p.left
            if let nameX { words = p.left.filter { $0.x0 >= nameX(p.y) - tol } }
            if !words.contains(where: { letterCount($0.text) >= 1 }) { words = p.left }
            var toks = words.map(\.text).filter { !isRacePoints($0) }
            while toks.count > 1, isPlacement(toks[0]) || letterCount(toks[0]) == 0 { toks.removeFirst() }
            while toks.count > 1, isMarker(toks[toks.count - 1]) { toks.removeLast() }
            let name = cleanName(toks.joined(separator: " "))
            guard letterCount(name) >= 1, name.count >= 2 else { continue }
            out.append(ParsedRow(name: name, score: p.score))
        }
        return out
    }

    // MARK: Pieces

    static func readScore(_ text: String) -> Int? {
        if text.hasPrefix("+") { return nil }            // "+12" = points this race, not the total
        var t = text
        while let f = t.first, !(f.isLetter || f.isNumber || f == "+") { t.removeFirst() }   // "▲98" -> "98"
        while let l = t.last, !(l.isLetter || l.isNumber) { t.removeLast() }                 // "98." -> "98"
        t = t.replacingOccurrences(of: "o", with: "0").replacingOccurrences(of: "O", with: "0")
             .replacingOccurrences(of: "l", with: "1").replacingOccurrences(of: "I", with: "1")
        guard (1...3).contains(t.count), t.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(t)
    }

    static func letterCount(_ s: String) -> Int { s.filter(\.isLetter).count }

    private static func isNameLike(_ w: OCRWord) -> Bool {
        letterCount(w.text) >= 2 && !isPlacement(w.text)
    }

    private static func isRacePoints(_ t: String) -> Bool {
        t.hasPrefix("+") && t.count > 1 && t.dropFirst().allSatisfy(\.isNumber)
    }

    private static func isPlacement(_ t: String) -> Bool {
        t.range(of: #"^\d{1,2}(st|nd|rd|th)?[.)]?$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Short bits between the name and the score: movement arrows, dots, stray race points.
    private static func isMarker(_ t: String) -> Bool {
        (letterCount(t) < 2 && t.count <= 3) || t.range(of: #"^[+\-]?\d{1,2}$"#, options: .regularExpression) != nil
    }

    static func cleanName(_ raw: String) -> String {
        var name = raw
        for ch in ["|", "¦", "_", "~", "`", "\"", "“", "”"] { name = name.replacingOccurrences(of: ch, with: " ") }
        name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while let f = name.first, !(f.isLetter || f.isNumber || f == "[" || f == "(") { name.removeFirst() }
        while let l = name.last, !(l.isLetter || l.isNumber || l == "]" || l == ")") { name.removeLast() }
        return name.trimmingCharacters(in: .whitespaces)
    }

    private static func median(_ a: [CGFloat]) -> CGFloat? {
        guard !a.isEmpty else { return nil }
        return a.sorted()[a.count / 2]
    }

    // MARK: Merging

    /// Same player appearing in two overlapping photos: keep the later reading.
    static func dedupe(_ rows: [ParsedRow]) -> [ParsedRow] {
        var out: [ParsedRow] = []
        for r in rows {
            let k = normKey(r.name)
            if let i = out.firstIndex(where: { similarity(normKey($0.name), k) >= 0.8 }) {
                out[i].score = r.score
            } else {
                out.append(r)
            }
        }
        return out
    }

    static func normKey(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// 1 - normalised Levenshtein distance.
    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let a = Array(a), b = Array(b)
        if a.isEmpty || b.isEmpty { return 0 }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return 1 - Double(prev[b.count]) / Double(max(a.count, b.count))
    }
}
