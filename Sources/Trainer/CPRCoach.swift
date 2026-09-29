import CoreGraphics
import Foundation
import Observation
import simd

/// Steps of the practice, in order; the loop after the first shock is compress → breaths.
enum CPRStage: Equatable {
    case check, call, bump, find, compress, airway, breaths, aed, analyse, shock
}

/// Runs the practice: reads touches on the 3D body, scores them, drives the scene.
@MainActor
@Observable
final class CPRCoach {
    enum Tone { case info, good, warn }

    let scene: CPRTrainerScene
    var victim: CPRVictim { scene.victim }
    var pregnant: Bool { scene.pregnant }

    private(set) var stage: CPRStage = .check
    private(set) var feedback = Bilingual("", "")
    private(set) var tone = Tone.info
    /// compressions in this cycle, and pushes ever (haptics)
    private(set) var count = 0
    private(set) var presses = 0
    private(set) var cycles = 0
    /// per minute, from the last few pushes
    private(set) var rate: Double = 0
    /// deepest point of the last push, cm (0 before the first)
    private(set) var lastDepth: Float = 0
    private(set) var breathsGiven = 0
    private(set) var foreheadDone = false
    /// blood reaching the brain, 0…1: rises with good pushes, drains in pauses
    private(set) var flow: Double = 0
    private(set) var shocks = 0
    /// bumps each time something worth a haptic happens
    private(set) var successes = 0
    private(set) var misses = 0

    @ObservationIgnored private var clock: Double = 0
    @ObservationIgnored private var pressing = false
    @ObservationIgnored private var held: Float = 0
    @ObservationIgnored private var pushStarts: [Double] = []
    @ObservationIgnored private var pending: [(at: Double, run: () -> Void)] = []
    @ObservationIgnored private var breathStart: Double = -10
    @ObservationIgnored private var tiltGoal: Float = 0
    @ObservationIgnored private var bumpDone = false
    @ObservationIgnored private var aedDone = false
    @ObservationIgnored private var touchStart: CGPoint?
    @ObservationIgnored private var touchMoved = false
    @ObservationIgnored private var draggingPad: Int?
    @ObservationIgnored private var padTarget: Int?
    @ObservationIgnored private var pushingBump = false
    @ObservationIgnored private var hinted = false

    init(scene: CPRTrainerScene) {
        self.scene = scene
        enter(.check)
    }

    // MARK: stages

    var stages: [CPRStage] {
        [.check, .call] + (pregnant ? [.bump] : []) + [.find, .compress, .breaths, .aed]
    }

    /// the chip lit for this stage
    var chip: CPRStage {
        switch stage {
        case .airway: .breaths
        case .analyse, .shock: .aed
        default: stage
        }
    }

    static func title(_ s: CPRStage, victim: CPRVictim) -> Bilingual {
        switch s {
        case .check: Bilingual("Check", "检查")
        case .call: Bilingual("Call", "呼救")
        case .bump: Bilingual("Bump", "推腹")
        case .find: Bilingual("Hands", "手位")
        case .compress: Bilingual("Push", "按压")
        case .airway, .breaths: Bilingual("Breaths", "吹气")
        case .aed, .analyse, .shock: Bilingual("AED", "AED")
        }
    }

