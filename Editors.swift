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
    @State private var day: Date
    @State private var startText: String
    @State private var endText: String
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

        let initialEnd = entry?.end ?? initialStart.addingTimeInterval(defaultIsPlan ? 3600 : 1800)

        _title = State(initialValue: entry?.title ?? "")
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initialEnd)
        _day = State(initialValue: initialStart)
        _startText = State(initialValue: Self.timeString(initialStart))
        _endText = State(initialValue: Self.timeString(initialEnd))
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
                    DatePicker("日期", selection: $day, displayedComponents: .date)

                    HStack {
                        Text("开始")
                        Spacer()
                        TextField("09:00", text: $startText)
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
                        TextField("10:00", text: $endText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 96)
                        if !endIsValid {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppStyle.danger)
                        }
                    }

                    Text("直接输入时间即可：21:30、930、9 都行。也可以在首页点时钟空白处选时间。")
                        .font(.caption)
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
            .onChange(of: day) { _, _ in applyTimes() }
        }
    }

    private var startIsValid: Bool {
        Self.minutes(from: startText) != nil
    }

    private var endIsValid: Bool {
        Self.minutes(from: endText) != nil
    }

    private func applyTimes() {
        guard let startMinutes = Self.minutes(from: startText),
              let endMinutes = Self.minutes(from: endText) else { return }
        let calendar = Calendar.current
        if let newStart = calendar.date(
            bySettingHour: startMinutes / 60,
            minute: startMinutes % 60,
            second: 0,
            of: day
        ) {
            start = newStart
        }
        if let newEnd = calendar.date(
            bySettingHour: endMinutes / 60,
            minute: endMinutes % 60,
            second: 0,
            of: day
        ) {
            end = newEnd
        }
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
        let cleaned = text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "点", with: ":")
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
