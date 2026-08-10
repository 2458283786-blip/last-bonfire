class_name Building
extends Node2D
## 建筑基类：统一血量/损坏/重建状态，所有建筑加入 buildings 组（供敌人选目标）。

signal damaged(building: Building, hp: int)
signal destroyed(building: Building)

## 建筑最大生命值
@export var max_hp: int = 100
## 建筑唯一 ID（存档用）
@export var building_id: String = "building"
## 建筑显示名（UI 展示）
@export var display_name: String = "建筑"
## 当前等级（升级功能预留）
@export var level: int = 1

var hp: int = 100
var is_destroyed := false

func _ready() -> void:
	add_to_group("buildings")
	hp = max_hp
	destroyed.connect(_on_destroyed)

func _on_destroyed(_building: Building) -> void:
	EventBus.building_destroyed.emit(building_id)
	_on_function_offline()

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(self, hp)
	if hp <= 0:
		is_destroyed = true
		destroyed.emit(self)
		_update_visual()

## 建筑被摧毁：功能下线（子类覆盖实现具体联动）。
func _on_function_offline() -> void:
	pass

## 建筑修复/重建：功能上线（子类覆盖实现具体联动）。
func _on_function_online() -> void:
	pass

## 按当前状态同步一次功能开关（存档加载后调用；子类保证幂等）。
func refresh_function_state() -> void:
	if is_destroyed:
		_on_function_offline()
	else:
		_on_function_online()

## 修复：恢复满血；已摧毁则重建。
func repair() -> void:
	is_destroyed = false
	hp = max_hp
	_update_visual()
	damaged.emit(self, hp)
	_on_function_online()
	EventBus.building_repaired.emit(building_id)

## 重建：恢复满血并显示（后续由玩家建造操作调用）。
func rebuild() -> void:
	is_destroyed = false
	hp = max_hp
	_update_visual()
	_on_function_online()
	EventBus.building_repaired.emit(building_id)

func _update_visual() -> void:
	visible = not is_destroyed
