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
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: system?.color ?? "#999999")).frame(height: 8)
                if let info = system?.info {
                    if settings.showEn { Text(info.summary) }
                    if settings.showZh { Text(info.summaryZh).foregroundStyle(settings.showEn ? .secondary : .primary) }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(info.facts, id: \.self) { fact in
                            Text("• " + (settings.names == .zh ? fact[1] : settings.names == .en ? fact[0] : "\(fact[0])\n  \(fact[1])")).font(.footnote)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
                    ForEach(info.links, id: \.route) { link in
                        if let route = Route(path: link.route) {
                            NavigationLink(link.label, value: route).font(.subheadline.weight(.semibold))
                        }
                    }
                }
                let parts = systemID == "acupoint-reflex-map" ? [] : systemParts(systemID)
                if !parts.isEmpty {
                    Text("PARTS 部位 · \(parts.count)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(parts, id: \.self) { part in
                            NavigationLink(value: Route.viewer(system: systemID, part: part.partID)) {
                                Text(settings.name(part.name, part.nameZh)).font(.footnote)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(system?.name ?? "Info")
        .navigationBarTitleDisplayMode(.inline)
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
