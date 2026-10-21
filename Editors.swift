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
            modelContext.insert(TodoItem(
                title: cleanTitle,
                category: finalCategory,
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

struct TimelineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]

    let entry: TimelineEntry?
    let differenceNote: String?

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var todoID: UUID?
    @State private var tags: String
    @State private var notes: String
    @State private var isPlan: Bool

    init(
        entry: TimelineEntry? = nil,
        defaultDate: Date = .now,
        startMinute: Int? = nil,
        defaultIsPlan: Bool,
        differenceNote: String? = nil
    ) {
        self.entry = entry
        self.differenceNote = differenceNote

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

        _title = State(initialValue: entry?.title ?? "")
        _start = State(initialValue: initialStart)
        _end = State(initialValue: entry?.end ?? initialStart.addingTimeInterval(defaultIsPlan ? 3600 : 1800))
        _todoID = State(initialValue: entry?.todoID)
        _tags = State(initialValue: entry?.tags ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isPlan = State(initialValue: entry?.isPlan ?? defaultIsPlan)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(TimeText.range(start, end))
                            .font(.title3.bold())
                            .foregroundStyle(AppStyle.ink)
                        Text(title.isEmpty ? "还没写内容" : title)
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
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
            .navigationTitle(entry == nil ? (isPlan ? "安排计划" : "快速记录") : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end < start)
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
                    Text("点色块换颜色；左滑删除分类。删除分类不会删除待办，已有待办会保留原来的分类名称。")
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
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]

    let category: TodoCategory
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 12) {
            Button(action: cycleColor) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
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

    private func cycleColor() {
        let palette = AppStyle.palette
        let currentIndex = palette.firstIndex(of: category.colorHex) ?? -1
        category.colorHex = palette[(currentIndex + 1) % palette.count]
    }
}
