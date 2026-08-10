extends Node
## 全局事件总线：跨系统解耦通信。
## 用法示例：EventBus.resource_changed.emit("wood", 10)
## 后续按需补充信号，避免系统之间直接互相引用。

signal resource_changed(resource_id: String, amount: int)
signal day_phase_changed(phase: String)
signal player_died
signal building_damaged(building_id: String, hp: int)
signal building_destroyed(building_id: String)
signal building_repaired(building_id: String)
signal bonfire_lost
signal bonfire_restored
signal villager_died(villager_id: String)
signal gold_changed(amount: int)
signal villager_injured(villager_id: String)
signal wave_spawned(count: int)
signal building_built(building_id: String)
signal pickup_collected(resource_id: String, amount: int)
signal villager_converted(display_name: String, job: String)
