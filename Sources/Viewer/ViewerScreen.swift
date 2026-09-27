import SwiftUI

struct ViewerScreen: View {
    let systemID: String
    var initialPoint: String?
    var initialPart: String?

    @Environment(Settings.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scene = BodyScene()
    @State private var showCredits = false
    /// the full-body page always opens as an adult man in underwear; changes there stay on the page
    @State private var local = LocalFigure()
    private var isFullBody: Bool { systemID == "body" }
    private var female: Bool { isFullBody ? local.female : settings.female }
    private var age: AgeGroup { isFullBody ? local.age : settings.age }
    private var pregnant: Bool { isFullBody ? local.pregnant && local.female && local.age == .adult : settings.profile.isPregnant }
    private var underwear: Bool { isFullBody ? local.underwear : settings.showUnderwear }
    private var isKid: Bool { age == .infant || age.isChild }
    @State private var layers: Set<LayerID> = []
    @State private var parts = PartState()
    @State private var history: [PartState] = []
    @State private var selectedPart: String?
    @State private var activePoint: String?
    @State private var effectVisible = false
    @State private var filter = "all"
    @State private var acuFilter = AcuFilter()
    @State private var bpm: Float = 72
    @State private var angles: [String: Float] = [:]
    @State private var built = false

    private var system: BodySystem { Catalog.system(systemID) ?? Catalog.systems[0] }
    private var systemPoints: SystemPoints? { Catalog.points[systemID] }
    private var isReflex: Bool { systemPoints?.points.contains { $0.target != nil } ?? false }
    private var meridians: [Meridian] { systemPoints?.meridians ?? [] }
    private var isAcupuncture: Bool { !meridians.isEmpty }
    /// adult body shape: before puberty both sexes use the same figure (as BodyScene does)
    private var femaleShape: Bool { female && !isKid }
    private var flowStops: [BodyPoint] {
        guard let sp = systemPoints, let flow = sp.flow else { return [] }
        return flow.pointIds.compactMap { id in sp.points.first { $0.id == id } }
    }
    private var tryJoint: Joint? {
        guard let id = selectedPart else { return nil }
        return Catalog.body.joints.first { $0.movers.contains(id) } ?? Catalog.body.joints.first { $0.parts.contains(id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            BodyView(scene: scene, meridians: isAcupuncture ? $acuFilter.lines : nil) { pick in
                switch pick {
                case let .point(id): press(id)
                case let .part(id): selectedPart = selectedPart == id ? nil : id
                }
            }
            .overlay { if !built { LoadingBadge(text: settings.t("Loading 3D body…", "正在载入 3D 人体…")) } }
            .padding(.bottom, -Radius.sheet)
            if typeSize.isAccessibilitySize {
                // huge type: cap the sheet and let it scroll so the model keeps half the screen
                ScrollView { panel }
                    .containerRelativeFrame(.vertical) { h, _ in h * 0.5 }
                    .background(Color.card)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .continuous))
            } else {
                panel
            }
        }
        .background(Color.page)
        .navigationTitle(settings.name(system.name, system.nameZh))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                NavigationLink(value: Route.info(system: systemID)) { Image(systemName: "info.circle") }
                    .accessibilityLabel(settings.t("About this system", "关于此系统"))
            }
            ToolbarItem {
                if isFullBody { LocalFigureMenu(figure: $local) } else { ProfileMenu() }
            }
            ToolbarItem { ViewerOptionsMenu(showCredits: $showCredits) }
        }
        .sheet(isPresented: $showCredits) { CreditsView() }
        .task { await BodyScene.prepare(); setUp() }
        .onChange(of: layers) { scene.setLayers(layers) }
        .onChange(of: parts) { scene.setParts(parts, selected: selectedPart) }
        .onChange(of: selectedPart) { scene.setParts(parts, selected: selectedPart) }
        .onChange(of: settings.female) { rebuild() }
        .onChange(of: settings.age) { rebuild() }
        .onChange(of: settings.pregnant) { rebuild() }
        .onChange(of: settings.heritage) { rebuild() }
        .onChange(of: settings.showUnderwear) { rebuild() }
        .onChange(of: local) { rebuild() }
        .onChange(of: bpm) { scene.bpm = bpm }
        .onChange(of: acuFilter) { applyAcuFilter() }
    }

    private func setUp() {
        guard !built else { return }
        built = true
        var base = Set(Catalog.body.defaultLayers[systemID] ?? [.skin, .organs])
        if let part = initialPart, let layer = Catalog.part(part)?.layer { base.insert(layer) }
        layers = base
        selectedPart = initialPart
        rebuild()
        if let point = initialPoint { press(point) }
    }

    private func rebuild() {
        scene.setAge(age)
        scene.heritage = settings.heritage
        scene.underwear = underwear || isKid
        scene.build(skinColor: UIColor(hex: "#F2C9A5"), female: female, pregnant: pregnant,
                    points: systemPoints?.points ?? [], flowStops: flowStops, meridians: meridians)
        scene.setLayers(layers)
        applyAcuFilter()
        if let activePoint { scene.setActivePoint(activePoint) }
        scene.setParts(parts, selected: selectedPart)
        for (id, deg) in angles { scene.setJoint(id, degrees: deg) }
    }

    private func press(_ id: String) {
        guard let point = systemPoints?.points.first(where: { $0.id == id }) else { return }
        scene.touched = true
        activePoint = id
        scene.setActivePoint(id)
        if let acu = point.acu, let site = acu.sites(female: femaleShape).first {
            scene.focus(on: site.simd, normal: acu.normal.simd)
            return
        }
        guard let target = point.target else { return }
        scene.faceFront()
        scene.pulse(from: point.position.simd, to: target.organIds)
        effectVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if activePoint == id { effectVisible = true }
        }
    }

    private func applyAcuFilter() {
        guard isAcupuncture, let points = systemPoints?.points else { return }
        let all = acuFilter.region == "all" && acuFilter.meridian == nil && !acuFilter.common
        scene.showPoints(all ? nil : Set(points.filter(acuFilter.shows).map(\.id)))
        scene.showMeridians(acuFilter.lines, only: acuFilter.meridian)
    }

    /// Organs on, camera back to the whole body, a pulse from the point to what it's said to act on.
    private func showLink(_ point: BodyPoint) {
        guard let acu = point.acu, let site = acu.sites(female: femaleShape).first else { return }
        layers.insert(.organs)
        scene.faceFront()
        scene.focus(.all)
        scene.pulse(from: site.simd, to: acu.organIds)
    }

    private func change(_ next: PartState) {
        history.append(parts)
        parts = next
    }

    // MARK: panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            PillRow {
                if !history.isEmpty {
                    Button { parts = history.removeLast() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.subheadline.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(Color.fill, in: .circle)
                            .frame(width: minTap, height: minTap)
                            .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(settings.t("Undo", "撤销"))
                    .sensoryFeedback(.impact(weight: .light), trigger: history.count)
                }
                ForEach(Catalog.body.layers) { layer in
                    Pill(label: settings.name(layer.label, layer.labelZh), selected: layers.contains(layer.id),
                         dot: layerColor(layer.id)) {
                        if layers.contains(layer.id) { layers.remove(layer.id) } else { layers.insert(layer.id) }
                    }
                }
                // what the figure wears, next to the layers; children always keep theirs on
                if layers.contains(.skin) && !isKid {
                    Pill(label: settings.t("Clothes", "衣服"), selected: underwear, symbol: "tshirt") {
                        if isFullBody { local.underwear.toggle() } else { settings.showUnderwear.toggle() }
                    }
                }
                if parts.changedCount > 0 {
                    Pill(label: settings.t("Show all (\(parts.changedCount))", "全部显示（\(parts.changedCount)）"), symbol: "eye") { change(PartState()) }
                }
            }
            .padding(.top, Space.xs)
            Group {
                if let id = selectedPart {
                    PartCard(partID: id, parts: parts, female: female, onChange: change) { selectedPart = nil }
                }
                if let joint = tryJoint {
                    JointControl(joint: joint, angle: angles[joint.id] ?? 0) { deg in
                        angles[joint.id] = deg
                        scene.setJoint(joint.id, degrees: deg)
                    }
                }
                if isAcupuncture, let sp = systemPoints {
                    AcupuncturePanel(points: sp.points, meridians: meridians, filter: $acuFilter, activeID: activePoint,
                                     onPress: press, onFocus: { f in
                        scene.touched = true
                        if f != .back { scene.faceFront() }
                        scene.focus(f)
                    }, onLink: showLink)
                } else if isReflex, let sp = systemPoints {
                    ReflexPanel(points: sp.points, filter: $filter, activeID: activePoint, effectVisible: effectVisible, onPress: press) { f in
                        scene.touched = true
                        scene.faceFront()
                        scene.focus(f)
                    }
                } else if !flowStops.isEmpty {
                    FlowPanel(stops: flowStops, bpm: $bpm, activeID: activePoint, onStop: press)
                } else if layers.isEmpty {
                    Hint(symbol: "square.stack.3d.up.slash", text: settings.t("All layers are hidden. Turn one on above.", "所有图层都已隐藏，请在上方打开一个。"))
                } else if selectedPart == nil {
                    Hint(symbol: "hand.tap", text: settings.t("Tap any part to name it. Tap an arm or leg bone or muscle to move its joint.", "点击任意部位查看名称。点击手臂或腿部的骨骼、肌肉可活动关节。"))
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .padding(.top, Space.s)
        .padding(.bottom, Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .continuous)
                .fill(Color.card)
                .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.snappy(duration: 0.25), value: selectedPart)
        .animation(.snappy(duration: 0.25), value: activePoint)
        .sensoryFeedback(.selection, trigger: selectedPart)
    }

    private func layerColor(_ id: LayerID) -> Color {
        id == .skin ? Color(hex: "#F2C9A5") : Color(hex: Catalog.system(id.rawValue)?.color ?? "#999999")
    }
}

