import Foundation

enum ReviewScope: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

struct TodoDayBucket: Identifiable {
    let date: Date
    let total: Int
    let completed: Int

    var id: Date { date }

    var ratio: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }
}

struct TodoReviewSummary {
    struct CategoryStat: Identifiable {
        let name: String
        let total: Int
        let completed: Int

        var id: String { name }

        var ratio: Double {
            total == 0 ? 0 : Double(completed) / Double(total)
        }
    }

    let scope: ReviewScope
    let anchor: Date
    let start: Date
    let end: Date
    let buckets: [TodoDayBucket]
    let total: Int
    let completed: Int
    let deferred: Int
    let byCategory: [CategoryStat]
    let unfinished: [TodoItem]

    var completionRate: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    var leading: Int { total - completed }

    var rangeTitle: String {
        switch scope {
        case .day:
            return start.formatted(.dateTime.month().day().weekday(.abbreviated))
        case .week:
            return "\(start.formatted(.dateTime.month().day())) – \(end.addingTimeInterval(-1).formatted(.dateTime.month().day()))"
        case .month:
            return start.formatted(.dateTime.year().month())
        }
    }
}

enum TodoReview {
    static func summary(
        scope: ReviewScope,
        anchor: Date,
        todos: [TodoItem],
        calendar: Calendar = .current
    ) -> TodoReviewSummary {
        let rangeStart: Date
        let rangeEnd: Date

        switch scope {
        case .day:
            rangeStart = calendar.startOfDay(for: anchor)
            rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart) ?? rangeStart
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            rangeStart = interval?.start ?? calendar.startOfDay(for: anchor)
            rangeEnd = interval?.end ?? rangeStart
        case .month:
            let interval = calendar.dateInterval(of: .month, for: anchor)
            rangeStart = interval?.start ?? calendar.startOfDay(for: anchor)
            rangeEnd = interval?.end ?? rangeStart
        }

        let scoped = todos.filter { todo in
            todo.parentID == nil && todo.dueDate >= rangeStart && todo.dueDate < rangeEnd
        }

        var buckets: [TodoDayBucket] = []
        var cursor = rangeStart
        while cursor < rangeEnd {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? rangeEnd
            let dayTodos = scoped.filter { $0.dueDate >= cursor && $0.dueDate < next }
            buckets.append(TodoDayBucket(
                date: cursor,
                total: dayTodos.count,
                completed: dayTodos.filter(\.isCompleted).count
            ))
            cursor = next
        }

        var categoryTotals: [String: (total: Int, completed: Int)] = [:]
        for todo in scoped {
            let current = categoryTotals[todo.category] ?? (0, 0)
            categoryTotals[todo.category] = (
                current.total + 1,
                current.completed + (todo.isCompleted ? 1 : 0)
            )
        }
        let categoryStats = categoryTotals
            .map { TodoReviewSummary.CategoryStat(name: $0.key, total: $0.value.total, completed: $0.value.completed) }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.name < rhs.name
            }

        let unfinished = scoped
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }

        return TodoReviewSummary(
            scope: scope,
            anchor: anchor,
            start: rangeStart,
            end: rangeEnd,
            buckets: buckets,
            total: scoped.count,
            completed: scoped.filter(\.isCompleted).count,
            deferred: scoped.filter { $0.deferCount > 0 }.count,
            byCategory: categoryStats,
            unfinished: unfinished
        )
    }

    static func shiftedAnchor(_ anchor: Date, scope: ReviewScope, step: Int) -> Date {
        let calendar = Calendar.current
        switch scope {
        case .day:
            return calendar.date(byAdding: .day, value: step, to: anchor) ?? anchor
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: step, to: anchor) ?? anchor
        case .month:
            return calendar.date(byAdding: .month, value: step, to: anchor) ?? anchor
        }
    }
}
