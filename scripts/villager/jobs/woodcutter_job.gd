class_name WoodcutterJob
extends RefCounted
## 伐木工职业策略：寻找未被预留且职业匹配的树并砍伐。
## 移动/捡取/搬运/入库等通用流程由 Villager 统一处理；
## 新增职业时在 jobs/ 下加一个类，实现 find_target 与 work 即可。

const JOB_NAME := "woodcutter"

var work_timer := 0.0

func find_target(villager: Villager) -> Node2D:
	var best: ResourceNode = null
	var best_dist := INF
	for node in villager.get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree == null or tree.is_depleted:
			continue
		if tree.data == null or tree.data.required_job != JOB_NAME:
			continue
		if tree.reserved_by != -1 and tree.reserved_by != villager.villager_id:
			continue
		var d := villager.global_position.distance_to(tree.global_position)
		if d < best_dist:
			best_dist = d
			best = tree
	return best

func work(villager: Villager, delta: float) -> bool:
	var tree := villager.work_target as ResourceNode
	if tree == null or not is_instance_valid(tree) or tree.is_depleted:
		return true
	work_timer += delta
	if work_timer < villager.work_interval:
		return false
	work_timer = 0.0
	tree.chop(villager.villager_id, tree.data.chop_damage)
	return tree.is_depleted
