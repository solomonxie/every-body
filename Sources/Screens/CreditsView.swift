import SwiftUI

/// Third-party models and their licences (full text: LICENSES/THIRD_PARTY.md in the source).
struct CreditsView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private struct Credit: Identifiable {
        let title: String
        let body: Bilingual
        let license: String
        let link: String
        var id: String { title }
    }

    private let credits = [
        Credit(title: "Z-Anatomy",
               body: Bilingual("3D skeleton, muscles, organs, blood vessels and nerves: adapted from “Z-Anatomy – The libre 3D atlas of anatomy” by Gauthier Kervyn, Marcin Zielinski et al. Parts were renamed, merged, decimated and fitted to this app's body. The adapted model files are released under the same licence.",
                               "3D 骨骼、肌肉、器官、血管与神经：改编自 Gauthier Kervyn、Marcin Zielinski 等人的《Z-Anatomy – 自由的 3D 解剖图谱》。各部分经过重命名、合并、减面并与本应用的人体对齐。改编后的模型文件以相同许可发布。"),
               license: "CC BY-SA 4.0", link: "https://github.com/Z-Anatomy/Models-of-human-anatomy"),
        Credit(title: "BodyParts3D",
               body: Bilingual("Z-Anatomy's models derive from BodyParts3D, © The Database Center for Life Science (Kousaku Okubo).",
                               "Z-Anatomy 的模型源自 BodyParts3D，© 生命科学数据库中心（大久保公策）。"),
               license: "CC BY-SA 2.1 JP", link: "https://dbarchive.biosciencedbc.jp/en/bodyparts3d/"),
        Credit(title: "Brainder / University of Dundee",
               body: Bilingual("Z-Anatomy's brain surface builds on the “Brainder” brain models (Anderson M. Winkler); its cranial nerves on “Cranial Nerves and Foramina” by the University of Dundee, CAHID.",
                               "Z-Anatomy 的脑表面基于 “Brainder” 脑模型（Anderson M. Winkler）；脑神经基于邓迪大学 CAHID 的《脑神经与孔》。"),
               license: "CC BY-SA 3.0 / CC BY 4.0", link: "https://brainder.org"),
        Credit(title: "MakeHuman / MPFB",
               body: Bilingual("Skin figures for every age and appearance made with MPFB (MakeHuman for Blender) from the MakeHuman base mesh, body and age targets, skins (young and old; African, Asian and Caucasian, some blended), eyes, eyebrows, eyelashes and hair — dedicated to the public domain. The underwear is cut from the same base mesh. Thank you to the MakeHuman community.",
                               "各年龄与各外貌的皮肤人体由 MPFB（Blender 版 MakeHuman）以 MakeHuman 的基础网格、体型与年龄目标、皮肤贴图（青年与老年；非洲、亚洲、高加索，部分混合）、眼睛、眉毛、睫毛与头发生成，已贡献至公有领域。内衣取自同一基础网格。感谢 MakeHuman 社区。"),
               license: "CC0 1.0", link: "https://static.makehumancommunity.org"),
        Credit(title: "Humaaans",
               body: Bilingual("People in the CPR illustration: “Humaaans” by Pablo Stanley — heads, hair, hands and shoes, recoloured, with new poses, face-on heads and child and baby parts drawn in the same style.",
                               "心肺复苏图解中的人物：Pablo Stanley 的 “Humaaans”——头部、发型、手与鞋，经重新配色，并以相同风格新绘了姿势、正面头像及儿童与婴儿部件。"),
               license: "CC0 / CC BY 4.0", link: "https://www.humaaans.com"),
        Credit(title: "Blender",
               body: Bilingual("Used as a tool to convert the models; no Blender code ships in the app.",
                               "仅用作模型转换工具，应用中不含 Blender 代码。"),
               license: "GPL (tool only)", link: "https://www.blender.org"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(credits) { c in
                    Section {
                        Text(settings.t(c.body)).font(.subheadline)
                        if let url = URL(string: c.link) {
                            Link(c.link, destination: url).font(.footnote)
                        }
                    } header: {
                        HStack {
                            Text(c.title)
                            Spacer()
                            Text(c.license)
                        }
                    }
                }
                Section {
                    Text(settings.t("Everything else — the generated body, charts, the other illustrations and texts — is original to Every Body.",
                                    "其余内容（生成的人体、图表、其他图解与文字）均为 Every Body 原创。"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(settings.t("Credits & licences", "致谢与许可"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("Done", "完成")) { dismiss() }
                }
            }
        }
    }
}
