import AppKit
import RealityKit

// Renders the real RealityKit body to PNGs on the Mac.
// Usage: scripts/render_body/render.sh out.png "skin,organs" [yaw] [focusY distance] [female] [age]

@MainActor
final class Renderer: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: ARView!
    let scene = BodyScene()

    func applicationDidFinishLaunching(_ note: Notification) {
        let a = CommandLine.arguments
        let out = a.count > 1 ? a[1] : "/tmp/body.png"
        let layers = Set((a.count > 2 ? a[2] : "skeletal").split(separator: ",").compactMap { LayerID(rawValue: String($0)) })
        let yaw = a.count > 3 ? Float(a[3]) ?? 0 : 0
        // "-" keeps the scene's own framing for the age
        let focus: (Float, Float)? = a.count > 5 && a[4] != "-" ? (Float(a[4]) ?? 0.05, Float(a[5]) ?? 5.8) : nil
        let female = a.count > 6 && a[6] == "female"
        let age = a.count > 7 ? AgeGroup(rawValue: a[7]) ?? .adult : .adult

        view = ARView(frame: NSRect(x: 0, y: 0, width: 600, height: 900))
        // BG=#FFFFFF / #000000 renders a pair for alpha matting (tiles)
        view.environment.background = .color(NSColor(hex: ProcessInfo.processInfo.environment["BG"] ?? "#DADCE2"))
        window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()

        Task { @MainActor in
            await BodyScene.prepare()
            scene.setAge(age)
            // POINTS=acupoint-reflex-map shows that system's points
            let system = ProcessInfo.processInfo.environment["POINTS"].flatMap { Catalog.points[$0] }
            scene.build(skinColor: NSColor(hex: "#F2C9A5"), female: female, points: system?.points ?? [], flowStops: [],
                        meridians: system?.meridians ?? [])
            scene.setLayers(layers)
            scene.touched = true
            scene.yaw = yaw
            if let focus {
                scene.goalFocusY = focus.0; scene.goalDistance = focus.1
            }
            scene.focusY = scene.goalFocusY; scene.distance = scene.goalDistance
            // PANX=0.45 slides the camera sideways (hands sit off the midline)
            if let pan = ProcessInfo.processInfo.environment["PANX"].flatMap(Float.init) { scene.panX = pan; scene.goalPanX = pan }
            scene.panX = scene.goalPanX
            // PITCH=0.8 tilts the body toward the camera (tops of the feet, crown)
            if let pitch = ProcessInfo.processInfo.environment["PITCH"].flatMap(Float.init) { scene.pitch = pitch }
            // FOCUS=acu-li11 turns the camera to that point, as tapping it does
            if let id = ProcessInfo.processInfo.environment["FOCUS"], let p = system?.points.first(where: { $0.id == id }), let acu = p.acu {
                scene.setActivePoint(id)
                scene.focus(on: acu.sites(female: female)[0].simd, normal: acu.normal.simd)
                scene.yaw = scene.goalYaw ?? scene.yaw
                scene.focusY = scene.goalFocusY; scene.distance = scene.goalDistance; scene.panX = scene.goalPanX
            }
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(scene.root)
            view.scene.addAnchor(anchor)
            for _ in 0..<5 { scene.update(dt: 0.016) }
            try? await Task.sleep(for: .seconds(1.5))
            view.snapshot(saveToHDR: false) { image in
                if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: out))
                    print(out)
                }
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct RenderBody {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = Renderer()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
