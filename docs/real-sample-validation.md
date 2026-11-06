# 首条真实样片记录

2026-11-02，本地开发预览；没有发布或上传视频。

## 样片与授权来源

Tears of Steel (2012)，Blender Foundation / Blender Institute，导演 Ian Hubert。
官方项目介绍列明影片为 Creative Commons Attribution 3.0：
https://mango.blender.org/about/

下载原件：https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov
许可：https://creativecommons.org/licenses/by/3.0/
署名：(CC) Blender Foundation | mango.blender.org
剪辑：原片 00:22.500–00:34.700，转码后的实测时长 12.212993 秒；不暗示作者认可 EnglishX。
署名、作者、来源、许可、剪辑说明随样片 attribution.json 和 clip.json 保存，在片段库可查看来源链接。

注意：下载目录中的 copyright.txt 明确只针对 Original Soundtrack 文件（BY-ND）；它没有被当成电影的授权证明。本次依据影片官方项目页的电影授权，不单独改编或分发原声音乐文件。

## 实际加工与保存

- 源文件：.local/sample-source/tears-of-steel-12s.mp4，约 1.6 MB。
- 模型：ggml-base.en.bin，147964211 字节，SHA256 `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002`。
- 本地调用 ffmpeg 规范化播放文件、抽取 16kHz 单声道 PCM；Whisper.cpp 执行英语识别和 attention-DTW（显式 -nfa -ng，避免默认 flash attention 关闭 DTW）。没有使用字符数分配词时长，缺失声学 anchor 会报错。
- 由 token DTW anchor 合并收缩词/标点并估计词边界。这是自动声学对齐结果，不是人工标注真值，也不是已经验证的音素强制对齐。
- 实际得到 4 段对白、38 个词。通过 gpt-6.1-sol / low 的真实 ephemeral、read-only turn 生成讲解，严格检查每个词 ID 与必需字段。
- 片段包 ID：93322dd7768049b1806d98a66b5934f5。
- 路径：`~/Library/Application Support/EnglishX/Library/93322dd7768049b1806d98a66b5934f5/`。
- 保留 original.mp4、media.mp4、audio.wav、asr.json、aligned.json、clip.json、attribution.json 和本地音频工具日志。成功后从 .staging 原子移入库；失败不替换已有片段。

第一轮完整加工由同一打包 worker 的 CLI 入口真实完成。设置页随后选择同一文件、读到 12 秒/1 音轨/无字幕轨，点击开始加工命中已有文件哈希，正确复用包，没有再次请求识别和生成。不要将这次 UI 去重测试说成第二次全量模型加工。

## 客户端观察与检查

- 重开客户端从持久目录加载片段，实际显示电影帧、对白和生成讲解。
- 实际播放时进度来自 AVPlayer 而非 mock tick；观察到播放进度推进以及末尾停在 12.212993 秒，详情切到 hand。
- Cmd+, 在同窗口进入设置，保留上下/左右分割比例；进入设置暂停播放器。
- Swift 8 项测试通过（原有时间同步 + 包数据 ID/时间/路径校验），Python 3 项对齐合并测试通过。

## 未通过的精度/产品验收

- ASR 将人名写成 Tom，参考字幕为 Thom。未静默替换原话；保留自动结果供核对。
- 对照参考字幕，其他对白表述大体一致，不等于已逐词听验或无漏词；标点、专名和词边界仍需要真实回放核对。
- 所有 segment 的 speaker 为“未标注”，界面显示 ?。没有假造 A/B 或角色身份。
- 所有片段/词边界均为 needs-review；没有宣称讲解质量全部正确，未实现自动转为已审核。
- 未实现用户逐词校正编辑器、人工审核入库状态切换、批量任务、完整失败重试管理或独立说话人识别。
