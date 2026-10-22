import SwiftUI
import SwiftData

struct TodoHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate, order: .reverse) private var todos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var scope: Scope = .past
    @State private var editingTodo: TodoItem?

    enum Scope: String, CaseIterable, Identifiable {
        case past = "过去"
        case pending = "未完成"
        case all = "全部"

        var id: String { rawValue }
    }

    private var filtered: [TodoItem] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let roots = todos.filter { $0.parentID == nil }
        switch scope {
        case .past:
            return roots.filter { Calendar.current.startOfDay(for: $0.dueDate) < startOfToday }
        case .pending:
            return roots.filter { !$0.isCompleted }
        case .all:
            return roots
        }
    }

    private struct DayGroup: Identifiable {
        let date: Date
        let items: [TodoItem]
        var id: Date { date }
    }

    private var groups: [DayGroup] {
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.dueDate) }
        return grouped.keys.sorted(by: >).map { key in
            let items = (grouped[key] ?? []).sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.title < rhs.title
            }
            return DayGroup(date: key, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("范围", selection: $scope) {
                    ForEach(Scope.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                if groups.isEmpty {
                    Spacer()
                    EmptyHintCard(
                        icon: "clock.arrow.circlepath",
                        title: "这里还没有记录",
                        subtitle: "过去日期的待办会按天归档在这里"
                    )
                    .padding(.horizontal, 18)
                    Spacer()
                } else {
                    List {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.items) { todo in
                                    HistoryRow(
                                        todo: todo,
                                        categories: categories,
                                        onEdit: { editingTodo = todo }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text(dateTitle(group.date))
                                    Spacer()
                                    if group.items.contains(where: { !$0.isCompleted }) {
                                        Button("全部顺延到今天") {
                                            group.items.filter { !$0.isCompleted }.forEach { $0.deferTo(.now) }
                                        }
                                        .font(.caption.weight(.semibold))
                                        .textCase(nil)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .navigationTitle("待办历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditor(todo: todo, initialDate: todo.dueDate, tomorrowImportant: todo.isTomorrowImportant)
            }
        }
    }

    private func dateTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day().weekday(.abbreviated))
    }
}

private struct HistoryRow: View {
    @Environment(\.modelContext) private var modelContext
    let todo: TodoItem
    let categories: [TodoCategory]
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                todo.isCompleted.toggle()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? AppStyle.green : AppStyle.muted.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "撤销完成" : "标记完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(todo.isCompleted ? AppStyle.muted : AppStyle.ink)
                    .strikethrough(todo.isCompleted)
                HStack(spacing: 6) {
                    Text(todo.category)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categories.color(named: todo.category).opacity(0.32), in: Capsule())
                    if todo.deferCount > 0 {
                        Text("顺延 \(todo.deferCount) 次")
                            .foregroundStyle(AppStyle.orange)
                    }
                    if todo.kind == "count" {
                        Text("\(todo.currentCount)/\(todo.targetCount) 次")
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
            }

            Spacer(minLength: 0)

            if !todo.isCompleted && todo.isOverdue {
                Button {
                    todo.deferTo(.now)
                } label: {
                    Text("顺延")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppStyle.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .leading) {
            if !todo.isCompleted {
                Button {
                    todo.deferTo(.now)
                } label: {
                    Label("顺延", systemImage: "arrow.uturn.forward")
                }
                .tint(AppStyle.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(todo)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
