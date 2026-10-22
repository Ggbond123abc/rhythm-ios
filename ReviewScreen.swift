import SwiftUI
import SwiftData

struct ReviewScreen: View {
    @Query(sort: \TimelineEntry.start) private var entries: [TimelineEntry]
    @Query(sort: \TodoItem.dueDate) private var todos: [TodoItem]
    @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]

    @State private var scope: ReviewScope = .day
    @State private var anchor = Date.now
    @State private var editingEntry: TimelineEntry?
    @State private var showingBackground = false

    private var summary: TodoReviewSummary {
        TodoReview.summary(scope: scope, anchor: anchor, todos: todos)
    }

    private var rangeEntries: [TimelineEntry] {
        entries.filter { $0.start >= summary.start && $0.start < summary.end }
            .sorted { $0.start < $1.start }
    }

    private var plans: [TimelineEntry] { rangeEntries.filter(\.isPlan) }
    private var actuals: [TimelineEntry] { rangeEntries.filter { !$0.isPlan } }

    private var comparisons: [PlanComparison] {
        let calendar = Calendar.current
        let days = Set(rangeEntries.map { calendar.startOfDay(for: $0.start) }).sorted()
        var result: [PlanComparison] = []
        for day in days {
            let dayEntries = rangeEntries.filter { calendar.isDate($0.start, inSameDayAs: day) }
            result.append(contentsOf: DayReview.comparisons(
                plans: dayEntries.filter(\.isPlan),
                actuals: dayEntries.filter { !$0.isPlan },
                todos: todos
            ))
        }
        return result
    }

    private var differences: [PlanComparison] {
        comparisons.filter { $0.kind.isDifference }
    }

    private var visibleDifferences: [PlanComparison] {
        scope == .day ? differences : Array(differences.prefix(10))
    }

    private var onTime: [PlanComparison] {
        comparisons.filter { !$0.kind.isDifference }
    }

    private var timeStats: TimeReviewSummary {
        TodoReview.timeSummary(scope: scope, anchor: anchor, entries: entries, todos: todos)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scopePicker
                    periodNavigator
                    todoReviewSection
                    timeSection
                }
                .padding(18)
            }
            .background(PageBackgroundView(page: .review))
            .navigationTitle("复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBackground = true
                    } label: {
                        Image(systemName: "photo")
                    }
                    .accessibilityLabel("更换复盘页背景")
                }
            }
            .sheet(isPresented: $showingBackground) {
                BackgroundPickerSheet(page: .review)
            }
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
            Text("按日、周、月回看待办和时间，计划钟上红色的时段就是和实际不一样的地方。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scopePicker: some View {
        Picker("复盘范围", selection: $scope) {
            ForEach(ReviewScope.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var periodNavigator: some View {
        HStack(spacing: 10) {
            Button {
                anchor = TodoReview.shiftedAnchor(anchor, scope: scope, step: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("上一段")

            VStack(spacing: 2) {
                Text(summary.rangeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppStyle.ink)
                if scope == .day {
                    DatePicker("", selection: $anchor, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(AppStyle.green)
                } else {
                    Text(scope == .week ? "一整周" : "一整月")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                anchor = TodoReview.shiftedAnchor(anchor, scope: scope, step: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.85), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一段")

            Button {
                anchor = .now
            } label: {
                Text("今天")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppStyle.paleGreen, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var todoReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("待办复盘")
                    .font(.title3.bold())
                    .foregroundStyle(AppStyle.ink)
                Text(scope == .day ? "这一天" : (scope == .week ? "这一周" : "这个月"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppStyle.green, in: Capsule())
                Spacer()
            }

            HStack(spacing: 10) {
                SummaryTile(title: "完成", count: summary.completed, color: AppStyle.green)
                SummaryTile(
                    title: "未完成",
                    count: summary.leading,
                    color: summary.leading == 0 ? AppStyle.green : AppStyle.orange
                )
                SummaryTile(title: "顺延过", count: summary.deferred, color: AppStyle.muted)
            }

            if summary.total == 0 {
                EmptyHintCard(
                    icon: "checklist",
                    title: "这段时间没有待办",
                    subtitle: "去「今天」加几件事，再回来复盘"
                )
            } else {
                completionBar
                if scope != .day {
                    bucketChart
                }
            }

            if !summary.byCategory.isEmpty {
                categoryBreakdown
            }

            if !summary.unfinished.isEmpty {
                unfinishedList
            }
        }
    }

    private var completionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppStyle.paleGreen)
                    Capsule()
                        .fill(AppStyle.green)
                        .frame(width: summary.completionRate == 0 ? 0 : max(6, geo.size.width * CGFloat(summary.completionRate)))
                }
            }
            .frame(height: 10)

            Text("完成率 \(Int((summary.completionRate * 100).rounded()))%　·　\(summary.completed)/\(summary.total) 件")
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
        }
    }

    private var bucketChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(summary.buckets) { bucket in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(bucket))
                            .frame(height: barHeight(bucket))
                        if scope == .week {
                            Text(bucket.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9))
                                .foregroundStyle(AppStyle.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92, alignment: .bottom)

            Text(scope == .week ? "每天完成的待办" : "每天完成的待办（一整个月）")
                .font(.caption2)
                .foregroundStyle(AppStyle.muted)
        }
        .padding(12)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    private func barHeight(_ bucket: TodoDayBucket) -> CGFloat {
        if bucket.total == 0 { return 4 }
        return 10 + CGFloat(bucket.ratio) * 54
    }

    private func barColor(_ bucket: TodoDayBucket) -> Color {
        if bucket.total == 0 { return AppStyle.paleGreen.opacity(0.55) }
        if bucket.completed == 0 { return AppStyle.orange.opacity(0.45) }
        return AppStyle.green.opacity(0.85)
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("分类完成情况")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)

            ForEach(summary.byCategory) { stat in
                HStack(spacing: 9) {
                    Circle()
                        .fill(categories.color(named: stat.name))
                        .frame(width: 9, height: 9)
                    Text(stat.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppStyle.ink)
                    Spacer(minLength: 4)
                    Text("\(stat.completed)/\(stat.total)")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppStyle.paleGreen)
                            .frame(width: 64, height: 6)
                        Capsule()
                            .fill(categories.color(named: stat.name))
                            .frame(width: CGFloat(64 * stat.ratio), height: 6)
                    }
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private var unfinishedList: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("还没完成的 \(summary.unfinished.count) 件")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)

            ForEach(Array(summary.unfinished.prefix(8))) { todo in
                HStack(spacing: 9) {
                    Button {
                        todo.isCompleted = true
                    } label: {
                        Image(systemName: "circle")
                            .foregroundStyle(AppStyle.muted.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("标记完成 \(todo.title)")

                    Text(todo.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppStyle.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(todo.dueDate.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                }
            }

            if summary.unfinished.count > 8 {
                Text("还有 \(summary.unfinished.count - 8) 件，去「待办历史」里继续处理")
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted)
            }
        }
        .padding(12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(scope == .day ? "时间复盘" : "时间使用")
                    .font(.title3.bold())
                    .foregroundStyle(AppStyle.ink)
                Spacer()
            }

            HStack(spacing: 10) {
                SummaryTile(title: "计划", count: plans.count, color: AppStyle.orange)
                SummaryTile(title: "实际", count: actuals.count, color: AppStyle.green)
                SummaryTile(
                    title: "差异",
                    count: differences.count,
                    color: differences.isEmpty ? AppStyle.green : AppStyle.danger
                )
            }

            if scope == .day {
                if rangeEntries.isEmpty {
                    EmptyHintCard(
                        icon: "clock",
                        title: "这一天还没有记录",
                        subtitle: "在时间线里写计划，再记录实际发生了什么"
                    )
                } else {
                    clockRow
                }
            } else {
                timeTotalsRow
            }

            if timeStats.total > 0 {
                timeSpentSection
            }

            if differences.isEmpty {
                if !rangeEntries.isEmpty {
                    EmptyHintCard(
                        icon: "checkmark.seal",
                        title: "计划和实际一致",
                        subtitle: "没有发现差异，按计划过完了这段时间"
                    )
                }
            } else {
                differenceList
            }

            if !onTime.isEmpty {
                onTimeList
            }
        }
    }

    private var timeTotalsRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("计划总时长")
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                Text(TimeText.duration(timeStats.planned))
                    .font(.headline)
                    .foregroundStyle(AppStyle.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 4) {
                Text("实际总时长")
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                Text(TimeText.duration(timeStats.total))
                    .font(.headline)
                    .foregroundStyle(AppStyle.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 15))
        }
    }

    private var timeSpentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("花了多少时间")
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                Spacer()
                Text("共 \(TimeText.duration(timeStats.total))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.green)
            }

            HStack(spacing: 10) {
                timeMetric(title: scope == .day ? "这一天" : "平均每天", value: TimeText.duration(timeStats.averagePerActiveDay))
                timeMetric(title: "记录段数", value: "\(timeStats.byTodo.reduce(0) { $0 + $1.sessions }) 段")
                timeMetric(title: "单件最久", value: TimeText.duration(timeStats.longestSession))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(timeStats.byTodo) { stat in
                    timeStatRow(stat)
                }
            }
            .padding(12)
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))

            if !timeStats.byCategory.isEmpty {
                categoryTimeCard
            }

            if timeStats.wasted > 0 {
                wastedCard
            }

            if timeStats.byDay.count > 1, timeStats.byDay.contains(where: { $0.duration > 0 }) {
                dailyTimeCard
            }
        }
    }

    private var wastedCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(AppStyle.danger)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("虚度 \(TimeText.duration(timeStats.wasted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.ink)
                    Text("\(timeStats.wastedCount) 段")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppStyle.danger.opacity(0.12), in: Capsule())
                }
                Text("⚠️ 是你手动标记的「虚度 / 无脑刷手机」时段，这段时长就是虚度了多少。")
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppStyle.danger.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppStyle.danger.opacity(0.28), lineWidth: 1)
        )
    }

    private func timeStatRow(_ stat: TodoTimeStat) -> some View {
        let ratio = timeStats.total == 0 ? 0 : stat.duration / timeStats.total
        let tint = timeStatColor(stat)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text(stat.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppStyle.ink)
                    .lineLimit(1)
                if !stat.isLinked {
                    Text("未关联")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AppStyle.canvas, in: Capsule())
                }
                Spacer(minLength: 4)
                Text(TimeText.duration(stat.duration))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.ink)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppStyle.paleGreen.opacity(0.7))
                        Capsule()
                            .fill(tint.opacity(0.9))
                            .frame(width: max(2, geo.size.width * CGFloat(ratio)))
                    }
                }
                .frame(height: 5)
                Text("\(stat.sessions) 段")
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var categoryTimeCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("分类用时")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)
            ForEach(timeStats.byCategory) { stat in
                HStack(spacing: 9) {
                    Circle()
                        .fill(categoryTimeColor(stat.name))
                        .frame(width: 9, height: 9)
                    Text(stat.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppStyle.ink)
                    Spacer(minLength: 4)
                    Text("\(Int((stat.share * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.muted)
                    Text(TimeText.duration(stat.duration))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.ink)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private func timeMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 13))
    }

    private var dailyTimeCard: some View {
        let peak = timeStats.byDay.map(\.duration).max() ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Text("每天花的时间")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(timeStats.byDay) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.duration > 0 ? AppStyle.green.opacity(0.8) : AppStyle.paleGreen.opacity(0.5))
                            .frame(height: dailyBarHeight(day.duration, peak: peak))
                        if timeStats.byDay.count <= 7 {
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9))
                                .foregroundStyle(AppStyle.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 88, alignment: .bottom)
        }
        .padding(12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private func dailyBarHeight(_ duration: TimeInterval, peak: TimeInterval) -> CGFloat {
        guard peak > 0, duration > 0 else { return 4 }
        return 8 + CGFloat(duration / peak) * 56
    }

    private func timeStatColor(_ stat: TodoTimeStat) -> Color {
        stat.isLinked ? categories.color(named: stat.category) : AppStyle.muted
    }

    private func linkedTodo(for comparison: PlanComparison) -> TodoItem? {
        guard let id = comparison.plan?.todoID ?? comparison.actual?.todoID else { return nil }
        return todos.first { $0.id == id }
    }

    private func categoryTimeColor(_ name: String) -> Color {
        if name == "未关联待办" { return AppStyle.muted }
        return categories.color(named: name)
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

            ForEach(visibleDifferences) { comparison in
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
                            if let todo = linkedTodo(for: comparison) {
                                HStack(spacing: 3) {
                                    Image(systemName: "link")
                                    Text(todo.title)
                                        .lineLimit(1)
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(categories.color(named: todo.category), in: Capsule())
                            }
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

            if visibleDifferences.count < differences.count {
                Text("只显示前 10 条，切到「日」可以逐天查看全部差异。")
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted)
            }
        }
    }

    private var onTimeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("按计划完成")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.muted)
            ForEach(Array(onTime.prefix(8))) { comparison in
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
            isFlagged: entry.isPlan && (comparison?.kind.isDifference ?? false),
            isWasted: !entry.isPlan && entry.isWasted
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
