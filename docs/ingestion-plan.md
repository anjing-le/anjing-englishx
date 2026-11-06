# EnglishX 素材加工方案

2026-11-02；设计与首条样片实现状态。首条端到端结果见 real-sample-validation.md；不代表识别/对齐精度已验收。

## 当前实现补充

已接通固定命令的音视频提取、本地 Whisper base.en ASR、attention-DTW 声学 token 对齐与词合并、gpt-6.1-sol 结构化讲解、原子写入本地片段包、AVPlayer 真实视频播放。采用自动估计的词边界，所有结果保留 needs-review。WhisperX/独立音素强制对齐、音频说话人分离/声纹识别尚未实现。2026-11-04 接入原话、角色、分句/合并、逐词时间校对与新版本分析；它仍需实际核对，不自动证明转写/时间准确。2026-11-03 新增独立的画面＋对白虚构角色分析，自动建议仍待核对，详见 character-analysis.md。

## 已确认

- createX 的 `CodexBridge.swift` 自行启动 `codex app-server --listen stdio://`，通过 JSONL 完成 initialize / initialized / account/read，再按需启动 ephemeral、read-only 的 thread 和 turn。每次显式指定 `gpt-6.1-sol`、`low`，校验服务返回的模型，没有打开应用就生成的调用。
- 本机 CLI 为 `0.166.0-alpha.5.1`。只读检查成功：当前已有登录，model/list 能看到 `gpt-6.1-sol`，默认 effort 为 low，目录支持 low/medium/high/xhigh/max/ultra，inputModalities 为 text/image。只证明登录和模型目录读取，不证明生成成功、额度足够或教学质量合格。
- 本机可执行文件包含 ffmpeg、ffprobe、whisper-cli。未验证可用的 Whisper 模型权重、识别质量、对齐质量、说话人识别或完整数据入库。
- EnglishX 已能加载真实片段，并保留两条 mock 示例。设置页的连接检查真实执行 initialize、account/read、model/list，不启动生成任务；文件选择读取 AVFoundation 元信息，只有点击开始加工才执行处理；完整视频/音频不上传；教学任务发送对白文字，角色任务发送有上限的抽帧画面、对白、文件名和可选作品提示。

## 加工职责

1. **保留与检查原件**：保留源视频、哈希和媒体时长，检查音轨，明确选择使用的音轨。外置字幕、内嵌字幕或画面 OCR 都只是对白初稿来源，不能代替核对实际发音。
2. **提取音频**：由应用调用固定的音频工具或 AVFoundation；使用适合语音识别的 PCM 音频，并保存音轨相对视频的时间偏移。不得让 Codex 临时生成任意 shell 命令来处理用户文件。
3. **实际对白转写**：先以本地 whisper.cpp 为待评估候选（Apple Silicon 友好，已有 CLI）；具体模型权重与性能由真实片段决定。语气词、重复、口语缩写不能被自动改成书面英语。无声片段不得凭空补话。
4. **核对文字，再做词级对齐**：逐词时间应来自音频对齐结果。WhisperX 的 forced alignment 是待评估方案；其 macOS CPU 路径与模型依赖需要实测。whisper.cpp 的词级时间目前文档标为 experimental，不直接当作最终正确答案。所有分块时间必须补回 chunk offset 和音视频偏移，再对应原视频时间。
5. **角色**：在独立多模态任务中用画面、对白与可选作品名识别虚构角色并建议台词归属。识别画面角色不等于识别说话者；反打、画外音、跨说话人分段或未抽帧段落保持未知。禁止改写台词/时间、识别现实演员或声称已做声纹分离。音频 diarization 后续单独评估。
6. **Codex 教学加工**：以 `gpt-6.1-sol` / low 为初始候选，输入当前句、邻近上下文、不可变词 ID 和已经核对的原话。输出原形、句中词性、语境释义、通俗讲解、缩写/固定搭配的词 ID 关联；不得重写对白、推测时间戳或补说话人。具体质量、耗时、重试和必要的 effort 升级由同一批真实片段验证。
7. **校验、核对、入库**：应用检查 ID 完整性、词范围、时间合法性、原文一致性和讲解字段。无时间、无法对齐、重叠语音或有争议释义进入待核对状态。核对后产出本地版本化学习包，播放时直接读取，不逐词实时调用模型。

“听出原话”“时间准确”“讲解正确”是三个独立验收点。顺畅的颜色动画不证明任何一个识别环节正确。

## 建议的数据边界（未实现）

每个片段独立目录：原件引用/副本、源文件哈希、媒体元信息、音频中间产物、原始转写结果、对齐结果、教学数据和审核记录。应用管理写入，不让生成模型写用户库。

- `schemaVersion`、`clipId`、`revision`、`sourceSHA256`：稳定身份与版本。
- `audioTrackId`、`audioToVideoOffsetSeconds`、`chunkOffsetSeconds`：显式处理媒体与分块偏移。
- `segments`：稳定 ID、原话、起止时间、speakerId（可空）。
- `words`：稳定 ID、原始文本范围、surface、start/end（未对齐可空）、alignmentStatus、reviewStatus。
- `analyses`：按 wordId 关联 lemma、partOfSpeech、meaningZh、plainExplanation、phraseIds。
- `phrases`：词 ID 序列和整体说明。let’s、have to、get soaked 等结合语境解释，不把每个词硬套一个字典义。
- `provenance`：ASR/对齐/教学模型及配置、输入 revision、生成时间、人工改动与审核状态；不储存登录凭证。

Codex 请求采用结构化输出约束，只接受分析字段和既有 ID，不允许返回覆盖原话/时间的字段。通过本地验证后才接入展示。修正原话时，将受影响的对齐与教学数据标记过期并重新生成；不能用旧词序对应新原文。保存操作应原子化，保留旧版本以便复核。

## 首个真实样本的验收

先选一个较短、两人轮流说话的原始片段，保留有字幕/无字幕的输入差异。逐句听回去检查漏词、多词、专名、缩写、重复和语气词；逐词检查首尾时间及变速/跳转后的同步；人工核对句中词性、语境释义和固定搭配。对于背景音乐、口音、重叠说话，再单独扩展样本，不以首条视频结果承诺所有影视素材。

已验证 base.en 模型哈希并运行本地 ASR/DTW；尚未决定最终识别/对齐引擎，不调用付费转写 API。

## 主要资料

- Codex App Server：https://learn.chatgpt.com/docs/app-server
- Whisper.cpp：https://github.com/ggml-org/whisper.cpp （Apple Silicon 支持；word-level timestamps 标为 experimental）
- WhisperX：https://github.com/m-bain/whisperX （转写、forced alignment、说话人；已说明重叠语音与对齐词典的限制）
- OpenAI File transcription：https://developers.openai.com/api/docs/guides/speech-to-text （如未来采用云端，另行核对模型、输出元信息、计费与可用性；不把 Codex 登录当作转写 API 凭据）

## 2026-11-04 推进

角色提示词 characters-v2 按每批最多 8 段、24 张图片覆盖所有对白，并携带前批角色表保持身份一致；不再用均匀抽段代替全覆盖。校对编辑与保存流程见 [review-workflow.md](review-workflow.md)。
