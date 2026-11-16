# 长夜 · OTTOSSOM

Moss、Otto、Mosto 的原生 iOS 像素冒险，SwiftUI + Canvas。当前入口为 `Game/Pixel/DigGame.swift`。

夜间下井找光晶与八块记忆石，白天为镇民配灯，晚间升级工具。奥托牵住光线，莫斯探索地下，莫斯托在井底等待；放下背包、挥手完成第一章。

晚间可查看记忆、同伴与灯火。交灯会点亮对应居民的窗户并保留颜色；居民再次来访时会记得上次的光。同伴记录随已发现的记忆和重逢结局更新。

- 物理与地下世界：`Game/Pixel/Dig.swift`
- 经济、存档、对白：`Game/Pixel/Lamps.swift`
- 镇民回应与持续灯火：`Game/Pixel/TownLights.swift`
- 场景与交互：`Game/Pixel/DigGame.swift`、`DigView.swift`
- 角色世界观和待开发章节：[叙事基线](docs/narrative.md)
- 测试：`GameTests/DigTests.swift`；macOS 上用 XcodeGen 生成工程，再运行 `xcodebuild test`。

仓库也保留早期俯视角解谜与回合制 RPG 原型，当前不作为游戏入口。旧房间参考规则可用 `node Tools/rooms/check.js` 校验。

`dev/**` 分支触发 iOS 构建和测试；`main` 还会归档并上传 TestFlight。CI 报告保存在 `ci-logs-<分支>` 分支。