    /// what to do now
    var instruction: Bilingual {
        switch stage {
        case .check:
            victim == .infant
                ? Bilingual("Tap the sole of the baby's foot and call out. Don't shake.", "轻拍婴儿足底并呼唤，不要摇晃。")
                : Bilingual("Tap both shoulders and shout “Are you OK?”", "拍打双肩，大声呼唤“你还好吗？”")
        case .call:
            victim == .adult
                ? Bilingual("No response, not breathing normally. Call now, phone on speaker, and send someone for an AED.",
                            "无反应、无正常呼吸。立即呼救，手机开免提，并让旁人去取 AED。")
                : Bilingual("No response, not breathing normally. A helper calls and fetches an AED. Alone: 2 minutes of CPR first, then call.",
                            "无反应、无正常呼吸。让旁人呼救并取 AED；独自一人时先做 2 分钟心肺复苏再呼救。")
        case .bump:
            Bilingual("Big bump: push it gently to her left and hold it there, so it stops pressing on the big vein.",
                      "腹部隆起：把子宫轻推向她的左侧并保持，避免压迫回心的大静脉。")
        case .find:
            switch victim {
            case .adult: Bilingual("Tap where the heel of your hand goes: center of the chest, lower half of the breastbone.",
                                   "点击掌根的位置：胸部正中，胸骨下半段。")
            case .child: Bilingual("Tap where the heel of one hand goes: lower half of the breastbone.", "点击单手掌根的位置：胸骨下半段。")
            case .infant: Bilingual("Tap where your two fingers go: breastbone, just below the nipple line.", "点击两指按压的位置：乳头连线正下方的胸骨上。")
            }
        case .compress:
            Bilingual("Press on the chest and let go, \(Int(victim.depth.lowerBound.rounded()))–\(Self.cm(victim.depth.upperBound)) cm deep, 100–120 a minute. Press longer to push deeper.",
                      "在胸部按下再松开，深 \(Int(victim.depth.lowerBound.rounded()))–\(Self.cm(victim.depth.upperBound)) 厘米，每分钟 100–120 次。按得越久越深。")
        case .airway:
            foreheadDone
                ? Bilingual("Now lift the chin: tap the chin.", "再抬起下巴：点击下巴。")
                : victim == .infant
                ? Bilingual("Open the airway: tap the forehead to tilt the head, only to a neutral position.", "开放气道：点击前额，头部只需保持中立位。")
                : Bilingual("Open the airway: tap the forehead to tilt the head back.", "开放气道：点击前额，使头后仰。")
        case .breaths:
            victim == .infant
                ? Bilingual("Cover the baby's mouth and nose with your mouth. Tap the mouth for a gentle puff, 1 second.", "用嘴罩住婴儿的口和鼻。点击嘴部轻轻吹气 1 秒。")
                : Bilingual("Pinch the nose, seal your mouth over theirs. Tap the mouth for a 1-second breath; watch the chest rise.",
                            "捏住鼻子，用嘴包住其口部。点击嘴部吹气 1 秒，看胸廓抬起。")
        case .aed:
            victim == .infant
                ? Bilingual("AED is here. Drag one pad to the center of the chest and one onto the back.", "AED 到了。把一片电极拖到胸部正中，另一片贴在背部。")
                : Bilingual("AED is here. Drag the pads onto bare skin: below the right collarbone, and on the left side below the armpit.",
                            "AED 到了。把电极片拖到裸露的皮肤上：右锁骨下方，以及左侧腋下。")
        case .analyse: Bilingual("Analyzing heart rhythm. Nobody touch!", "正在分析心律，所有人不要触碰！")
        case .shock: Bilingual("Shock advised. Stand clear! Check nobody touches, then press Shock.", "建议电击。所有人离开！确认无人接触后按下电击键。")
        }
    }

