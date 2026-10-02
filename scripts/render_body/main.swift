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

        let env = ProcessInfo.processInfo.environment
        // TRAINER=<state> renders the CPR trainer (phone-shaped) instead of the body viewer
        let trainerState = env["TRAINER"]
        // SIZE=430x400 renders a custom frame (the posture view's top half on a phone)
        let size = env["SIZE"].map { $0.split(separator: "x").compactMap { Double($0) } }
        view = ARView(frame: size?.count == 2 ? NSRect(x: 0, y: 0, width: size![0], height: size![1])
                      : trainerState == nil ? NSRect(x: 0, y: 0, width: 600, height: 900) : NSRect(x: 0, y: 0, width: 430, height: 932))
        // BG=#FFFFFF / #000000 renders a pair for alpha matting (tiles)
        view.environment.background = .color(NSColor(hex: ProcessInfo.processInfo.environment["BG"] ?? "#DADCE2"))
        window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()

        if let trainerState {
            Task { @MainActor in await renderTrainer(trainerState, out: out, female: female, age: age) }
            return
        }
        Task { @MainActor in
            await BodyScene.prepare()
            if let topic = ProcessInfo.processInfo.environment["POSTURE"] {
                renderPosture(topic, out: out, female: female)
                return
            }
            scene.setAge(age)
            // GLASS=0.4 makes the skin over inner layers less see-through
            if let glass = ProcessInfo.processInfo.environment["GLASS"].flatMap(Float.init) { BodyScene.glassOpacity = glass }
            // HERITAGE=black, UNDERWEAR=0 change the outer figure
            scene.heritage = ProcessInfo.processInfo.environment["HERITAGE"].flatMap(Heritage.init(rawValue:)) ?? .white
            scene.underwear = ProcessInfo.processInfo.environment["UNDERWEAR"] != "0"
            // CHEST=small|medium|large, HIPS=… (adult women)
            if let v = ProcessInfo.processInfo.environment["CHEST"].flatMap(BodySize.init(rawValue:)) { scene.chest = v }
            if let v = ProcessInfo.processInfo.environment["HIPS"].flatMap(BodySize.init(rawValue:)) { scene.hips = v }
            // MERIDIANS=0 switches the lines off before the build: it must survive rebuilds
            if ProcessInfo.processInfo.environment["MERIDIANS"] == "0" { scene.showMeridians(false) }
            // POINTS=acupoint-reflex-map shows that system's points
            let system = ProcessInfo.processInfo.environment["POINTS"].flatMap { Catalog.points[$0] }
            scene.build(skinColor: NSColor(hex: "#F2C9A5"), female: female, pregnant: ProcessInfo.processInfo.environment["PREGNANT"] == "1", points: system?.points ?? [], flowStops: [],
                        meridians: system?.meridians ?? [])
            scene.setLayers(layers)
            if ProcessInfo.processInfo.environment["LINES"] == "0" { scene.showMeridians(false) }
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
            // FIND=quadratus-lumborum-l selects a part and turns to it, as the viewer's part search does
            if let id = ProcessInfo.processInfo.environment["FIND"] {
                scene.setParts(PartState(), selected: id)
                scene.focus(onPart: id)
                scene.yaw = scene.goalYaw ?? scene.yaw
                scene.focusY = scene.goalFocusY; scene.distance = scene.goalDistance; scene.panX = scene.goalPanX
            }
            // JOINT=elbow-l:90 bends a joint
            if let spec = ProcessInfo.processInfo.environment["JOINT"]?.split(separator: ":"), spec.count == 2 {
                scene.setJoint(String(spec[0]), degrees: Float(spec[1]) ?? 0)
            }
            // SELECT=a,b selects each part in turn (as tapping them does); the last stays selected; FADE=a,b fades those
            let faded = PartState(faded: Set((ProcessInfo.processInfo.environment["FADE"] ?? "").split(separator: ",").map(String.init)))
            scene.setParts(faded, selected: nil)
            for id in (ProcessInfo.processInfo.environment["SELECT"] ?? "").split(separator: ",") {
                scene.setParts(faded, selected: String(id))
            }
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(scene.root)
            view.scene.addAnchor(anchor)
            for _ in 0..<5 { scene.update(dt: 0.016) }
            try? await Task.sleep(for: .seconds(1.5))
            // HIDE=skin:body,skin:eyes disables those entities (a garment on its own)
            for name in (ProcessInfo.processInfo.environment["HIDE"] ?? "").split(separator: ",") {
                func walk(_ e: Entity) { if e.name == name { e.isEnabled = false }; e.children.forEach(walk) }
                walk(scene.root)
            }
            // DUPES=1 lists entity names used more than once
            if ProcessInfo.processInfo.environment["DUPES"] == "1" {
                var seen: [String: Int] = [:]
                func walk(_ e: Entity) { if e is ModelEntity, !e.name.isEmpty { seen[e.name, default: 0] += 1 }; e.children.forEach(walk) }
                walk(scene.root)
                print("DUPES", seen.filter { $0.value > 1 }.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" })
            }
            // FIND also fades what covers the part, as the viewer does
            if let id = ProcessInfo.processInfo.environment["FIND"] {
                scene.setParts(PartState(faded: scene.covering(id)), selected: id)
                print("COVERING", scene.covering(id).sorted())
            }
            // HITS=x,y;x,y prints what a tap at each view point lands on
            for spec in (ProcessInfo.processInfo.environment["HITS"] ?? "").split(separator: ";") {
                let c = spec.split(separator: ",").compactMap { Double($0) }
                guard c.count == 2 else { continue }
                let hits: [CollisionCastHit] = view.hitTest(CGPoint(x: c[0], y: c[1]), query: .all, mask: .all)
                print("HIT", c[0], c[1], hits.prefix(4).map { $0.entity.name })
            }
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

extension Renderer {
    /// POSTURE=sitting [BLEND=0…1] [VIEW=side|back|front] [YAW, PITCH, DIST, FOCUSY] [SOLID=1]: a posture scene
    func renderPosture(_ topic: String, out: String, female: Bool) {
        let env = ProcessInfo.processInfo.environment
        let scene = PostureScene()
        let heritage = env["HERITAGE"].flatMap(Heritage.init(rawValue:)) ?? .white
        scene.build(topic: topic, female: female, pregnant: env["PREGNANT"] == "1", heritage: heritage, underwear: env["UNDERWEAR"] != "0",
                    chest: env["CHEST"].flatMap(BodySize.init(rawValue:)) ?? .small, hips: env["HIPS"].flatMap(BodySize.init(rawValue:)) ?? .medium)
        scene.seeThrough = env["SOLID"] != "1"
        scene.goalBlend = env["BLEND"].flatMap(Float.init) ?? 0
        let preset: PostureScene.View = switch env["VIEW"] { case "back": .back; case "front": .front; case "spine": .spine; default: .side }
        scene.show(preset)
        if let yaw = env["YAW"].flatMap(Float.init) { scene.goalYaw = yaw }
        if let pitch = env["PITCH"].flatMap(Float.init) { scene.goalPitch = pitch }
        if let d = env["DIST"].flatMap(Float.init) { scene.goalDistance = d }
        if let y = env["FOCUSY"].flatMap(Float.init) { scene.goalFocusY = y }
        scene.settle()
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(scene.root)
        self.view.scene.addAnchor(anchor)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            self.view.snapshot(saveToHDR: false) { image in
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

extension Renderer {
    /// TRAINER = check | find-miss | find | compress | compress-down | tilt | breath | bump | aed | aed-drag | aed-placed
    /// Env: PREGNANT=1, GLASS=1, AZ / EL / DIST (camera), HERITAGE
    func renderTrainer(_ state: String, out: String, female: Bool, age: AgeGroup) async {
        let env = ProcessInfo.processInfo.environment
        await BodyScene.prepare()
        BodyScene.glassOpacity = 0.22
        let t = CPRTrainerScene(victim: CPRVictim(age), pregnant: env["PREGNANT"] == "1")
        t.build(female: female, heritage: env["HERITAGE"].flatMap(Heritage.init(rawValue:)) ?? .white, age: age,
                chest: env["CHEST"].flatMap(BodySize.init(rawValue:)) ?? .small, hips: env["HIPS"].flatMap(BodySize.init(rawValue:)) ?? .medium)
        // past the check the camera comes in to the chest
        if state != "check" { t.frameWhole(false); for _ in 0..<240 { t.update(dt: 1 / 60) } }
        if env["CLOSE"] == "1" { t.focusOnTarget() }
        t.glass = env["GLASS"] == "1"
        if let v = env["AZ"].flatMap(Float.init) { t.azimuth = v }
        if let v = env["EL"].flatMap(Float.init) { t.elevation = v }
        if let v = env["ZOOM"].flatMap(Float.init) { t.zoom = v }
        let m = t.marks
        if env["DEBUG"] == "1" { print(m, "scale", t.body.root.findEntity(named: "skin:body")?.parent?.scale ?? .zero) }
        if state == "sim" { simulate(t) }
        switch state {
        case "check":
            t.hint([t.victim == .infant ? .feet : .shoulder])
            if t.victim == .infant { t.frameWhole(true); for _ in 0..<240 { t.update(dt: 1 / 60) } }
        case "find-miss":
            t.showRing = true
            t.markTap(m.target + SIMD3(0.012, 0.09, 0), normal: m.targetNormal)
        case "find":
            t.showRing = true; t.ringGood = true; t.showHands = true
        case "compress":
            t.showHands = true
        case "compress-down":
            t.showHands = true
            t.depthCm = t.victim.depth.upperBound - 0.4
            t.pumpBlood()
        case "tilt":
            t.tilt = 1
            t.hint([.mouth])
        case "breath":
            t.tilt = 1; t.breath = 1
        case "bump":
            t.bump = 1
        case "aed":
            t.showPads = true
        case "aed-drag":
            t.showPads = true
            t.placePad(0, on: 0)
        case "aed-placed":
            t.showPads = true
            t.placePad(0, on: 0); t.placePad(1, on: 1)
        default:
            break
        }
        if env["DEBUG"] == "1" {
            t.update(dt: 0.016)
            let a = t.alignment
            print("ring", a.ring, "heel", a.heel, "target", a.target, "heel-ring cm", simd_distance(a.ring, a.heel) / CPRTrainerScene.cm)
        }
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(t.root)
        view.scene.addAnchor(anchor)
        // advance so blood-flow dots are mid-way
        for _ in 0..<(state == "compress-down" ? 20 : 3) { t.update(dt: 0.016) }
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

extension Renderer {
    /// Scripted run through every step with taps at the landmarks' screen points; prints what the coach says.
    func simulate(_ t: CPRTrainerScene) {
        let size = CGSize(width: 430, height: 932)
        let coach = CPRCoach(scene: t)
        func run(_ seconds: Float) { for _ in 0..<Int(seconds * 60) { coach.tick(1 / 60) } }
        func screen(_ body: SIMD3<Float>) -> CGPoint { t.project(t.world(body), size: size) }
        func tap(_ body: SIMD3<Float>) { let p = screen(t.headPoint(body)); coach.touchBegan(p, size: size); coach.touchEnded(p, size: size) }
        func log(_ what: String) { print(String(describing: coach.stage).padding(toLength: 9, withPad: " ", startingAt: 0), what, "→", coach.feedback.en) }
        let m = t.marks
        run(0.1)
        tap(m.target); log("tap chest in check")
        tap(t.victim == .infant ? SIMD3(0.1, m.feetY + 0.05, 0.1) : m.shoulders[0]); log("tap shoulder/foot")
        run(1.1)
        coach.call(); log("call"); run(1.3)
        if coach.stage == .bump {
            let a = screen(m.belly), b = t.screenAxis(size: size).1
            coach.touchBegan(a, size: size)
            for k in 1...10 { let f = CGFloat(k) / 10; coach.touchMoved(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), size: size); run(0.02) }
            coach.touchEnded(b, size: size); log("push bump"); run(1.1)
        }
        tap(m.target + SIMD3(0, 0.1, 0)); log("tap 5 cm high")
        tap(m.target + SIMD3(0.12, 0, 0)); log("tap off-centre")
        tap(m.target - SIMD3(0, 0.12, 0)); log("tap low")
        tap(m.target); log("tap target"); run(1.3)
        for k in 0..<30 {
            let p = screen(m.target)
            coach.touchBegan(p, size: size); run(k < 10 ? 0.05 : 0.09); coach.touchEnded(p, size: size)
            run(k < 10 ? 0.3 : 0.45)
            if k == 5 || k == 20 || k == 29 { log("push \(k + 1) depth \(String(format: "%.1f", coach.lastDepth)) rate \(Int(coach.rate)) flow \(String(format: "%.2f", coach.flow))") }
        }
        run(0.8)
        tap(m.chin); log("tap chin first")
        tap(m.forehead); log("tap forehead"); run(0.3)
        tap(m.chin); log("tap chin"); run(1)
        tap(m.mouth); log("breath 1"); run(2.1)
        tap(m.mouth); log("breath 2"); run(2.4)
        for i in 0..<2 {
            let from = t.padEntities[i].position(relativeTo: nil)
            let a = t.project(from, size: size), b = screen(m.pads[i].point)
            coach.touchBegan(a, size: size)
            for k in 1...12 { let f = CGFloat(k) / 12; coach.touchMoved(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), size: size) }
            coach.touchEnded(b, size: size); log("drag pad \(i)")
        }
        run(0.8); log("wait"); run(2.6); log("analysed")
        coach.shock(); log("shock"); run(1.3); log("after")
        tap(m.target)
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
