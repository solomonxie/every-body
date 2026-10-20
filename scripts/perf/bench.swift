import AppKit
import RealityKit

// CPU timings of the 3D screens' hot paths on the Mac, plus checksums of what they write (compare before/after a change).
// Usage: scripts/perf/bench.sh [load,drag,posture,cpr]

@MainActor
final class Bench: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        Task { @MainActor in
            await run()
            NSApp.terminate(nil)
        }
    }

    func ms(_ f: () -> Void) -> Double {
        let t = DispatchTime.now().uptimeNanoseconds
        f()
        return Double(DispatchTime.now().uptimeNanoseconds - t) / 1e6
    }

    func report(_ name: String, _ times: [Double]) {
        guard !times.isEmpty else { return }
        let s = times.sorted()
        print(String(format: "%-34@ n=%3d  mean %8.2f  median %8.2f  max %8.2f ms", name as NSString, times.count,
                     times.reduce(0, +) / Double(times.count), s[s.count / 2], s.last!))
    }

    /// FNV-1a over the floats' bits
    func hash(_ arrays: [[SIMD3<Float>]]) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for a in arrays { for v in a { for x in [v.x, v.y, v.z] { h = (h ^ UInt64(x.bitPattern)) &* 0x100000001b3 } } }
        return String(h, radix: 16)
    }

    func deformerHash(_ ds: [SkinDeformer]) -> String { hash(ds.flatMap { d in let (p, n) = d.current(); return [p, n] }) }

    func run() async {
        let repeats = Int(ProcessInfo.processInfo.environment["REPEAT"] ?? "1") ?? 1
        let what = Set((CommandLine.arguments.dropFirst().first ?? "load,drag,posture,cpr").split(separator: ",").map(String.init))
        var t0 = DispatchTime.now().uptimeNanoseconds
        _ = Figure.available
        report("load: figure.bin decode", [Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6])
        t0 = DispatchTime.now().uptimeNanoseconds
        await BodyScene.prepare()
        report("load: BodyScene.prepare", [Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6])
        let look = Figure.Look(female: true, age: .adult, pregnant: false, heritage: .white, underwear: true)
        report("load: Figure.pieces (woman)", [ms { _ = Figure.pieces(look) }])

        if what.contains("load") || what.contains("drag") {
            let scene = BodyScene()
            scene.heritage = .white; scene.underwear = true
            report("load: BodyScene.build (woman)", [ms {
                scene.build(skinColor: NSColor(hex: "#F2C9A5"), female: true, points: [], flowStops: [])
                scene.setLayers([.skin, .organs])
            }])
            report("load: rebuild same look", [ms {
                scene.build(skinColor: NSColor(hex: "#F2C9A5"), female: true, points: [], flowStops: [])
                scene.setLayers([.skin, .organs])
            }])
            report("frame: BodyScene.update", (0..<60).map { _ in ms { scene.update(dt: 1 / 60) } })
            if what.contains("drag") {
                report("drag: first bend (bindSkin)", [ms { scene.setJoint("shoulder-l", degrees: 2) }])
                var hashes: [String] = []
                for (id, maxDeg) in [("shoulder-l", 160), ("elbow-l", 145), ("knee-r", 135), ("shoulder-r", 120), ("back", 40), ("neck", 30)] as [(String, Int)] {
                    guard scene.joints.contains(where: { $0.id == id }) else { print("no joint", id); continue }
                    let steps = stride(from: 0, through: maxDeg, by: max(1, maxDeg / 40)).map(Float.init)
                    report("drag: setJoint \(id)", steps.map { d in ms { scene.setJoint(id, degrees: d) } })
                    hashes.append(deformerHash(scene.skinDeformers))
                }
                print("HASH drag", hashes.joined(separator: " "))
            }
        }

        if what.contains("posture") {
            for topic in ["sitting", "phone-standing"] {
                let p = PostureScene()
                report("posture: build \(topic)", [ms { p.build(topic: topic, female: true, heritage: .white) }])
                var hashes: [String] = []
                let steps = (0...60 * repeats).map { Float($0 % 61) / 60 }
                report("posture: scrub \(topic)", steps.map { b in ms { p.goalBlend = b; p.settle() } })
                for b: Float in [0, 0.37, 1] {
                    p.goalBlend = b; p.settle()
                    let meshes = Mirror(reflecting: p).children.first { $0.label == "meshes" }?.value as? [DeformMesh] ?? []
                    hashes.append(hash(meshes.flatMap { [$0.positions, $0.currentNormals] }))
                }
                report("posture: idle frame \(topic)", (0..<60).map { _ in ms { p.update(dt: 1 / 60) } })
                if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
                    for label in ["halos", "muscles", "hot", "vessels"] {
                        let es = Mirror(reflecting: p).children.first { $0.label == label }?.value as? [ModelEntity] ?? []
                        let m = es.first?.model?.materials.first
                        print("DEBUG", label, es.count, (m as? PhysicallyBasedMaterial).map { "\($0.emissiveIntensity) \($0.blending)" } ?? (m as? UnlitMaterial).map { "\($0.blending)" } ?? "-")
                    }
                }
                print("HASH posture \(topic)", hashes.joined(separator: " "))
            }
        }

        if what.contains("cpr") {
            for pregnant in [false, true] {
                let t = CPRTrainerScene(victim: .adult, pregnant: pregnant)
                report("cpr: build\(pregnant ? " pregnant" : "")", [ms { t.build(female: true, heritage: .white, age: .adult) }])
                t.frameWhole(false)
                for _ in 0..<240 { t.update(dt: 1 / 60) }
                var hashes: [String] = []
                let skins = Mirror(reflecting: t).children.compactMap { c -> [SkinDeformer]? in
                    if c.label == "skin", let s = c.value as? SkinDeformer { return [s] }
                    if c.label == "garments" { return c.value as? [SkinDeformer] }
                    return nil
                }.flatMap { $0 }
                var frames: [Double] = []
                for k in 0..<120 {
                    t.depthCm = 5.5 * abs(sin(Float(k) * 0.13))
                    t.breath = k > 60 ? Float(k - 60) / 60 : 0
                    t.tilt = k > 90 ? Float(k - 90) / 30 : 0
                    if pregnant { t.bump = Float(k % 30) / 30 }
                    frames.append(ms { t.update(dt: 1 / 60) })
                    if k % 40 == 7 { hashes.append(deformerHash(skins)) }
                }
                report("cpr: deform frame\(pregnant ? " pregnant" : "")", frames)
                let size = CGSize(width: 430, height: 932)
                var hits: [String] = []
                let pts = (0..<30).map { CGPoint(x: 140 + Double($0 % 6) * 30, y: 300 + Double($0 / 6) * 70) }
                report("cpr: hitBody (touch)", pts.map { pt in ms {
                    let h = t.hitBody(t.ray(pt, size: size))
                    hits.append(h.map { "\($0.point.x.bitPattern)/\($0.normal.y.bitPattern)" } ?? "nil")
                } })
                print("HASH cpr\(pregnant ? " pregnant" : "")", hashes.joined(separator: " "), "hits", String(hits.joined().utf8.reduce(UInt64(0xcbf29ce484222325)) { ($0 ^ UInt64($1)) &* 0x100000001b3 }, radix: 16), hits.filter { $0 != "nil" }.count)
            }
        }
    }
}

@main
struct BenchMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = Bench()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
