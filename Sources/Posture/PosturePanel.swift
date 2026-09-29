import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Under the 3D view: the slider between the two postures, the load gauge, what changes, tips and sources.
struct PosturePanel: View {
    let topic: PostureTopic
    @Binding var blend: Double
    /// forward lean of the neck (degrees from sitting tall) at the slumped end, from the posed model
    var neckLean: Float = 34
    var pregnant = false
    @Environment(Settings.self) private var settings

    private var load: Float { topic.loads.0 + (topic.loads.1 - topic.loads.0) * Float(blend) }
    private var neck: Float { Neck.kg(neckLean * Float(blend)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if pregnant, let note = topic.pregnancy {
                Banner(text: settings.t(note), symbol: "figure.and.child.holdinghands", ink: .note, fill: .noteFill)
            }
            compare
            gauges
            explain
            tips
            sources
        }
    }

    // MARK: before / after

    private var compare: some View {
        let tall = (disc: topic.loads.0, neck: Neck.kg(0)), slump = (disc: topic.loads.1, neck: Neck.kg(neckLean))
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                side(topic.ends.0, disc: tall.disc, neck: tall.neck, on: blend < 0.5) { blend = 0 }
                Image(systemName: "arrow.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                side(topic.ends.1, disc: slump.disc, neck: slump.neck, on: blend >= 0.5) { blend = 1 }
            }
            Slider(value: $blend, in: 0...1)
                .tint(Color(uiColor: PostureColors.load(load)))
                .accessibilityLabel(settings.t("Posture", "姿势"))
                .accessibilityValue(settings.t(blend < 0.5 ? topic.ends.0 : topic.ends.1))
            let more = Int(((slump.disc / tall.disc - 1) * 100).rounded())
            let times = String(format: "%.1f", slump.neck / tall.neck)
            Label(settings.t("Slumping: +\(more)% pressure on the lumbar discs, and the neck holds the head as if it weighed \(times)× as much.",
                             "瘫坐时：腰椎间盘压力 +\(more)%，颈部承受的头部重量约为 \(times) 倍。"),
                  systemImage: "arrow.up.right")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.caution)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func side(_ title: Bilingual, disc: Float, neck: Float, on: Bool, action: @escaping () -> Void) -> some View {
        let color = Color(uiColor: PostureColors.load(disc))
        return Button { withAnimation(.snappy) { action() } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(title)).font(.subheadline.weight(.bold)).foregroundStyle(on ? Color.primary : .secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int((disc * 100).rounded()))%").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(color)
                    Text(settings.t("disc", "椎间盘")).font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("≈\(Int(neck.rounded())) kg").font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color(uiColor: Neck.color(neck)))
                    Text(settings.t("on the neck", "颈部")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.m)
            .background(on ? color.opacity(0.12) : Color.fill.opacity(0.5), in: .rect(cornerRadius: Radius.tile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(on ? color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: gauges

    private var gauges: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            reading(settings.t(topic.gauge.title), value: "\(Int((load * 100).rounded()))%", color: PostureColors.load(load))
            LoadGauge(value: load, marks: topic.gauge.marks, max: topic.gauge.max, color: PostureColors.load)
                .frame(height: 50)
            Divider()
            reading(settings.t("Load on the neck from the head, ≈ kg", "头部对颈椎的负荷，约 kg"), value: "≈\(Int(neck.rounded())) kg", color: Neck.color(neck))
            LoadGauge(value: neck, marks: Neck.marks, max: 30, color: Neck.color)
                .frame(height: 50)
            if let caveat = topic.caveat {
                Text(settings.t(caveat)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(settings.t("Neck: head tipped forward by the angle shown (Hansraj 2014, a computer model). A slump pushes the head \(Int(neckLean.rounded()))° forward.",
                            "颈部：按图中头部前倾角度估算（Hansraj 2014，计算模型）。瘫坐时头部前倾约 \(Int(neckLean.rounded()))°。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func reading(_ title: String, value: String, color: UIColor) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: Space.s)
            Text(value).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Color(uiColor: color))
                .contentTransition(.numericText())
        }
    }

    private var explain: some View {
        let lines = blend < 0.5 ? topic.explain.0 : topic.explain.1
        return VStack(alignment: .leading, spacing: Space.s) {
            Eyebrow(settings.t("What's happening", "身体里发生了什么"))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label { Text(settings.t(line)).fixedSize(horizontal: false, vertical: true) } icon: {
                    Circle().fill(Color(uiColor: PostureColors.load(load))).frame(width: 8, height: 8)
                }
                .font(.subheadline)
            }
            HStack(spacing: Space.m) {
                legend(PostureColors.load(load), settings.t("Lumbar discs", "腰椎间盘"))
                legend(UIColor(hex: blend < 0.5 ? "#C1443C" : "#FF7A2F"), settings.t("Back and neck muscles", "腰背与颈部肌肉"))
            }
            .padding(.top, Space.xs)
        }
        .card()
        .animation(.easeInOut(duration: 0.2), value: blend < 0.5)
    }

    private func legend(_ color: UIColor, _ text: String) -> some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: 3).fill(Color(uiColor: color)).frame(width: 14, height: 8)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Eyebrow(settings.t("What helps", "怎么做"))
            ForEach(Array(topic.tips.enumerated()), id: \.offset) { _, tip in
                Label { Text(settings.t(tip.text)).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: tip.symbol).foregroundStyle(Color.success)
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Eyebrow(settings.t("Sources", "参考资料"))
            ForEach(topic.sources, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            Text(settings.t("Not medical advice. See a doctor for back pain that lasts, spreads down a leg, or comes with numbness or weakness.",
                            "非医疗建议。腰痛持续不缓解、向腿部放射，或伴麻木无力时请就医。"))
                .font(.caption).foregroundStyle(.secondary).padding(.top, Space.xs)
        }
        .card()
    }
}

/// A horizontal scale, coloured by load, with fixed marks and the current value's pointer.
private struct LoadGauge: View {
    let value: Float
    let marks: [PostureTopic.Mark]
    let max: Float
    let color: (Float) -> UIColor
    @Environment(Settings.self) private var settings

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (v: Float) in CGFloat(Swift.min(v / max, 1)) * w }
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(LinearGradient(stops: stride(from: Float(0), through: max, by: max / 12).map {
                        .init(color: Color(uiColor: color($0)), location: CGFloat($0 / max))
                    }, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .offset(y: 14)
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    Rectangle().fill(.primary.opacity(0.5)).frame(width: 1.5, height: 16).offset(x: x(mark.value) - 0.75, y: 11)
                    Text(settings.t(mark.label))
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: 80)
                        .offset(x: Swift.min(Swift.max(x(mark.value) - 40, -18), w - 62), y: 32)
                }
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .offset(x: x(value) - 6.5, y: -3)
            }
            .animation(.snappy, value: value)
        }
    }
}



