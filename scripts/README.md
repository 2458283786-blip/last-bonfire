# scripts — GDScript 脚本

Godot 4.7 / GDScript 2.0。每个目录对应一个系统模块，与 `scenes/` 同名目录对应。

## 目录约定

- `autoload/`：全局单例（EventBus / GameManager / SaveManager / AudioManager）
- `main/`、`town/`：场景逻辑
- `player/`：玩家移动、近战/弓箭、装备、背包、状态
- `combat/`：伤害、生命、掉落（金币/怪物材料）
- `enemy/`：敌人 AI、夜晚波次生成
- `economy/`：资源、生产、自动入库
- `building/`：建筑放置、升级、损坏
- `villager/`：居民 AI、职业自动分配
- `daynight/`：昼夜循环、时间管理
- `ui/`：界面逻辑
- `utils/`：通用工具（数学、事件、调试）

## 编码规范

- 类名（文件内 `class_name`）PascalCase，变量/函数 snake_case，常量 SCREAMING_SNAKE。
- 每个文件顶部用 `##` 写清职责；`TODO` 标注未实现部分。
- 中文注释，方便团队阅读。
- 跨系统通信优先通过 `EventBus` 信号，不要直接引用其他系统节点。
