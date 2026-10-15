import SwiftUI

/// A posture topic: two poses to compare in 3D, a load gauge, what changes, tips and sources.
struct PostureTopic: Identifiable {
    struct Mark {
        let value: Float
        let label: Bilingual
    }

    /// how the gauge's value reads
    enum Unit { case percent, kg, mmHg, degrees }

    let id: String
    let symbol: String
    let title: Bilingual
    let note: Bilingual
    /// false: listed as coming soon
    var ready = false
    var ends: (Bilingual, Bilingual) = (Bilingual("", ""), Bilingual("", ""))
    /// load at each end (relative, standing = 1) and the fixed marks on the gauge
    var loads: (Float, Float) = (1, 1)
    var gauge: (title: Bilingual, marks: [Mark], max: Float) = (Bilingual("", ""), [], 1)
    /// what's happening at each end
    var explain: ([Bilingual], [Bilingual]) = ([], [])
    var tips: [(symbol: String, text: Bilingual)] = []
    var sources: [String] = []
    var caveat: Bilingual?
    /// shown for a pregnant profile
    var pregnancy: Bilingual?
    /// the part of the body the 3D view picks out
    var region: PostureRegion = .lumbar
    var unit: Unit = .percent
    /// value → place on the shared colour scale (1 green, 1.4 amber, 1.85 red), as stops
    var heat: [(value: Float, heat: Float)] = [(0, 0), (3, 3)]
    /// values at evenly spaced slider positions, when the load doesn't follow the slider in a straight line
    var curve: [Float] = []
    /// the neck's load (Hansraj) as a second gauge
    var neckGauge = true
    /// beside the value on each end's card
    var cardLabel = Bilingual("disc", "椎间盘")
    /// under the slider; {pct} the second end's rise in percent, {x} its ratio, {a} {b} the two ends, {neck} the neck's ratio
    var summary = Bilingual("Slumping: +{pct}% pressure on the lumbar discs, and the neck holds the head as if it weighed {neck}× as much.",
                            "瘫坐时：腰椎间盘压力 +{pct}%，颈部承受的头部重量约为 {neck} 倍。")
    /// what the 3D colours mean: the glowing discs (or other load) and the muscles
    var legend = (Bilingual("Lumbar discs", "腰椎间盘"), Bilingual("Back and neck muscles", "腰背与颈部肌肉"))
    var doctor = Bilingual("Not medical advice. See a doctor for back pain that lasts, spreads down a leg, or comes with numbness or weakness.",
                           "非医疗建议。腰痛持续不缓解、向腿部放射，或伴麻木无力时请就医。")
    var sceneLabel = Bilingual("3D figure sitting on a chair", "坐在椅子上的 3D 人体")

    /// the load at slider position t (0…1)
    func load(_ t: Float) -> Float {
        let t = min(max(t, 0), 1)
        guard curve.count > 1 else { return loads.0 + (loads.1 - loads.0) * t }
        let x = t * Float(curve.count - 1), i = min(Int(x), curve.count - 2)
        return curve[i] + (curve[i + 1] - curve[i]) * (x - Float(i))
    }

    func heat(of v: Float) -> Float {
        guard let first = heat.first, v > first.value else { return heat.first?.heat ?? v }
        for i in 1..<heat.count where v <= heat[i].value {
            let a = heat[i - 1], b = heat[i]
            return a.heat + (b.heat - a.heat) * (v - a.value) / (b.value - a.value)
        }
        return heat.last!.heat
    }

    func color(_ v: Float) -> UIColor { PostureColors.load(heat(of: v)) }

    func format(_ v: Float) -> String {
        switch unit {
        case .percent: "\(Int((v * 100).rounded()))%"
        case .kg: "≈\(Int(v.rounded())) kg"
        case .mmHg: "\(Int(v.rounded())) mmHg"
        case .degrees: "\(Int(v.rounded()))°"
        }
    }

    static func find(_ id: String) -> PostureTopic? { all.first { $0.id == id } }

