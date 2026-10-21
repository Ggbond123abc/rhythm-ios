import SwiftUI
import SwiftData

private enum AppStyle {
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.19)
    static let muted = Color(red: 0.47, green: 0.53, blue: 0.51)
    static let canvas = Color(red: 0.96, green: 0.96, blue: 0.92)
    static let green = Color(red: 0.20, green: 0.48, blue: 0.39)
    static let paleGreen = Color(red: 0.87, green: 0.92, blue: 0.86)
    static let orange = Color(red: 0.78, green: 0.39, blue: 0.22)

    static func categoryColor(_ category: String) -> Color {
        switch category {
        case "工作": return Color(red: 0.83, green: 0.91, blue: 0.94)
        case "学习": return Color(red: 0.91, green: 0.88, blue: 0.97)
        case "生活": return Color(red: 0.98, green: 0.88, blue: 0.77)
        case "美食": return Color(red: 0.97, green: 0.86, blue: 0.83)
        default: return paleGreen
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            DayTimelineView()
                .tabItem { Label("时间线", systemImage: "clock") }
            ReviewView()
                .tabItem { Label("复盘", systemImage: "chart.bar.xaxis") }
        }
        .tint(AppStyle.green)
    }
}

private struct TodayView: View {
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @State private var showingTodoEditor = false
    @State private var showingQuickLog = false
    @State private var editingTodo: TodoItem?
    @State private var tomorrowMode = false

    private var todayTodos: [TodoItem] {
        todos.filter {
            Calendar.current.isDateInToday($0.dueDate) &&
            !$0.isTomorrowImportant &&
            $0.parentID == nil
        }
    }

    private var tomorrowTodos: [TodoItem] {
        todos.filter { $0.isTomorrowImportant && Calendar.current.isDateInTomorrow($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    quickLogButton
                    todaySection
                    tomorrowSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingTodoEditor) {
                TodoEditor(initialDate: tomorrowMode ? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now : .now,
                           tomorrowImportant: tomorrowMode)
            }
            .sheet(isPresented: $showingQuickLog) {
                TimelineEditor(defaultIsPlan: false)
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditor(todo: todo, initialDate: todo.dueDate, tomorrowImportant: todo.isTomorrowImportant)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppStyle.muted)
            Text("把今天过清楚")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(AppStyle.ink)
            Text("计划可以调整，记录可以补上。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickLogButton: some View {
        Button {
            showingQuickLog = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.19), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速记录")
                        .font(.headline)
                    Text("刚刚做了什么？自动记下现在的时间")
                        .font(.caption)
                        .opacity(0.82)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(15)
            .background(AppStyle.green, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日待办")
                    .font(.title3.bold())
                    .foregroundStyle(AppStyle.ink)
                Text("\(todayTodos.filter(\.isCompleted).count)/\(todayTodos.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppStyle.paleGreen, in: Capsule())
                Spacer()
                Button {
                    tomorrowMode = false
                    showingTodoEditor = true
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(AppStyle.green)
            }

            if todayTodos.isEmpty {
                EmptyCard(icon: "checkmark.circle", title: "今天还没有待办", subtitle: "先加一件想完成的小事")
            } else {
                VStack(spacing: 9) {
                    ForEach(todayTodos) { todo in
                        TodoRow(todo: todo, allTodos: todos, onEdit: { editingTodo = todo })
                    }
                }
            }
        }
    }

    private var tomorrowSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("明天最重要的事")
                        .font(.title3.bold())
                        .foregroundStyle(AppStyle.ink)
                    Text("最多选 3 件，不用一次想完整天")
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                }
                Spacer()
                Button {
                    guard tomorrowTodos.count < 3 else { return }
                    tomorrowMode = true
                    showingTodoEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tomorrowTodos.count < 3 ? AppStyle.green : AppStyle.muted)
                }
                .disabled(tomorrowTodos.count >= 3)
                .accessibilityLabel("添加明天的重要事项")
            }

