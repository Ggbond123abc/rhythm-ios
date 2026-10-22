import Foundation
import SwiftData

@Model
final class TodoCategory {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(name: String, colorHex: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var category: String
    var dueDate: Date
    var kind: String
    var targetCount: Int
    var currentCount: Int
    var isCompleted: Bool
    var isTomorrowImportant: Bool
    var parentID: UUID?
    var notes: String
    var deferCount: Int = 0

    init(
        title: String,
        category: String,
        dueDate: Date,
        kind: String = "normal",
        targetCount: Int = 1,
        currentCount: Int = 0,
        isCompleted: Bool = false,
        isTomorrowImportant: Bool = false,
        parentID: UUID? = nil,
        notes: String = "",
        deferCount: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.dueDate = dueDate
        self.kind = kind
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.isCompleted = isCompleted
        self.isTomorrowImportant = isTomorrowImportant
        self.parentID = parentID
        self.notes = notes
        self.deferCount = deferCount
    }

    var isOverdue: Bool {
        !isCompleted && Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now)
    }

    func deferTo(_ date: Date) {
        dueDate = Calendar.current.startOfDay(for: date)
        deferCount += 1
    }
}

@Model
final class TimelineEntry {
    var id: UUID
    var title: String
    var start: Date
    var end: Date
    var todoID: UUID?
    var tags: String
    var notes: String
    var isPlan: Bool

    init(
        title: String,
        start: Date,
        end: Date,
        todoID: UUID? = nil,
        tags: String = "",
        notes: String = "",
        isPlan: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.start = start
        self.end = end
        self.todoID = todoID
        self.tags = tags
        self.notes = notes
        self.isPlan = isPlan
    }

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}