    static let all: [PostureTopic] = [
        PostureTopic(
            id: "sitting", symbol: "chair", title: Bilingual("Long sitting and your lower back", "久坐与腰椎"),
            note: Bilingual("Sit tall vs slump: the load on your lumbar discs", "坐直与瘫坐：腰椎间盘承受的压力"), ready: true,
            ends: (Bilingual("Sit tall", "坐直"), Bilingual("Slump", "瘫坐")),
            loads: (1.4, 1.85),
            gauge: (Bilingual("Pressure in a lumbar disc (L3), standing = 100%", "腰椎间盘（L3）内压，站立 = 100%"),
                    [Mark(value: 0.25, label: Bilingual("Lying", "平躺")), Mark(value: 1.0, label: Bilingual("Standing", "站立")),
                     Mark(value: 1.4, label: Bilingual("Sit tall", "坐直")), Mark(value: 1.85, label: Bilingual("Slump", "瘫坐"))], 2.2),
            explain: ([Bilingual("Pelvis upright on the sit bones", "骨盆立在坐骨上"),
                       Bilingual("Lower back keeps a gentle inward curve", "腰部保持自然前凸"),
                       Bilingual("Load spread evenly over each disc", "压力均匀分布在椎间盘上"),
                       Bilingual("Ears over the shoulders: the neck carries just the head's weight", "耳朵在肩膀正上方：颈部只承受头部本身的重量")],
                      [Bilingual("Pelvis rolls back, hips slide forward", "骨盆后倾，臀部前滑"),
                       Bilingual("Lower back rounds into a C: discs squeezed at the front, pushed backward", "腰椎弯成 C 形：椎间盘前缘受挤、髓核向后推"),
                       Bilingual("Back muscles and ligaments held on stretch", "腰背肌与韧带持续被拉长"),
                       Bilingual("Head pokes forward: the neck muscles carry several times its weight", "头部前伸：颈部肌肉承受数倍于头重的负荷")]),
            tips: [("rectangle.portrait.and.arrow.right", Bilingual("Sit back in the chair; a lumbar support or a rolled towel keeps the curve", "坐满椅面，用腰靠或卷起的毛巾撑住腰部曲线")),
                   ("shoeprints.fill", Bilingual("Feet flat, knees about level with the hips", "双脚平放，膝盖与髋部大致同高")),
                   ("figure.walk", Bilingual("Stand up and move every 30–60 minutes", "每 30–60 分钟起身活动一下")),
                   ("display", Bilingual("Screen at eye level, ears over shoulders, so you don't lean in", "屏幕与眼睛齐平、耳朵在肩膀正上方，免得身体前倾"))],
            sources: ["Nachemson A. Disc pressure measurements. Spine 1981;6(1):93–97.",
                      "Wilke HJ et al. New in vivo measurements of pressures in the intervertebral disc in daily life. Spine 1999;24(8):755–762.",
                      "O'Sullivan PB et al. Effect of different upright sitting postures on spinal-pelvic curvature and trunk muscle activation. Spine 2006;31(19):E707–712.",
                      "Hansraj KK. Assessment of stresses in the cervical spine caused by posture and position of the head. Surg Technol Int 2014;25:277–279."],
            caveat: Bilingual("Classic values (Nachemson). Later measurements (Wilke 1999) found relaxed sitting closer to standing, but slumped, bent-forward sitting stays the highest.",
                              "经典数据（Nachemson）。后来的测量（Wilke 1999）发现放松坐姿接近站立，但弯腰瘫坐始终最高。"),
            pregnancy: Bilingual("Pregnant: the bump already deepens the low-back curve. Sit back with a cushion behind your lower back, feet flat or on a low footrest, and get up often.",
                                 "孕期：孕肚本身会加深腰部前凸。坐满椅面、腰后垫靠枕，双脚平放或踩在矮凳上，并经常起身活动。")),
        PostureTopic(
            id: "computer", symbol: "keyboard", title: Bilingual("Arms and wrists at the computer", "电脑前的手臂与手腕"),
            note: Bilingual("Elbows, shoulders, wrists and the carpal tunnel", "肘、肩、手腕与腕管"), ready: true,
            ends: (Bilingual("Keys at elbow height", "键盘与肘同高"), Bilingual("Desk too high", "桌子太高")),
            loads: (5, 32),
            gauge: (Bilingual("Pressure in the carpal tunnel, ≈ mmHg", "腕管内压力，约 mmHg"),
                    [Mark(value: 5, label: Bilingual("Straight", "平直")), Mark(value: 30, label: Bilingual("Nerve strained", "神经受压"))], 50),
            explain: ([Bilingual("Keyboard at elbow height: forearms level, shoulders relaxed", "键盘与肘部同高：前臂水平，肩膀放松"),
                       Bilingual("Wrists straight: the carpal tunnel is roomiest and the median nerve under least pressure", "手腕平直：腕管最宽松，正中神经受压最小"),
                       Bilingual("Elbows close to the body, bent about 90–100°", "手肘贴近身体，弯曲约 90–100°"),
                       Bilingual("Top of the screen at about eye level", "屏幕顶端大约与眼睛齐平")],
                      [Bilingual("The desk is too high, so the shoulders shrug and stay tense", "桌子太高，肩膀耸起并一直紧绷"),
                       Bilingual("Wrists rest on the edge and bend back about 35° to reach the keys", "手腕压在桌沿上，向上翻约 35° 去够键盘"),
                       Bilingual("Bending the wrist back narrows the carpal tunnel: pressure on the median nerve rises several-fold", "手腕后伸让腕管变窄：正中神经受到的压力成倍上升"),
                       Bilingual("Past about 30 mmHg, blood flow in the nerve suffers: numbness and tingling in the thumb and fingers", "超过约 30 mmHg，神经血流受影响：拇指和手指发麻、刺痛")]),
            tips: [("chair", Bilingual("Raise the chair (or lower the desk) until the keys are at elbow height; use a footrest if your feet dangle", "调高椅子（或调低桌子），让键盘与肘同高；脚够不着地就加脚凳")),
                   ("hand.raised", Bilingual("Keep the wrists straight and floating while you type; rest them only in pauses", "打字时手腕保持平直、悬空，停顿时再放下休息")),
                   ("computermouse", Bilingual("Keep the mouse right beside the keyboard, close to your body", "鼠标紧挨键盘、靠近身体")),
                   ("timer", Bilingual("Every 30–60 minutes, shake out and stretch your hands", "每 30–60 分钟甩甩手、拉伸一下"))],
            sources: ["Gelberman RH et al. The carpal tunnel syndrome. A study of carpal canal pressures. J Bone Joint Surg Am 1981;63(3):380–383.",
                      "Lundborg G et al. Median nerve compression in the carpal tunnel: functional response to experimentally induced controlled pressure. J Hand Surg Am 1982;7(3):252–259.",
                      "Weiss ND et al. Position of the wrist associated with the lowest carpal-tunnel pressure: implications for splint design. J Bone Joint Surg Am 1995;77(11):1695–1699.",
                      "Keir PJ, Bach JM, Hudes M, Rempel DM. Guidelines for wrist posture based on carpal tunnel pressure thresholds. Hum Factors 2007;49(1):88–99."],
            caveat: Bilingual("Approximate values for healthy wrists, measured with a catheter in the carpal tunnel. They vary a lot between people and rise further while the fingers press keys. Keir 2007 found the average wrist reaches 30 mmHg at about 33° of extension.",
                              "健康手腕的近似值，由插入腕管的导管测得。个体差异很大，手指按键时还会更高。Keir 2007 发现，平均而言手腕后伸约 33° 时压力就达到 30 mmHg。"),
            pregnancy: Bilingual("Pregnant: fluid retention makes carpal tunnel symptoms common, especially later on. Keep the wrists straight, take breaks, and mention numbness or tingling at your check-ups; a wrist splint at night often helps.",
                                 "孕期：水肿让腕管症状很常见，孕晚期尤甚。保持手腕平直、多休息，产检时说明手麻或刺痛；夜间戴护腕夹板常有帮助。"),
            region: .wrist, unit: .mmHg, heat: [(5, 1), (15, 1.4), (30, 1.85), (45, 2.5)], curve: [5, 9.5, 17, 32], neckGauge: false,
            cardLabel: Bilingual("wrist", "腕管"),
            summary: Bilingual("Desk too high: about {x}× the pressure on the nerve in each wrist.", "桌子太高时：每只手腕的神经受压约为 {x} 倍。"),
            legend: (Bilingual("Wrist bones", "腕骨"), Bilingual("Shoulder muscles", "肩部肌肉")),
            doctor: Bilingual("Not medical advice. See a doctor for numbness, tingling or weakness in the hand that lasts or wakes you at night.",
                              "非医疗建议。手部麻木、刺痛或无力持续不缓解，或夜里麻醒时请就医。"),
            sceneLabel: Bilingual("3D figure typing at a desk", "坐在桌前打字的 3D 人体")),
        PostureTopic(
            id: "standing", symbol: "figure.stand", title: Bilingual("Long standing and your legs", "久站与腿部"),
            note: Bilingual("Blood pooling in the calves, and the calf pump", "小腿静脉淤血与小腿肌肉泵"), ready: true,
            ends: (Bilingual("Calf raises", "踮脚提踵"), Bilingual("Standing still", "一动不动地站着")),
            loads: (22, 87),
            gauge: (Bilingual("Vein pressure at the ankle, ≈ mmHg", "脚踝静脉压，约 mmHg"),
                    [Mark(value: 22, label: Bilingual("Walking", "行走")), Mark(value: 87, label: Bilingual("Standing still", "静立"))], 100),
            explain: ([Bilingual("Rising onto the toes squeezes the calf muscles around the deep veins", "踮起脚尖时，小腿肌肉挤压包裹其中的深静脉"),
                       Bilingual("One-way valves let the squeezed blood go only upward, toward the heart", "单向静脉瓣只让被挤出的血液向上流回心脏"),
                       Bilingual("After a few raises or steps, pressure in the ankle veins falls to about a quarter", "踮几下或走几步，脚踝静脉压就降到约四分之一"),
                       Bilingual("Shifting your weight and walking do the same job", "换脚、走动也有同样的作用")],
                      [Bilingual("With no squeeze, the column of blood from the heart down to the ankle presses on the leg veins", "没有肌肉挤压时，从心脏到脚踝的整段血柱都压在腿部静脉上"),
                       Bilingual("Ankle vein pressure climbs to about 85–90 mmHg", "脚踝静脉压升到约 85–90 mmHg"),
                       Bilingual("Fluid seeps into the tissue: swollen ankles and heavy, aching legs by evening", "液体渗进组织：傍晚脚踝肿胀、双腿沉重酸痛"),
                       Bilingual("Years of long standing at work are linked with varicose veins", "多年工作久站与静脉曲张有关")]),
            tips: [("figure.walk", Bilingual("Every 20–30 minutes, shift your weight, take a few steps or do 10 calf raises", "每 20–30 分钟换换脚、走几步，或踮脚 10 次")),
                   ("shoeprints.fill", Bilingual("Comfortable, supportive shoes; a cushioned mat if you stand in one spot", "穿舒适、支撑好的鞋；固定站位时脚下垫软垫")),
                   ("arrow.up.circle", Bilingual("At the end of the day, lie with your legs raised for 15 minutes", "一天结束时，躺下把腿抬高 15 分钟")),
                   ("cross.case", Bilingual("If your legs swell, ask about compression stockings", "腿常肿的话，可以咨询是否需要穿压力袜"))],
            sources: ["Pollack AA, Wood EH. Venous pressure in the saphenous vein at the ankle in man during exercise and changes in posture. J Appl Physiol 1949;1(9):649–662.",
                      "Tüchsen F et al. Prolonged standing at work and hospitalisation due to varicose veins: a 12 year prospective study of the Danish population. Occup Environ Med 2005;62(12):847–850.",
                      "Waters TR, Dick RB. Evidence of health risks associated with prolonged standing at work and intervention effectiveness. Rehabil Nurs 2015;40(3):148–165."],
            caveat: Bilingual("Pressures measured with a needle in a vein at the ankle of healthy people (Pollack & Wood 1949). When the vein valves leak, pressure stays high even while walking.",
                              "数据来自健康人脚踝静脉内的穿刺测量（Pollack & Wood 1949）。静脉瓣关闭不全时，即使走动压力也降不下来。"),
            pregnancy: Bilingual("Pregnant: the womb presses on the pelvic veins and hormones relax vein walls, so legs swell faster. Move often, raise your legs when resting, lie on your left side, and ask about compression stockings.",
                                 "孕期：子宫压迫盆腔静脉，激素又让静脉壁变松弛，腿更容易肿。多活动，休息时抬高双腿，左侧卧，并咨询是否需要压力袜。"),
            region: .legs, unit: .mmHg, heat: [(10, 0.6), (22, 1), (50, 1.45), (87, 1.95)], neckGauge: false,
            cardLabel: Bilingual("ankle vein", "脚踝静脉"),
            summary: Bilingual("Standing still: about {x}× the pressure in the ankle veins.", "一动不动地站着：脚踝静脉压约为踮脚时的 {x} 倍。"),
            legend: (Bilingual("Leg veins", "腿部静脉"), Bilingual("Calf muscles (the pump)", "小腿肌肉（泵）")),
            doctor: Bilingual("Not medical advice. See a doctor at once for one leg that suddenly swells, hurts or turns red (a possible clot), or swelling with breathlessness.",
                              "非医疗建议。一条腿突然肿胀、疼痛或发红（可能是血栓），或腿肿伴气短时，请立即就医。"),
            sceneLabel: Bilingual("3D figure standing, rising onto the toes", "站立并踮起脚尖的 3D 人体")),
        PostureTopic(
            id: "couch", symbol: "sofa", title: Bilingual("Sitting on a couch", "坐沙发"),
            note: Bilingual("Sinking into soft cushions vs a cushion at the low back", "陷进软垫 vs 腰后垫靠枕"), ready: true,
            ends: (Bilingual("Cushion at the low back", "腰后垫靠枕"), Bilingual("Sunk in", "陷进沙发")),
            loads: (0, 35),
            gauge: (Bilingual("Low back rounded, degrees (3D model)", "腰椎弯曲程度，度（3D 模型）"),
                    [Mark(value: 0, label: Bilingual("Curve kept", "保持曲线")), Mark(value: 35, label: Bilingual("Rounded", "弓成 C 形"))], 45),
            explain: ([Bilingual("A firm cushion fills the gap behind the low back", "结实的靠枕填满腰后的空隙"),
                       Bilingual("Leaning back on it, the backrest carries part of the trunk's weight", "靠在上面，椅背分担了部分上身重量"),
                       Bilingual("The low back keeps its gentle inward curve", "腰部保持自然前凸"),
                       Bilingual("Hips stay back on the seat, head over the shoulders", "臀部坐在座位后部，头在肩膀上方")],
                      [Bilingual("Soft, deep cushions let the hips slide forward and the pelvis roll far back", "又软又深的坐垫让臀部前滑、骨盆大幅后倾"),
                       Bilingual("The low back rounds into a C: the discs are squeezed at the front, pushed backward", "腰椎弯成 C 形：椎间盘前缘受挤、髓核向后推"),
                       Bilingual("Ligaments at the back of the spine hold the trunk up instead of the muscles", "靠脊柱后方的韧带撑住上身，而不是肌肉"),
                       Bilingual("Held for a film or two, this is a common trigger of low-back ache", "一两部电影的时间保持这个姿势，常会引起腰痛")]),
            tips: [("sofa", Bilingual("Put a firm cushion or a rolled towel behind your low back", "腰后垫一个结实的靠枕或卷起的毛巾")),
                   ("arrow.down.to.line", Bilingual("Sit right back on the seat; a deep couch may need a cushion behind you to shorten it", "坐满座位；沙发太深就在背后垫靠枕把它“变浅”")),
                   ("shoeprints.fill", Bilingual("Feet flat on the floor or on a footstool, not tucked under you", "双脚平放地面或踩脚凳，不要盘在身下")),
                   ("figure.walk", Bilingual("Get up at every episode or ad break", "每集结束或插播广告时起身活动"))],
            sources: ["Andersson BJ, Örtengren R, Nachemson A, Elfström G. Lumbar disc pressure and myoelectric back muscle activity during sitting. I. Studies on an experimental chair. Scand J Rehabil Med 1974;6(3):104–114.",
                      "Nachemson A. Disc pressure measurements. Spine 1981;6(1):93–97.",
                      "Wilke HJ et al. New in vivo measurements of pressures in the intervertebral disc in daily life. Spine 1999;24(8):755–762.",
                      "Callaghan JP, McGill SM. Low back joint loading and kinematics during standing and unsupported sitting. Ergonomics 2001;44(3):280–294."],
            caveat: Bilingual("The gauge reads the 3D model's low-back bend, not a measurement. Disc pressure studies agree on the direction: a reclined backrest with a low-back support lowers the pressure (Andersson 1974), and rounded, slumped sitting raises it (Nachemson 1981, Wilke 1999).",
                              "刻度显示的是 3D 模型的腰椎弯曲角度，并非实测。椎间盘压力研究的结论方向一致：后仰的椅背加腰部支撑能降低压力（Andersson 1974），弓背瘫坐则会升高压力（Nachemson 1981、Wilke 1999）。"),
            pregnancy: Bilingual("Pregnant: a deep, soft couch is hard to get out of and lets the low back sag. Sit back with a firm cushion behind you, keep your knees a little below your hips, and roll to your side to get up.",
                                 "孕期：又深又软的沙发起身困难，还会让腰部塌陷。坐满座位、背后垫结实的靠枕，让膝盖略低于髋部，起身时先侧身。"),
            region: .lumbar, unit: .degrees, heat: [(0, 1), (15, 1.4), (30, 1.85), (40, 2.2)], neckGauge: false,
            cardLabel: Bilingual("low-back bend", "腰椎弯曲"),
            summary: Bilingual("Sunk in: the low back rounds about {b} away from its natural curve.", "陷进沙发时：腰椎偏离自然曲线、弓起约 {b}。"),
            sceneLabel: Bilingual("3D figure sitting on a couch", "坐在沙发上的 3D 人体")),
        PostureTopic(id: "floor", symbol: "figure.mind.and.body", title: Bilingual("Sitting on the floor", "席地而坐"),
                     note: Bilingual("Cross-legged and slouched vs against a wall", "盘腿弓背 vs 靠墙坐")),
        PostureTopic(
            id: "laptop", symbol: "laptopcomputer", title: Bilingual("Laptop on your lap", "笔记本放腿上"),
            note: Bilingual("Bent neck and rounded shoulders vs a raised screen", "低头圆肩 vs 抬高屏幕"), ready: true,
            ends: (Bilingual("Raised screen", "屏幕抬高"), Bilingual("On your lap", "放在腿上")),
            loads: (5, 22),
            gauge: (Bilingual("Load on the neck from the head, ≈ kg", "头部对颈椎的负荷，约 kg"), Neck.marks, 30),
            explain: ([Bilingual("Top of the screen at eye level: the head stays balanced over the shoulders", "屏幕顶端与眼睛齐平：头部稳稳立在肩膀上方"),
                       Bilingual("A separate keyboard at elbow height: shoulders relaxed, forearms level", "外接键盘放在肘部高度：肩膀放松，前臂水平"),
                       Bilingual("Back against the chair, the low back keeps its curve", "背靠椅背，腰部保持自然曲线"),
                       Bilingual("The neck carries about the head's own weight", "颈部只承受大约头部本身的重量")],
                      [Bilingual("The eyes drop to a screen at thigh level, so the head bows about 45°", "视线落到大腿高度的屏幕上，头部前倾约 45°"),
                       Bilingual("At 45° the neck works as if the head weighed about 22 kg", "前倾 45° 时，颈部承受的负荷约相当于 22 kg"),
                       Bilingual("The upper back rounds and the shoulders roll forward to reach the keys", "上背弓起、肩膀前扣去够键盘"),
                       Bilingual("The low back slumps away from the chair", "腰部离开椅背，塌成弓形")]),
            tips: [("laptopcomputer", Bilingual("Raise the screen to eye level on a stand or a stack of books", "用支架或一摞书把屏幕抬到与眼睛齐平")),
                   ("keyboard", Bilingual("Add a separate keyboard and mouse so your hands can stay low", "外接键盘和鼠标，让双手留在低处")),
                   ("chair", Bilingual("Sit back against the chair with your feet flat", "背靠椅背坐，双脚平放")),
                   ("timer", Bilingual("On the couch or in bed, keep it short and change position often", "在沙发或床上用时，时间要短，并经常换姿势"))],
            sources: ["Straker L, Jones KJ, Miller J. A comparison of the postures assumed when using laptop computers and desktop computers. Appl Ergon 1997;28(4):263–268.",
                      "Berkhout AL, Hendriksson-Larsén K, Bongers P. The effect of using a laptopstation compared to using a standard laptop PC on the cervical spine torque, perceived strain and productivity. Appl Ergon 2004;35(2):147–152.",
                      "Asundi K et al. Notebook computer use on a desk, lap and lap support: effects on posture, performance and comfort. Ergonomics 2010;53(1):74–82.",
                      "Hansraj KK. Assessment of stresses in the cervical spine caused by posture and position of the head. Surg Technol Int 2014;25:277–279."],
            caveat: Bilingual("Neck loads from Hansraj's head-tilt model, a computer model. The 45° shown is a typical lap posture; studies agree a laptop on the lap bends the head and neck further than a raised screen (Straker 1997, Asundi 2010).",
                              "颈部负荷按 Hansraj 的头部前倾计算模型估算。图中 45° 为典型的腿上姿势；研究一致发现，笔记本放在腿上比抬高屏幕时头颈弯得更多（Straker 1997、Asundi 2010）。"),
            pregnancy: Bilingual("Pregnant: the lap shrinks as the bump grows, and leaning over it strains the back. Use a table or a lap desk, and raise the screen.",
                                 "孕期：孕肚越大，腿上空间越小，俯身越伤腰背。请用桌子或膝上桌，并把屏幕抬高。"),
            region: .neck, unit: .kg, heat: Neck.heat, curve: [Neck.kg(0), Neck.kg(15), Neck.kg(30), Neck.kg(45)], neckGauge: false,
            cardLabel: Bilingual("on the neck", "颈部"),
            summary: Bilingual("On your lap: the neck holds the head as if it weighed {x}× as much.", "放在腿上时：颈部承受的头部重量约为抬高屏幕时的 {x} 倍。"),
            legend: (Bilingual("Neck discs", "颈椎间盘"), Bilingual("Neck and shoulder muscles", "颈肩肌肉")),
            doctor: Bilingual("Not medical advice. See a doctor for neck pain that lasts, spreads into an arm, or comes with numbness, tingling or weakness.",
                              "非医疗建议。颈痛持续不缓解、向手臂放射，或伴麻木、刺痛、无力时请就医。"),
            sceneLabel: Bilingual("3D figure at a desk with a raised laptop, then with the laptop on the lap", "坐在桌前用抬高的笔记本、再把笔记本放到腿上的 3D 人体")),
        PostureTopic(
            id: "phone-standing", symbol: "iphone", title: Bilingual("Looking down at your phone", "低头看手机"),
            note: Bilingual("How the load on your neck grows as the head tips forward", "头越低，颈椎负荷越大"), ready: true,
            ends: (Bilingual("Head up", "抬头平视"), Bilingual("Head down 60°", "低头 60°")),
            loads: (5, 27),
            gauge: (Bilingual("Load on the neck from the head, ≈ kg", "头部对颈椎的负荷，约 kg"), Neck.marks, 30),
            explain: ([Bilingual("Ears over the shoulders: the neck carries just the head's own weight, about 5 kg", "耳朵在肩膀正上方：颈部只承受头部本身的重量，约 5 kg"),
                       Bilingual("The neck keeps its gentle inward curve", "颈椎保持自然前凸"),
                       Bilingual("The muscles at the back of the neck barely need to work", "颈后肌肉几乎不用费力"),
                       Bilingual("Phone raised toward eye level, elbows close to the body", "手机抬到接近视线高度，手肘贴近身体")],
                      [Bilingual("The further the head tips, the further its weight hangs in front of the spine, and the harder the neck muscles pull to hold it", "头越低，重心越偏离脊柱前方，颈后肌肉要越用力才能拉住它"),
                       Bilingual("At 60° the neck works as if the head weighed about 27 kg, over five times its real weight", "低头 60° 时，颈部承受的负荷约相当于 27 kg，是头部实际重量的五倍多"),
                       Bilingual("The neck's inward curve flattens: the discs are squeezed at the front", "颈椎前凸变直：椎间盘前缘受挤压"),
                       Bilingual("Shoulders round forward; the muscles from the skull to the shoulder blades stay on stretch", "肩膀前扣，从颅底到肩胛骨的肌肉持续被拉长")]),
            tips: [("iphone", Bilingual("Raise the phone toward eye level and lower your eyes, not your head", "把手机举高到接近视线，用眼睛往下看，而不是低头")),
                   ("hand.raised", Bilingual("Rest your elbows on a table, your bag or your chest to hold it up without tiring", "手肘撑在桌上、包上或贴着胸口，举高手机也不累")),
                   ("timer", Bilingual("Look up from the screen every 15–20 minutes", "每 15–20 分钟抬头离开屏幕")),
                   ("arrow.uturn.backward", Bilingual("Chin tucks: glide the head straight back until the ears are over the shoulders, 10 times", "收下巴：头部水平向后移，直到耳朵在肩膀正上方，做 10 次"))],
            sources: ["Hansraj KK. Assessment of stresses in the cervical spine caused by posture and position of the head. Surg Technol Int 2014;25:277–279.",
                      "Lee S, Kang H, Shin G. Head flexion angle while using a smartphone. Ergonomics 2015;58(2):220–226.",
                      "Vasavada AN et al. Gravitational demand on the neck musculature during tablet computer use. Ergonomics 2015;58(6):990–1004.",
                      "Barrett JM, McKinnon C, Callaghan JP. Cervical spine joint loading with neck flexion. Ergonomics 2020;63(1):101–108."],
            caveat: Bilingual("Hansraj's figures come from a simple computer model, not measurements in people. Later models (Vasavada 2015, Barrett 2020) give lower numbers but agree the load climbs steeply as the head tips. People texting typically hold the head about 35–45° forward (Lee 2015).",
                              "Hansraj 的数据来自简化的计算模型，并非人体实测。后来的模型（Vasavada 2015、Barrett 2020）数值较低，但同样显示头越低负荷上升越快。人们发短信时头部通常前倾约 35–45°（Lee 2015）。"),
            pregnancy: Bilingual("Pregnant: a growing bust and bump already pull the shoulders forward. Hold the phone higher with your elbows propped on a cushion or table, and look up often.",
                                 "孕期：日渐增大的胸部和孕肚本身就会把肩膀往前拉。把手机举高、手肘垫在靠枕或桌上，并经常抬头。"),
            region: .neck, unit: .kg, heat: Neck.heat, curve: Neck.table.map(\.kg), neckGauge: false,
            cardLabel: Bilingual("on the neck", "颈部"),
            summary: Bilingual("Head down 60°: the neck holds the head as if it weighed {x}× as much.", "低头 60° 时：颈部承受的头部重量约为平视时的 {x} 倍。"),
            legend: (Bilingual("Neck discs", "颈椎间盘"), Bilingual("Neck and shoulder muscles", "颈肩肌肉")),
            doctor: Bilingual("Not medical advice. See a doctor for neck pain that lasts, spreads into an arm, or comes with numbness, tingling or weakness.",
                              "非医疗建议。颈痛持续不缓解、向手臂放射，或伴麻木、刺痛、无力时请就医。"),
            sceneLabel: Bilingual("3D figure standing, looking down at a phone", "站着低头看手机的 3D 人体")),
        PostureTopic(
            id: "phone-bed", symbol: "bed.double", title: Bilingual("Phone in bed", "躺着玩手机"),
            note: Bilingual("Neck, shoulder and arm strain, and sleep", "颈、肩、手臂劳损与睡眠"), ready: true,
            ends: (Bilingual("Flat, phone up", "平躺举手机"), Bilingual("Propped, chin down", "垫高低头")),
            loads: (0, 45),
            gauge: (Bilingual("Neck bent toward the chest, degrees", "颈部向胸前弯曲的角度"),
                    [Mark(value: 0, label: Bilingual("Neutral", "中立")), Mark(value: 15, label: Bilingual("15°", "15°")),
                     Mark(value: 30, label: Bilingual("30°", "30°")), Mark(value: 45, label: Bilingual("45°", "45°"))], 60),
            explain: ([Bilingual("The pillow carries the head; the neck rests near its neutral curve", "枕头托住头部，颈椎接近自然中立的曲线"),
                       Bilingual("Arms held up over the face: the shoulders and arms tire, so you keep shifting", "手臂举在脸上方：肩膀和手臂会累，于是不停换姿势"),
                       Bilingual("Screen light this close to the eyes still keeps you awake", "离眼睛这么近的屏幕光，依然会让人不困")],
                      [Bilingual("Stacked pillows push the head forward: the neck stays bent about 45° toward the chest", "叠高的枕头把头往前推：颈部持续向胸前弯约 45°"),
                       Bilingual("Ligaments and muscles at the back of the neck stay on stretch; the discs are squeezed at the front", "颈后韧带和肌肉持续被拉长，椎间盘前缘受挤压"),
                       Bilingual("The upper back rounds and the shoulders roll in over the phone", "上背弓起，肩膀向手机内扣"),
                       Bilingual("Lying back, gravity pulls on the head less than standing, but the bend is held for a long time", "半躺时重力对头部的拉力比站立时小，但这个弯曲会保持很久")]),
            tips: [("bed.double", Bilingual("One pillow that keeps your head in line with your body", "用一个让头部与身体保持一条线的枕头")),
                   ("arrow.triangle.2.circlepath", Bilingual("Lie on your side with the phone on the mattress at eye level, and switch sides", "侧躺，把手机放在床垫上与眼睛齐平，并左右轮换")),
                   ("sun.min", Bilingual("Turn the brightness down and use night mode", "调低亮度，开启夜间模式")),
                   ("moon.zzz", Bilingual("Put the phone away 30–60 minutes before sleep", "睡前 30–60 分钟放下手机"))],
            sources: ["Chang AM et al. Evening use of light-emitting eReaders negatively affects sleep, circadian timing, and next-morning alertness. PNAS 2015;112(4):1232–1237.",
                      "Exelmans L, Van den Bulck J. Bedtime mobile phone use and sleep in adults. Soc Sci Med 2016;148:93–101.",
                      "Gustafsson E et al. Texting on mobile phones and musculoskeletal disorders in young adults: a five-year cohort study. Appl Ergon 2017;58:208–214."],
            caveat: Bilingual("There is no good measurement of neck load lying down: the pillow carries much of the head, so standing figures (Hansraj) don't apply. The concern is a long bend near the end of the neck's range, and arms held up. Screen use in bed pushes back sleep (Chang 2015, Exelmans 2016).",
                              "躺着时的颈部负荷没有可靠的实测数据：枕头承担了大部分头重，站立时的数据（Hansraj）并不适用。问题在于颈部长时间接近极限的弯曲，以及手臂一直举着。睡前在床上用手机会推迟入睡（Chang 2015、Exelmans 2016）。"),
            pregnancy: Bilingual("Pregnant: from mid-pregnancy, lying flat on your back for long can press on the large vein behind the womb. Lie on your side with a pillow between your knees, and keep the phone at eye level on the mattress.",
                                 "孕期：从孕中期起，长时间平躺可能压迫子宫后方的大静脉。请侧躺、两膝之间夹一个枕头，并把手机放在床垫上与眼睛齐平。"),
            region: .neck, unit: .degrees, heat: [(0, 1), (15, 1.4), (30, 1.85), (45, 2.3), (60, 2.75)], neckGauge: false,
            cardLabel: Bilingual("neck bend", "颈部弯曲"),
            summary: Bilingual("Propped up: the neck stays bent {b} toward the chest for as long as you scroll.", "垫高低头时：只要还在刷手机，颈部就一直向胸前弯着 {b}。"),
            legend: (Bilingual("Neck discs", "颈椎间盘"), Bilingual("Neck and shoulder muscles", "颈肩肌肉")),
            doctor: Bilingual("Not medical advice. See a doctor for neck pain that lasts, spreads into an arm, or comes with numbness, tingling or weakness.",
                              "非医疗建议。颈痛持续不缓解、向手臂放射，或伴麻木、刺痛、无力时请就医。"),
            sceneLabel: Bilingual("3D figure lying in bed with a phone", "躺在床上玩手机的 3D 人体")),
    ]
}

