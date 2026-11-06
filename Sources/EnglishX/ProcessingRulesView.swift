import SwiftUI
import CryptoKit

@MainActor
final class ProcessingRulesPresentation: ObservableObject {
    @Published private(set) var isVisible = false
    @Published private(set) var pinned = false
    private var badgeHovered = false
    private var panelHovered = false
    private var dismissTask: Task<Void, Never>?

    func hoverBadge(_ inside: Bool) { badgeHovered = inside; reconcile() }
    func hoverPanel(_ inside: Bool) { panelHovered = inside; reconcile() }
    func togglePin() {
        if pinned { close() }
        else { dismissTask?.cancel(); pinned = true; isVisible = true }
    }
    func pinForReading() { dismissTask?.cancel(); pinned = true; isVisible = true }
    func close() {
        dismissTask?.cancel(); pinned = false; badgeHovered = false; panelHovered = false; isVisible = false
    }
    private func reconcile() {
        dismissTask?.cancel()
        if pinned || badgeHovered || panelHovered { isVisible = true; return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            self?.isVisible = false
        }
    }
}

struct ProcessingRulesAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct ProcessingRulesBadge: View {
    @ObservedObject var presentation: ProcessingRulesPresentation
    var body: some View {
        Button { presentation.togglePin() } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("解析原理")
            }
            .font(.system(size: 12)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Palette.sage.opacity(presentation.isVisible ? 0.3 : 0.13), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { presentation.hoverBadge($0) }
        .anchorPreference(key: ProcessingRulesAnchor.self, value: .bounds) { $0 }
        .accessibilityLabel("解析原理与当前规则")
        .accessibilityHint("悬停查看，或点击固定展开；Escape 关闭")
        .accessibilityValue(presentation.isVisible ? "已展开" : "已收起")
    }
}