    private static func cm(_ v: Float) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }

    private func enter(_ s: CPRStage) {
        stage = s
        say(Bilingual("", ""), .info)
        showHints()
        scene.showRing = false
        scene.ringGood = false
        switch s {
        case .find:
            misses = 0
            scene.showHands = false
        case .compress:
            count = 0
            scene.showHands = true
        case .airway, .breaths:
            scene.showHands = false
            breathsGiven = 0
        case .aed:
            scene.showHands = false
            scene.resetPads()
            scene.showPads = true
            // from higher up both pad spots show
            scene.goalElevation = max(scene.elevation, 1.25)
        case .analyse:
            later(2.5) { self.enter(.shock) }
        default:
            break
        }
    }

    /// rings on what to tap next
    private func showHints() {
        guard scene.ready else { return }
        // the baby's feet are out of the chest view
        if victim == .infant { scene.frameWhole(stage == .check) }
        switch stage {
        case .check: scene.hint([victim == .infant ? .feet : .shoulder])
        case .bump: scene.hint([.belly])
        case .airway: scene.hint([foreheadDone ? .chin : .forehead])
        case .breaths: scene.hint(breathsGiven < 2 ? [.mouth] : [])
        default: scene.hint([])
        }
    }

    private func say(_ b: Bilingual, _ t: Tone) {
        feedback = b
        tone = t
    }

    private func later(_ seconds: Double, _ run: @escaping () -> Void) {
        pending.append((clock + seconds, run))
    }

    private func next() {
        switch stage {
        case .check: enter(.call)
        case .call: enter(pregnant && !bumpDone ? .bump : .find)
        case .bump: enter(.find)
        case .find: enter(.compress)
        case .compress:
            cycles += 1
            enter(scene.tilt > 0.9 ? .breaths : .airway)
        case .airway: enter(.breaths)
        // the AED arrives after the first round of CPR
        case .breaths: enter(aedDone ? .compress : .aed)
        case .aed: enter(.analyse)
        case .analyse: enter(.shock)
        case .shock:
            aedDone = true
            enter(.compress)
        }
    }

    /// Skip / "do it for me" (accessibility and testing).
    func skip() {
        switch stage {
        case .bump:
            scene.bump = 1; bumpDone = true
        case .airway:
            tiltGoal = 1
        case .aed:
            scene.placePad(0, on: 0); scene.placePad(1, on: 1)
        case .shock:
            shock(); return
        default: break
        }
        next()
    }

    func restart() {
        pending = []
        cycles = 0; shocks = 0; flow = 0; rate = 0; lastDepth = 0; pushStarts = []
        bumpDone = false; aedDone = false; foreheadDone = false
        tiltGoal = 0; scene.tilt = 0; scene.bump = 0; scene.breath = 0; scene.depthCm = 0
        scene.showPads = false
        scene.resetPads()
        enter(.check)
    }

    // MARK: buttons

    func call() {
        guard stage == .call else { return }
        successes += 1
        say(Bilingual("Help is on the way. Stay with them.", "救援正在赶来，留在患者身边。"), .good)
        later(1.2) { if self.stage == .call { self.next() } }
    }

    func shock() {
        guard stage == .shock else { return }
        shocks += 1
        successes += 1
        scene.jolt()
        say(Bilingual("Shock delivered. Start compressions straight away.", "已电击。立即继续胸外按压。"), .good)
        later(1.2) { if self.stage == .shock { self.next() } }
    }

    // MARK: touches (one finger)

    func touchBegan(_ pt: CGPoint, size: CGSize) {
        touchStart = pt
        touchMoved = false
        let ray = scene.ray(pt, size: size)
        switch stage {
        case .compress:
            guard scene.onChest(pt, size: size) else {
                say(Bilingual("Press on the chest, where your hands are.", "请按在胸部、双手所在的位置。"), .warn)
                return
            }
            pressDown()
        case .aed:
            draggingPad = scene.pad(at: ray)
        case .bump:
            if let hit = scene.hitBody(ray), scene.spot(hit.point) == .belly { pushingBump = true }
        default:
            break
        }
    }

    func touchMoved(_ pt: CGPoint, size: CGSize) {
        guard let start = touchStart else { return }
        if hypot(pt.x - start.x, pt.y - start.y) > 12 { touchMoved = true }
        if let pad = draggingPad {
            padTarget = scene.drag(pad: pad, ray: scene.ray(pt, size: size))
        }
        if pushingBump {
            // finger travel along her left, as seen on screen, over what 7 cm looks like there
            let (a, b) = scene.screenAxis(size: size)
            let len = max(1, hypot(b.x - a.x, b.y - a.y))
            let along = ((pt.x - start.x) * (b.x - a.x) + (pt.y - start.y) * (b.y - a.y)) / len
            scene.bump = Float(min(1, max(0, along / len)))
        }
    }

    func touchEnded(_ pt: CGPoint, size: CGSize) {
        defer { touchStart = nil; draggingPad = nil; pushingBump = false }
        if pressing { pressUp() }
        if let pad = draggingPad {
            scene.drop(pad: pad, on: padTarget)
            padTarget = nil
            if scene.padsDone {
                successes += 1
                say(Bilingual("Pads on. The AED is analyzing.", "电极片已贴好，AED 正在分析。"), .good)
                later(0.6) { if self.stage == .aed { self.next() } }
            } else if scene.padPlaced[pad] != nil {
                successes += 1
                say(Bilingual("Good. Now the other pad.", "很好，再贴另一片。"), .good)
            } else if touchMoved {
                misses += 1
                say(victim == .infant ? Bilingual("Center of the chest, or slide it under the back.", "放在胸部正中，或塞到背部。")
                    : Bilingual("Not there: follow the green outlines.", "位置不对：按绿色轮廓放置。"), .warn)
            }
            return
        }
        if pushingBump {
            if scene.bump > 0.75 {
                scene.bump = 1
                bumpDone = true
                successes += 1
                say(Bilingual("Good: the bump is held to her left. Keep it there during CPR.", "很好：子宫已推向左侧，按压时保持住。"), .good)
                later(1) { if self.stage == .bump { self.next() } }
            } else {
                scene.bump = 0
                say(Bilingual("Push further, toward her left side.", "再往她的左侧多推一些。"), .warn)
            }
            return
        }
        guard !touchMoved, stage != .compress else { return }
        tap(scene.ray(pt, size: size))
    }

    private func tap(_ ray: (SIMD3<Float>, SIMD3<Float>)) {
        let hit = scene.hitBody(ray)
        let spot = hit.map { scene.spot($0.point) } ?? .other
        switch stage {
        case .check:
            let ok = victim == .infant ? spot == .feet : spot == .shoulder
            if ok {
                scene.hint([])
                if victim != .infant { scene.shake() }
                successes += 1
                say(Bilingual("No response.", "没有反应。"), .good)
                later(1) { if self.stage == .check { self.next() } }
            } else {
                say(victim == .infant ? Bilingual("Tap the foot.", "请轻拍脚底。") : Bilingual("Tap a shoulder.", "请拍肩膀。"), .warn)
            }
        case .bump:
            say(Bilingual("Drag the bump toward her left (away from you).", "把肚子向她的左侧（远离你）拖动。"), .warn)
        case .find:
            guard let hit else { return }
            scene.markTap(hit.point, normal: hit.normal)
            let d = scene.offsetFromTarget(hit.point)
            let tol = victim.tolerance
            if simd_length(d) <= tol {
                scene.showRing = true
                scene.ringGood = true
                scene.showHands = true
                successes += 1
                say(victim == .infant ? Bilingual("Right: index and middle finger on the breastbone, just below the nipple line.", "正确：食指和中指放在乳头连线正下方的胸骨上。")
                    : victim == .child ? Bilingual("Right: heel of one hand, arm straight.", "正确：单手掌根，手臂伸直。")
                    : Bilingual("Right: other hand on top, fingers laced, arms straight.", "正确：另一只手叠放、手指交扣，手臂伸直。"), .good)
                later(1.2) { if self.stage == .find { self.next() } }
                return
            }
            misses += 1
            scene.showRing = true
            let n = Int(simd_length(d).rounded())
            if abs(d.x) > tol && abs(d.x) >= abs(d.y) {
                say(Bilingual("About \(n) cm off: move to the middle of the chest, on the breastbone.", "偏了约 \(n) 厘米：移到胸部正中的胸骨上。"), .warn)
            } else if d.y > 0 {
                say(Bilingual("About \(n) cm too high: move toward the feet, to the lower half of the breastbone.", "高了约 \(n) 厘米：向脚的方向移到胸骨下半段。"), .warn)
            } else {
                say(Bilingual("About \(n) cm too low: move toward the head. Not on the tip of the breastbone or the belly.", "低了约 \(n) 厘米：向头的方向移。不要按在胸骨下端尖部或腹部。"), .warn)
            }
        case .airway:
            if spot == .forehead && !foreheadDone {
                foreheadDone = true
                tiltGoal = 0.45
                later(0.5) { self.showHints() }
                successes += 1
                say(Bilingual("Hand on the forehead, tilting.", "手放前额，头后仰。"), .good)
            } else if spot == .chin && foreheadDone {
                tiltGoal = 1
                successes += 1
                scene.hint([])
                say(Bilingual("Airway open.", "气道已开放。"), .good)
                later(0.9) { if self.stage == .airway { self.next() } }
            } else {
                say(foreheadDone ? Bilingual("Tap the chin.", "请点击下巴。") : Bilingual("Tap the forehead first.", "请先点击前额。"), .warn)
            }
        case .breaths:
            guard spot == .mouth || spot == .chin || spot == .forehead else {
                say(Bilingual("Tap the mouth.", "请点击嘴部。"), .warn)
                return
            }
            guard clock - breathStart > 2 else {
                say(Bilingual("Let the chest fall first.", "先等胸廓回落。"), .warn)
                return
            }
            breathStart = clock
            breathsGiven += 1
            successes += 1
            say(breathsGiven == 1 ? Bilingual("Chest rises. One more.", "胸廓抬起，再吹一次。") : Bilingual("Two breaths given.", "已吹气两次。"), .good)
            later(1) { self.showHints() }
            if breathsGiven >= 2 { later(2.2) { if self.stage == .breaths { self.next() } } }
        default:
            break
        }
    }

    // MARK: compressions

    private func pressDown() {
        // the chest must be back up before the next push
        if scene.depthCm > victim.depth.lowerBound * 0.3 {
            say(Bilingual("Let the chest come all the way back up between pushes.", "每次按压后让胸廓完全回弹。"), .warn)
        }
        pressing = true
        held = 0
        presses += 1
        let gap = pushStarts.last.map { clock - $0 } ?? 0
        if gap > 2 { pushStarts = [] }
        pushStarts = Array((pushStarts + [clock]).suffix(6))
        if pushStarts.count > 1 {
            let span = pushStarts.last! - pushStarts.first!
            rate = 60 * Double(pushStarts.count - 1) / span
        }
    }

    private func pressUp() {
        pressing = false
        lastDepth = scene.depthCm
        count += 1
        scene.pumpBlood()
        let band = victim.depth
        let depthOK = band.contains(((lastDepth * 10).rounded() / 10))
        let rateOK = rate == 0 || (100...120).contains(rate)
        flow = min(1, flow + (depthOK ? 0.09 : 0.04) * (rateOK ? 1 : 0.6))
        if lastDepth < band.lowerBound {
            say(Bilingual("Push harder: press a little longer.", "用力些：按得稍久一点。"), .warn)
        } else if lastDepth > band.upperBound + 0.05 {
            say(Bilingual("Too deep: shorter, lighter pushes.", "太深了：按得短一点、轻一点。"), .warn)
        } else if rate > 0 && rate < 100 {
            say(Bilingual("Faster: aim for 100–120 a minute.", "快一点：每分钟 100–120 次。"), .warn)
        } else if rate > 120 {
            say(Bilingual("Slower: aim for 100–120 a minute.", "慢一点：每分钟 100–120 次。"), .warn)
        } else {
            say(Bilingual("Good push. Keep going.", "按压良好，继续。"), .good)
        }
        if count >= 30 {
            say(Bilingual("30 done. Give 2 breaths.", "完成 30 次，接着吹气 2 次。"), .good)
            later(0.6) { if self.stage == .compress { self.next() } }
        }
    }

    // MARK: frame

    func tick(_ dt: Float) {
        clock += Double(dt)
        if !hinted && scene.ready { hinted = true; showHints() }
        let due = pending.filter { $0.at <= clock }
        pending.removeAll { $0.at <= clock }
        due.forEach { $0.run() }

        // chest: sinks while pressed (longer = deeper), springs back when let go
        let mid = (victim.depth.lowerBound + victim.depth.upperBound) / 2
        if pressing {
            held += dt
            scene.depthCm = 1.2 * mid * (1 - exp(-held / 0.05))
        } else {
            scene.depthCm *= exp(-dt / 0.05)
            if scene.depthCm < 0.01 { scene.depthCm = 0 }
        }
        // breath: 1 s in, 1 s out
        let b = Float(clock - breathStart)
        scene.breath = b < 1 ? sin(b * .pi / 2) : b < 2 ? cos((b - 1) * .pi / 2) : 0
        scene.tilt += (tiltGoal - scene.tilt) * (1 - exp(-dt * 6))
        if abs(tiltGoal - scene.tilt) < 0.002 { scene.tilt = tiltGoal }
        // blood to the brain drains within seconds of stopping
        flow *= exp(-Double(dt) / (stage == .compress ? 6 : 3))
        if pushStarts.last.map({ clock - $0 > 2.5 }) ?? false { rate = 0 }
        scene.update(dt: dt)
    }
}
