import SwiftUI
import Foundation

enum AppStyle {
    static let ink = Color(red: 0.11, green: 0.23, blue: 0.18)
    static let muted = Color(red: 0.38, green: 0.47, blue: 0.42)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.94)
    static let green = Color(red: 0.26, green: 0.46, blue: 0.36)
    static let paleGreen = Color(red: 0.87, green: 0.92, blue: 0.87)
    static let orange = Color(red: 0.72, green: 0.45, blue: 0.18)
    static let danger = Color(red: 0.70, green: 0.24, blue: 0.21)
    static let untagged = Color(red: 0.48, green: 0.53, blue: 0.50)

    static let palette = [
        "#4E8C74", "#6C9A8B", "#A7B85C", "#C9A227",
        "#C4705A", "#8A7CA8", "#5E8FA6", "#8A8F98"
    ]

    static let paletteNames = ["绿", "青", "橄榄", "金", "陶土", "紫", "湖蓝", "灰"]
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            self.init(
                red: Double((value & 0xFF0000) >> 16) / 255,
                green: Double((value & 0x00FF00) >> 8) / 255,
                blue: Double(value & 0x0000FF) / 255
            )
        } else {
            self.init(red: 0.54, green: 0.56, blue: 0.57)
        }
    }
}

extension Array where Element == TodoCategory {
    func color(named name: String) -> Color {
        guard let match = first(where: { $0.name == name }) else { return AppStyle.untagged }
        return Color(hex: match.colorHex)
    }

    func nextColorHex() -> String {
        let used = Set(map(\.colorHex))
        if let free = AppStyle.palette.first(where: { !used.contains($0) }) {
            return free
        }
        return AppStyle.palette[count % AppStyle.palette.count]
    }
}

enum TimeText {
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "\(clock(start))–\(clock(end))"
    }
}

struct EmptyHintCard: View {
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
