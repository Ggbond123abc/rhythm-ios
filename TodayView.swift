import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var showingTodoEditor = false
    @State private var showingCategories = false
    @State private var showingHistory = false
    @State private var showingBackground = false
    @State private var editingTodo: TodoItem?
    @State private var editingEntry: TimelineEntry?
    @State private var newEntry: NewEntrySeed?
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

    private var overdueTodos: [TodoItem] {
        todos.filter { $0.isOverdue && $0.parentID == nil }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var todayEntries: [TimelineEntry] {
        entries.filter { Calendar.current.isDateInToday($0.start) }
    }

    private var plans: [TimelineEntry] { todayEntries.filter(\.isPlan) }
    private var actuals: [TimelineEntry] { todayEntries.filter { !$0.isPlan } }

    private var comparisons: [PlanComparison] {
        DayReview.comparisons(plans: plans, actuals: actuals, todos: todos)
    }

    private var differences: [PlanComparison] {
        comparisons.filter { $0.kind.isDifference }
    }

    private var planSlices: [ClockSlice] { plans.map { makeSlice($0) } }
    private var actualSlices: [ClockSlice] { actuals.map { makeSlice($0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    quickLogButton
                    clockSection
                    if !overdueTodos.isEmpty {
                        overdueSection
                    }
                    todaySection
                    tomorrowSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .background(PageBackgroundView(page: .today))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingTodoEditor) {
                TodoEditor(
                    initialDate: tomorrowMode
                        ? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                        : .now,
                    tomorrowImportant: tomorrowMode
                )
            }
            .sheet(isPresented: $showingCategories) {
                CategoryManagerView()
            }
            .sheet(isPresented: $showingHistory) {
                TodoHistoryView()
            }
            .sheet(isPresented: $showingBackground) {
                BackgroundPickerSheet(page: .today)
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditor(todo: todo, initialDate: todo.dueDate, tomorrowImportant: todo.isTomorrowImportant)
            }
            .sheet(item: $editingEntry) { entry in
                TimelineEditor(
                    entry: entry,
                    defaultDate: entry.start,
                    defaultIsPlan: entry.isPlan,
                    differenceNote: differenceNote(for: entry)
                )
            }
            .sheet(item: $newEntry) { seed in
                TimelineEditor(defaultDate: .now, startMinute: seed.minute, defaultIsPlan: seed.isPlan)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppStyle.muted)
                Text("把今天过清楚")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppStyle.ink)
                Text("计划可以调整，记录可以补上。")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer(minLength: 0)
            Button {
                showingBackground = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更换今天页背景")
            Button {
                showingHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("待办历史")
            Button {
                showingCategories = true
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分类管理")
        }
    }

    private var quickLogButton: some View {
        Button {
            newEntry = NewEntrySeed(minute: nil, isPlan: false)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.19), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速记录")
                        .font(.headline)
                    Text("接着上次记录的结束时间，一次记一段")
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

    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("今日时钟")
                    .font(.title3.bold())
                    .foregroundStyle(AppStyle.ink)
                if !differences.isEmpty {
                    Text("差异 \(differences.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppStyle.danger, in: Capsule())
                }
                Spacer()
                Button {
                    showingBackground = true
                } label: {
                    Label("背景图", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppStyle.paleGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("给今天页换背景图")
            }

            HStack(alignment: .top, spacing: 10) {
                clockCard(title: "计划", isPlan: true, slices: planSlices, entriesOfDay: plans, tint: AppStyle.orange)
                clockCard(title: "实际", isPlan: false, slices: actualSlices, entriesOfDay: actuals, tint: AppStyle.green)
            }

            HStack(spacing: 12) {
                legend(color: AppStyle.orange, text: "计划")
                legend(color: AppStyle.green, text: "实际")
                legend(color: AppStyle.danger, text: "计划有差异")
                Spacer(minLength: 0)
            }

            Text("点色块查看几点到几点做什么，点空白处按该时间补记。")
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
        }
    }

    private func clockCard(
        title: String,
        isPlan: Bool,
        slices: [ClockSlice],
        entriesOfDay: [TimelineEntry],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppStyle.ink)
                Spacer(minLength: 0)
                Button {
                    newEntry = NewEntrySeed(minute: nil, isPlan: isPlan)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlan ? "添加计划" : "添加实际记录")
            }

            DayClock(
                slices: slices,
                centerValue: "\(entriesOfDay.count) 段",
                centerCaption: entriesOfDay.isEmpty ? "空白" : totalText(entriesOfDay)
            ) { slice, minute in
                if let slice, let entry = entries.first(where: { $0.id == slice.id }) {
                    editingEntry = entry
                } else {
                    newEntry = NewEntrySeed(minute: Int(minute.rounded()), isPlan: isPlan)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
    }

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Text("逾期未完成")
                    .font(.title3.bold())
                    .foregroundStyle(AppStyle.ink)
                Text("\(overdueTodos.count) 件")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#F6E2CB"), in: Capsule())
                Spacer(minLength: 0)
                Button {
                    overdueTodos.forEach { $0.deferTo(.now) }
                } label: {
                    Label("全部顺延", systemImage: "arrow.uturn.forward")
                        .font(.caption.weight(.semibold))
                }
                .tint(AppStyle.green)
            }

            VStack(spacing: 8) {
                ForEach(overdueTodos) { todo in
                    TodoRow(
                        todo: todo,
                        allTodos: todos,
                        onEdit: { editingTodo = todo },
                        onDefer: { todo.deferTo(.now) }
                    )
                }
            }

            Text("长按单条待办可以顺延到明天，历史记录在右上角时钟按钮里。")
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
        }
        .padding(14)
        .background(Color(hex: "#F7EAD4").opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
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
                EmptyHintCard(icon: "checkmark.circle", title: "今天还没有待办", subtitle: "先加一件想完成的小事")
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

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(AppStyle.muted)
        }
    }

    private func totalText(_ list: [TimelineEntry]) -> String {
        TimeText.duration(list.reduce(0) { $0 + $1.duration })
    }

    private func currentMinute() -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func makeSlice(_ entry: TimelineEntry) -> ClockSlice {
        let categoryName = todos.first { $0.id == entry.todoID }?.category ?? ""
        var color = categories.color(named: categoryName)
        let comparison = comparisons.first {
            $0.plan?.id == entry.id || $0.actual?.id == entry.id
        }
        if entry.isPlan == false, comparison?.kind == .unplanned {
            color = AppStyle.orange
        }
        let flagged = entry.isPlan && (comparison?.kind.isDifference ?? false)
        return ClockSlice(entry: entry, color: color, isFlagged: flagged)
    }

    private func differenceNote(for entry: TimelineEntry) -> String? {
        comparisons.first {
            ($0.plan?.id == entry.id || $0.actual?.id == entry.id) && $0.kind.isDifference
        }?.detail
    }
}

