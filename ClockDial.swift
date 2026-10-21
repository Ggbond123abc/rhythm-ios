import SwiftUI

struct ClockSlice: Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let title: String
    let color: Color
    let isFlagged: Bool
    let startMinute: Double
    let endMinute: Double

    init(
        entry: TimelineEntry,
        color: Color,
        isFlagged: Bool = false,
        calendar: Calendar = .current
    ) {
        self.id = entry.id
        self.start = entry.start
        self.end = entry.end
        self.title = entry.title
        self.color = color
        self.isFlagged = isFlagged

        let startParts = calendar.dateComponents([.hour, .minute], from: entry.start)
        let begin = Double((startParts.hour ?? 0) * 60 + (startParts.minute ?? 0))

        let endParts = calendar.dateComponents([.hour, .minute], from: entry.end)
        var finish = Double((endParts.hour ?? 0) * 60 + (endParts.minute ?? 0))
        if !calendar.isDate(entry.end, inSameDayAs: entry.start) {
            finish = 1440
        }
        if finish <= begin {
            finish = begin + 10
        } else if finish - begin < 6 {
            finish = begin + 6
        }

        self.startMinute = begin
        self.endMinute = min(1440, finish)
    }

    func contains(_ minute: Double) -> Bool {
        minute >= startMinute && minute < max(endMinute, startMinute + 0.01)
    }
}

struct DayClock: View {
    let slices: [ClockSlice]
    let centerValue: String
    let centerCaption: String
    var onTap: (ClockSlice?, Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: side / 2, y: side / 2)
            let outer = side / 2 - 18
            let thickness = max(18, side * 0.18)
            let inner = outer - thickness
            let labelStep = side >= 210 ? 1 : (side >= 145 ? 2 : 3)
            let labelRadius = outer + 9
            let labelFont = max(6, side * 0.042)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: inner * 2, height: inner * 2)

                ForEach(slices) { slice in
                    ClockArcShape(
                        startMinute: slice.startMinute,
                        endMinute: slice.endMinute,
                        thickness: thickness
                    )
                    .fill(slice.isFlagged ? AppStyle.danger : slice.color)
                    .overlay(
                        ClockArcShape(
                            startMinute: slice.startMinute,
                            endMinute: slice.endMinute,
                            thickness: thickness
                        )
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
                }

                Canvas { context, size in
                    let middle = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 18
                    for hour in 0..<24 {
                        let angle = Double(hour) / 24 * 2 * .pi - .pi / 2
                        let major = hour % 6 == 0
                        let outerTick = radius + (major ? 3 : 2)
                        let innerTick = radius
                        var path = Path()
                        path.move(to: CGPoint(
                            x: middle.x + CGFloat(cos(angle)) * innerTick,
                            y: middle.y + CGFloat(sin(angle)) * innerTick
                        ))
                        path.addLine(to: CGPoint(
                            x: middle.x + CGFloat(cos(angle)) * outerTick,
                            y: middle.y + CGFloat(sin(angle)) * outerTick
                        ))
                        context.stroke(
                            path,
                            with: .color(AppStyle.muted.opacity(major ? 0.6 : 0.3)),
                            lineWidth: major ? 1.1 : 0.5
                        )
                    }
                }

                ForEach(Array(stride(from: 0, to: 24, by: labelStep)), id: \.self) { hour in
                    let angle = Double(hour) / 24 * 2 * .pi - .pi / 2
                    Text("\(hour)")
                        .font(.system(
                            size: labelFont,
                            weight: hour % 6 == 0 ? .bold : .regular,
                            design: .rounded
                        ))
                        .foregroundStyle(hour % 6 == 0 ? AppStyle.ink.opacity(0.75) : AppStyle.muted.opacity(0.85))
                        .position(
                            x: center.x + CGFloat(cos(angle)) * labelRadius,
                            y: center.y + CGFloat(sin(angle)) * labelRadius
                        )
                }

                VStack(spacing: 1) {
                    Text(centerValue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppStyle.ink)
                    Text(centerCaption)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(AppStyle.muted)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let dx = Double(value.location.x - center.x)
                        let dy = Double(value.location.y - center.y)
                        let radius = sqrt(dx * dx + dy * dy)
                        guard radius > Double(inner) - 10 else { return }
                        var degrees = atan2(dy, dx) * 180 / .pi + 90
                        if degrees < 0 { degrees += 360 }
                        let minute = degrees / 360 * 1440
                        onTap(slices.first { $0.contains(minute) }, minute)
                    }
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ClockArcShape: Shape {
    let startMinute: Double
    let endMinute: Double
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 - 18
        let inner = outer - thickness
        let startAngle = Angle.degrees(startMinute / 1440 * 360 - 90)
        let endAngle = Angle.degrees(endMinute / 1440 * 360 - 90)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
