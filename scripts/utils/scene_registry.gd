class_name SceneRegistry
## 场景路径常量：所有场景切换/加载统一走这里，禁止在业务代码里散落硬编码路径。
## 重命名/移动场景文件只需改这里。

const BOOT := "res://scenes/main/boot.tscn"
const TOWN := "res://scenes/town/town.tscn"
const DUNGEON := "res://scenes/dungeon/level_forest.tscn"
const DOOR_CHOICE := "res://scenes/dungeon/door_choice.tscn"
const VILLAGER := "res://scenes/villagers/villager.tscn"
const LOADING_OVERLAY := "res://scenes/ui/loading_overlay.tscn"
