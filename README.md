# 长夜 · OTTOSSOM

Moss、Otto、Mosto 的 iOS 游戏：太阳一百天没有升起，三个角色各走一章，第四章汇合。俯视角格子冒险解谜，原生 SwiftUI，没有网页。

- 四章 21 个房间：守灯人（Otto · 照）、摸（Moss · 摸与推石）、影子大盗（Mosto · 抓光、飞过水）、让太阳睡一觉（三人轮换）
- 规则：`Game/Engine/Rules.swift`；参考实现 `Tools/rooms/core.js`（房间设计与校验用，两者逐条一致）
- 房间：`Tools/rooms/rooms.src.json` → `node Tools/rooms/build.js` → `Game/Resources/rooms.json`（带最短解）
- 剧情：`Game/Resources/story.json`
- 验证：CI 先用参考规则重解全部房间（`Tools/rooms/check.js`），再由 Swift 测试回放每个参考解、独立求解较小的房间，最短步数与搜索状态数必须一致
- 构建：推送到 main 后构建、测试、给每个房间截图并上传 TestFlight；`dev/**` 分支只构建与测试。报告在 `ci-logs-<分支>` 分支
