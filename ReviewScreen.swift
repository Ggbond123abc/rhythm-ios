import SwiftUI
import SwiftData

struct ReviewScreen: View {
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var selectedDate = Date.now
    @State private var editingEntry: TimelineEntry?

    private var dayEntries: [TimelineEntry] {
        entries.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var plans: [TimelineEntry] { dayEntries.filter(\.isPlan) }
    private var actuals: [TimelineEntry] { dayEntries.filter { !$0.isPlan } }

    private var comparisons: [PlanComparison] {
        DayReview.comparisons(plans: plans, actuals: actuals, todos: todos)
    }

    private var differences: [PlanComparison] {
        comparisons.filter { $0.kind.isDifference }
    }

    private var onTime: [PlanComparison] {
        comparisons.filter { !$0.kind.isDifference }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    DatePicker("复盘日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppStyle.green)

                    HStack(spacing: 10) {
                        SummaryTile(title: "计划", count: plans.count, color: AppStyle.orange)
                        SummaryTile(title: "实际", count: actuals.count, color: AppStyle.green)
                        SummaryTile(title: "差异", count: differences.count, color: differences.isEmpty ? AppStyle.green : AppStyle.danger)
                    }

                    clockRow

                    if differences.isEmpty {
                        EmptyHintCard(
                            icon: plans.isEmpty ? "sparkles" : "checkmark.seal",
                            title: plans.isEmpty ? "还没有可复盘的内容" : "计划和实际一致",
                            subtitle: plans.isEmpty ? "在时间线里写计划，再记录实际发生了什么" : "没有发现差异，按计划过完了这一天"
                        )
                    } else {
                        differenceList
                    }

                    if !onTime.isEmpty {
                        onTimeList
                    }
                }
                .padding(18)
            }
            .background(AppStyle.canvas.ignoresSafeArea())
            .navigationTitle("复盘")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingEntry) { entry in
                TimelineEditor(
                    entry: entry,
                    defaultDate: entry.start,
                    defaultIsPlan: entry.isPlan,
                    differenceNote: comparisons.first {
                        ($0.plan?.id == entry.id || $0.actual?.id == entry.id) && $0.kind.isDifference
                    }?.detail
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("计划和实际")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppStyle.ink)
            Text("计划钟上红色的时段，就是和实际不一样的地方。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clockRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                clockCard(title: "计划", entriesOfDay: plans, isPlan: true)
                clockCard(title: "实际", entriesOfDay: actuals, isPlan: false)
            }
            HStack(spacing: 12) {
                legend(color: AppStyle.danger, text: "计划差异")
                legend(color: AppStyle.orange, text: "计划外")
                Spacer(minLength: 0)
                Text("点色块看详情")
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted)
            }
        }
    }

    private func clockCard(title: String, entriesOfDay: [TimelineEntry], isPlan: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPlan ? AppStyle.orange : AppStyle.green)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppStyle.ink)
                Spacer(minLength: 0)
            }
            DayClock(
                slices: entriesOfDay.map { makeSlice($0) },
                centerValue: "\(entriesOfDay.count) 段",
                centerCaption: entriesOfDay.isEmpty ? "空白" : TimeText.duration(entriesOfDay.reduce(0) { $0 + $1.duration })
            ) { slice, _ in
                if let slice, let entry = entries.first(where: { $0.id == slice.id }) {
                    editingEntry = entry
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
    }

    private var differenceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("差异 \(differences.count) 处")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)

            ForEach(differences) { comparison in
                let tint = color(for: comparison.kind)
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(comparison.kind.label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(tint, in: Capsule())
                            Text(comparison.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppStyle.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        Text(comparison.detail)
                            .font(.caption)
                            .foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .onTapGesture {
                    editingEntry = comparison.plan ?? comparison.actual
                }
            }
        }
    }

    private var onTimeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("按计划完成")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)
            ForEach(onTime) { comparison in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppStyle.green)
                    Text(comparison.title)
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                    Spacer()
                    if let plan = comparison.plan {
                        Text(TimeText.range(plan.start, plan.end))
                            .font(.caption2)
                            .foregroundStyle(AppStyle.muted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func makeSlice(_ entry: TimelineEntry) -> ClockSlice {
        let categoryName = todos.first { $0.id == entry.todoID }?.category ?? ""
        var color = categories.color(named: categoryName)
        let comparison = comparisons.first { $0.plan?.id == entry.id || $0.actual?.id == entry.id }
        if !entry.isPlan, comparison?.kind == .unplanned {
            color = AppStyle.orange
        }
        return ClockSlice(
            entry: entry,
            color: color,
            isFlagged: entry.isPlan && (comparison?.kind.isDifference ?? false)
        )
    }

    private func color(for kind: PlanComparison.Kind) -> Color {
        switch kind {
        case .missed, .delayed, .overtime, .partial:
            return AppStyle.danger
        case .unplanned:
            return AppStyle.orange
        case .onTime:
            return AppStyle.green
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(AppStyle.muted)
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(AppStyle.muted)
            Text("\(count)").font(.title2.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 15))
    }
}
