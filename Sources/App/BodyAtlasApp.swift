import SwiftUI

@main
struct BodyAtlasApp: App {
    @State private var settings = Settings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .tint(.brand)
        }
    }
}

struct RootView: View {
    @State private var tab = 0
    @State private var path: [Route] = []

    var body: some View {
        TabView(selection: $tab) {
            Tab("Explore", systemImage: "figure.stand", value: 0) {
                NavigationStack(path: $path) {
                    ExploreView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
            Tab("Settings", systemImage: "gearshape", value: 1) {
                NavigationStack { SettingsView() }
            }
        }
        .onOpenURL { url in
            guard let route = Route(path: "/\(url.host() ?? "")\(url.path())") else { return }
            // ?yaw=1.57 pins the 3D view at an angle (for screenshots)
            BodyScene.pinnedYaw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "yaw" }?.value.flatMap(Float.init)
            tab = 0
            path = [route]
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case let .viewer(system, point, part):
            ViewerScreen(systemID: system, initialPoint: point, initialPart: part)
        case let .chart(id, face, zone, side):
            ChartScreen(chartID: id, initialFace: face, initialZone: zone, initialSide: side)
        case let .illustration(id):
            IllustrationScreen(id: id)
        case let .info(system):
            InfoScreen(systemID: system)
        case let .quiz(system):
            QuizScreen(systemID: system)
        case .search:
            SearchScreen()
        }
    }
}
