# EnglishX

通过喜欢的影视对白、比赛解说和演讲学英语的原生 macOS 客户端。左边看视频，右边跟随对白，下方只讲解当前学到的词。采用安静的纸张与蜡笔视觉风格。

源码仓库：[anjing-le/anjing-englishx](https://github.com/anjing-le/anjing-englishx)。按 [MIT](LICENSE) 开源，素材与外部依赖说明见 [NOTICE.md](NOTICE.md)。

## 当前功能

- 本地视频播放、倍速、逐句定位与逐词填色；可隐藏片段库。
- 视频与对白左右并排，单词讲解在下方；两条分隔线均可拖动并记住比例。
- 拖入视频后检查素材，显式开始加工：本地语音识别、逐词时间估计、模型角色建议与语境讲解，最后保存到本地片段库。
- 对白采用左右气泡，当前词显示语境释义；词性、原形与搭配可按需展开。
- 校对原话、分句/合并、确认角色、调整逐词时间；保存为新版本并重新生成讲解，保留原件与旧结果。
- 设置中的「解析原理」可悬停查看实际处理步骤、当前规则版本及完整提示词。
- 附带两段原创 Mock 对白供体验；真实视频、影视台词数据和学习库不随仓库分发。

一个桥段按完整素材保留，不要求压缩到 30 秒。长素材仍可能受到本机性能和模型单次任务超时的限制；当前没有自动完成任意长度视频的保证。

## 本地运行

需要 macOS 14+、Xcode Command Line Tools 和支持 Swift tools 5.10 的 Swift 工具链。

```sh
git clone https://github.com/anjing-le/anjing-englishx.git
cd anjing-englishx
bash scripts/preview.sh
```

脚本构建并生成本地 ad-hoc 签名预览包 `dist/preview/EnglishX.app`，随后打开客户端。无需 Apple 开发者证书；这不是公证安装包，也没有 OTA 或正式发行版本。

真实视频加工还需要可执行的 `python3`、`ffmpeg`、`ffprobe`、`whisper-cli`（whisper.cpp）以及已登录的 Codex CLI。首次加工下载约 148 MB 的 `base.en` 语音权重并校验固定 SHA256。仅体验内置 Mock 不需要启动模型加工。

当前讲解和画面分析指定 `gpt-6.1-sol`，默认推理强度 `low`；你的 Codex 模型目录必须能提供该模型。模型可用性和额度取决于自己的账号与环境，本仓库不提供账号或 API 凭据，也不保证所有环境都能使用这个模型。

公开源码不包含个人图标和第三方鼠标图片，缺失时回退到系统图标/原生鼠标；本机可选放入自有授权的 `Resources/AppIcon.icns`。不要把本机包含私人素材的预览包作为公开发行包上传。

## 使用

| 操作 | 快捷键 |
| --- | --- |
| 播放／暂停 | 空格 |
| 按设定步长后退／前进 | ← / → |
| 设置 | ⌘, |
| 关闭窗口，应用继续运行 | ⌘W |
| 最小化 | ⌘M |
| 全屏 | ⌃⌘F |
| 退出应用 | ⌘Q |

进入设置、选择或拖入本地视频，必要时填作品名，然后点击「开始加工」。在设置中查看结果或进入校对。打开设置、查看解析原理、日常播放已有片段都不会自动发起模型生成。

## 数据与准确性

- 原始音频、完整视频和学习库保存在本机。语音识别与 DTW 对齐在本地执行；角色分析把抽取的画面、转写文字与可选作品提示发给 Codex，逐词讲解只发送文字。
- 通过独立的本机 Codex app-server 复用 CLI 登录；不读取或复制认证文件，不修改全局 Codex 配置。
- 真实资料默认位于 `~/Library/Application Support/EnglishX/Library`，权重位于相邻的 `Models` 目录。它们均不在仓库里。
- 自动结果保留「待核对」。词边界是 attention-DTW 估计，不保证音素级准确；人名、快速解说、重叠语音和背景音乐尤其需要核对。
- 角色建议目前只面向虚构影视角色，不识别现实演员。音频说话人分离、声纹匹配尚未实现；比赛解说不会套用虚构角色身份。
- 当前处理仍会一次生成片段的逐词讲解，并非点词后才生成详细讲解。

请只导入你有权使用的素材。源码开源不意味着影视、比赛、演讲等外部视频也随之获得复用授权。

## 验证与文档

```sh
swift test --disable-keychain
python3 scripts/test_ingest.py
```

- [加工流程与边界](docs/ingestion-plan.md)
- [教学数据与提示词](docs/teaching-contract.md)
- [角色分析](docs/character-analysis.md)
- [校对与版本保存](docs/review-workflow.md)
- [首个真实样本验证](docs/real-sample-validation.md)
- [经典对白样本验证](docs/classic-dialogue-validation.md)

验证文档记录特定样本与当时版本的结果，不代表所有素材均达到同样质量。
