import AppKit
import SwiftUI

// Renders app screens (no RealityKit) as light/dark × EN/中文 contact sheets.
// Usage: scripts/render_ui/render.sh [out-dir] [page…]

@MainActor
func sheet(_ name: String, out: URL, height: CGFloat? = nil, @ViewBuilder _ page: @escaping () -> some View) {
    var images: [NSImage] = []
    for zh in [false, true] {
        for dark in [false, true] {
            let settings = Settings()
            settings.names = zh ? .zh : .en
            // PROFILE=infant|toddler|child|senior renders for that person type
            if let age = ProcessInfo.processInfo.environment["PROFILE"].flatMap(AgeGroup.init(rawValue:)) { settings.age = age }
            let view = VStack(alignment: .leading) { page() }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(width: 390, height: height, alignment: .top)
                .background(Color.page)
                .environment(settings)
                .environment(\.colorScheme, dark ? .dark : .light)
                .tint(.brand)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage { images.append(img) }
        }
    }
    let h = images.map(\.size.height).max() ?? 0
    let w = images.map(\.size.width).reduce(0, +)
    let out_ = NSImage(size: NSSize(width: w, height: h))
    out_.lockFocus()
    NSColor.gray.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    var x: CGFloat = 0
    for img in images { img.draw(in: NSRect(x: x, y: h - img.size.height, width: img.size.width, height: img.size.height)); x += img.size.width }
    out_.unlockFocus()
    if let tiff = out_.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: out.appendingPathComponent("\(name).png"))
        print(out.appendingPathComponent("\(name).png").path)
    }
}

@main
struct RenderUI {
    @MainActor static func main() {
        let args = CommandLine.arguments.dropFirst()
        let out = URL(fileURLWithPath: args.first ?? "/tmp/ui")
        let only = Set(args.dropFirst())
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func want(_ n: String) -> Bool { only.isEmpty || only.contains(n) }

        if want("home") { sheet("home", out: out) { HomeContent(query: .constant("")) } }
        if want("posture") {
            let topic = PostureTopic.find("sitting")!
            sheet("posture-tall", out: out) { PosturePanel(topic: topic, blend: .constant(0)) }
            sheet("posture-slump", out: out) { PosturePanel(topic: topic, blend: .constant(1)) }
            sheet("posture-mid", out: out) { PosturePanel(topic: topic, blend: .constant(0.5)) }
        }
        if want("suggest") {
            let s = Settings()
            s.clearRecentSearches()
            for q in ["heart", "心肺复苏", "femur"] { s.remember(search: q) }
            sheet("suggest", out: out) { SearchSuggestions(query: .constant("")) }
        }
        if want("results") { sheet("results", out: out) { SearchResults(query: "heart") } }
        if want("nomatch") { sheet("nomatch", out: out) { SearchResults(query: "zzqx") } }
        if want("acu-search") {
            for q in ["elbow", "LI11", "曲池", "quchi"] { sheet("results-\(q)", out: out) { SearchResults(query: q) } }
        }
        if want("acu") {
            let sp = Catalog.points["acupuncture"]
            for id in ["acu-li11", "acu-li4"] {
                sheet("acu-\(id)", out: out) {
                    AcupuncturePanel(points: sp?.points ?? [], meridians: sp?.meridians ?? [], filter: .constant(AcuFilter(region: "arm")),
                                     activeID: id, onPress: { _ in }, onFocus: { _ in }, onLink: { _ in })
                        .padding(.vertical, 12)
                        .background(Color.card, in: .rect(cornerRadius: 22))
                }
            }
        }
        if want("info") { for id in ["skeletal", "circulatory", "acupuncture"] { sheet("info-\(id)", out: out) { InfoContent(systemID: id) } } }
        // first try step of each listed scenario
        for id in ["cpr", "stroke", "choking"] where want("try-\(id)") {
            sheet("try-\(id)", out: out, height: 760) {
                let p = Player(Illustrations.find(id)!)
                let _ = p.goTo(p.scenario.steps.firstIndex { $0.kind == .try } ?? 0)
                PlayerView(player: p)
            }
        }
        if want("panels") {
            let reflex = Catalog.points["acupoint-reflex-map"]?.points ?? []
            let flow = Catalog.points["circulatory"]?.points ?? []
            sheet("panels", out: out) {
                VStack(alignment: .leading, spacing: 12) {
                    PartCard(partID: "heart", parts: PartState(faded: ["heart"]), female: false, onChange: { _ in }, onClose: {})
                    if let j = Catalog.body.joints.first { JointControl(joint: j, angle: 45, onChange: { _ in }) }
                    Divider()
                    ReflexPanel(points: reflex, filter: .constant("foot"), activeID: reflex.first { $0.region == "foot" }?.id,
                                effectVisible: true, onPress: { _ in }, onFocus: { _ in })
                    Divider()
                    FlowPanel(stops: flow, bpm: .constant(72), activeID: nil, onStop: { _ in })
                    Hint(symbol: "hand.tap", text: "Tap any part to name it.")
                    LoadingBadge(text: "Loading 3D body…")
                }
                .padding(.vertical, 12)
                .background(Color.card, in: .rect(cornerRadius: 22))
            }
        }
        if want("hidden") { sheet("hidden", out: out, height: 500) { IllustrationScreen(id: "blood-pressure") } }
        if want("player") { sheet("player", out: out, height: 760) { IllustrationScreen(id: "cpr") } }
    }
}
