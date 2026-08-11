extends Node
## 统一调试开关：正式逻辑写成"正式条件 OR Debug 开关"，避免并行分支。
## 发布构建（export template）不带 debug feature，is_debug_build() 自动返回 false。

const DEBUG_FEATURE := "debug"

## 强制解锁全部建筑蓝图（商店/NPC 建筑调试用）
var unlock_all_blueprints := false
## 临时人口招募开关（P10 用）
var instant_recruit := false
## 建造/升级跳过资源消耗
var skip_costs := false
## 快速推进天数（配合 F9/F10）
var fast_days := false

func is_debug_build() -> bool:
	return OS.has_feature(DEBUG_FEATURE)

## 蓝图是否可用：正式解锁 OR 调试强制解锁。
func blueprint_unlocked(building_id: String, formally_unlocked: bool) -> bool:
	return formally_unlocked or unlock_all_blueprints
