import SwiftUI
import SwiftData

@main
struct RhythmApp: App {
    private let container: ModelContainer

    init() {
        do {
            let container = try ModelContainer(for: TodoItem.self, TimelineEntry.self, TodoCategory.self)
            Self.seedCategoriesIfNeeded(in: container)
            self.container = container
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private static func seedCategoriesIfNeeded(in container: ModelContainer) {
        guard UserDefaults.standard.object(forKey: "didSeedCategories") == nil else { return }
        let context = ModelContext(container)
        let count = (try? context.fetchCount(FetchDescriptor<TodoCategory>())) ?? 0
        guard count == 0 else { return }
        let defaults = [("工作", "#4F7CAC"), ("学习", "#7A6FA8"), ("生活", "#4E8C74"), ("美食", "#C9A227")]
        for (index, item) in defaults.enumerated() {
            context.insert(TodoCategory(
                name: item.0,
                colorHex: item.1,
                createdAt: Date().addingTimeInterval(TimeInterval(index))
            ))
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: "didSeedCategories")
    }
}
