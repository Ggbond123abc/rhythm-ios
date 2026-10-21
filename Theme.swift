import SwiftUI
import Foundation

enum AppStyle {
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.19)
    static let muted = Color(red: 0.47, green: 0.53, blue: 0.51)
    static let canvas = Color(red: 0.96, green: 0.96, blue: 0.92)
    static let green = Color(red: 0.20, green: 0.48, blue: 0.39)
    static let paleGreen = Color(red: 0.87, green: 0.92, blue: 0.86)
    static let orange = Color(red: 0.78, green: 0.39, blue: 0.22)
    static let danger = Color(red: 0.77, green: 0.18, blue: 0.16)
    static let untagged = Color(red: 0.54, green: 0.56, blue: 0.57)

    static let palette = [
        "#4F7CAC", "#7A6FA8", "#C9A227", "#C4705A",
        "#4E8C74", "#B4698C", "#5E8FA6", "#8A8F98"
    ]
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
