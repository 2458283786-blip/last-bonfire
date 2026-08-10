class_name HarvestJob
extends RefCounted
## 采集职业基类：寻找与 job_name 匹配、未被预留且未耗尽的资源节点并采集。
## 移动/捡取/搬运/入库等通用流程由 Villager 统一处理；
## 新采集职业 = 子类只改 job_name，无需复制 find_target / work。

var job_name := "woodcutter"

var work_timer := 0.0

func find_target(villager: Villager) -> Node2D:
	var best: ResourceNode = null
	var best_dist := INF
	for node in villager.get_tree().get_nodes_in_group("resources"):
		var res := node as ResourceNode
		if res == null or res.is_depleted:
			continue
		if res.data == null or res.data.required_job != job_name:
			continue
		if res.reserved_by != -1 and res.reserved_by != villager.villager_id:
			continue
		var d := villager.global_position.distance_to(res.global_position)
		if d < best_dist:
			best_dist = d
			best = res
	return best

func work(villager: Villager, delta: float) -> bool:
	var res := villager.work_target as ResourceNode
	if res == null or not is_instance_valid(res) or res.is_depleted:
		return true
	work_timer += delta
	if work_timer < villager.work_interval:
		return false
	work_timer = 0.0
	res.chop(villager.villager_id, res.data.chop_damage)
	return res.is_depleted
