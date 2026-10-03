import SwiftUI

@main
struct EveryBodyApp: App {
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
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ExploreView()
                .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
        .task { await BodyScene.prepare() }
        .onOpenURL { url in
            guard let route = Route(path: "/\(url.host() ?? "")\(url.path())") else { return }
            // ?yaw=1.57 pins the 3D view at an angle (for screenshots)
            BodyScene.pinnedYaw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "yaw" }?.value.flatMap(Float.init)
            path = [route]
        }
        #if SCREENSHOTS
        .onAppear { if let route = Screenshot.route { path = [route] } }
        #endif
    }
}

#if SCREENSHOTS
/// Launch arguments for simulator screenshots: -screen viewer/skeletal [-part femur-l] [-point acu-li4]
/// [-face sole -zone sole-heart] [-yaw 0.3] [-trainer YES] [-credits YES]
enum Screenshot {
    nonisolated(unsafe) static let args = UserDefaults.standard
    static func flag(_ key: String) -> Bool { args.bool(forKey: key) }

    @MainActor static var route: Route? {
        guard let screen = args.string(forKey: "screen"), var route = Route(path: "/" + screen) else { return nil }
        BodyScene.pinnedYaw = args.string(forKey: "yaw").flatMap(Float.init)
        switch route {
        case let .viewer(system, _, _):
            route = .viewer(system: system, point: args.string(forKey: "point"), part: args.string(forKey: "part"))
        case let .chart(id, _, _, _):
            route = .chart(id: id, face: args.string(forKey: "face"), zone: args.string(forKey: "zone"))
        default: break
        }
        return route
    }
}
#endif

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
        case let .posture(id):
            PostureScreen(id: id)
        case .search:
            SearchScreen()
        }
    }
}