/// Effective weight of the head on the cervical spine by forward tilt (Hansraj 2014): 0° ≈ 5 kg … 60° ≈ 27 kg.
enum Neck {
    static let table: [(deg: Float, kg: Float)] = [(0, 5), (15, 12), (30, 18), (45, 22), (60, 27)]

    static func kg(_ deg: Float) -> Float {
        let d = min(max(deg, 0), 60)
        for i in 1..<table.count where d <= table[i].deg {
            let a = table[i - 1], b = table[i]
            return a.kg + (b.kg - a.kg) * (d - a.deg) / (b.deg - a.deg)
        }
        return table.last!.kg
    }

    /// green when upright, amber, red past ~18 kg
    static func color(_ kg: Float) -> UIColor {
        let load: Float = kg <= 5 ? 1 : kg <= 12 ? 1 + 0.4 * (kg - 5) / 7 : kg <= 18 ? 1.4 + 0.45 * (kg - 12) / 6 : 1.85 + 0.9 * min((kg - 18) / 9, 1)
        return PostureColors.load(load)
    }

    static let marks: [PostureTopic.Mark] = table.map { Mark(value: $0.kg, label: Bilingual("\(Int($0.deg))°", "\(Int($0.deg))°")) }
    typealias Mark = PostureTopic.Mark
}
