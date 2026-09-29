import AppKit
import SwiftUI

// Renders every step of every illustration into one contact sheet per scenario.
// Usage: scripts/render_scenes/render.sh [out-dir] [scenario-id…]

@MainActor
func render(_ scenario: Scenario, step: Int, t: Double) -> NSImage? {
    var params = scenario.targets(at: step)
    if let t = scenario.steps[step].try {
        if let demo = t.demo { params.merge(demo) { _, n in n } }
        if case .rhythm = t.mode { params.merge(["taps": 12, "rate": 110, "press": 0.6]) { _, n in n } }
        if case let .hold(param, progress, _, _) = t.mode { params.merge([param: 1, progress: 0.5]) { _, n in n } }
    }
    let view = Canvas { ctx, _ in
        var sketch = Sketch(ctx: ctx, zh: ProcessInfo.processInfo.environment["ZH"] == "1")
        scenario.draw(&sketch, params, t)
    }
    .frame(width: 360, height: 300)
    .background(.white)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    return renderer.nsImage
}

@MainActor
func renderAll() {
    let args = CommandLine.arguments.dropFirst()
    let out = URL(fileURLWithPath: args.first ?? "/tmp/scenes")
    let only = Set(args.dropFirst())
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    // PROFILE=infant|toddler|child|adult|senior|pregnant renders that person type's version
    let env = ProcessInfo.processInfo.environment["PROFILE"] ?? "adult"
    // FEMALE=1 renders the female version
    let female = ProcessInfo.processInfo.environment["FEMALE"] == "1"
    let profile = env == "pregnant" ? Profile(age: .adult, female: true, pregnant: true) : Profile(age: AgeGroup(rawValue: env) ?? .adult, female: female)
    for scenario in Illustrations.builders.map({ $0(profile) }) where only.isEmpty || only.contains(scenario.id) {
        guard Illustrations.shown(scenario.id, for: profile) else { print("\(scenario.id): hidden for \(env)"); continue }
        let images = scenario.steps.indices.compactMap { render(scenario, step: $0, t: 1.3) }
        // SPLIT=1 also writes one PNG per step
        if ProcessInfo.processInfo.environment["SPLIT"] == "1" {
            for (i, img) in images.enumerated() { writePNG(img, out.appendingPathComponent("\(scenario.id)-\(i).png")) }
        }
        let sheet = NSImage(size: NSSize(width: 360 * images.count, height: 300))
        sheet.lockFocus()
        for (i, img) in images.enumerated() { img.draw(in: NSRect(x: 360 * i, y: 0, width: 360, height: 300)) }
        sheet.unlockFocus()
        writePNG(sheet, out.appendingPathComponent("\(scenario.id).png"))
        print(scenario.id)
    }
}

func writePNG(_ img: NSImage, _ url: URL) {
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: url)
    }
}

@main
struct RenderScenes {
    @MainActor static func main() { renderAll() }
}
