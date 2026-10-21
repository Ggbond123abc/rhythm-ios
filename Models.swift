import Foundation
import SwiftData

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
        notes: String = ""
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
}
