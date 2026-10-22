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

struct TodoTimeStat: Identifiable {
    let id: String
    let title: String
    let category: String
    let duration: TimeInterval
    let sessions: Int
    let isLinked: Bool
}

struct CategoryTimeStat: Identifiable {
    let name: String
    let duration: TimeInterval
    let share: Double

    var id: String { name }
}

struct DayTimeStat: Identifiable {
    let date: Date
    let duration: TimeInterval

    var id: Date { date }
}

struct TimeReviewSummary {
    let total: TimeInterval
    let planned: TimeInterval
    let byTodo: [TodoTimeStat]
    let byCategory: [CategoryTimeStat]
    let byDay: [DayTimeStat]

    var averagePerActiveDay: TimeInterval {
        let active = byDay.filter { $0.duration > 0 }.count
        return active == 0 ? 0 : total / Double(active)
    }

    var longestSession: TimeInterval {
        byTodo.map(\.duration).max() ?? 0
    }
}

enum TodoReview {
    static func range(
        scope: ReviewScope,
        anchor: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        switch scope {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return (start, calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            let start = interval?.start ?? calendar.startOfDay(for: anchor)
            return (start, interval?.end ?? start)
        case .month:
            let interval = calendar.dateInterval(of: .month, for: anchor)
            let start = interval?.start ?? calendar.startOfDay(for: anchor)
            return (start, interval?.end ?? start)
        }
    }

    static func summary(
        scope: ReviewScope,
        anchor: Date,
        todos: [TodoItem],
        calendar: Calendar = .current
    ) -> TodoReviewSummary {
        let bounds = range(scope: scope, anchor: anchor, calendar: calendar)
        let rangeStart = bounds.start
        let rangeEnd = bounds.end

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

    static func timeSummary(
        scope: ReviewScope,
        anchor: Date,
        entries: [TimelineEntry],
        todos: [TodoItem],
        calendar: Calendar = .current
    ) -> TimeReviewSummary {
        let bounds = range(scope: scope, anchor: anchor, calendar: calendar)
        let actuals = entries.filter { !$0.isPlan && $0.start >= bounds.start && $0.start < bounds.end }
        let plans = entries.filter { $0.isPlan && $0.start >= bounds.start && $0.start < bounds.end }

        var groups: [String: (title: String, category: String, duration: TimeInterval, sessions: Int, isLinked: Bool)] = [:]
        var categoryTotals: [String: TimeInterval] = [:]
        var dayTotals: [Date: TimeInterval] = [:]

        for entry in actuals {
            let linked = entry.todoID.flatMap { id in todos.first { $0.id == id } }
            let cleanTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstTag = entry.tags
                .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == " " })
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""

            let key: String
            let title: String
            let category: String
            let isLinked: Bool

            if let linked {
                key = "todo:\(linked.id.uuidString)"
                title = linked.title
                category = linked.category
                isLinked = true
            } else {
                key = "free:\(cleanTitle.lowercased())"
                title = cleanTitle.isEmpty ? "未命名记录" : cleanTitle
                category = firstTag.isEmpty ? "未关联待办" : firstTag
                isLinked = false
            }

            var group = groups[key] ?? (title: title, category: category, duration: 0, sessions: 0, isLinked: isLinked)
            group.duration += entry.duration
            group.sessions += 1
            groups[key] = group

            categoryTotals[category, default: 0] += entry.duration
            dayTotals[calendar.startOfDay(for: entry.start), default: 0] += entry.duration
        }

        let totalDuration = actuals.reduce(0) { $0 + $1.duration }

        let byTodo = groups
            .map { key, value in
                TodoTimeStat(
                    id: key,
                    title: value.title,
                    category: value.category,
                    duration: value.duration,
                    sessions: value.sessions,
                    isLinked: value.isLinked
                )
            }
            .sorted { lhs, rhs in
                if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
                return lhs.title < rhs.title
            }

        let byCategory = categoryTotals
            .map { name, duration in
                CategoryTimeStat(
                    name: name,
                    duration: duration,
                    share: totalDuration == 0 ? 0 : duration / totalDuration
                )
            }
            .sorted { $0.duration > $1.duration }

        var byDay: [DayTimeStat] = []
        var cursor = calcDayStart(bounds.start, calendar: calendar)
        let lastDay = calcDayStart(bounds.end.addingTimeInterval(-1), calendar: calendar)
        while cursor <= lastDay {
            byDay.append(DayTimeStat(date: cursor, duration: dayTotals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return TimeReviewSummary(
            total: totalDuration,
            planned: plans.reduce(0) { $0 + $1.duration },
            byTodo: byTodo,
            byCategory: byCategory,
            byDay: byDay
        )
    }

    private static func calcDayStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
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