struct TodoRow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [TimelineEntry]
    @Query private var storedTodos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]
    let todo: TodoItem
    let allTodos: [TodoItem]
    let onEdit: () -> Void
    var onDefer: (() -> Void)? = nil

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
                            .foregroundStyle(AppStyle.ink)
                            .background(categories.color(named: todo.category).opacity(0.35), in: Capsule())
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

                if let onDefer {
                    Button(action: onDefer) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.green)
                            .frame(width: 28, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("顺延到今天")
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
        .contextMenu {
            if !todo.isCompleted {
                Button {
                    todo.deferTo(.now)
                } label: {
                    Label("顺延到今天", systemImage: "arrow.uturn.forward")
                }
                Button {
                    todo.deferTo(Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
                } label: {
                    Label("顺延到明天", systemImage: "sunrise")
                }
            }
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
        }
    }

    private func toggleProgress() {
        if todo.kind == "count" {
            if todo.isCompleted {
                todo.currentCount = max(0, todo.targetCount - 1)
                todo.isCompleted = false
            } else {
                increment()
                return
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
        guard let parentID = todo.parentID,
              let parent = storedTodos.first(where: { $0.id == parentID }) else { return }
        let siblings = storedTodos.filter { $0.parentID == parentID }
        let wasCompleted = parent.isCompleted
        parent.isCompleted = !siblings.isEmpty && siblings.allSatisfy(\.isCompleted)
        if parent.isCompleted && !wasCompleted {
            recordCompletion(for: parent)
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
        }) else { return }
        let now = Date()
        modelContext.insert(TimelineEntry(title: completedTodo.title, start: now, end: now, todoID: completedTodo.id))
    }
}
