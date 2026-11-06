import SwiftUI

struct ClipReviewView: View {
    @ObservedObject var model: ClipReviewModel
    let effort: String
    let back: () -> Void
    let completed: (String, String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Button(action: back) { Image(systemName: "arrow.left") }
                    .buttonStyle(PaintedButtonStyle(color: Palette.sage)).accessibilityLabel("返回设置，保留本次校对草稿")
                    .disabled(model.saving)
                Text("校对片段").font(Palette.handwriting(27))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(model.package.name).font(.system(size: 15, weight: .medium))
                    LocalVideoView(player: model.player)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit).frame(maxHeight: 190)
                        .clipShape(PencilOutline(radius: 12))
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { lineControls }
                        VStack(alignment: .leading, spacing: 12) { lineControls }
                    }
                    ReviewLineEditor(model: model).id(model.lines[model.selected].id)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                .background { QuietScrollChrome() }
            }.scrollIndicators(.hidden)
            VStack(alignment: .leading, spacing: 8) {
                if let validation = model.validation {
                    Text(validation).font(.system(size: 12)).foregroundStyle(Palette.spoken)
                }
                if !model.status.isEmpty {
                    Text(model.status).font(.system(size: 12)).foregroundStyle(model.failed ? Palette.spoken : Palette.muted)
                }
                HStack(spacing: 16) {
                    if model.saving {
                        Button("停止加工") { model.cancel() }.buttonStyle(PaintedButtonStyle(color: Palette.peach))
                    } else {
                        Button("保存并更新分析") { model.save(effort: effort, completed: completed) }
                            .buttonStyle(PaintedButtonStyle(color: Palette.yellow))
                            .disabled(!model.changed || model.validation != nil)
                    }
                    Text("生成新版本，保留原片段").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    if model.changed && !model.saving {
                        Button("还原修改") { model.resetDraft() }.buttonStyle(.plain)
                            .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 44).padding(.bottom, 24)
        .frame(maxWidth: 810).frame(maxWidth: .infinity).foregroundStyle(Palette.ink)
        .onDisappear { model.stopPreview() }
    }
    @ViewBuilder private var lineControls: some View {
        PaperChoice(title: "选择校对的对白", value: String(model.selected),
            options: model.lines.enumerated().map { PaperOption(value: String($0.offset), label: "\($0.offset + 1). " + String($0.element.text.prefix(20))) }) {
                if let index = Int($0), model.lines.indices.contains(index) { model.selected = index }
            }.disabled(model.saving)
        Button(model.playing ? "暂停" : "听这句") {
            if model.playing { model.stopPreview() } else { model.preview() }
        }.buttonStyle(PaintedButtonStyle(color: Palette.sage))
        Text("\(model.selected + 1) / \(model.lines.count)").font(.system(size: 12)).foregroundStyle(Palette.muted)
    }
}

private struct ReviewLineEditor: View {
    @ObservedObject var model: ClipReviewModel
    @State private var splitAfter = ""
    private var index: Int { model.selected }
    private var line: ReviewLine { model.lines[index] }
    private var unsynced: Bool { line.text.split(whereSeparator: \.isWhitespace).map(String.init) != line.words.map(\.text) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                TextField("角色名，未知可留空", text: Binding(get: { line.speakerName }, set: {
                    model.lines[index].speakerName = $0; model.lines[index].speakerConfirmed = true
                }))
                .reviewField(empty: line.speakerName.isEmpty).accessibilityLabel("这句的角色名")
                Button {
                    model.lines[index].speakerConfirmed.toggle()
                } label: {
                    Text(line.speakerConfirmed ? "已确认" : "确认角色")
                        .font(.system(size: 12)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Palette.sage.opacity(line.speakerConfirmed ? 0.5 : 0.18), in: Capsule())
                }.buttonStyle(.plain)
                    .accessibilityLabel(line.speakerConfirmed ? "取消角色人工确认" : "确认这句的角色，留空表示保留未知")
            }
            TextField("按实际发音填写原话", text: $model.lines[index].text, axis: .vertical)
                .lineLimit(2...5).reviewField(empty: line.text.isEmpty).accessibilityLabel("当前句原话")
            if unsynced {
                Button("更新词表") { model.syncWords() }.buttonStyle(PaintedButtonStyle(color: Palette.sage))
            }
            Text("时间单位为秒；点词试听。增加或删减单词后，空白时间需要手动补齐。")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text("单词").frame(maxWidth: .infinity, alignment: .leading)
                Text("开始").frame(width: 76)
                Text("结束").frame(width: 76)
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
            VStack(spacing: 8) {
                ForEach(Array(line.words.enumerated()), id: \.element.id) { offset, word in
                    HStack(spacing: 10) {
                        Button(word.text) { model.preview(from: Double(word.start), to: Double(word.end)) }
                            .buttonStyle(.plain).font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("试听单词 " + word.text)
                            .disabled(Double(word.start) == nil || Double(word.end) == nil)
                        TextField("秒", text: timeBinding(offset, start: true))
                            .reviewField(empty: word.start.isEmpty).frame(width: 76)
                            .accessibilityLabel(word.text + " 开始秒数")
                        TextField("秒", text: timeBinding(offset, start: false))
                            .reviewField(empty: word.end.isEmpty).frame(width: 76)
                            .accessibilityLabel(word.text + " 结束秒数")
                    }
                }
            }
            if line.words.count > 1 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { splitControls }
                    VStack(alignment: .leading, spacing: 12) { splitControls }
                }
            }
            if model.lines.indices.contains(index + 1) {
                Button("与下一句合并") { model.mergeNext() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    .disabled(unsynced)
            }
        }.disabled(model.saving)
    }
    @ViewBuilder private var splitControls: some View {
        PaperChoice(title: "分句位置", value: splitAfter.isEmpty ? line.words[0].id : splitAfter,
            options: line.words.dropLast().enumerated().map { PaperOption(value: $0.element.id, label: "\($0.offset + 1). \($0.element.text) 后") }) { splitAfter = $0 }
        Button("在这里分句") { model.split(after: splitAfter.isEmpty ? line.words[0].id : splitAfter) }
            .buttonStyle(PaintedButtonStyle(color: Palette.sage)).disabled(unsynced)
    }
    private func timeBinding(_ offset: Int, start: Bool) -> Binding<String> {
        Binding(get: {
            guard model.lines.indices.contains(index), model.lines[index].words.indices.contains(offset) else { return "" }
            return start ? model.lines[index].words[offset].start : model.lines[index].words[offset].end
        }, set: {
            guard model.lines.indices.contains(index), model.lines[index].words.indices.contains(offset) else { return }
            if start { model.lines[index].words[offset].start = $0 }
            else { model.lines[index].words[offset].end = $0 }
        })
    }
}

private extension View {
    func reviewField(empty: Bool) -> some View {
        self.textFieldStyle(.plain).font(.system(size: 13)).tint(Palette.ink)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Palette.paper.opacity(empty ? 0 : 0.8), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7), lineWidth: 0.8))
            .shadow(color: Palette.ink.opacity(0.04), radius: 4, y: 2)
    }
}
