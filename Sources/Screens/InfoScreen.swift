import SwiftUI

struct SystemPart: Hashable {
    let partID: String
    let name: String
    let nameZh: String
}

/// One entry per anatomical name (left/right and numbered items collapsed), from the system's layers.
func systemParts(_ systemID: String) -> [SystemPart] {
    let layers = Set((Catalog.body.defaultLayers[systemID] ?? [.organs]).filter { $0 != .skin })
    func base(_ s: String) -> String {
        s.replacingOccurrences(of: #" \((L|R)\)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^[左右]"#, with: "", options: .regularExpression)
    }
    var seen = Set<String>(), items: [SystemPart] = []
    for part in Catalog.body.parts where layers.contains(part.layer) {
        let name = base(part.name).replacingOccurrences(of: #"^(C|T|L)\d+ vertebra$"#, with: "Vertebra", options: .regularExpression)
            .replacingOccurrences(of: #"^Rib \d+$"#, with: "Rib", options: .regularExpression)
        let zh = base(part.nameZh).replacingOccurrences(of: #"^第\d+(颈椎|胸椎|腰椎)$"#, with: "椎骨", options: .regularExpression)
            .replacingOccurrences(of: #"^第\d+肋$"#, with: "肋骨", options: .regularExpression)
        if seen.insert(name).inserted { items.append(SystemPart(partID: part.id, name: name, nameZh: zh)) }
    }
    if layers.contains(.organs) {
        for organ in Catalog.body.organs {
            guard let n = organ.names else { continue }
            let name = n[0].replacingOccurrences(of: #"^(Left|Right) "#, with: "", options: .regularExpression).capitalized
            if seen.insert(name).inserted { items.append(SystemPart(partID: organ.id, name: name, nameZh: base(n[1]))) }
        }
    }
    return items
}

struct InfoScreen: View {
    let systemID: String
    @Environment(Settings.self) private var settings

    var body: some View {
        let system = Catalog.system(systemID)
        ScrollView {
            InfoContent(systemID: systemID)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
        }
        .background(Color.page)
        .navigationTitle(system.map { settings.name($0.name, $0.nameZh) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .profileToolbar()
    }
}

struct InfoContent: View {
    let systemID: String
    @Environment(Settings.self) private var settings

    var body: some View {
        let system = Catalog.system(systemID)
        let color = Color(hex: system?.color ?? "#999999")
        let parts = systemID == "acupoint-reflex-map" ? [] : systemParts(systemID)
        VStack(alignment: .leading, spacing: Space.xl) {
            HStack(spacing: Space.l) {
                ZStack {
                    LinearGradient(colors: [color.opacity(0.18), color.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                    if systemID == "acupoint-reflex-map" {
                        ReflexMapThumb()
                    } else if UIImage(named: "tile-\(systemID)") != nil {
                        Image("tile-\(systemID)").resizable().scaledToFill()
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(system.map { settings.name($0.name, $0.nameZh) } ?? "").font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    if !parts.isEmpty {
                        Text(settings.t("\(parts.count) parts", "\(parts.count) 个部位")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if let info = system?.info {
                Text(settings.name(info.summary, info.summaryZh))
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if !info.facts.isEmpty {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Eyebrow(settings.t("Key facts", "要点")).padding(.horizontal, Space.xs)
                        VStack(alignment: .leading, spacing: Space.m) {
                            ForEach(info.facts, id: \.self) { fact in
                                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                                    Circle().fill(color).frame(width: 7, height: 7).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                                    Text(settings.name(fact[0], fact[1])).font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .card()
                    }
                }
                let links = info.links.compactMap { Route(path: $0.route) }
                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Eyebrow(settings.t("See also", "相关")).padding(.horizontal, Space.xs)
                        VStack(spacing: 0) {
                            ForEach(Array(links.enumerated()), id: \.offset) { i, route in
                                if i > 0 { Divider().padding(.leading, Space.l + 30 + Space.m) }
                                NavigationLink(value: route) { linkRow(route) }
                                    .buttonStyle(RowButtonStyle())
                            }
                        }
                        .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
                        .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                    }
                }
            }
            if !parts.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    Eyebrow("\(settings.t("Parts", "部位")) · \(parts.count)").padding(.horizontal, Space.xs)
                    Text(settings.t("Tap one to find it on the 3D model.", "点击即可在 3D 模型上找到。"))
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, Space.xs)
                    FlowLayout(spacing: Space.s) {
                        ForEach(parts, id: \.self) { part in
                            NavigationLink(value: Route.viewer(system: systemID, part: part.partID)) {
                                Text(settings.name(part.name, part.nameZh)).font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, Space.m)
                                    .frame(minHeight: 34)
                                    .background(Color.card, in: .capsule)
                                    .padding(.vertical, 5)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
    }

    private func linkRow(_ route: Route) -> some View {
        let (symbol, color): (String, Color) = switch route {
        case .chart: ("hand.raised.fill", Color(hex: "#D9853B"))
        case let .illustration(id): ("play.fill", Illustrations.find(id)?.group.color ?? .brandFill)
        case .viewer: ("cube.fill", .brandFill)
        case .info: ("info", .blue)
        case .search: ("magnifyingglass", .gray)
        }
        return HStack(spacing: Space.m) {
            IconBadge(symbol: symbol, color: color)
            Text(settings.t(route.title)).foregroundStyle(.primary).multilineTextAlignment(.leading)
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(minHeight: minTap)
        .contentShape(.rect)
    }
}

/// Wraps children onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
