# resources — 配置数据与资源

## 目录约定

- `data/`：数值配置（`.tres` 或 `.json`）——建筑造价与属性、武器参数、怪物属性、掉落表、昼夜时长等
- `shaders/`：材质与着色器资源（`.material`、`.shader` 引用）

## 规范

- 所有可调数值必须进 `resources/data/`，脚本只负责读取与执行逻辑。
- 配置命名与场景一致：`building_lumber_hut.tres`、`weapon_bow.tres`、`enemy_goblin.tres`。
- 新增建筑/武器/怪物 = 新增一个配置 + 复用通用场景模板，禁止复制粘贴脚本。
