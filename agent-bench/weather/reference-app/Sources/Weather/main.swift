// Smallest app that passes agent-bench/weather/gate.sh: Berlin's live temperature and a 7-day list.
// Set WEATHER_REFERENCE_MODE=blank to get a window with no data (the gate must reject it).
import SwiftUI
import AppKit

struct Forecast: Decodable {
    struct Current: Decodable { let temperature_2m: Double }
    struct Daily: Decodable { let time: [String]; let temperature_2m_max: [Double] }
    let current: Current
    let daily: Daily
}

@MainActor final class Model: ObservableObject {
    @Published var temp: String = "…"
    @Published var days: [(String, String)] = []

    func load() async {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current=temperature_2m&daily=temperature_2m_max&timezone=auto")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let f = try? JSONDecoder().decode(Forecast.self, from: data) else { temp = "network error"; return }
        temp = String(format: "%.1f°C", f.current.temperature_2m)
        let parse = DateFormatter(); parse.dateFormat = "yyyy-MM-dd"
        let show = DateFormatter(); show.dateFormat = "EEE"
        days = zip(f.daily.time, f.daily.temperature_2m_max).map { (show.string(from: parse.date(from: $0.0) ?? Date()), String(format: "%.0f°", $0.1)) }
    }
}

struct ContentView: View {
    @StateObject var model = Model()
    let blank = ProcessInfo.processInfo.environment["WEATHER_REFERENCE_MODE"] == "blank"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !blank {
                Text("Berlin").font(.largeTitle)
                Text(model.temp).font(.system(size: 48, weight: .bold))
                ForEach(model.days, id: \.0) { Text("\($0.0)  \($0.1)") }
            }
        }
        .frame(width: 420, height: 480)
        .padding()
        .task { if !blank { await model.load() } }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) { NSApp.activate(ignoringOtherApps: true) }
}

struct WeatherApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}

NSApplication.shared.setActivationPolicy(.regular)
WeatherApp.main()
