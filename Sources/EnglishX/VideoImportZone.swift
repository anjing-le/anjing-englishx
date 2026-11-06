import SwiftUI
import UniformTypeIdentifiers

struct VideoImportZone: View {
    @ObservedObject var model: ProcessingSettingsModel
    @State private var targeted = false
    var body: some View {
        Button { model.chooseVideo() } label: {
            Group {
                if let video = model.video {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { preview; fileInfo(video) }
                        VStack(alignment: .leading, spacing: 14) { preview; fileInfo(video) }
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: model.inspectingVideo ? "ellipsis" : "film")
                            .font(.system(size: 27, weight: .light))
                            .foregroundStyle(Palette.ink.opacity(0.65))
                            .frame(width: 56, height: 48)
                            .background { CrayonFill(color: Palette.blue.opacity(0.4)).clipShape(PencilOutline(radius: 12)) }
                        Text(model.inspectingVideo ? "正在读取视频…" : (targeted ? "松开放入视频" : "拖入视频，或点此选择"))
                            .font(.system(size: 15, weight: .medium))
                    }.frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(24).frame(maxWidth: .infinity, minHeight: 158)
            .background {
                CrayonFill(color: targeted ? Palette.sage.opacity(0.45) : Palette.paper.opacity(0.7))
                    .clipShape(PencilOutline(radius: 18))
            }
            .overlay {
                PencilOutline(radius: 18).stroke(Palette.ink.opacity(targeted ? 0.8 : 0.3),
                    style: StrokeStyle(lineWidth: targeted ? 2 : 1.4, lineCap: .round, dash: targeted ? [] : [6, 5]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.processing || model.inspectingVideo)
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { model.acceptDrop($0) }
        .accessibilityLabel(model.video == nil ? "拖入或选择视频" : "更换视频")
        .accessibilityHint("一次添加一个本地视频，检查后再开始加工")
    }
    private var preview: some View {
        Group {
            if let thumbnail = model.thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
            } else {
                Palette.blue.opacity(0.4).overlay { Image(systemName: "film") }
            }
        }.frame(width: 130, height: 82).clipped()
            .clipShape(PencilOutline(radius: 10))
            .overlay { PencilOutline(radius: 10).stroke(Palette.ink.opacity(0.6), lineWidth: 1.3) }
    }
    private func fileInfo(_ video: SelectedVideo) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(video.url.lastPathComponent).font(.system(size: 16, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(Int(video.seconds) / 60):\(String(format: "%02d", Int(video.seconds) % 60))\(video.audioTracks > 0 ? "" : " · 无音轨")")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            if targeted {
                Text("松开更换片段").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