            if tomorrowTodos.isEmpty {
                Button {
                    tomorrowMode = true
                    showingTodoEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle")
                        Text("留一件明天想优先做的事")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppStyle.green)
                    .padding(15)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(tomorrowTodos) { todo in
                        TodoRow(todo: todo, allTodos: todos, onEdit: { editingTodo = todo })
                    }
                }
            }
        }
        .padding(16)
        .background(AppStyle.paleGreen.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct TodoRow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [TimelineEntry]
    @Query private var storedTodos: [TodoItem]
    let todo: TodoItem
    let allTodos: [TodoItem]
    let onEdit: () -> Void

    private var children: [TodoItem] {
        allTodos.filter { $0.parentID == todo.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                Button(action: toggleProgress) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(todo.isCompleted ? AppStyle.green : AppStyle.muted.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.isCompleted ? "撤销完成" : "标记完成")

                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(todo.isCompleted ? AppStyle.muted : AppStyle.ink)
                        .strikethrough(todo.isCompleted)
                    HStack(spacing: 6) {
                        Text(todo.category)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppStyle.categoryColor(todo.category), in: Capsule())
                        if todo.kind == "count" {
                            Text("\(todo.currentCount)/\(todo.targetCount) 次")
                        } else if !children.isEmpty {
                            Text("\(children.filter(\.isCompleted).count)/\(children.count) 子任务")
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppStyle.muted)
                }
                Spacer(minLength: 4)
                if todo.kind == "count" {
                    Button(action: increment) {
                        Image(systemName: "plus")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppStyle.green, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("增加一次进度")
                    if todo.currentCount > 0 {
                        Button(action: decrement) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.caption)
                                .foregroundStyle(AppStyle.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("撤销一次进度")
                    }
                }
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppStyle.muted)
                        .frame(width: 24, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑待办")
            }

            if !children.isEmpty {
                ForEach(children) { child in
                    HStack(spacing: 9) {
                        Rectangle()
                            .fill(AppStyle.paleGreen)
                            .frame(width: 2, height: 21)
                            .padding(.leading, 8)
                        Button {
                            child.isCompleted.toggle()
                            updateParentCompletion()
                        } label: {
                            Image(systemName: child.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(child.isCompleted ? AppStyle.green : AppStyle.muted.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        Text(child.title)
                            .font(.caption)
                            .foregroundStyle(child.isCompleted ? AppStyle.muted : AppStyle.ink)
                            .strikethrough(child.isCompleted)
                        Spacer()
                    }
                }
            }
        }
        .padding(13)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 17))
    }

    private func toggleProgress() {
        if todo.kind == "count" {
            if todo.isCompleted {
                todo.currentCount = max(0, todo.targetCount - 1)
                todo.isCompleted = false
            } else {
                increment()
            }
        } else {
            todo.isCompleted.toggle()
            if !children.isEmpty {
                children.forEach { $0.isCompleted = todo.isCompleted }
            }
        }
        recordCompletionIfNeeded()
    }

    private func increment() {
        guard todo.currentCount < todo.targetCount else { return }
        todo.currentCount += 1
        todo.isCompleted = todo.currentCount >= todo.targetCount
        recordCompletionIfNeeded()
    }

    private func decrement() {
        todo.currentCount = max(0, todo.currentCount - 1)
        todo.isCompleted = todo.currentCount >= todo.targetCount
    }

    private func updateParentCompletion() {
        let siblings = storedTodos.filter { $0.parentID == todo.parentID && $0.parentID != nil }
        if let parentID = todo.parentID,
           let parent = storedTodos.first(where: { $0.id == parentID }) {
            let wasCompleted = parent.isCompleted
            parent.isCompleted = !siblings.isEmpty && siblings.allSatisfy(\.isCompleted)
            if parent.isCompleted && !wasCompleted {
                recordCompletion(for: parent)
            }
        }
    }

    private func recordCompletionIfNeeded() {
        guard todo.isCompleted else { return }
        recordCompletion(for: todo)
    }

    private func recordCompletion(for completedTodo: TodoItem) {
        guard !entries.contains(where: {
            !$0.isPlan &&
            $0.todoID == completedTodo.id &&
            Calendar.current.isDateInToday($0.start)
        })
        else { return }
        let now = Date()
        modelContext.insert(TimelineEntry(title: completedTodo.title, start: now, end: now, todoID: completedTodo.id))
    }
}

private struct DayTimelineView: View {
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @State private var selectedDate = Date.now
    @State private var showingEditor = false
    @State private var editingEntry: TimelineEntry?
    @State private var newEntryIsPlan = false

