import Foundation

struct PlanComparison: Identifiable {
    enum Kind: String {
        case onTime
        case missed
        case delayed
        case overtime
        case partial
        case unplanned

        var isDifference: Bool { self != .onTime }

        var label: String {
            switch self {
            case .onTime: return "按计划完成"
            case .missed: return "未做"
            case .delayed: return "延迟"
            case .overtime: return "超时"
            case .partial: return "部分完成"
            case .unplanned: return "计划外"
            }
        }
    }

    let id: UUID
    let plan: TimelineEntry?
    let actual: TimelineEntry?
    let kind: Kind
    let detail: String

    var title: String {
        plan?.title ?? actual?.title ?? ""
    }
}

enum DayReview {
    static func comparisons(
        plans: [TimelineEntry],
        actuals: [TimelineEntry],
        todos: [TodoItem]
    ) -> [PlanComparison] {
        var remaining = actuals.sorted { $0.start < $1.start }
        var results: [PlanComparison] = []

        for plan in plans.sorted(by: { $0.start < $1.start }) {
            guard let index = remaining.firstIndex(where: { matches(plan, $0) }) else {
                results.append(PlanComparison(
                    id: plan.id,
                    plan: plan,
                    actual: nil,
                    kind: .missed,
                    detail: "计划 \(TimeText.range(plan.start, plan.end))，没有对应记录"
                ))
                continue
            }
            let actual = remaining.remove(at: index)
            let task = todos.first { $0.id == plan.todoID }
            let outcome = evaluate(plan: plan, actual: actual, task: task)
            results.append(PlanComparison(
                id: plan.id,
                plan: plan,
                actual: actual,
                kind: outcome.kind,
                detail: outcome.detail
            ))
        }

        for actual in remaining {
            results.append(PlanComparison(
                id: actual.id,
                plan: nil,
                actual: actual,
                kind: .unplanned,
                detail: "实际 \(TimeText.range(actual.start, actual.end))，计划里没有这一段"
            ))
        }
        return results
    }

    private static func matches(_ plan: TimelineEntry, _ actual: TimelineEntry) -> Bool {
        if let planTodo = plan.todoID, let actualTodo = actual.todoID, planTodo == actualTodo {
            return true
        }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !planTitle.isEmpty else { return false }
        return planTitle == actual.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func evaluate(
        plan: TimelineEntry,
        actual: TimelineEntry,
        task: TodoItem?
    ) -> (kind: PlanComparison.Kind, detail: String) {
        let base = "计划 \(TimeText.range(plan.start, plan.end))，实际 \(TimeText.range(actual.start, actual.end))"

        if let task {
            if task.kind == "count", task.currentCount < task.targetCount {
                return (.partial, "\(base)，进度 \(task.currentCount)/\(task.targetCount) 次")
            }
            if task.kind != "count", !task.isCompleted {
                return (.partial, "\(base)，待办还没有完成")
            }
        }

        let delay = actual.start.timeIntervalSince(plan.start)
        if delay > 15 * 60 {
            return (.delayed, "\(base)，比计划晚 \(TimeText.duration(delay))")
        }

        let overtime = actual.end.timeIntervalSince(plan.end)
        if overtime > 15 * 60 {
            return (.overtime, "\(base)，比计划多用了 \(TimeText.duration(overtime))")
        }

        return (.onTime, base)
    }
}
