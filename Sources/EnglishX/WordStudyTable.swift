import SwiftUI

struct WordExplanation {
    let partOfSpeech: String
    let meaning: String
    let explanation: String
    var lemma: String? = nil
    var phrase: String? = nil
}

// Hand-authored notes for the original mock dialogue, scoped to each sentence.
// These are not automatic dictionary/grammar analysis results.
enum MockWordNotes {
    private static func entries(_ rows: [(String, String, String)]) -> [WordExplanation] {
        rows.map { WordExplanation(partOfSpeech: $0.0, meaning: $0.1, explanation: $0.2) }
    }
    static let clips: [[[WordExplanation]]] = [
        [
            entries([
                ("助动词", "用来问过去的事", "did 帮这句话变成过去时疑问句；后面的 bring 保持原形。"),
                ("代词", "你", "指正在被问话的对方。"),
                ("动词", "带来、带上", "bring an umbrella 就是带伞；不是问对方有没有买伞。"),
                ("不定冠词", "一把", "umbrella 的开头是元音音素，所以用 an，不用 a。"),
                ("名词", "雨伞", "整句是在问：你带伞了吗？")
            ]),
            entries([
                ("答语", "没有", "单独回答前面的疑问句，相当于 No, I didn't。"),
                ("代词", "我", "说话的人在解释自己为什么没带伞。"),
                ("动词 · 过去式", "原以为", "thought 是 think 的过去式；这里在回顾先前的判断。"),
                ("定冠词", "这场", "the rain 指双方眼前这场雨，而不是泛指所有雨。"),
                ("名词", "雨", "是后面 would stop 的主语：雨会停。"),
                ("情态助动词", "当时以为会", "过去的想法里说“将会”，用 would；不是这里另起一个假设。"),
                ("动词", "停止", "the rain would stop 就是雨会停。整句：我原以为雨会停。")
            ]),
            entries([
                ("副词", "那就", "接着对方的话提出主意，不是这里的“在那时”。"),
                ("let us 的缩写", "我们……吧", "let's + 动词原形，用来提议一起做某件事。"),
                ("动词", "走、选择", "take 在这里搭配 way，表示走某条路，不是“拿走”。"),
                ("定冠词", "那条", "和 long way 连用，把要走的那条路说出来。"),
                ("形容词", "远一些的", "修饰 way。take the long way home 合起来是“绕远路回家”。"),
                ("名词", "路线、路", "这里讲回家的路线。和 long 一起看，比单记“方式”更准确。"),
                ("副词", "回家", "这里直接跟在路线表达后面，不加 to：the long way home。")
            ]),
            entries([
                ("定冠词", "那条", "重复对方刚说的 the long way，表示确认和一点惊讶。"),
                ("形容词", "远的", "long 修饰 way；语气上在问：还要绕远路？"),
                ("名词", "路", "The long way? 是省略问法，完整意思靠上文补足。"),
                ("we will 的缩写", "我们会", "we 是我们，will 表示对接下来结果的判断。"),
                ("系动词", "变得", "get + 形容词表示状态变化；get soaked 就是变得湿透。"),
                ("形容词", "湿透的", "比 wet 更强调彻底湿了；整句是在担心大家会淋透。")
            ]),
            entries([
                ("代词", "我", "由说话的人接着提出解决办法。"),
                ("动词", "知道", "I know a place 是“我知道一个地方”。"),
                ("不定冠词", "一个", "第一次提到这个地方，对方还不知道具体是哪里。"),
                ("名词", "地方", "后面的 where we can wait 继续说明这个地方有什么用。"),
                ("关系副词", "在那里", "引出修饰 place 的从句：我们可以在那里等。"),
                ("代词", "我们", "把自己和对方都包括在这个安排里。"),
                ("情态动词", "可以", "这里表达有条件、有地方等，不是请求许可。"),
                ("动词", "等候", "结合下雨的场景，指找个地方等一等。")
            ]),
            entries([
                ("固定表达的一部分", "好吧", "All right 合起来作答语，表示同意、接受这个主意。"),
                ("固定表达的一部分", "好吧", "这里不要把 right 单独理解成“右边”或“正确”。"),
                ("动词 · 祈使句", "带路", "Lead the way 是自然的“你带路吧”，省略了主语 you。"),
                ("定冠词", "这条", "the way 在固定搭配 lead the way 中一起理解。"),
                ("名词", "路", "这里跟 lead 组成“带路”，不是让对方解释一种方法。")
            ])
        ],
        [
            entries([
                ("助动词", "用来构成疑问句", "Do 在句首帮助提问，主要意思在后面的 have to leave。"),
                ("代词", "你", "问话的对象。"),
                ("动词 · 短语内", "得、必须", "have to + 动词原形表示不得不、需要，这里不是“拥有”。"),
                ("不定式标记", "和 have 一起看", "have to leave 是“得走了”；to 后面用 leave 的原形。"),
                ("动词", "离开", "这里指结束眼前的相处、动身走。"),
                ("副词", "这么快就", "already 表示比说话人预期更早，有点舍不得的意味。")
            ]),
            entries([
                ("代词", "我", "说话人在给出自己的想法。"),
                ("动词", "想、觉得", "I guess 在口语里可以把语气放软：我想……吧。"),
                ("代词", "我", "是后面 could stay 的主语。"),
                ("情态动词", "可以", "这里表示一种可行的选择，不是在叙述过去的能力。"),
                ("动词", "留下", "stay a little longer：再待一会儿。"),
                ("不定冠词 · 短语内", "和 little 一起看", "a little 在这里合起来表示“一点儿”，修饰 longer。"),
                ("形容词 · 短语内", "一点儿", "a little longer 是“再久一点”，不是“一个小东西”。"),
                ("副词 · 比较级", "更久一点", "longer 修饰 stay，表示延长停留的时间。")
            ]),
            entries([
                ("形容词 · 简短答语", "太好了", "单独说 Good，是对“可以再待一会儿”的回应。"),
                ("定冠词", "这杯", "双方都知道眼前这杯茶，因此用 the。"),
                ("名词", "茶", "tea 在这里按不可数名词使用。"),
                ("系动词", "是、处于", "is 把主语 tea 和它的状态 warm 连起来。"),
                ("副词", "还、仍然", "still 表示之前是热的，现在也还保持着。"),
                ("形容词", "温热的", "warm 是舒服的温热，不一定像 hot 那样烫。")
            ]),
            entries([
                ("代词", "你", "对眼前的人说。"),
                ("频率副词", "总是", "修饰 know，表达对对方一贯表现的评价。"),
                ("动词", "知道", "know what to say：知道该说什么。"),
                ("疑问代词", "什么", "what to say 是“该说什么”，不是在这里另问一个问题。"),
                ("不定式标记", "和 say 一起看", "to say 跟在 what 后面，组成“该说什么”。"),
                ("动词", "说", "整句是在夸对方很会说话、总能说到点上。")
            ]),
            entries([
                ("副词", "只有", "Only when… 把情况限定为“只有……的时候”。"),
                ("连词", "当……的时候", "引出条件般的时间场景：有茶的时候。"),
                ("there is 的缩写", "有", "there's 表示存在；这里说有茶这回事。"),
                ("名词", "茶", "这里仍然按不可数名词使用。"),
                ("形容词 · 分词形式", "牵涉其中的", "there's tea involved 合起来指“有茶这回事”，语气是在开玩笑。")
            ])
        ]
    ]
}

