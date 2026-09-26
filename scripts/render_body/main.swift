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
        let focus = a.count > 5 ? (Float(a[4]) ?? 0.05, Float(a[5]) ?? 5.8) : (0.05, 5.8)
        let female = a.count > 6 && a[6] == "female"
        let age = a.count > 7 ? AgeGroup(rawValue: a[7]) ?? .adult : .adult

        view = ARView(frame: NSRect(x: 0, y: 0, width: 600, height: 900))
        view.environment.background = .color(NSColor(hex: "#DADCE2"))
        window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()

        Task { @MainActor in
            await BodyScene.prepare()
            scene.setAge(age)
            scene.build(skinColor: NSColor(hex: "#F2C9A5"), female: female, points: [], flowStops: [])
            scene.setLayers(layers)
            scene.touched = true
            scene.yaw = yaw
            scene.goalFocusY = focus.0; scene.focusY = focus.0
            scene.goalDistance = focus.1; scene.distance = focus.1
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
