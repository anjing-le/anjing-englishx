[English](README.md) · **简体中文** · [开始使用](GUIDE.zh-CN.md#本地运行) · [使用指南](GUIDE.zh-CN.md) · [MIT](LICENSE)

# EnglishX

<p align="center">
  <a href="GUIDE.zh-CN.md"><img src="assets/readme/paper-v2/00-brand.png" width="360" alt="EnglishX：蜡笔胶片、声音与对白的品牌插画，非截图。" /></a>
</p>
<p align="center">
  <a href="assets/readme/paper-v2/01-overview.png"><img src="assets/readme/paper-v2/01-overview.png" width="100%" alt="EnglishX 功能总览：片段收藏、对白回放、词句理解与校对保存。功能示意，自动结果需核对。" /></a>
</p>

<p align="center">
  <a href="assets/readme/paper-v2/02-library.png"><img src="assets/readme/paper-v2/02-library.png" width="100%" alt="片段收藏：将自己的视频加工后收入片段库，旁栏选择片段。画面与数据为示意。" /></a>
</p>

<p align="center">
  <a href="assets/readme/paper-v2/03-playback.png"><img src="assets/readme/paper-v2/03-playback.png" width="100%" alt="对白回放：点击句子跳转，调整倍速，金色标记当前词。示例对白为原创演示。" /></a>
</p>

<p align="center">
  <a href="assets/readme/paper-v2/04-context.png"><img src="assets/readme/paper-v2/04-context.png" width="100%" alt="词句理解：根据当前句解释 made it，词句讲解与发音参考需核对。" /></a>
</p>

<p align="center">
  <a href="assets/readme/paper-v2/05-review.png"><img src="assets/readme/paper-v2/05-review.png" width="100%" alt="校对保存：修正原话和逐词时间，保存并更新分析，保留原片段与旧版本。功能示意。" /></a>
</p>

以上为功能示意插画，不是真实产品截图。

一个原生 macOS 视频英语学习客户端：收藏喜欢的桥段，反复听、跟着说，理解每个词在这句话里的意思。

EnglishX 管理视频、学习界面和本地数据，把需要语言理解的加工步骤交给 agent：

- **本地处理**：提取音频、听写和估计逐词时间，不让语言模型猜时间戳。
- **Agent 分析**：目前通过本机 Codex CLI 的 app-server 接入 `gpt-6.1-sol`，复用已有登录，生成语境讲解与虚构影视角色建议。
- **校验与学习**：检查结构化结果后保存到本地片段库；播放、逐词跟随、回放和已有讲解的查看不再调用 agent。

目前仅实现 Codex 接入。可插拔的 agent 接口正在设计，尚不代表已经兼容其他 agent 或模型。语音识别在本地；分析会向 Codex 发送对白文字，影视角色任务还会发送抽样画面。自动结果需要校对。

macOS 14+ · 本地预览 · [安装与使用](GUIDE.zh-CN.md) · [数据与准确性](GUIDE.zh-CN.md#数据与准确性)

<p align="center"><a href="assets/star-growth.json"><img src="assets/star-growth.png" width="100%" alt="共同成长：GitHub 真实加星日期与数量（UTC），仅统计当前仍在加星的用户，不含已取消的 Star。点击查看数据。" /></a></p>
