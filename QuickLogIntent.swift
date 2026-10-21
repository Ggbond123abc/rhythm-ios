import AppIntents
import SwiftData

struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录"
    static var description = IntentDescription("将刚刚完成的事情记录到今天的时间线。")
    static var openAppWhenRun = false

    @Parameter(title: "记录内容")
    var content: String

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: TodoItem.self, TimelineEntry.self, TodoCategory.self)
        let context = ModelContext(container)
        let now = Date()
        context.insert(TimelineEntry(title: content, start: now, end: now))
        try context.save()
        return .result()
    }
}

struct RhythmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogIntent(),
            phrases: [
                "在\(.applicationName)中记录\(\.$content)",
                "用\(.applicationName)记录\(\.$content)"
            ],
            shortTitle: "快速记录",
            systemImageName: "plus.circle"
        )
    }
}
