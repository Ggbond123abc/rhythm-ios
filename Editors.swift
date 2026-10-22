import SwiftUI
import SwiftData

struct NewEntrySeed: Identifiable {
    let id = UUID()
    var minute: Int?
    var isPlan: Bool
}

struct TodoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    let todo: TodoItem?
    let tomorrowImportant: Bool

    @State private var title: String
    @State private var categoryName: String
    @State private var dueDate: Date
    @State private var kind: String
    @State private var targetCount: Int
    @State private var parentID: UUID?
    @State private var notes: String
    @State private var newCategoryName = ""
    @State private var showingNewCategoryField = false
    @State private var newSubtaskTitle = ""
    @State private var draftSubtasks: [String] = []

    init(todo: TodoItem? = nil, initialDate: Date, tomorrowImportant: Bool = false) {
        self.todo = todo
        self.tomorrowImportant = tomorrowImportant
        _title = State(initialValue: todo?.title ?? "")
        _categoryName = State(initialValue: todo?.category ?? "")
        _dueDate = State(initialValue: todo?.dueDate ?? initialDate)
        _kind = State(initialValue: todo?.kind ?? "normal")
        _targetCount = State(initialValue: todo?.targetCount ?? 5)
        _parentID = State(initialValue: todo?.parentID)
        _notes = State(initialValue: todo?.notes ?? "")
    }

    private var parentOptions: [TodoItem] {
        todos.filter { $0.parentID == nil && $0.id != todo?.id }
    }

    private var subtasks: [TodoItem] {
        guard let todo else { return [] }
        return todos
            .filter { $0.parentID == todo.id }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.title < rhs.title
            }
    }

    private var canAddTomorrow: Bool {
        todo != nil || !tomorrowImportant ||
            todos.filter { $0.isTomorrowImportant && Calendar.current.isDateInTomorrow($0.dueDate) }.count < 3
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("待办内容") {
                    TextField("例如：完成项目提案", text: $title)
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

                Section {
                    ForEach(subtasks) { child in
                        HStack(spacing: 10) {
                            Button {
                                toggleSubtask(child)
                            } label: {
                                Image(systemName: child.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(child.isCompleted ? AppStyle.green : AppStyle.muted.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(child.isCompleted ? "撤销完成 \(child.title)" : "完成 \(child.title)")

                            Text(child.title)
                                .font(.subheadline)
                                .foregroundStyle(child.isCompleted ? AppStyle.muted : AppStyle.ink)
                                .strikethrough(child.isCompleted)

                            Spacer(minLength: 0)

                            Button(role: .destructive) {
                                modelContext.delete(child)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除子待办 \(child.title)")
                        }
                    }

                    ForEach(Array(draftSubtasks.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 10) {
                            Image(systemName: "circle")
                                .foregroundStyle(AppStyle.muted.opacity(0.5))
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(AppStyle.ink)
                            Spacer(minLength: 0)
                            Button {
                                draftSubtasks.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("添加子待办，如 顺手倒垃圾", text: $newSubtaskTitle)
                        Button("添加", action: addSubtask)
                            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("子待办")
                } footer: {
                    Text(todo == nil
                         ? "保存时一起建好；子待办全部完成时，父待办会自动完成。"
                         : "子待办全部完成时，父待办会自动完成，也可以手动改回。")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                }

                Section("分类") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { category in
                                Button {
                                    categoryName = category.name
                                } label: {
                                    Text(category.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(categoryName == category.name ? .white : AppStyle.ink)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(
                                            Color(hex: category.colorHex)
                                                .opacity(categoryName == category.name ? 1 : 0.28),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                showingNewCategoryField.toggle()
                            } label: {
                                Label("新分类", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppStyle.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(AppStyle.paleGreen, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }

                    if showingNewCategoryField {
                        HStack {
                            TextField("分类名称，如 运动", text: $newCategoryName)
                            Button("添加") { addCategory() }
                                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if categories.isEmpty && !showingNewCategoryField {
                        Text("还没有分类，点上面的“新分类”建一个。")
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                    }
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
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canAddTomorrow)
                }
            }
            .onAppear {
                if categoryName.isEmpty {
                    categoryName = categories.first?.name ?? "未分类"
                }
            }
        }
    }

    private func addSubtask() {
        let name = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let todo {
            let child = TodoItem(
                title: name,
                category: todo.category,
                dueDate: todo.dueDate,
                parentID: todo.id
            )
            modelContext.insert(child)
            refreshParentCompletion(todo)
        } else {
            draftSubtasks.append(name)
        }
        newSubtaskTitle = ""
    }

    private func toggleSubtask(_ child: TodoItem) {
        child.isCompleted.toggle()
        if let parent = todos.first(where: { $0.id == child.parentID }) {
            refreshParentCompletion(parent)
        }
    }

    private func refreshParentCompletion(_ parent: TodoItem) {
        let children = todos.filter { $0.parentID == parent.id }
        guard !children.isEmpty else { return }
        parent.isCompleted = children.allSatisfy(\.isCompleted)
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = categories.first(where: { $0.name == name }) {
            categoryName = existing.name
        } else {
            modelContext.insert(TodoCategory(name: name, colorHex: categories.nextColorHex()))
            categoryName = name
        }
        newCategoryName = ""
        showingNewCategoryField = false
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = cleanCategory.isEmpty ? "未分类" : cleanCategory
        let selectedParent = parentID == nil ? nil : todos.first { $0.id == parentID }

        if !categories.contains(where: { $0.name == finalCategory }) {
            modelContext.insert(TodoCategory(name: finalCategory, colorHex: categories.nextColorHex()))
        }

        guard canAddTomorrow else { return }

        if let todo {
            todo.title = cleanTitle
            todo.category = finalCategory
            todo.dueDate = dueDate
            todo.kind = kind
            todo.targetCount = targetCount
            todo.isTomorrowImportant = tomorrowImportant
            todo.parentID = selectedParent?.id
            todo.notes = notes
        } else {
            let created = TodoItem(
                title: cleanTitle,
                category: finalCategory,
                dueDate: dueDate,
                kind: kind,
                targetCount: targetCount,
                isTomorrowImportant: tomorrowImportant,
                parentID: selectedParent?.id,
                notes: notes
            )
            modelContext.insert(created)
            for name in draftSubtasks {
                modelContext.insert(TodoItem(
                    title: name,
                    category: finalCategory,
                    dueDate: dueDate,
                    parentID: created.id
                ))
            }
        }
        dismiss()
    }
}

struct TimelineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @Query(sort: \TimelineEntry.start, order: .reverse) private var recentEntries: [TimelineEntry]

    let entry: TimelineEntry?
    let differenceNote: String?
    private let seededFromClock: Bool

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var day: Date
    @State private var startText: String
    @State private var endText: String
    @State private var todoID: UUID?
    @State private var tags: String
    @State private var notes: String
    @State private var isPlan: Bool
    @State private var isWasted: Bool
    @State private var checkedTodoIDs: Set<UUID> = []
    @State private var didSeedStart = false
    @State private var autoStartText: String?

    init(
        entry: TimelineEntry? = nil,
        defaultDate: Date = .now,
        startMinute: Int? = nil,
        defaultIsPlan: Bool,
        differenceNote: String? = nil
    ) {
        self.entry = entry
        self.differenceNote = differenceNote
        self.seededFromClock = startMinute != nil

        let calendar = Calendar.current
        let initialStart: Date
        if let entry {
            initialStart = entry.start
        } else if let startMinute {
            initialStart = calendar.date(
                bySettingHour: startMinute / 60,
                minute: startMinute % 60,
                second: 0,
                of: defaultDate
            ) ?? defaultDate
        } else if defaultIsPlan {
            initialStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        } else {
            initialStart = .now
        }

        let initialEnd = entry?.end ?? initialStart.addingTimeInterval(defaultIsPlan ? 3600 : 1800)

        _title = State(initialValue: entry?.title ?? "")
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initialEnd)
        _day = State(initialValue: initialStart)
        _startText = State(initialValue: entry.map { Self.timeString($0.start) } ?? "")
        _endText = State(initialValue: entry.map { Self.timeString($0.end) } ?? "")
        _todoID = State(initialValue: entry?.todoID)
        _tags = State(initialValue: entry?.tags ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isPlan = State(initialValue: entry?.isPlan ?? defaultIsPlan)
        _isWasted = State(initialValue: entry?.isWasted ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(TimeText.range(start, end))
                                .font(.title3.bold())
                                .foregroundStyle(AppStyle.ink)
                            Text(TimeText.duration(max(0, end.timeIntervalSince(start))))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppStyle.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(AppStyle.paleGreen, in: Capsule())
                            if isWasted {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(AppStyle.danger, in: Circle())
                                    .accessibilityLabel("虚度时间")
                            }
                        }
                        Text(title.isEmpty ? "还没写内容" : title)
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)

                        if let linkedTodo {
                            HStack(spacing: 5) {
                                Image(systemName: "link")
                                Text("关联待办")
                                    .opacity(0.85)
                                Text(linkedTodo.title)
                                    .lineLimit(1)
                                Text(linkedTodo.category)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.24), in: Capsule())
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AppStyle.green, in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let differenceNote {
                    Section {
                        Label(differenceNote, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppStyle.danger)
                    } header: {
                        Text("和计划不一致")
                    }
                }

                Section("内容") {
                    TextField("做了什么 / 计划做什么", text: $title)
                    Picker("记录类型", selection: $isPlan) {
                        Text("实际").tag(false)
                        Text("计划").tag(true)
                    }
                    Picker("关联到待办", selection: $todoID) {
                        Text("不关联").tag(Optional<UUID>.none)
                        ForEach(todos) { todo in
                            Text(todo.title).tag(Optional(todo.id))
                        }
                    }
                }

                Section("时间") {
                    DatePicker("日期", selection: $day, displayedComponents: .date)

                    HStack {
                        Text("开始")
                        Spacer()
                        TextField("14:13", text: $startText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 96)
                        if !startIsValid {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppStyle.danger)
                        }
                    }

                    HStack {
                        Text("结束")
                        Spacer()
                        TextField("15:00", text: $endText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 96)
                        if !endIsValid {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppStyle.danger)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            fillNow()
                        } label: {
                            Label("用现在的时间", systemImage: "clock.arrow.circlepath")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AppStyle.green)

                        Spacer(minLength: 0)

                        if !startText.isEmpty || !endText.isEmpty {
                            Button {
                                startText = ""
                                endText = ""
                            } label: {
                                Text("清空")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(AppStyle.muted)
                        }
                    }

                    Text("开始时间会接着上一条记录的结束时间，可以改。也可以直接打字：14:13、14.13、1413 都是下午 2:13，只写 9 就是 9:00；留空按现在算。")
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                }

                Section {
                    if checklistRows.isEmpty {
                        Text("没有未完成的待办，先把待办都完成了。")
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                    } else {
                        ForEach(checklistRows) { row in
                            Button {
                                toggleCompletion(row.todo)
                            } label: {
                                HStack(spacing: 9) {
                                    if row.depth > 0 {
                                        Rectangle()
                                            .fill(AppStyle.paleGreen)
                                            .frame(width: 2, height: 22)
                                            .padding(.leading, 6)
                                    }
                                    Image(systemName: checkedTodoIDs.contains(row.todo.id) ? "checkmark.circle.fill" : "circle")
                                        .font(row.depth > 0 ? .body : .title3)
                                        .foregroundStyle(checkedTodoIDs.contains(row.todo.id) ? AppStyle.green : AppStyle.muted.opacity(0.55))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.todo.title)
                                            .font(row.depth > 0 ? .caption.weight(.medium) : .subheadline.weight(.medium))
                                            .foregroundStyle(checkedTodoIDs.contains(row.todo.id) ? AppStyle.muted : AppStyle.ink)
                                            .strikethrough(checkedTodoIDs.contains(row.todo.id))
                                        Text(todoSubtitle(row.todo, depth: row.depth))
                                            .font(.caption2)
                                            .foregroundStyle(AppStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                    if checkedTodoIDs.contains(row.todo.id) {
                                        Text("已勾选")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppStyle.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppStyle.paleGreen, in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .padding(.leading, CGFloat(row.depth) * 12)
                                .background(
                                    checkedTodoIDs.contains(row.todo.id)
                                        ? AppStyle.paleGreen.opacity(0.55)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("这个时间完成了什么待办")
                } footer: {
                    Text("勾一下就把待办标记完成，这条记录会顺手关联到它；子待办也在这里，全部完成的待办不会再出现。")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                }

                Section {
                    Toggle(isOn: $isWasted) {
                        HStack(spacing: 9) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(isWasted ? AppStyle.danger : AppStyle.muted.opacity(0.7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("虚度时光 / 无脑刷手机")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppStyle.ink)
                                Text("这段时间没有产出")
                                    .font(.caption2)
                                    .foregroundStyle(AppStyle.muted)
                            }
                        }
                    }
                    .tint(AppStyle.danger)
                } header: {
                    Text("⚠️ 标记虚度")
                } footer: {
                    Text("打开后这段时间只标一个 ⚠️，时长就是你虚度的时间；复盘里会单独统计总数，不用在标题里写原因。")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
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
            .navigationTitle(entry == nil ? (isPlan ? "安排计划" : "快速记录") : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !startIsValid || !endIsValid || end < start
                        )
                }
            }
            .onChange(of: startText) { _, _ in applyTimes() }
            .onChange(of: endText) { _, _ in applyTimes() }
            .onChange(of: day) { _, _ in
                resetSeededStart()
                seedStartFromLastEntry()
                applyTimes()
            }
            .onChange(of: isPlan) { _, _ in
                resetSeededStart()
                seedStartFromLastEntry()
                applyTimes()
            }
            .onAppear { seedStartFromLastEntry() }
            .onChange(of: recentEntries.count) { _, _ in seedStartFromLastEntry() }
        }
    }

    private var linkedTodo: TodoItem? {
        guard let todoID else { return nil }
        return todos.first { $0.id == todoID }
    }

    private func seedStartFromLastEntry() {
        guard entry == nil, !seededFromClock, !didSeedStart else { return }
        guard startText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let calendar = Calendar.current
        let sameKind = recentEntries.filter {
            $0.isPlan == isPlan && calendar.isDate($0.start, inSameDayAs: day)
        }
        guard let last = sameKind.max(by: { $0.end < $1.end }) else { return }
        if calendar.isDateInToday(day), last.end > Date().addingTimeInterval(5 * 60) {
            return
        }

        didSeedStart = true
        let text = Self.timeString(last.end)
        autoStartText = text
        startText = text
        endText = ""
        applyTimes()
    }

    private func resetSeededStart() {
        guard entry == nil, !seededFromClock else { return }
        if let autoStartText, startText == autoStartText {
            startText = ""
            endText = ""
        }
        self.autoStartText = nil
        didSeedStart = false
    }

    private struct ChecklistRow: Identifiable {
        let todo: TodoItem
        let depth: Int

        var id: UUID { todo.id }
    }

    private var checklistRows: [ChecklistRow] {
        let roots = todos.filter { $0.parentID == nil }
        var rows: [ChecklistRow] = []

        for root in roots.sorted(by: checklistOrder) {
            let children = todos.filter { $0.parentID == root.id }
            let visibleChildren = children
                .filter { !$0.isCompleted || checkedTodoIDs.contains($0.id) }
                .sorted(by: checklistOrder)
            let rootVisible = !root.isCompleted || checkedTodoIDs.contains(root.id) || !visibleChildren.isEmpty
            guard rootVisible else { continue }
            rows.append(ChecklistRow(todo: root, depth: 0))
            rows.append(contentsOf: visibleChildren.map { ChecklistRow(todo: $0, depth: 1) })
        }
        return rows
    }

    private func checklistOrder(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
        let lhsChecked = checkedTodoIDs.contains(lhs.id) || lhs.isCompleted
        let rhsChecked = checkedTodoIDs.contains(rhs.id) || rhs.isCompleted
        if lhsChecked != rhsChecked { return !lhsChecked }
        if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
        return lhs.title < rhs.title
    }

    private func todoSubtitle(_ todo: TodoItem, depth: Int) -> String {
        var parts = [todo.category]
        if todo.kind == "count" {
            parts.append("\(todo.currentCount)/\(todo.targetCount) 次")
        }
        if depth > 0, let parent = parentTodo(of: todo) {
            parts.append("属于 \(parent.title)")
        }
        if Calendar.current.isDateInToday(todo.dueDate) {
            parts.append("今天")
        } else {
            parts.append(todo.dueDate.formatted(.dateTime.month().day()))
        }
        return parts.joined(separator: " · ")
    }

    private func parentTodo(of todo: TodoItem) -> TodoItem? {
        guard let parentID = todo.parentID else { return nil }
        return todos.first { $0.id == parentID }
    }

    private func rootTodo(of todo: TodoItem) -> TodoItem {
        var current = todo
        while let parent = parentTodo(of: current) {
            current = parent
        }
        return current
    }

    private func toggleCompletion(_ todo: TodoItem) {
        if checkedTodoIDs.contains(todo.id) {
            todo.isCompleted = false
            if todo.kind == "count" {
                todo.currentCount = 0
            }
            checkedTodoIDs.remove(todo.id)
            if todoID == todo.id {
                todoID = nil
            }
            if let parent = parentTodo(of: todo) {
                parent.isCompleted = false
                checkedTodoIDs.remove(parent.id)
            }
            return
        }

        todo.isCompleted = true
        if todo.kind == "count" {
            todo.currentCount = todo.targetCount
        }
        checkedTodoIDs.insert(todo.id)
        completeAncestors(of: todo)

        let anchorTodo = rootTodo(of: todo)
        if todoID == nil {
            todoID = anchorTodo.id
        }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = anchorTodo.title
        }
    }

    private func completeAncestors(of todo: TodoItem) {
        guard let parent = parentTodo(of: todo) else { return }
        let siblings = todos.filter { $0.parentID == parent.id }
        let allDone = siblings.allSatisfy { $0.isCompleted || checkedTodoIDs.contains($0.id) }
        guard allDone else { return }
        parent.isCompleted = true
        if parent.kind == "count" {
            parent.currentCount = parent.targetCount
        }
        checkedTodoIDs.insert(parent.id)
        completeAncestors(of: parent)
    }

    private var startIsValid: Bool {
        let text = startText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || Self.minutes(from: text) != nil
    }

    private var endIsValid: Bool {
        let text = endText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || Self.minutes(from: text) != nil
    }

    private func applyTimes() {
        let calendar = Calendar.current
        let defaultSpan: TimeInterval = isPlan ? 3600 : 1800

        if let startMinutes = Self.minutes(from: startText) {
            if let newStart = calendar.date(
                bySettingHour: startMinutes / 60,
                minute: startMinutes % 60,
                second: 0,
                of: day
            ) {
                start = newStart
            }
        } else {
            let parts = calendar.dateComponents([.hour, .minute], from: start)
            if let rebuilt = calendar.date(
                bySettingHour: parts.hour ?? 9,
                minute: parts.minute ?? 0,
                second: 0,
                of: day
            ) {
                start = rebuilt
            }
        }

        if let endMinutes = Self.minutes(from: endText) {
            if let newEnd = calendar.date(
                bySettingHour: endMinutes / 60,
                minute: endMinutes % 60,
                second: 0,
                of: day
            ) {
                end = newEnd
            }
        } else {
            end = start.addingTimeInterval(defaultSpan)
        }
    }

    private func fillNow() {
        let now = Date()
        startText = Self.timeString(now)
        endText = Self.timeString(now.addingTimeInterval(isPlan ? 3600 : 1800))
        day = now
        applyTimes()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func minutes(from text: String) -> Int? {
        let normalized = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let cleaned = normalized
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "时", with: ":")
            .replacingOccurrences(of: "點", with: ":")
            .replacingOccurrences(of: "点", with: ":")
            .replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: true)
        if parts.count == 2,
           let hour = Int(parts[0]),
           let minute = Int(parts[1]),
           (0...23).contains(hour),
           (0...59).contains(minute) {
            return hour * 60 + minute
        }

        let digits = cleaned.filter(\.isNumber)
        let allowed = CharacterSet(charactersIn: "0123456789: ")
        guard !digits.isEmpty, cleaned.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        switch digits.count {
        case 1, 2:
            guard let hour = Int(digits), (0...23).contains(hour) else { return nil }
            return hour * 60
        case 3, 4:
            guard let minute = Int(digits.suffix(2)),
                  let hour = Int(digits.prefix(digits.count - 2)),
                  (0...23).contains(hour),
                  (0...59).contains(minute) else { return nil }
            return hour * 60 + minute
        default:
            return nil
        }
    }

    private func save() {
        applyTimes()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.title = cleanTitle
            entry.start = start
            entry.end = end
            entry.todoID = todoID
            entry.tags = tags
            entry.notes = notes
            entry.isPlan = isPlan
            entry.isWasted = isWasted
        } else {
            modelContext.insert(TimelineEntry(
                title: cleanTitle,
                start: start,
                end: end,
                todoID: todoID,
                tags: tags,
                notes: notes,
                isPlan: isPlan,
                isWasted: isWasted
            ))
        }
        dismiss()
    }
}

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("新增分类") {
                    HStack {
                        TextField("分类名称，如 运动", text: $newName)
                        Button("添加", action: add)
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("已有分类") {
                    ForEach(categories) { category in
                        CategoryRow(category: category)
                    }
                    .onDelete(perform: delete)
                }

                Section {
                    Text("颜色就是时钟上填充的颜色。点圆点换色，左滑删除标签；删除标签不会删除待办，已有待办会保留原来的标签名称。")
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !categories.contains(where: { $0.name == name }) else { return }
        modelContext.insert(TodoCategory(name: name, colorHex: categories.nextColorHex()))
        newName = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}

private struct CategoryRow: View {
    @Query private var todos: [TodoItem]

    let category: TodoCategory
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(Array(AppStyle.palette.enumerated()), id: \.offset) { index, hex in
                    Button {
                        category.colorHex = hex
                    } label: {
                        Label(
                            AppStyle.paletteNames[index],
                            systemImage: category.colorHex == hex ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            } label: {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
            }
            .accessibilityLabel("更换颜色")

            TextField("分类名称", text: $draft)
                .onChange(of: draft) { _, newValue in
                    rename(to: newValue)
                }

            Text("\(todos.filter { $0.category == category.name }.count)")
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
        }
        .onAppear { draft = category.name }
    }

    private func rename(to newValue: String) {
        let name = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != category.name else { return }
        let oldName = category.name
        todos.filter { $0.category == oldName }.forEach { $0.category = name }
        category.name = name
    }
}
