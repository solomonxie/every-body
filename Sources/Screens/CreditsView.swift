import SwiftUI

/// Third-party models and their licences (full text: LICENSES/THIRD_PARTY.md in the source).
struct CreditsView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private struct License {
        let name: String
        let url: String
        static let ccBySA4 = License(name: "CC BY-SA 4.0", url: "https://creativecommons.org/licenses/by-sa/4.0/")
        static let ccBySA21JP = License(name: "CC BY-SA 2.1 JP", url: "https://creativecommons.org/licenses/by-sa/2.1/jp/")
        static let ccBySA3 = License(name: "CC BY-SA 3.0", url: "https://creativecommons.org/licenses/by-sa/3.0/")
        static let ccBy4 = License(name: "CC BY 4.0", url: "https://creativecommons.org/licenses/by/4.0/")
        static let cc0 = License(name: "CC0 1.0", url: "https://creativecommons.org/publicdomain/zero/1.0/")
        static let gpl = License(name: "GPL (tool only)", url: "https://www.blender.org/about/license/")
    }

    private struct Credit: Identifiable {
        let title: String
        let body: Bilingual
        let licenses: [License]
        let links: [String]
        var id: String { title }
    }

    private let credits = [
        Credit(title: "Z-Anatomy",
               body: Bilingual("3D skeleton, muscles, organs, blood vessels and nerves: adapted from “Z-Anatomy – The libre 3D atlas of anatomy” by Gauthier Kervyn, Marcin Zielinski et al. Parts were renamed, merged, decimated and fitted to this app's body. The adapted model files are released under the same licence.",
                               "3D 骨骼、肌肉、器官、血管与神经：改编自 Gauthier Kervyn、Marcin Zielinski 等人的《Z-Anatomy – 自由的 3D 解剖图谱》。各部分经过重命名、合并、减面并与本应用的人体对齐。改编后的模型文件以相同许可发布。"),
               licenses: [.ccBySA4], links: ["https://github.com/Z-Anatomy/Models-of-human-anatomy"]),
        Credit(title: "BodyParts3D",
               body: Bilingual("Z-Anatomy's models derive from BodyParts3D, © The Database Center for Life Science (Kousaku Okubo).",
                               "Z-Anatomy 的模型源自 BodyParts3D，© 生命科学数据库中心（大久保公策）。"),
               licenses: [.ccBySA21JP], links: ["https://dbarchive.biosciencedbc.jp/en/bodyparts3d/"]),
        Credit(title: "Brainder / University of Dundee",
               body: Bilingual("Z-Anatomy's brain surface builds on the “Brainder” brain models (Anderson M. Winkler); its cranial nerves on “Cranial Nerves and Foramina” by the University of Dundee, CAHID.",
                               "Z-Anatomy 的脑表面基于 “Brainder” 脑模型（Anderson M. Winkler）；脑神经基于邓迪大学 CAHID 的《脑神经与孔》。"),
               licenses: [.ccBySA3, .ccBy4], links: ["https://brainder.org"]),
        Credit(title: "MakeHuman / MPFB",
               body: Bilingual("Skin figures for every age and appearance made with MPFB (MakeHuman for Blender) from the MakeHuman base mesh, body, face and age targets, skins (young and old; African, Asian and Caucasian, some blended), eyes, eyebrows, eyelashes and hair — dedicated to the public domain. The underwear is cut from the same base mesh. The first-aid and pregnancy pictures are the same people, with MakeHuman clothes and hair, posed and rendered in Blender. Thank you to the MakeHuman community.",
                               "各年龄与各外貌的皮肤人体由 MPFB（Blender 版 MakeHuman）以 MakeHuman 的基础网格、体型、面部与年龄目标、皮肤贴图（青年与老年；非洲、亚洲、高加索，部分混合）、眼睛、眉毛、睫毛与头发生成，已贡献至公有领域。内衣取自同一基础网格。急救与孕期图解中的人物同样来自 MakeHuman（含其服装与发型），在 Blender 中摆姿势并渲染。感谢 MakeHuman 社区。"),
               licenses: [.cc0], links: ["https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html",
                                         "https://github.com/makehumancommunity/mpfb2"]),
        Credit(title: "Blender Studio – Snow and Rain",
               body: Bilingual("Face shapes and hair of the figures, after Blender Studio's characters. Snow Rig © Blender Foundation | studio.blender.org. Rain Rig © Blender Foundation | studio.blender.org.",
                               "人物的脸型与发型取自 Blender Studio 的角色。Snow Rig © Blender Foundation | studio.blender.org。Rain Rig © Blender Foundation | studio.blender.org。"),
               licenses: [.ccBy4], links: ["https://studio.blender.org/characters/snow/v2/", "https://studio.blender.org/characters/rain/v2/"]),
        Credit(title: "Blender",
               body: Bilingual("Used as a tool to convert the models; no Blender code ships in the app.",
                               "仅用作模型转换工具，应用中不含 Blender 代码。"),
               licenses: [.gpl], links: ["https://www.blender.org"]),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(credits) { c in
                    Section {
                        Text(settings.t(c.body)).font(.subheadline)
                        ForEach(c.links, id: \.self) { link in
                            if let url = URL(string: link) {
                                Link(link, destination: url).font(.footnote)
                            }
                        }
                        ForEach(c.licenses, id: \.name) { license in
                            if let url = URL(string: license.url) {
                                Link(destination: url) {
                                    Label(settings.t("License: \(license.name)", "许可：\(license.name)"), systemImage: "doc.text")
                                }
                                .font(.footnote)
                            }
                        }
                    } header: {
                        HStack {
                            Text(c.title)
                            Spacer()
                            Text(c.licenses.map(\.name).joined(separator: " / "))
                        }
                    }
                }
                Section {
                    Text(settings.t("Everything else — the generated body, charts, the other illustrations and texts — is original to Every Body.",
                                    "其余内容（生成的人体、图表、其他图解与文字）均为 Every Body 原创。"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(settings.t("Credits & licenses", "致谢与许可"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("Done", "完成")) { dismiss() }
                }
            }
        }
    }
}
