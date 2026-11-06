# 经典对白第二样本：验证记录

2026-11-03，本地预览实测。目标是检验熟知角色、短问答、连续说话、跨说话人分段、逐词时间和讲解；单个片段不能覆盖所有口音、重叠语音、噪声、长视频或声纹问题。

## 素材选择与边界

用户优先举例《权力的游戏》。已找到 HBO 官方发布的 [Daenerys and Tyrion Meet](https://www.youtube.com/watch?v=CO1S9o1u3II)，以及 [Rotten Tomatoes 的同名片段页](https://www.rottentomatoes.com/tv/game_of_thrones/videos/jj9IcZwIqCzC)。YouTube 自动访问要求登录/机器人验证，未使用账户 cookies 或规避验证；其他公开播放地址访问失败。未取得可加工副本，也未确认开放下载复用许可，因此没有把《权游》入库或声称已实测。

本轮替代实测采用 1954 年美制《Sherlock Holmes》首集 The Case of the Cunningham Heritage，合租前讨论音乐、阿富汗经历的对话。是老版福尔摩斯，不是现代 BBC《神探夏洛克》。角色熟知并不意味着这版画面/演员像现代热门剧一样熟知。

- [Internet Archive 原件页](https://archive.org/details/SherlockHolmes-TheCaseoftheCunninghamHeritage) 明确标记 Usage: Public Domain，并提供下载。这里只记录来源的公版标记，没有做全球版权状态的独立法律认定。
- 原件内位置 00:04:59.000–00:05:28.500；提取 29.5 秒，实际容器时长 29.529133 秒，384×240，H.264/AAC。
- 本地源文件 `.local/sherlock-validation/classic-dialogue-29s.mp4`。署名、来源、公版标记和剪辑说明保存在 attribution sidecar；仅本地加工，没有发布。
- 来源自动 VTT 单独保留用于比较，未喂给 ASR、角色模型或教学模型；自动字幕不是人工真值。角色任务只提供作品提示 `Sherlock Holmes (1954)`，文件名没有泄漏人物名/台词归属。画面、原话仍可能包含正常角色线索。

## 已观察结果

- 本地 base.en ASR/DTW 返回 14 段、122 个词；有有效声学 token anchors，不是按字数生成时间。
- 多模态任务建立 Sherlock Holmes / Dr. Watson 两个人物建议。14 段中 7 段为 high、6 段 uncertain、1 段 unknown；high 是模型定性建议，不是准确率。
- 第 9 段把简短应答与随后提问合成一段。模型明确指出可能跨说话人并返回 unknown，未强行给它单一角色名。
- 当前单次最多 24 张帧、8 段的上限会漏采这段快节奏对话的 6 段。未采样段保留候选，但界面待确认。这不是自动身份识别已完整覆盖。
- ASR 含 `Vegas`、`sharing the plants`、`they're for an army doctor` 等可疑转写，和来源自动字幕/租房语境有冲突。它们是疑似错误，尚无人工听验的完整真值，不计算 WER，也不静默用字幕或模型猜测替换。
- 模型能识别熟知角色，并不能修复转写和分段。未经审核的错误原话仍可能获得一份看似通顺的逐词讲解，需要专门检查。

这些是自动结果的观察，不是完整人工真值或角色准确率。

## 失败与读取修复

首轮在角色分析后、教学结果读取阶段失败，未生成 clip.json、未入库，目录 `.staging/2f331e7450274d85a7d768feedd1d42a` 保留。旧实现没有保存原始教学回复，所以不能追溯确认具体异常文本。代码检查发现其拼接全部 agentMessage（包含可能的 commentary）及流式 delta，会污染严格 JSON。已按 [官方 Items 文档](https://learn.chatgpt.com/docs/app-server#items) 改用已完成的最终消息，保留本地 text/phase 响应，并对无最终结果、非法 JSON 明确报错。不抽取或修补杂文中的 JSON。Python 9 项回归检查通过；后续真实重跑结果如下，不能将代码修复直接当成这次失败根因已证实。

## 重跑与客户端结果

第二次完整 worker 运行成功，包 ID `f62a245d93af476780a094935e17d2de`，位于用户本地 EnglishX Library。仍为 needs-review。新版 character-response / teaching-response 各含一条 final_answer，教学回复约 15,239 字符，覆盖全部 122 个词 ID。角色建议分布与首轮一致；这不证明首轮一定因 commentary 混入而失败。

| 检查项 | 本轮观察 |
| --- | --- |
| 视频导入 | 客户端读到真实缩略图、29 秒、有声音；选中后不自动生成 |
| 识别、对齐、生成、入库 | 真实执行并保存；没有用来源字幕替换或手填台词/角色 |
| UI 入口 | 选择相同视频和作品提示后命中缓存，加载上述新包；这次 UI 点击是复用，不是第三次完整加工 |
| 角色气泡 | Sherlock Holmes / Dr. Watson 的建议名可见，标待核对；同 ID 固定侧，未命名的仍待确认 |
| 暂停与快退/快进 | 从 7.76 秒附近按右键跳入下一句并切换释义，再按左键返回原句和 No 的语境释义 |
| 倍速 | 选中自绘菜单中的 1.25×，实际视频继续播放，台词/当前词随时间变化；暂停后画面与词详情保持。已恢复 1×。未测量实际速率误差 |
| 词内进度 | 拖动自绘时间轴停在 plants 词内，观察到部分字形变色，暂停后保持固定；这只证明 UI 同步，不证明词边界准确 |
| 片尾 | 从末句实际播放至 29 秒，按钮恢复“播放”，末词详情为 doctor；检查后停回 4 秒的华生对白，保持暂停和 1× |
| 语境讲解 | 抽查 pop around、go ahead、rather、army doctor 均按当前表达解释；未逐一人工验收全部讲解 |
| 疑似错误传播 | plants 有“原文可能需核对”的提示；Vegas 却直接被解释成拉斯维加斯，缺少前置转写核对依然会误导学习 |

尚未逐词人工听验边界、没有独立声纹/音频 diarization、没有重叠语音/多口音/噪声覆盖、没有把自动数据升为已审核。现有画面采样上限与 ASR 分段不足仍保留，未为这次展示手动填满角色名。

本次仅修改结果读取代码并补回归检查；没有趁测试替换 ASR 模型或调整教学/角色提示词以掩盖失败样本。预览重新编译、打包与签名验证通过，打包 worker 哈希与源码一致。
