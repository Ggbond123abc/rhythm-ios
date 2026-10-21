import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            DayTimelineView()
                .tabItem { Label("时间线", systemImage: "clock") }
            ReviewScreen()
                .tabItem { Label("复盘", systemImage: "chart.bar.xaxis") }
        }
        .tint(AppStyle.green)
    }
}
