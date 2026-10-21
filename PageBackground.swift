import SwiftUI
import PhotosUI
import UIKit

enum AppPage: String, CaseIterable, Identifiable {
    case today
    case timeline
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .timeline: return "时间线"
        case .review: return "复盘"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .timeline: return "clock"
        case .review: return "chart.bar.xaxis"
        }
    }
}

struct BackgroundTheme: Identifiable {
    let id: Int
    let name: String
    let hexColors: [String]

    var colors: [Color] { hexColors.map { Color(hex: $0) } }

    static let presets: [BackgroundTheme] = [
        BackgroundTheme(id: 0, name: "苔原", hexColors: ["#F5F8F0", "#D9E7D2"]),
        BackgroundTheme(id: 1, name: "竹林", hexColors: ["#EAF3E5", "#BBD8BF"]),
        BackgroundTheme(id: 2, name: "晨雾", hexColors: ["#F7F9F3", "#CEDFD8"]),
        BackgroundTheme(id: 3, name: "稻谷", hexColors: ["#F8F5EA", "#E0DCBE"]),
        BackgroundTheme(id: 4, name: "湖岸", hexColors: ["#EEF6F3", "#C9E1DB"]),
        BackgroundTheme(id: 5, name: "原野", hexColors: ["#F4F8EC", "#CEE0B8"])
    ]

    static func theme(at index: Int) -> BackgroundTheme {
        guard !presets.isEmpty else {
            return BackgroundTheme(id: 0, name: "苔原", hexColors: ["#F5F8F0", "#D9E7D2"])
        }
        let safeIndex = min(max(index, 0), presets.count - 1)
        return presets[safeIndex]
    }
}

final class PageBackgroundStore: ObservableObject {
    static let shared = PageBackgroundStore()

    @Published private var images: [AppPage: UIImage] = [:]
    @Published private var themeIndexes: [AppPage: Int] = [:]
    @Published private var revision = 0

    private let defaults = UserDefaults.standard

    private init() {
        for page in AppPage.allCases {
            themeIndexes[page] = defaults.integer(forKey: Self.themeKey(for: page))
            if let data = try? Data(contentsOf: Self.fileURL(for: page)),
               let image = UIImage(data: data) {
                images[page] = image
            }
        }
    }

    func image(for page: AppPage) -> UIImage? {
        _ = revision
        return images[page]
    }

    func hasImage(for page: AppPage) -> Bool {
        image(for: page) != nil
    }

    func themeIndex(for page: AppPage) -> Int {
        _ = revision
        return themeIndexes[page] ?? 0
    }

    func setTheme(_ index: Int, for page: AppPage) {
        themeIndexes[page] = index
        defaults.set(index, forKey: Self.themeKey(for: page))
        revision += 1
    }

    func setImage(from data: Data, for page: AppPage) {
        guard let image = UIImage(data: data) else { return }
        let resized = Self.resized(image, maxSide: 1600)
        guard let jpeg = resized.jpegData(compressionQuality: 0.86) else { return }
        try? jpeg.write(to: Self.fileURL(for: page), options: .atomic)
        images[page] = resized
        revision += 1
    }

    func clearImage(for page: AppPage) {
        try? FileManager.default.removeItem(at: Self.fileURL(for: page))
        images[page] = nil
        revision += 1
    }

    private static func themeKey(for page: AppPage) -> String {
        "page.background.theme.\(page.rawValue)"
    }

    private static func fileURL(for page: AppPage) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("page-background-\(page.rawValue).jpg")
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

struct PageBackgroundView: View {
    let page: AppPage
    @ObservedObject private var store = PageBackgroundStore.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: BackgroundTheme.theme(at: store.themeIndex(for: page)).colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image = store.image(for: page) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                Color.white.opacity(0.32)
            }
        }
        .ignoresSafeArea()
    }
}

struct BackgroundPickerSheet: View {
    let page: AppPage

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PageBackgroundStore.shared
    @State private var pickerItem: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(BackgroundTheme.presets) { theme in
                            Button {
                                store.setTheme(theme.id, for: page)
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(
                                            colors: theme.colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(height: 62)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    store.themeIndex(for: page) == theme.id && !store.hasImage(for: page)
                                                        ? AppStyle.green
                                                        : Color.clear,
                                                    lineWidth: 2.4
                                                )
                                        )
                                    Text(theme.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppStyle.ink)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("自然底色")
                } footer: {
                    Text("没有选照片时，用这套绿色底色。")
                }

                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label(store.hasImage(for: page) ? "换一张背景图" : "从相册选一张背景图", systemImage: "photo.on.rectangle.angled")
                            .foregroundStyle(AppStyle.green)
                    }

                    if store.hasImage(for: page) {
                        Button(role: .destructive) {
                            store.clearImage(for: page)
                        } label: {
                            Label("移除背景图", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("自定义背景图")
                } footer: {
                    Text("只改「\(page.title)」这一页的背景，其他页面不受影响。")
                }

                Section("预览") {
                    ZStack {
                        PageBackgroundView(page: page)
                            .frame(height: 150)
                            .overlay(
                                Text("\(page.title)页背景预览")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppStyle.ink)
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .navigationTitle("\(page.title)页背景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            store.setImage(from: data, for: page)
                        }
                    }
                }
            }
        }
    }
}
