import SwiftUI

/// A topic picked for one group of people.
private struct AudienceItem: Identifiable {
    let id: String
    let symbol: String
    let title: Bilingual
    let note: Bilingual
    var route: Route? = nil
}

/// Home section for pregnant women: each topic opens in its pregnancy version.
struct PregnancySection: View {
    /// inside the illustrations list: shown as the 孕产 group card
    var embedded = false
    @Environment(Settings.self) private var settings
    private let color = Color(hex: "#C77DA0")

    private let items: [AudienceItem] = [
        AudienceItem(id: "pregnancy-warning-signs", symbol: "exclamationmark.triangle", title: Bilingual("Warning signs", "孕期危险信号"),
                     note: Bilingual("When to call now, and counting baby’s kicks", "何时立即就医，以及数胎动"), route: .illustration(id: "pregnancy-warning-signs")),
        AudienceItem(id: "fetal-growth", symbol: "figure.and.child.holdinghands", title: Bilingual("Baby’s growth, week by week", "胎儿逐周发育"),
                     note: Bilingual("Size, weight and the bump from week 8 to 40", "第 8–40 周的大小、体重与孕肚"), route: .illustration(id: "fetal-growth")),
        AudienceItem(id: "morning-sickness", symbol: "leaf", title: Bilingual("Morning sickness", "孕吐"),
                     note: Bilingual("What helps, the P6 point, and when it’s too much", "缓解方法、内关穴，以及何时需就医"), route: .illustration(id: "morning-sickness")),
        AudienceItem(id: "pregnancy-sleep-position", symbol: "bed.double", title: Bilingual("Sleeping position", "孕期睡姿"),
                     note: Bilingual("Sleep on your side from 28 weeks", "孕 28 周起侧卧睡"), route: .illustration(id: "pregnancy-sleep-position")),
        AudienceItem(id: "labor", symbol: "clock.badge.checkmark", title: Bilingual("Labour & birth", "分娩过程"),
                     note: Bilingual("The stages, and when to go to hospital (5-1-1)", "产程分期，何时去医院（5-1-1）"), route: .illustration(id: "labor")),
        AudienceItem(id: "acupressure", symbol: "hand.raised.slash", title: Bilingual("Points to avoid in pregnancy", "孕期禁按穴位"),
                     note: Bilingual("Hegu, Sanyinjiao and reproductive zones are flagged ⚠", "合谷、三阴交与生殖区会标出 ⚠"), route: .viewer(system: "acupoint-reflex-map")),
        AudienceItem(id: "blood-pressure", symbol: "heart.text.square", title: Bilingual("Blood pressure & pre-eclampsia", "血压与子痫前期"),
                     note: Bilingual("140/90 after week 20 needs a doctor the same day", "孕 20 周后 ≥140/90 需当天就医"), route: .illustration(id: "blood-pressure")),
        AudienceItem(id: "blood-sugar", symbol: "drop.fill", title: Bilingual("Gestational diabetes", "妊娠期糖尿病"),
                     note: Bilingual("Lower targets in pregnancy, and what helps", "孕期血糖目标更低，以及如何控制"), route: .illustration(id: "blood-sugar")),
        AudienceItem(id: "acid-reflux", symbol: "flame", title: Bilingual("Heartburn", "烧心"),
                     note: Bilingual("Why it gets worse as the baby grows", "为什么随孕周加重"), route: .illustration(id: "acid-reflux")),
        AudienceItem(id: "cpr", symbol: "heart.circle", title: Bilingual("CPR for a pregnant woman", "孕妇心肺复苏"),
                     note: Bilingual("Push the bump to her left while compressing", "按压时把孕肚推向她的左侧"), route: .illustration(id: "cpr")),
        AudienceItem(id: "choking", symbol: "lungs", title: Bilingual("Choking in pregnancy", "孕妇气道异物"),
                     note: Bilingual("Chest thrusts instead of abdominal thrusts", "用胸部冲击代替腹部冲击"), route: .illustration(id: "choking")),
    ]

    var body: some View {
        AudienceCard(title: settings.t(embedded ? IllustrationGroup.pregnancy.title : Bilingual("Pregnancy", "孕期")),
                     subtitle: settings.t("Opens each topic for a pregnant woman.", "每个主题都按孕妇版本打开。"),
                     symbol: IllustrationGroup.pregnancy.symbol, color: IllustrationGroup.pregnancy.color, items: items, embedded: embedded) {
            // these topics are about her: switch the person type so every page adapts
            settings.female = true
            settings.age = .adult
            settings.pregnant = true
        }
    }
}

/// Home section for children — not built yet.
struct ChildrenSection: View {
    @Environment(Settings.self) private var settings

    private let items: [AudienceItem] = [
        AudienceItem(id: "growth", symbol: "ruler", title: Bilingual("Growth & milestones", "生长发育与里程碑"),
                     note: Bilingual("Height, weight and skills by age", "各年龄的身高、体重与能力")),
        AudienceItem(id: "fever", symbol: "thermometer.medium", title: Bilingual("Fever in babies & children", "婴幼儿发热"),
                     note: Bilingual("When it’s an emergency", "什么情况要紧急就医")),
        AudienceItem(id: "first-aid", symbol: "cross.case", title: Bilingual("Baby & child first aid", "婴幼儿急救"),
                     note: Bilingual("CPR, choking and burns for little ones", "小宝宝的心肺复苏、异物与烫伤")),
        AudienceItem(id: "vaccines", symbol: "syringe", title: Bilingual("Vaccinations", "预防接种"),
                     note: Bilingual("What each vaccine protects against", "每种疫苗预防什么")),
    ]

    var body: some View {
        AudienceCard(title: settings.t("Children", "儿童"),
                     subtitle: settings.t("Coming soon.", "即将推出。"),
                     symbol: "figure.and.child.holdinghands", color: Color(hex: "#3F95D6"), items: items, embedded: false, onOpen: nil)
    }
}

/// Titled card of topic rows; rows without a route show "Coming soon".
private struct AudienceCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let items: [AudienceItem]
    var embedded = false
    let onOpen: (() -> Void)?
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if !embedded {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    SectionHeader(title)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                if embedded {
                    // same header row as the other illustration group cards
                    HStack(spacing: Space.m) {
                        IconBadge(symbol: symbol, color: color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Space.s)
                        Text("\(items.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.m)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Divider().padding(.leading, Space.l)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().padding(.leading, Space.l + 30 + Space.m) }
                    if let route = item.route {
                        NavigationLink(value: route) { row(item, soon: false) }
                            .buttonStyle(RowButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded { onOpen?() })
                    } else {
                        row(item, soon: true)
                    }
                }
            }
            .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func row(_ item: AudienceItem, soon: Bool) -> some View {
        HStack(spacing: Space.m) {
            IconBadge(symbol: item.symbol, color: soon ? .gray : color)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(item.title)).font(.body).foregroundStyle(soon ? .secondary : .primary)
                Text(settings.t(item.note)).font(.caption).foregroundStyle(.secondary)
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
