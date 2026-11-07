import SwiftUI

@main
struct MKTeamScoresApp: App {
    @StateObject private var store = ScoreStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