struct WordStudyDetail: View {
    @ObservedObject var model: LearningMockModel
    private var line: DialogueLine { model.clip.lines[model.activeID] }
    private var wordID: Int { line.words.last(where: { model.time >= $0.start })?.id ?? 0 }
    private var word: TimedWord { line.words[wordID] }
    private var note: WordExplanation {
        if let notes = model.clip.notes { return notes[model.activeID][wordID] }
        return MockWordNotes.clips[model.clipIndex][model.activeID][wordID]
    }

    @State private var detailsVisible = false
    private var surface: String { word.text.trimmingCharacters(in: .punctuationCharacters) }
    private var expandedForm: String? {
        guard let lemma = note.lemma, !lemma.isEmpty, lemma.lowercased() != surface.lowercased() else { return nil }
        return lemma
    }
    private var contraction: Bool {
        (surface.contains("'") || surface.contains("’")) && (expandedForm?.contains(" ") == true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 22) {
                        wordHeading
                        meaning
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        wordHeading
                        meaning
                    }
                }
                Text(note.explanation)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink.opacity(0.84))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                Button { detailsVisible.toggle() } label: {
                    HStack(spacing: 7) {
                        Text(detailsVisible ? "收起用法" : "用法细节")
                        Image(systemName: detailsVisible ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    .padding(.vertical, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(detailsVisible ? "收起词性与用法细节" : "展开词性与用法细节")
                if detailsVisible {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow("词性", note.partOfSpeech)
                        if let expandedForm { detailRow(contraction ? "完整写法" : "原形", expandedForm) }
                        if let phrase = note.phrase, !phrase.isEmpty, !contraction {
                            detailRow("搭配", phrase)
                        }
                    }
                    .padding(.leading, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background { QuietScrollChrome() }
        }
        .scrollIndicators(.hidden)
        .transaction { $0.animation = nil }
    }

    private var meaning: some View {
        Text(note.meaning).font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var wordHeading: some View {
        Text(surface).font(.custom("AvenirNext-Medium", size: 31)).foregroundStyle(Palette.spoken)
    }
    private func detailRow(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label).foregroundStyle(Palette.muted).frame(width: 58, alignment: .leading)
            Text(text).foregroundStyle(Palette.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        }.font(.system(size: 13))
    }
}
