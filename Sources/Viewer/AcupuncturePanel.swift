import SwiftUI

/// What the acupuncture viewer shows: region, one meridian or all, only the commonly needled points.
struct AcuFilter: Equatable {
    var region = "all"
    var meridian: String?
    var common = false
    var lines = true

    static let regions: [(id: String, label: Bilingual, focus: Focus)] = [
        ("all", Bilingual("All", "全部"), .all), ("head", Bilingual("Head", "头颈"), .head), ("arm", Bilingual("Arm", "上肢"), .arm),
        ("front", Bilingual("Front", "胸腹"), .front), ("back", Bilingual("Back", "背部"), .back), ("leg", Bilingual("Leg", "下肢"), .leg),
    ]

    func shows(_ p: BodyPoint) -> Bool {
        guard let acu = p.acu else { return false }
        return (region == "all" || p.region == region) && (meridian == nil || acu.meridian == meridian) && (!common || acu.common)
    }
}

extension Meridian {
    /// "Large Intestine" / "大肠经"
    var short: Bilingual {
        Bilingual(name.replacingOccurrences(of: " meridian", with: ""), nameZh.count > 4 ? String(nameZh.dropFirst(3)) : nameZh)
    }
}

struct AcupuncturePanel: View {
    let points: [BodyPoint]
    let meridians: [Meridian]
    @Binding var filter: AcuFilter
    let activeID: String?
    let onPress: (String) -> Void
    let onFocus: (Focus) -> Void
    let onLink: (BodyPoint) -> Void
    @Environment(Settings.self) private var settings
    @State private var needling = false

    var body: some View {
        let visible = points.filter(filter.shows)
        let used = Set(points.compactMap(\.acu?.meridian))
        VStack(alignment: .leading, spacing: Space.s) {
            Picker(settings.t("Region", "部位"), selection: Binding(get: { filter.region }, set: { id in
                filter.region = id
                if let r = AcuFilter.regions.first(where: { $0.id == id }) { onFocus(r.focus) }
            })) {
                ForEach(AcuFilter.regions, id: \.id) { Text(settings.t($0.label)).tag($0.id) }
            }
            .adaptivePickerStyle()
            .padding(.horizontal, Space.l)
            PillRow {
                Pill(label: settings.t("Meridians", "经络线"), selected: filter.lines, symbol: "point.bottomleft.forward.to.point.topright.scurvepath") {
                    filter.lines.toggle()
                }
                Pill(label: settings.t("Commonly needled", "常用穴"), selected: filter.common, symbol: "star.fill") { filter.common.toggle() }
                Divider().frame(height: 24)
                Pill(label: settings.t("All channels", "全部经脉"), selected: filter.meridian == nil) { filter.meridian = nil }
                ForEach(meridians.filter { used.contains($0.id) }) { m in
                    Pill(label: "\(m.id) · \(settings.t(m.short))", selected: filter.meridian == m.id, dot: Color(hex: m.color)) {
                        filter.meridian = filter.meridian == m.id ? nil : m.id
                    }
                }
            }
            if visible.isEmpty {
                Hint(symbol: "line.3.horizontal.decrease.circle", text: settings.t("No points match — widen the filters.", "没有符合条件的穴位，请放宽筛选。"))
            } else {
                PillRow {
                    ForEach(visible) { p in
                        Pill(label: title(p), selected: p.id == activeID, symbol: p.acu?.common == true ? "star.fill" : nil,
                             warn: Cautions.avoid(p.id, for: settings.profile)) { onPress(p.id) }
                    }
                }
            }
            if let p = points.first(where: { $0.id == activeID }), let acu = p.acu {
                let card = AcupointCard(point: p, acu: acu, meridian: meridians.first { $0.id == acu.meridian }, needling: $needling, onLink: onLink)
                // the card scrolls on its own once it outgrows its share, so the body stays in view
                ViewThatFits(in: .vertical) {
                    card
                    #if SCREENSHOTS
                    ScrollView { card }.scrollBounceBehavior(.basedOnSize)
                        .defaultScrollAnchor(Screenshot.flag("cardBottom") ? .bottom : .top)
                    #else
                    ScrollView { card }.scrollBounceBehavior(.basedOnSize)
                    #endif
                }
                .frame(maxHeight: 260)
            } else {
                Hint(symbol: "hand.point.up.left", text: settings.t("Tap a point on the body or a name above. ★ = commonly needled.",
                                                                    "点身体上的穴位或上方名称。★ 为常用穴。"))
            }
        }
        .onChange(of: activeID) { needling = false }
    }

    /// "LI11 Quchi" / "曲池 LI11"
    private func title(_ p: BodyPoint) -> String {
        guard let acu = p.acu else { return settings.name(p.name, p.nameZh) }
        return settings.zh ? "\(p.nameZh) \(acu.code)" : "\(acu.code) \(acu.pinyin)"
    }
}

/// Code, names, location, traditional uses, cautions; needling and safety on demand.
struct AcupointCard: View {
    let point: BodyPoint
    let acu: Acupoint
    let meridian: Meridian?
    @Binding var needling: Bool
    let onLink: (BodyPoint) -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        let color = Color(hex: meridian?.color ?? "#7D7D8C")
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(acu.code)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.s).padding(.vertical, Space.xxs)
                    .background(color, in: .capsule)
                VStack(alignment: .leading, spacing: 0) {
                    Text(settings.zh ? point.nameZh : acu.pinyin).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if acu.common {
                    Label(settings.t("Common", "常用"), systemImage: "star.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.brand)
                        .labelStyle(.titleAndIcon)
                }
            }
            .accessibilityElement(children: .combine)
            section(settings.t("Location", "定位"), settings.name(point.description, point.descriptionZh))
            section(settings.t("Traditional uses", "传统主治"), settings.name(acu.uses, acu.usesZh))
            CautionList(warnings: Cautions.warnings(point.id, for: settings.profile))
            DisclosureGroup(isExpanded: $needling) {
                VStack(alignment: .leading, spacing: Space.s) {
                    // safety first, then the depths
                    ForEach(Cautions.acupunctureSafety, id: \.en) { note in
                        Label(settings.t(note), systemImage: "checkmark.shield")
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(settings.name(acu.needling, acu.needlingZh)).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Space.xs)
            } label: {
                Label(settings.t("Needling & safety", "针刺与安全"), systemImage: "cross.case")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: minTap)
            }
            HStack(alignment: .center) {
                Text(settings.t("Traditional claims — not medical advice.", "传统说法，非医疗建议。"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !acu.organIds.isEmpty {
                    Button { onLink(point) } label: {
                        Label(settings.t("Related organs", "相关脏腑"), systemImage: "scope")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: minTap)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.page, in: .rect(cornerRadius: Radius.tile, style: .continuous))
        .padding(.horizontal, Space.l)
    }

    /// "Pool at the Bend · Large Intestine meridian" / "Quchi · 手阳明大肠经"
    private var subtitle: String {
        let channel = meridian.map { settings.name($0.name, $0.nameZh) } ?? ""
        return settings.zh ? "\(acu.pinyin) · \(channel)" : "\(point.name) · \(channel)"
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
