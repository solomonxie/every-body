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

/// Nothing picked: one row of filters, points of a chosen channel. A point picked: just its card.
struct AcupuncturePanel<Extras: View>: View {
    let points: [BodyPoint]
    let meridians: [Meridian]
    @Binding var filter: AcuFilter
    let activeID: String?
    let onPress: (String) -> Void
    let onClose: () -> Void
    let onFocus: (Focus) -> Void
    let onLink: (BodyPoint) -> Void
    /// layers and figure menus, after the filters
    @ViewBuilder let extras: Extras
    @Environment(Settings.self) private var settings
    @State private var needling = false

    var body: some View {
        Group {
            if let p = points.first(where: { $0.id == activeID }), let acu = p.acu {
                card(p, acu)
            } else {
                filters
            }
        }
        .onChange(of: activeID) { needling = false }
    }

    private var filters: some View {
        let visible = points.filter(filter.shows)
        let used = Set(points.compactMap(\.acu?.meridian))
        let region = AcuFilter.regions.first { $0.id == filter.region }
        let channel = meridians.first { $0.id == filter.meridian }
        return VStack(alignment: .leading, spacing: Space.s) {
            PillRow {
                MenuPill(label: filter.region == "all" ? settings.t("Region", "部位") : settings.t(region?.label ?? Bilingual("", ""))) {
                    Picker(settings.t("Region", "部位"), selection: Binding(get: { filter.region }, set: { id in
                        filter.region = id
                        if let r = AcuFilter.regions.first(where: { $0.id == id }) { onFocus(r.focus) }
                    })) {
                        ForEach(AcuFilter.regions, id: \.id) { Text(settings.t($0.label)).tag($0.id) }
                    }
                }
                MenuPill(label: channel.map { "\($0.id) · \(settings.t($0.short))" } ?? settings.t("Channel", "经脉")) {
                    Picker(settings.t("Channel", "经脉"), selection: $filter.meridian) {
                        Text(settings.t("All channels", "全部经脉")).tag(String?.none)
                        ForEach(meridians.filter { used.contains($0.id) }) { m in
                            Text("\(m.id) · \(settings.t(m.short))").tag(Optional(m.id))
                        }
                    }
                }
                Pill(label: settings.t("Common", "常用"), selected: filter.common, symbol: "star.fill") { filter.common.toggle() }
                extras
            }
            if visible.isEmpty {
                Hint(symbol: "line.3.horizontal.decrease.circle", text: settings.t("No points match — widen the filters.", "没有符合条件的穴位，请放宽筛选。"))
            } else if filter.meridian != nil {
                // one channel is a short list: its points by name
                PillRow {
                    ForEach(visible) { p in
                        Pill(label: title(p), selected: false, symbol: p.acu?.common == true ? "star.fill" : nil,
                             warn: Cautions.avoid(p.id, for: settings.profile)) { onPress(p.id) }
                    }
                }
            } else {
                Hint(symbol: "hand.point.up.left", text: settings.t("Tap a point on the body · \(visible.count) points",
                                                                    "点身体上的穴位 · 共 \(visible.count) 个"))
            }
        }
    }

    private func card(_ p: BodyPoint, _ acu: Acupoint) -> some View {
        let card = AcupointCard(point: p, acu: acu, meridian: meridians.first { $0.id == acu.meridian }, needling: $needling,
                                onClose: onClose, onLink: onLink)
        // the card scrolls on its own once it outgrows its share, so the body stays in view
        return ViewThatFits(in: .vertical) {
            card
            #if SCREENSHOTS
            ScrollView { card }.scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(Screenshot.flag("cardBottom") ? .bottom : .top)
            #else
            ScrollView { card }.scrollBounceBehavior(.basedOnSize)
            #endif
        }
        .frame(maxHeight: 300)
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
    var onClose: (() -> Void)? = nil
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
                        .accessibilityElement(children: .combine)
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                            .frame(width: minTap, height: minTap)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.t("Close", "关闭"))
                }
            }
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
