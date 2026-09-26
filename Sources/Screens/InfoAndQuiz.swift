import SwiftUI

struct QuizItem: Hashable {
    let partID: String
    let name: String
    let nameZh: String
}

/// One item per anatomical name (left/right and numbered items collapsed), from the system's layers.
func quizPool(_ systemID: String) -> [QuizItem] {
    let layers = Set((Catalog.body.defaultLayers[systemID] ?? [.organs]).filter { $0 != .skin })
    func base(_ s: String) -> String {
        s.replacingOccurrences(of: #" \((L|R)\)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^[左右]"#, with: "", options: .regularExpression)
    }
    var seen = Set<String>(), items: [QuizItem] = []
    for part in Catalog.body.parts where layers.contains(part.layer) {
        let name = base(part.name).replacingOccurrences(of: #"^(C|T|L)\d+ vertebra$"#, with: "Vertebra", options: .regularExpression)
            .replacingOccurrences(of: #"^Rib \d+$"#, with: "Rib", options: .regularExpression)
        let zh = base(part.nameZh).replacingOccurrences(of: #"^第\d+(颈椎|胸椎|腰椎)$"#, with: "椎骨", options: .regularExpression)
            .replacingOccurrences(of: #"^第\d+肋$"#, with: "肋骨", options: .regularExpression)
        if seen.insert(name).inserted { items.append(QuizItem(partID: part.id, name: name, nameZh: zh)) }
    }
    if layers.contains(.organs) {
        for organ in Catalog.body.organs {
            guard let n = organ.names else { continue }
            let name = n[0].replacingOccurrences(of: #"^(Left|Right) "#, with: "", options: .regularExpression).capitalized
            if seen.insert(name).inserted { items.append(QuizItem(partID: organ.id, name: name, nameZh: base(n[1]))) }
        }
    }
    return items
}

struct QuizScreen: View {
    let systemID: String
    @Environment(Settings.self) private var settings
    @State private var scene = BodyScene()
    @State private var questions: [(answer: QuizItem, options: [QuizItem])] = []
    @State private var index = 0
    @State private var picked: QuizItem?
    @State private var score = 0

    private var system: BodySystem { Catalog.system(systemID) ?? Catalog.systems[1] }
    private var layers: Set<LayerID> { Set(Catalog.body.defaultLayers[systemID] ?? [.skin, .organs]) }

    var body: some View {
        VStack(spacing: 0) {
            BodyView(scene: scene)
            VStack(alignment: .leading, spacing: 8) {
                if index >= questions.count, !questions.isEmpty {
                    Text("\(score) / \(questions.count)").font(.largeTitle.bold())
                    Text(score == questions.count ? "Perfect! 全对！" : Double(score) >= Double(questions.count) * 0.7 ? "Well done 不错！" : "Keep exploring 继续加油")
                        .foregroundStyle(.secondary)
                    Button("Again 再来") { start() }.buttonStyle(.borderedProminent)
                } else if index < questions.count {
                    let q = questions[index]
                    HStack {
                        Text("What is the glowing part? 发光的是哪个部位？").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(index + 1)/\(questions.count) · ✓ \(score)").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(q.options, id: \.self) { option in
                        let color: Color = picked == nil ? Color.secondary.opacity(0.15)
                            : option == q.answer ? Color(hex: "#2E9E5B") : option == picked ? Color(hex: "#D8434B") : Color.secondary.opacity(0.15)
                        Button {
                            guard picked == nil else { return }
                            picked = option
                            if option == q.answer { score += 1 }
                        } label: {
                            Text(settings.name(option.name, option.nameZh)).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(color, in: .rect(cornerRadius: 12))
                                .foregroundStyle(picked != nil && (option == q.answer || option == picked) ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    if picked != nil {
                        Button(index + 1 == questions.count ? "See score 查看得分" : "Next 下一题 ›") { picked = nil; index += 1; highlight() }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .navigationTitle("Quiz 测验 · \(system.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard questions.isEmpty else { return }
            scene.build(skinColor: UIColor(hex: system.color), female: settings.female, points: [], flowStops: [])
            scene.setLayers(layers)
            start()
        }
    }

    private func start() {
        let pool = quizPool(systemID).shuffled()
        questions = pool.prefix(10).map { answer in
            (answer, ([answer] + pool.filter { $0.name != answer.name }.shuffled().prefix(3)).shuffled())
        }
        index = 0; score = 0; picked = nil
        highlight()
    }

    private func highlight() {
        scene.setParts(PartState(), selected: index < questions.count ? questions[index].answer.partID : nil)
    }
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
                let parts = systemID == "acupoint-reflex-map" ? [] : quizPool(systemID)
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