    private var dayEntries: [TimelineEntry] {
        entries.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageHeader
                    DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppStyle.green)
                    HStack(spacing: 10) {
                        Button {
                            newEntryIsPlan = false
                            showingEditor = true
                        } label: {
                            Label("记实际", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(AppStyle.green, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        Button {
                            newEntryIsPlan = true
                            showingEditor = true
                        } label: {
                            Label("加计划", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(AppStyle.green)
                        }
                    }
                    if dayEntries.isEmpty {
                        EmptyCard(icon: "clock", title: "这一天还没有记录", subtitle: "补记也可以，时间线不需要填满")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(dayEntries) { entry in
                                TimelineRow(
                                    entry: entry,
                                    linkedTodo: todos.first { $0.id == entry.todoID },
                                    difference: differenceLabel(for: entry)
                                ) {
                                    editingEntry = entry
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .navigationTitle("时间线")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditor) {
                TimelineEditor(defaultDate: selectedDate, defaultIsPlan: newEntryIsPlan)
            }
            .sheet(item: $editingEntry) { entry in
                TimelineEditor(entry: entry, defaultDate: selectedDate, defaultIsPlan: entry.isPlan)
            }
        }
    }

    private func differenceLabel(for entry: TimelineEntry) -> String? {
        let plans = dayEntries.filter(\.isPlan).sorted { $0.start < $1.start }
        let actuals = dayEntries.filter { !$0.isPlan }.sorted { $0.start < $1.start }
        var unmatchedActuals = actuals
        var actualForPlan: [UUID: TimelineEntry] = [:]
        for plan in plans {
            guard let index = unmatchedActuals.firstIndex(where: {
                (plan.todoID != nil && $0.todoID == plan.todoID) || $0.title == plan.title
            }) else { continue }
            actualForPlan[plan.id] = unmatchedActuals.remove(at: index)
        }

        if entry.isPlan {
            guard let actual = actualForPlan[entry.id] else {
                return "未做"
            }
            if let todoID = entry.todoID,
               let todo = todos.first(where: { $0.id == todoID }) {
                if todo.kind == "count", todo.currentCount < todo.targetCount {
                    return "部分完成"
                }
                if todo.kind == "normal", !todo.isCompleted {
                    return "部分完成"
                }
            }
            let delay = actual.start.timeIntervalSince(entry.start)
            if delay > 15 * 60 {
                return "延迟 \(Self.durationText(delay))"
            }
            let overtime = actual.end.timeIntervalSince(entry.end)
            if overtime > 15 * 60 {
                return "超时 \(Self.durationText(overtime))"
            }
            return nil
        }
        return unmatchedActuals.contains(where: { $0.id == entry.id }) ? "计划外" : nil
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int(interval / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainingMinutes) 分"
        }
        return "\(minutes) 分钟"
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("实际发生的")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(AppStyle.ink)
            Text("记录时间点或时间段，之后仍可编辑。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimelineRow: View {
    let entry: TimelineEntry
    let linkedTodo: TodoItem?
    let difference: String?
    let onEdit: () -> Void

    var body: some View {
        let hasDifference = difference != nil
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(entry.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppStyle.muted)
                Circle().fill(hasDifference || entry.isPlan ? AppStyle.orange : AppStyle.green).frame(width: 8, height: 8)
                Rectangle().fill(AppStyle.paleGreen).frame(width: 1, height: 46)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.ink)
                    Spacer()
                    Text(entry.isPlan ? "计划" : "实际")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(entry.isPlan ? AppStyle.orange : AppStyle.green)
                }
                Text("\(entry.start.formatted(date: .omitted, time: .shortened)) – \(entry.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                HStack(spacing: 5) {
                    if let linkedTodo {
                        Label(linkedTodo.title, systemImage: "link")
                    }
                    if !entry.tags.isEmpty {
                        Label(entry.tags, systemImage: "tag")
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
                if let difference {
                    Text(difference)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppStyle.orange)
                }
            }
            .padding(.bottom, 17)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
    }
}

private struct ReviewView: View {
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query private var todos: [TodoItem]
    @State private var selectedDate = Date.now

    private var plans: [TimelineEntry] {
        entries.filter { $0.isPlan && Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var actuals: [TimelineEntry] {
        entries.filter { !$0.isPlan && Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var findings: [ReviewFinding] {
        var matchedIDs = Set<UUID>()
        var results = plans.map { plan -> ReviewFinding in
            let match = actuals.first {
                !matchedIDs.contains($0.id) &&
                (($0.todoID != nil && $0.todoID == plan.todoID) || ($0.title == plan.title))
            }
            guard let actual = match else {
                return ReviewFinding(title: plan.title, detail: "未做", tone: .missed)
            }
            matchedIDs.insert(actual.id)
            let task = todos.first { $0.id == plan.todoID }
            if let task, task.kind == "count", task.currentCount < task.targetCount {
                return ReviewFinding(title: plan.title, detail: "部分完成 · \(task.currentCount)/\(task.targetCount) 次", tone: .partial)
            }
            if let task, task.kind == "normal", !task.isCompleted {
                return ReviewFinding(title: plan.title, detail: "部分完成", tone: .partial)
            }
            let delayedBy = actual.start.timeIntervalSince(plan.start)
            if delayedBy > 15 * 60 {
                return ReviewFinding(title: plan.title, detail: "延迟 \(Self.durationText(delayedBy))", tone: .late)
            }
            let overBy = actual.end.timeIntervalSince(plan.end)
            if overBy > 15 * 60 {
                return ReviewFinding(title: plan.title, detail: "超时 \(Self.durationText(overBy))", tone: .late)
            }
            return ReviewFinding(title: plan.title, detail: "按计划完成", tone: .good)
        }
        results += actuals.filter { !matchedIDs.contains($0.id) }.map {
            ReviewFinding(title: $0.title, detail: "计划外", tone: .extra)
        }
        return results
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("计划和实际")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(AppStyle.ink)
                        Text("只看差异，不给自己打分。")
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
                    }
                    DatePicker("复盘日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppStyle.green)
                    HStack(spacing: 10) {
                        SummaryTile(title: "计划", count: plans.count, color: AppStyle.orange)
                        SummaryTile(title: "实际记录", count: actuals.count, color: AppStyle.green)
                        SummaryTile(title: "差异", count: findings.filter { $0.tone != .good }.count, color: AppStyle.ink)
                    }
                    if findings.isEmpty {
                        EmptyCard(icon: "sparkles", title: "还没有可复盘的内容", subtitle: "添加计划和实际记录后，差异会显示在这里")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("今日差异")
                                .font(.headline)
                                .foregroundStyle(AppStyle.ink)
                            ForEach(Array(findings.enumerated()), id: \.offset) { item in
                                FindingRow(finding: item.element)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .navigationTitle("复盘")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int(interval / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainingMinutes) 分"
        }
        return "\(minutes) 分钟"
    }
}

private struct ReviewFinding {
    enum Tone: Equatable {
        case missed, partial, late, extra, good
    }
    let title: String
    let detail: String
    let tone: Tone
}

private struct FindingRow: View {
    let finding: ReviewFinding
    private var color: Color {
        switch finding.tone {
        case .missed, .late: return AppStyle.orange
        case .partial: return Color(red: 0.72, green: 0.48, blue: 0.16)
        case .extra: return AppStyle.muted
        case .good: return AppStyle.green
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.ink)
                Text(finding.detail).font(.caption.weight(.medium)).foregroundStyle(color)
            }
            Spacer()
            if finding.tone != .good {
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppStyle.muted)
            }
        }
        .padding(12)
        .frame(minHeight: 58)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SummaryTile: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(AppStyle.muted)
            Text("\(count)").font(.title2.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct EmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppStyle.green)
                .frame(width: 40, height: 40)
                .background(AppStyle.paleGreen, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.ink)
                Text(subtitle).font(.caption).foregroundStyle(AppStyle.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct TodoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]
    let todo: TodoItem?
    let initialDate: Date
    let tomorrowImportant: Bool

    @State private var title: String
    @State private var category: String
    @State private var dueDate: Date
    @State private var kind: String
    @State private var targetCount: Int
    @State private var parentID: UUID?
    @State private var notes: String

    init(todo: TodoItem? = nil, initialDate: Date, tomorrowImportant: Bool = false) {
        self.todo = todo
        self.initialDate = initialDate
        self.tomorrowImportant = tomorrowImportant
        _title = State(initialValue: todo?.title ?? "")
        _category = State(initialValue: todo?.category ?? "生活")
        _dueDate = State(initialValue: todo?.dueDate ?? initialDate)
        _kind = State(initialValue: todo?.kind ?? "normal")
        _targetCount = State(initialValue: todo?.targetCount ?? 5)
        _parentID = State(initialValue: todo?.parentID)
        _notes = State(initialValue: todo?.notes ?? "")
    }

    private let suggestedCategories = ["工作", "学习", "生活", "美食"]
    private var parentOptions: [TodoItem] {
        todos.filter { $0.parentID == nil && $0.id != todo?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("待办内容") {
                    TextField("例如：完成项目提案", text: $title)
                    TextField("分类", text: $category)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestedCategories, id: \.self) { item in
                                Button(item) { category = item }
                                    .font(.caption.weight(.medium))
                                    .buttonStyle(.bordered)
                                    .tint(category == item ? AppStyle.green : AppStyle.muted)
                            }
                        }
                    }
                    DatePicker("日期", selection: $dueDate, displayedComponents: .date)
                    Picker("类型", selection: $kind) {
                        Text("普通待办").tag("normal")
                        Text("按次数完成").tag("count")
                    }
                    if kind == "count" {
                        Stepper("目标次数：\(targetCount)", value: $targetCount, in: 1...99)
                    }
                    if !parentOptions.isEmpty && kind == "normal" {
                        Picker("所属待办", selection: $parentID) {
                            Text("无（独立待办）").tag(Optional<UUID>.none)
                            ForEach(parentOptions) { option in
                                Text(option.title).tag(Optional(option.id))
                            }
                        }
                    }
                    TextField("备注（选填）", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if tomorrowImportant && todo == nil {
                    Section {
                        Label("已加入明天最重要的事项", systemImage: "sparkle")
                            .foregroundStyle(AppStyle.green)
                    }
                }
                if let todo {
                    Section {
                        Button("删除待办", role: .destructive) {
                            todos.filter { $0.parentID == todo.id }.forEach { modelContext.delete($0) }
                            modelContext.delete(todo)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(todo == nil ? "新建待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedParent = parentID == nil ? nil : todos.first { $0.id == parentID }
        if todo == nil, tomorrowImportant, todos.filter({ $0.isTomorrowImportant && Calendar.current.isDateInTomorrow($0.dueDate) }).count >= 3 {
            dismiss()
            return
        }
        if let todo {
            todo.title = cleanTitle
            todo.category = cleanCategory.isEmpty ? "未分类" : cleanCategory
            todo.dueDate = dueDate
            todo.kind = kind
            todo.targetCount = targetCount
            todo.isTomorrowImportant = tomorrowImportant
            todo.parentID = selectedParent?.id
            todo.notes = notes
        } else {
            modelContext.insert(TodoItem(
                title: cleanTitle,
                category: cleanCategory.isEmpty ? "未分类" : cleanCategory,
                dueDate: dueDate,
                kind: kind,
                targetCount: targetCount,
                isTomorrowImportant: tomorrowImportant,
                parentID: selectedParent?.id,
                notes: notes
            ))
        }
        dismiss()
    }
}

private struct TimelineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]
    let entry: TimelineEntry?
    let defaultIsPlan: Bool

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var todoID: UUID?
    @State private var tags: String
    @State private var notes: String
    @State private var isPlan: Bool

    init(entry: TimelineEntry? = nil, defaultDate: Date = .now, defaultIsPlan: Bool) {
        self.entry = entry
        self.defaultIsPlan = defaultIsPlan
        let now = Date.now
        _title = State(initialValue: entry?.title ?? "")
        _start = State(initialValue: entry?.start ?? (defaultIsPlan ? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate : now))
        _end = State(initialValue: entry?.end ?? (defaultIsPlan ? Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: defaultDate) ?? defaultDate : now))
        _todoID = State(initialValue: entry?.todoID)
        _tags = State(initialValue: entry?.tags ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isPlan = State(initialValue: entry?.isPlan ?? defaultIsPlan)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("做了什么 / 计划做什么", text: $title)
                    Picker("记录类型", selection: $isPlan) {
                        Text("实际").tag(false)
                        Text("计划").tag(true)
                    }
                    Picker("关联待办", selection: $todoID) {
                        Text("不关联").tag(Optional<UUID>.none)
                        ForEach(todos) { todo in
                            Text(todo.title).tag(Optional(todo.id))
                        }
                    }
                }
                Section("时间") {
                    DatePicker("开始", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束", selection: $end, displayedComponents: [.date, .hourAndMinute])
                }
                Section("补充") {
                    TextField("标签，用逗号分隔", text: $tags)
                    TextField("备注", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                if let entry {
                    Section {
                        Button("删除记录", role: .destructive) {
                            modelContext.delete(entry)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? (defaultIsPlan ? "安排计划" : "快速记录") : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end < start)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.title = cleanTitle
            entry.start = start
            entry.end = end
            entry.todoID = todoID
            entry.tags = tags
            entry.notes = notes
            entry.isPlan = isPlan
        } else {
            modelContext.insert(TimelineEntry(
                title: cleanTitle,
                start: start,
                end: end,
                todoID: todoID,
                tags: tags,
                notes: notes,
                isPlan: isPlan
            ))
        }
        dismiss()
    }
}
