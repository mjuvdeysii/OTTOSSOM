# OTTOSSOM

Moss & Otto 的 iOS 游戏。无对白、回合制的光影解谜：Moss 只走被照亮的地方，Otto 掌灯，Mosto 是两人性格另一面的合体，总在暗处反着学 Moss 走路。

- 故事正典与游戏设计：见项目文档《OTTOSSOM · IP 故事正典与游戏设计》
- 规则参考实现：`Tools/engine.py`（Swift 引擎 `Game/Engine/Engine.swift` 与之逐条一致）
- 关卡：`Tools/levels.txt` → `python3 Tools/build_levels.py` → `Game/Resources/levels.json`
- 验证：CI 先用 Python 参考实现重解全部关卡（`Tools/check_levels.py`），再由 Swift 测试目标独立求解，两者的最短解必须完全一致
- 美术：`Tools/art/characters.py`（三位角色，3D）、`Tools/art/props.py`（道具与桌面）；2D 版由 `Game/IP/Flat2D.swift` 绘制
- 构建：推送到 main 后由 GitHub Actions 构建、测试、截图并上传 TestFlight；报告在 `ci-logs` 分支

隐藏彩蛋：标题页连点三位角色 5 下切换为平面 2D；按住 3 秒回到 3D。
