import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: ScoreStore
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var confirmNewEvent = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case tag(UUID), name(UUID), score(UUID)
    }

    var body: some View {
        NavigationStack {
            List {
                setupSection
                scanSection
                standingsSection
                playersSection
            }
            .navigationTitle("Lounge Team Scores")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: store.shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(store.teams.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await store.scan([image]) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    photoItems = []
                    await store.scan(images)
                }
            }
            .confirmationDialog("Clear all players and scores for a new event?",
                                isPresented: $confirmNewEvent, titleVisibility: .visible) {
                Button("New event", role: .destructive) { store.newEvent() }
            }
        }
    }

    // MARK: Setup

    private var setupSection: some View {
        Section("Event setup") {
            Picker("Players", selection: $store.playerCount) {
                ForEach(PlayerCount.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Format").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.playerCount.formats, id: \.self) { size in
                            let selected = size == store.teamSize
                            Button {
                                store.teamSize = size
                            } label: {
                                Text(formatLabel(size))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selected ? Color.accentColor : Color(.tertiarySystemFill)))
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            Stepper(value: $store.tagLength, in: 1...4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tag length: \(store.tagLength)")
                    Text("Characters at the start of each name. Leading [ ( and symbols are skipped.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Scan

    private var scanSection: some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isScanning || !UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images) {
                    Label("Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.isScanning)
            }
            .padding(.vertical, 4)

            if store.isScanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(store.status).font(.subheadline)
                }
            } else if !store.status.isEmpty {
                Text(store.status).font(.subheadline).foregroundStyle(.secondary)
            }
        } header: {
            Text("Scan results")
        } footer: {
            Text("Photograph the results screen after any race. Each scan reads every player's running total: players already listed get the new total, new players are added. For 24 players, pick several photos at once.")
        }
    }

    // MARK: Standings

    private var standingsSection: some View {
        Section("Team standings") {
            ForEach(store.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            let teams = store.teams
            if teams.isEmpty {
                Text("Scan a results screen or add players to see standings.")
                    .foregroundStyle(.secondary)
            } else {
                let ranks = Self.ranks(for: teams)
                let top = teams[0].total
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    teamRow(team, rank: ranks[index], gap: index == 0 ? nil : top - team.total)
                }
            }
        }
    }

    private func teamRow(_ team: Team, rank: Int, gap: Int?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.heavy))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Self.rankColor(rank)))
                .foregroundStyle(rank <= 3 ? Color.white : Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.tag).font(.headline.weight(.heavy))
                if store.teamSize > 1 {
                    Text(team.members.map { "\($0.name) (\($0.score))" }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    if team.members.count != store.teamSize {
                        Text("\(team.members.count) player\(team.members.count == 1 ? "" : "s") (expected \(store.teamSize))")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(team.total)").font(.title2.weight(.heavy)).monospacedDigit()
                if let gap {
                    Text("−\(gap)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    static func ranks(for teams: [Team]) -> [Int] {
        var ranks: [Int] = []
        for (i, t) in teams.enumerated() {
            if i > 0, t.total == teams[i - 1].total { ranks.append(ranks[i - 1]) } else { ranks.append(i + 1) }
        }
        return ranks
    }

    static func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.83, green: 0.63, blue: 0.09)
        case 2: return Color(red: 0.60, green: 0.64, blue: 0.68)
        case 3: return Color(red: 0.71, green: 0.44, blue: 0.24)
        default: return Color(.tertiarySystemFill)
        }
    }

    // MARK: Players

    private var playersSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("TAG").frame(width: 56)
                Text("NAME").frame(maxWidth: .infinity, alignment: .leading)
                Text("SCORE").frame(width: 64, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)

            ForEach($store.players) { $player in
                playerRow($player)
            }
            .onDelete { store.players.remove(atOffsets: $0) }

            HStack {
                Button("Add player", systemImage: "plus") {
                    store.addPlayer()
                    if let id = store.players.last?.id { focusedField = .name(id) }
                }
                Spacer()
                Button("Sort", systemImage: "arrow.down") { store.sortByScore() }
                Spacer()
                Button("New event", role: .destructive) { confirmNewEvent = true }
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
        } header: {
            HStack {
                Text("Players")
                Spacer()
                Text("\(store.players.count)/\(store.playerCount.rawValue)")
            }
        } footer: {
            Text("Fix any misread names or scores here — totals update as you type. Edit a tag to override it for that player. Swipe left to remove a player.")
        }
    }

    private func playerRow(_ player: Binding<Player>) -> some View {
        let p = player.wrappedValue
        let tagBinding = Binding<String>(
            get: { store.tag(for: p) },
            set: { store.setTag($0, for: p.id) }
        )
        let updated = store.lastUpdated.contains(p.id)
        return HStack(spacing: 8) {
            TextField("Tag", text: tagBinding)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.body.weight(.bold))
                .frame(width: 56)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8)
                    .stroke(p.tagOverride.isEmpty ? Color.clear : Color.accentColor, lineWidth: 1.5))
                .focused($focusedField, equals: .tag(p.id))

            TextField("Name", text: player.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .name(p.id))

            TextField("0", value: player.score, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(updated ? Color.green : Color.primary)
                .frame(width: 64)
                .focused($focusedField, equals: .score(p.id))
        }
    }
}

#Preview {
    ContentView().environmentObject(ScoreStore())
}
