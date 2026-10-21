import SwiftUI
import SwiftData

@main
struct RhythmApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TodoItem.self, TimelineEntry.self])
    }
}