@MainActor
private struct BundledTeachingPrompt {
    let text: String
    let version: String
    let hash: String
    init(resource: String) {
        text = PaperResources.resources.url(forResource: resource, withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        version = text.split(separator: "\n").first.map { String($0).replacingOccurrences(of: "EnglishX ", with: "") } ?? "未读取到版本"
        hash = text.isEmpty ? "" : SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// Reads the actual completed package, never estimates a version from its creation date.
private struct CompletedProcessingRecipe: Decodable {
    let model: String?
    let effort: String?
    let promptVersion: String?
    let promptSHA256: String?
    let characterPromptVersion: String?
    let characterPromptSHA256: String?
    let revisionSource: String?
}

struct ProcessingRulesLayer: View {
    @ObservedObject var presentation: ProcessingRulesPresentation
    let anchor: Anchor<CGRect>?
    let effort: String
    let completedPackage: String?
    let recipeTitle: String
    var body: some View {
        GeometryReader { geometry in
            if presentation.isVisible, let anchor {
                let trigger = geometry[anchor]
                let width = min(CGFloat(470), max(0, geometry.size.width - 32))
                let below = max(0, geometry.size.height - trigger.maxY - 16)
                let above = max(0, trigger.minY - 40)
                let showBelow = below >= above
                let height = min(CGFloat(540), max(120, showBelow ? below : above))
                let x = min(max(16, trigger.maxX - width), max(16, geometry.size.width - width - 16))
                let proposedY = showBelow ? trigger.maxY + 8 : trigger.minY - height - 8
                let y = min(max(16, proposedY), max(16, geometry.size.height - height - 16))
                if presentation.pinned {
                    Color.clear.contentShape(Rectangle()).onTapGesture { presentation.close() }
                }
                ProcessingRulesCard(presentation: presentation, effort: effort, completedPackage: completedPackage, recipeTitle: recipeTitle)
                    .frame(width: width, height: height)
                    .position(x: x + width / 2, y: y + height / 2)
                    .onHover { presentation.hoverPanel($0) }
            }
        }
        .allowsHitTesting(presentation.isVisible)
    }
}

@MainActor
private struct ProcessingRulesCard: View {
    @ObservedObject var presentation: ProcessingRulesPresentation
    let effort: String
    let completedPackage: String?
    let recipeTitle: String
    @State private var showPrompts = false
    @State private var recipe: CompletedProcessingRecipe?
    private let teaching = BundledTeachingPrompt(resource: "teaching-prompt")
    private let characters = BundledTeachingPrompt(resource: "character-prompt")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("解析原理").font(.system(size: 17, weight: .medium))
                Spacer()
                Button { presentation.close() } label: { Image(systemName: "xmark").font(.system(size: 12)) }
                    .buttonStyle(.plain).accessibilityLabel("关闭解析原理")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("gpt-6.1-sol · \(effort) · 讲解 \(teaching.version.replacingOccurrences(of: "teaching-", with: "")) · 角色 \(characters.version.replacingOccurrences(of: "characters-", with: ""))")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 13) {
                        capability("1 · 提取声音", "ffmpeg：从视频分离音轨，原片保留。", state: "本地")
                        capability("2 · 听写对白", "Whisper base.en：听声音，转成英文。", state: "本地")
                        capability("3 · 对齐单词", "音频 DTW：估计每个词的时间，跟随播放变色。", state: "本地")
                        capability("4 · 判断角色", "Codex：看抽取的画面，结合对白与作品名给出角色建议。", state: "模型")
                        capability("5 · 解释词义", "Codex：结合上下文生成词义、词性和通俗讲解。", state: "模型")
                        capability("6 · 存入片段库", "校验后保存到本机，下次直接学；原话和词时间可校对。", state: "本地")
                    }
                    Text("只把抽取的画面和文字发给模型，不发送完整视频或原始音频。时间与角色仍需核对，按声音区分说话人尚未接入。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("本地步骤不耗模型 token；看图和讲解会消耗。已有结果直接复用，日常播放不再调用模型。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    divider
                    VStack(alignment: .leading, spacing: 7) {
                        Text("规则版本").font(.system(size: 13, weight: .medium))
                        versionRow("讲解", teaching)
                        versionRow("角色", characters)
                        Text("只解释语境，不改原话和时间；角色结果保留依据，自动结果均待核对。")
                            .font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    if let recipe {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recipeTitle).font(.system(size: 13, weight: .medium))
                            Text("\(recipe.model ?? "未记录模型") · \(recipe.effort ?? "未记录强度")")
                            Text("\(recipe.promptVersion ?? "未记录讲解版本") · \(recipe.characterPromptVersion ?? "未记录角色版本")")
                            if recipe.revisionSource == "manual-editor-v1" {
                                Text("包含校对修改 · 编辑器 v1").foregroundStyle(Palette.muted)
                            }
                            if recipe.promptSHA256 == teaching.hash && recipe.characterPromptSHA256 == characters.hash {
                                Text("与当前提示词一致").foregroundStyle(Palette.muted)
                            } else {
                                Text("与当前提示词不同或版本未记录，需重新加工才能应用新规则。")
                                    .foregroundStyle(Palette.spoken)
                            }
                        }.font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                    divider
                    Button { showPrompts.toggle(); presentation.pinForReading() } label: {
                        HStack(spacing: 6) {
                            Text(showPrompts ? "收起完整提示词" : "查看完整提示词")
                            Image(systemName: showPrompts ? "chevron.up" : "chevron.down").font(.system(size: 9))
                        }.font(.system(size: 12)).foregroundStyle(Palette.ink)
                    }.buttonStyle(.plain)
                    if showPrompts {
                        Text("讲解").font(.system(size: 13, weight: .medium))
                        promptText(teaching.text)
                        Text("角色").font(.system(size: 13, weight: .medium))
                        promptText(characters.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 3).padding(.bottom, 4)
                .background { QuietScrollChrome() }
            }.scrollIndicators(.hidden)
        }
        .padding(20).foregroundStyle(Palette.ink)
        .background {
            PencilOutline(radius: 17).fill(Palette.ink.opacity(0.18)).offset(x: 3, y: 4)
            CrayonFill(color: Palette.paper).clipShape(PencilOutline(radius: 17))
            PencilOutline(radius: 17).stroke(Palette.ink.opacity(0.65), lineWidth: 1.3)
        }
        .task(id: completedPackage) {
            recipe = completedPackage.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
                .flatMap { try? JSONDecoder().decode(CompletedProcessingRecipe.self, from: $0) }
        }
    }
    private var divider: some View { Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 1) }
    private func capability(_ title: String, _ detail: String, state: String, missing: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            Text(state).font(.system(size: 10)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background((missing ? Palette.peach : Palette.sage).opacity(0.35), in: Capsule())
                .fixedSize()
        }
    }
    private func versionRow(_ title: String, _ prompt: BundledTeachingPrompt) -> some View {
        Text("\(title)  \(prompt.version)\(prompt.hash.isEmpty ? "" : " · " + prompt.hash.prefix(8))")
            .font(.system(size: 12)).foregroundStyle(Palette.muted).textSelection(.enabled)
    }
    private func promptText(_ value: String) -> some View {
        Text(value.isEmpty ? "未能读取提示词文件" : value)
            .font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.muted)
            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
    }
}