/// 3D view options: background, auto-rotate, and the credits for the 3D models.
struct ViewerOptionsMenu: View {
    @Binding var showCredits: Bool
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Toggle(settings.t("White background", "白色背景"), isOn: $settings.whiteBackground)
            Toggle(settings.t("Auto-rotate on open", "打开时自动旋转"), isOn: $settings.autoRotate)
            Divider()
            Button { showCredits = true } label: {
                Label(settings.t("Credits & licences", "致谢与许可"), systemImage: "doc.text")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(settings.t("3D view options", "3D 视图选项"))
    }
}

/// Who the full-body page shows; not saved.
struct LocalFigure: Equatable {
    var female = false
    var age: AgeGroup = .adult
    var pregnant = false
    var underwear = true
}

/// Profile menu for the full-body page: same choices, kept on the page only.
struct LocalFigureMenu: View {
    @Binding var figure: LocalFigure
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Picker(settings.t("Age", "年龄"), selection: $figure.age) {
                ForEach(AgeGroup.allCases, id: \.self) { Text(settings.t($0.label)).tag($0) }
            }
            Picker(settings.t("Sex", "性别"), selection: $figure.female) {
                Text(settings.t("Male", "男")).tag(false)
                Text(settings.t("Female", "女")).tag(true)
            }
            if figure.female && figure.age == .adult {
                Toggle(settings.t("Pregnant", "怀孕"), isOn: $figure.pregnant)
            }
            if !(figure.age == .infant || figure.age.isChild) {
                Toggle(settings.t("Show underwear", "显示内衣"), isOn: $figure.underwear)
            }
            Picker(settings.t("Appearance", "外貌"), selection: $settings.heritage) {
                ForEach(Heritage.allCases, id: \.self) { Text(settings.t($0.label)).tag($0) }
            }
            .pickerStyle(.menu)
        } label: {
            Label(title, systemImage: figure.age == .adult || figure.age == .senior ? "figure.stand" : "figure.child")
                .labelStyle(.titleAndIcon)
                .font(.footnote.weight(.semibold))
        }
        .accessibilityLabel(settings.t("Figure", "人物"))
    }

    private var title: String {
        switch figure.age {
        case .adult: settings.t(figure.female ? "Woman" : "Man", figure.female ? "女" : "男")
        case .senior: settings.t(figure.female ? "Older woman" : "Older man", figure.female ? "老年女性" : "老年男性")
        default: settings.t(figure.age.label)
        }
    }
}