/// Home section: one row per posture topic; unfinished ones are listed as coming soon.
struct PostureSection: View {
    @Environment(Settings.self) private var settings
    private let color = Color(hex: "#2E8B7A")

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                SectionHeader(settings.t("Posture & habits", "姿势与习惯"))
                Text(settings.t("See what everyday positions do inside your body.", "看看日常姿势对身体内部的影响。"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(PostureTopic.all.enumerated()), id: \.element.id) { i, topic in
                    if i > 0 { Divider().padding(.leading, Space.l + 30 + Space.m) }
                    if topic.ready {
                        NavigationLink(value: Route.posture(id: topic.id)) { row(topic) }
                            .buttonStyle(RowButtonStyle())
                    } else {
                        row(topic)
                    }
                }
            }
            .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func row(_ topic: PostureTopic) -> some View {
        let soon = !topic.ready
        return HStack(spacing: Space.m) {
            IconBadge(symbol: topic.symbol, color: soon ? .gray : color)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(topic.title)).font(.body).foregroundStyle(soon ? .secondary : .primary)
                Text(settings.t(topic.note)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            if soon {
                Text(settings.t("Soon", "即将推出"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, Space.s).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: .capsule)
            } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(minHeight: minTap)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(soon ? settings.t("Coming soon", "即将推出") : "")
    }
}
