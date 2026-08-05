# scenes — Godot 场景

每个场景与 `scripts/` 中同名目录的脚本一一对应（`scenes/town/` ↔ `scripts/town/`）。

## 目录约定

- `main/`：启动场景、主菜单
- `town/`：城镇主场景（建造、居民、昼夜、夜晚防御、地下通道入口）
- `dungeon/`：探索关卡场景（战斗、刷怪、掉落）
- `player/`：玩家角色场景
- `villagers/`：居民场景
- `enemies/`：敌人场景
- `buildings/`：建筑场景（篝火、伐木屋，及城墙/箭塔等预留）
- `ui/`：HUD、建造菜单、背包、装备界面

## 规范

- 场景文件名使用小写下划线命名（如 `town.tscn`、`lumber_hut.tscn`）。
- 场景根节点命名与文件同名（PascalCase）。
- 新场景的脚本放 `scripts/` 对应目录，场景内通过 `ext_resource` 引用。
