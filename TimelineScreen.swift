import SwiftUI
import SwiftData

struct DayTimelineView: View {
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var selectedDate = Date.now
    @State private var editingEntry: TimelineEntry?
    @State private var newEntry: NewEntrySeed?

    private var dayEntries: [TimelineEntry] {
        entries.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var plans: [TimelineEntry] { dayEntries.filter(\.isPlan) }
    private var actuals: [TimelineEntry] { dayEntries.filter { !$0.isPlan } }

    private var comparisons: [PlanComparison] {
        DayReview.comparisons(plans: plans, actuals: actuals, todos: todos)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppStyle.green)

                    HStack(alignment: .top, spacing: 10) {
                        miniClock(title: "计划", entriesOfDay: plans, isPlan: true)
                        miniClock(title: "实际", entriesOfDay: actuals, isPlan: false)
                    }

                    HStack(spacing: 10) {
                        Button {
                            newEntry = NewEntrySeed(minute: nil, isPlan: false)
                        } label: {
                            Label("记实际", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(AppStyle.green, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        Button {
                            newEntry = NewEntrySeed(minute: nil, isPlan: true)
                        } label: {
                            Label("加计划", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(AppStyle.green)
                        }
                    }

                    if dayEntries.isEmpty {
                        EmptyHintCard(icon: "clock", title: "这一天还没有记录", subtitle: "补记也可以，时间线不需要填满")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(dayEntries) { entry in
                                TimelineRow(
                                    entry: entry,
                                    linkedTodo: todos.first { $0.id == entry.todoID },
                                    difference: comparison(for: entry)?.detail,
                                    isDifference: comparison(for: entry)?.kind.isDifference ?? false
                                ) {
                                    editingEntry = entry
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .navigationTitle("时间线")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $newEntry) { seed in
                TimelineEditor(defaultDate: selectedDate, startMinute: seed.minute, defaultIsPlan: seed.isPlan)
            }
            .sheet(item: $editingEntry) { entry in
                TimelineEditor(
                    entry: entry,
                    defaultDate: entry.start,
                    defaultIsPlan: entry.isPlan,
                    differenceNote: comparison(for: entry)?.kind.isDifference == true ? comparison(for: entry)?.detail : nil
                )
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("实际发生的")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppStyle.ink)
            Text("写一天的计划，也补记真实发生的事。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniClock(title: String, entriesOfDay: [TimelineEntry], isPlan: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(isPlan ? AppStyle.orange : AppStyle.green).frame(width: 6, height: 6)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppStyle.ink)
                Spacer()
                Button {
                    newEntry = NewEntrySeed(minute: nil, isPlan: isPlan)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(isPlan ? AppStyle.orange : AppStyle.green)
                }
                .buttonStyle(.plain)
            }
            DayClock(
                slices: entriesOfDay.map { makeSlice($0) },
                centerValue: "\(entriesOfDay.count)",
                centerCaption: "段"
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
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    private func makeSlice(_ entry: TimelineEntry) -> ClockSlice {
        let categoryName = todos.first { $0.id == entry.todoID }?.category ?? ""
        var color = categories.color(named: categoryName)
        let comparison = comparison(for: entry)
        if !entry.isPlan, comparison?.kind == .unplanned {
            color = AppStyle.orange
        }
        return ClockSlice(
            entry: entry,
            color: color,
            isFlagged: entry.isPlan && (comparison?.kind.isDifference ?? false)
        )
    }

    private func comparison(for entry: TimelineEntry) -> PlanComparison? {
        comparisons.first { $0.plan?.id == entry.id || $0.actual?.id == entry.id }
    }
}

struct TimelineRow: View {
    let entry: TimelineEntry
    let linkedTodo: TodoItem?
    let difference: String?
    let isDifference: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(TimeText.clock(entry.start))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppStyle.muted)
                Circle()
                    .fill(isDifference ? AppStyle.danger : (entry.isPlan ? AppStyle.orange : AppStyle.green))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(isDifference ? AppStyle.danger.opacity(0.35) : AppStyle.paleGreen)
                    .frame(width: 1, height: 46)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.ink)
                    Spacer()
                    Text(entry.isPlan ? "计划" : "实际")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(entry.isPlan ? AppStyle.orange : AppStyle.green)
                }
                Text(TimeText.range(entry.start, entry.end))
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
                if let difference, isDifference {
                    Text(difference)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppStyle.danger)
                }
            }
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
    }
}
