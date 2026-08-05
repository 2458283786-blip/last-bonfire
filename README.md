# 最后的篝火

2D 横版建造经营 + 探索战斗游戏（开发中）。

游戏氛围与循环参考《王国两位君主》，玩家战斗参考《小骨英雄杀手》：玩家在城镇发展居民与建筑、在白天经营，夜晚抵御怪物；通过城镇中的地下通道进入探索关卡打怪，获得金币与怪物材料，不断重建与扩张。

## 环境要求

- Godot 4.7.1（本机为 Steam 版：`D:\steam\steamapps\common\Godot Engine`）

## 运行方式

- 用 Godot 打开本目录的 `project.godot`，按 F5 运行。
- 或命令行：`godot --path .`
- 当前入口场景：`scenes/main/boot.tscn`（按 Enter 进入城镇占位场景）

## 操作说明

| 按键 | 功能 |
| --- | --- |
| A / ← | 左移 |
| D / → | 右移 |
| 空格 / W / ↑ | 跳跃 |
| J / 鼠标左键 | 近战攻击 |
| K / 鼠标右键 | 弓箭射击 |
| E | 交互（预留，地下通道等后续使用） |

## 运行测试

```bash
godot --headless --path . --script res://tests/run_all.gd
```

## 目录结构

```
├── docs/           # 设计文档与开发日志
├── assets/         # 原始素材（美术/音频/字体）
├── scenes/         # Godot 场景（main/town/dungeon/player/villagers/enemies/buildings/ui）
├── scripts/        # GDScript（autoload 单例 + 各系统模块）
├── resources/      # 配置数据（.tres）与材质资源
└── shaders/        # 着色器源码
```

各目录的详细约定见对应文件夹内的 `README.md`。

## 开发规范

1. **数据驱动**：建筑、居民、怪物、武器等一律使用 `resources/data/` 下的配置，禁止写死在脚本里。
2. **场景与逻辑分离**：`.tscn` 放场景，`.gd` 放脚本（`scenes/` 与 `scripts/` 一一对应）。
3. **系统解耦**：跨系统通信走 `EventBus` 信号，不直接互相引用。
4. **玩法优先**：先跑通"探索 → 战斗 → 回城 → 建造 → 夜晚防御"核心循环，再扩展内容。
5. **预留接口**：所有系统保留等级/类型/属性/状态扩展位，避免后期重构。
6. **先设计后实现**：新功能先更新 `docs/design/` 设计文档，再动手写代码。

## 当前状态

- [x] 项目框架与目录结构
- [x] Godot 4.7 项目配置与全局单例（EventBus / GameManager / SaveManager / AudioManager）
- [x] 启动场景 → 城镇场景切换链路
- [x] 玩家移动、跳跃、近战攻击与弓箭射击
- [x] 玩家动画状态机（idle / run / jump / attack）
- [x] 自动化测试（tests/，7 个测试脚本）
- [ ] 敌人与伤害结算
- [ ] 建筑放置与升级
- [ ] 居民职业自动分配与采集 AI
- [ ] 昼夜循环与夜晚怪物袭击
- [ ] 地下通道与探索关卡

详细设计见 [docs/design/2026-08-05-demo-design.md](docs/design/2026-08-05-demo-design.md)。
