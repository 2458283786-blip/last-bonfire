# 玩家角色（移动 + 跳跃 + 近战/弓箭）实施计划

> **For agentic workers:** 本计划由主代理按 superpowers:executing-plans 内联执行，任务用 checkbox 跟踪。

**Goal:** 在城镇场景中实现可操作的玩家角色：左右移动、跳跃、近战攻击、弓箭射击，并带动画与自动化测试。

**Architecture:** Godot 4.7 CharacterBody2D 驱动物理；玩家场景 `scenes/player/player.tscn` + 逻辑脚本 `scripts/player/player.gd`；动画由 `scripts/player/player_animations.gd` 在运行时从素材包 16x16 序列图构建 SpriteFrames；弓箭为独立 Area2D 场景。测试用 `godot --headless --script` 运行 SceneTree 脚本断言真实行为。

**Tech Stack:** Godot 4.7.1 / GDScript 2.0 / 素材包 `Darkwood Forest Platformer Free Asset`

## Global Constraints

- Godot 4.7.1，GDScript 2.0，`config_version=5`。
- 玩家碰撞体与运动参数以 `@export` 暴露，数值集中在 player.gd 顶部，不散落。
- 动画帧统一从 `res://assets/Darkwood Forest Platformer Free Asset/Free Character Animations/` 的 16x16 序列图构建。
- 输入动作：move_left / move_right / jump / attack / bow（+ 预留 interact）。
- 跨系统通信走 EventBus；本阶段不新增跨系统耦合。
- 所有测试必须通过 `godot --headless` 运行，禁止依赖窗口/渲染。

---

### Task 1: 测试基础设施

**Files:**
- Create: `tests/run_all.gd`
- Create: `tests/test_input_map.gd`

**Interfaces:**
- Produces: `godot --headless --path . --script res://tests/run_all.gd`，退出码 0 = 全过，1 = 有失败。

- [ ] **Step 1: 写失败的输入映射测试**（含运行器骨架）

`tests/test_input_map.gd`:
```gdscript
extends SceneTree

var failures: Array[String] = []
var assertions := 0
const REQUIRED_ACTIONS := ["move_left", "move_right", "jump", "attack", "bow", "interact"]

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	for action in REQUIRED_ACTIONS:
		check(InputMap.has_action(action), "缺少输入动作: " + action)
	_finish()

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_input_map: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_input_map: %d 个断言失败" % failures.size())
		quit(1)
```

`tests/run_all.gd`（运行器，后续任务把测试脚本路径加进列表）:
```gdscript
extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_input_map.gd",
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var code := 0
	for script_path in TEST_SCRIPTS:
		print("=== 运行测试: ", script_path)
		var output: Array = []
		var exit_code := execute(script_path, [], output, true)
		for line in output:
			print(line)
		if exit_code != 0:
			code = 1
	if code == 0:
		print("[PASS] 全部测试通过")
	else:
		push_error("[FAIL] 存在失败的测试")
	quit(code)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `godot --headless --path . --script res://tests/run_all.gd`
Expected: 报错"缺少输入动作: move_left"，退出码 1。

- [ ] **Step 3: 在 project.godot 添加 [input] 输入映射**

在 `project.godot` 的 `[display]` 之前插入 `[input]` 段（A/D/W/Space/方向键/J/K/E + 鼠标左右键）：
```ini
[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
jump={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
attack={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
bow={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `godot --headless --path . --script res://tests/run_all.gd`
Expected: `[PASS] test_input_map: 6 断言全部通过`，退出码 0。

- [ ] **Step 5: 提交**

```bash
git add project.godot tests/ && git commit -m "feat: 添加输入映射与测试运行器"
```

---

### Task 2: 玩家场景与左右移动

**Files:**
- Create: `scenes/player/player.tscn`
- Create: `scripts/player/player.gd`
- Create: `tests/test_player_movement.gd`

**Interfaces:**
- Produces: `class_name Player extends CharacterBody2D`；`var facing: int`（1 右 / -1 左）；`var velocity: Vector2`（继承）；`@export move_speed: float`。

- [ ] **Step 1: 写失败测试**

`tests/test_player_movement.gd`（SceneTree 脚本，复用 test_input_map 的 check/_finish 模式）:
```gdscript
extends SceneTree

var failures: Array[String] = []
var assertions := 0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	Input.action_press("move_right")
	await process_frame
	await physics_frame
	check(p.velocity.x > 0, "按住 move_right 应产生正 x 速度")
	var x0 := p.global_position.x
	await physics_frame
	await physics_frame
	check(p.global_position.x > x0, "持续 move_right 位置应右移")
	Input.action_release("move_right")
	await process_frame
	await physics_frame
	check(p.velocity.x == 0, "松开 move_right 后 x 速度应为 0")
	check(p.facing == 1, "朝右时 facing 应为 1")
	Input.action_press("move_left")
	await process_frame
	await physics_frame
	check(p.velocity.x < 0, "按住 move_left 应产生负 x 速度")
	check(p.facing == -1, "朝左时 facing 应为 -1")
	_finish()

func _spawn_player() -> Player:
	var scene := load(PLAYER_SCENE) as PackedScene
	var p := scene.instantiate() as Player
	root.add_child(p)
	p.global_position = Vector2(400, 300)
	_add_floor(Vector2(400, 420))
	await physics_frame
	await physics_frame
	return p

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	root.add_child(floor)

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_player_movement: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_player_movement: %d 个断言失败" % failures.size())
		quit(1)
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_player_movement.gd`
Expected: 报错（缺少 player.tscn / Player 类），退出码非 0。

- [ ] **Step 3: 最小实现——玩家场景与移动脚本**

`scenes/player/player.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/player/player.gd" id="1_player"]
[ext_resource type="PackedScene" path="res://scenes/player/arrow.tscn" id="2_arrow"]

[sub_resource type="CapsuleShape2D" id="Capsule_body"]
radius = 10.0
height = 48.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_player")
arrow_scene = ExtResource("2_arrow")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -4)
shape = SubResource("Capsule_body")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -4)
scale = Vector2(4, 4)
texture_filter = 1

[node name="AttackHitbox" type="Area2D" parent="."]
position = Vector2(20, -4)
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackHitbox"]
shape = SubResource("Capsule_body")

[node name="BowSpawn" type="Marker2D" parent="."]
position = Vector2(16, -10)
```

（AttackHitbox 的胶囊体由运行时脚本缩放；BowSpawn 为箭矢出生点。）

`scripts/player/player.gd`（先实现移动与朝向，攻击/弓箭在后续任务补）:
```gdscript
class_name Player
extends CharacterBody2D

@export var move_speed: float = 260.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1200.0

@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.5
@export var bow_cooldown: float = 0.6
@export var arrow_speed: float = 520.0
@export var arrow_scene: PackedScene

var facing := 1
var is_attacking := false
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var bow_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var bow_spawn: Marker2D = $BowSpawn

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		facing = 1 if dir > 0 else -1
	velocity.x = dir * move_speed
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("bow"):
		try_shoot_bow()
	_tick_timers(delta)
	move_and_slide()
	_update_visual()

func _tick_timers(delta: float) -> void:
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	bow_cooldown_timer = maxf(bow_cooldown_timer - delta, 0.0)
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			attack_hitbox.monitoring = false

func try_attack() -> void:
	if attack_cooldown_timer > 0.0 or is_attacking:
		return
	is_attacking = true
	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	attack_hitbox.monitoring = true

func try_shoot_bow() -> void:
	# 由 Task 4 实现
	pass

func _update_visual() -> void:
	sprite.flip_h = facing < 0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing
	bow_spawn.position.x = absf(bow_spawn.position.x) * facing
```

- [ ] **Step 4: 运行测试确认通过**

Run: `godot --headless --path . --script res://tests/test_player_movement.gd`
Expected: `[PASS] test_player_movement: 6 断言全部通过`。

- [ ] **Step 5: 提交**

```bash
git add scenes/player/player.tscn scripts/player/player.gd tests/test_player_movement.gd
git commit -m "feat: 玩家角色左右移动与朝向"
```

---

### Task 3: 跳跃与重力

**Files:**
- Create: `tests/test_player_jump.gd`

**Interfaces:**
- Consumes: `Player.jump_velocity` / `Player.gravity` / `Player.is_on_floor()`。

- [ ] **Step 1: 写失败测试**

`tests/test_player_jump.gd`（结构同 test_player_movement，含 `_spawn_player`/`_add_floor`）:
```gdscript
func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	check(p.is_on_floor(), "落地后 is_on_floor 应为 true")
	Input.action_press("jump")
	await process_frame
	await physics_frame
	check(p.velocity.y < 0, "跳跃后 y 速度应为负")
	var vy_after_jump := p.velocity.y
	await physics_frame
	check(p.velocity.y > vy_after_jump, "上升过程中重力应使 y 速度增大（绝对值减小）")
	check(not p.is_on_floor(), "跳跃后应离地")
	_finish()
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_player_jump.gd`
Expected: 失败（跳跃逻辑未生效），退出码 1。

- [ ] **Step 3: 最小实现**

Task 2 的 `player.gd` 已含重力与跳跃逻辑。若测试失败，检查 `_physics_process` 中条件 `is_on_floor()` 与 `jump_velocity` 赋值。

- [ ] **Step 4: 运行确认通过**

Run: `godot --headless --path . --script res://tests/test_player_jump.gd`
Expected: `[PASS] test_player_jump: 4 断言全部通过`。

- [ ] **Step 5: 提交**

```bash
git add tests/test_player_jump.gd scripts/player/player.gd
git commit -m "feat: 玩家跳跃与重力（含测试）"
```

---

### Task 4: 角色动画

**Files:**
- Create: `scripts/player/player_animations.gd`
- Create: `tests/test_player_animations.gd`

**Interfaces:**
- Produces: `PlayerAnimations.build_sprite_frames() -> SpriteFrames`；动画名：idle / run / jump / attack / damaged / death。

- [ ] **Step 1: 写失败测试**

`tests/test_player_animations.gd`:
```gdscript
func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	check(p.sprite.sprite_frames.has_animation("idle"), "应有 idle 动画")
	check(p.sprite.sprite_frames.has_animation("run"), "应有 run 动画")
	check(p.sprite.sprite_frames.has_animation("jump"), "应有 jump 动画")
	check(p.sprite.sprite_frames.has_animation("attack"), "应有 attack 动画")
	check(p.sprite.animation == "idle", "静止时应播放 idle")
	Input.action_press("move_right")
	await process_frame
	await physics_frame
	await physics_frame
	check(p.sprite.animation == "run", "移动时应播放 run")
	_finish()
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_player_animations.gd`
Expected: 失败（sprite_frames 为空）。

- [ ] **Step 3: 最小实现**

`scripts/player/player_animations.gd`:
```gdscript
class_name PlayerAnimations
## 从素材包 16x16 序列图构建 SpriteFrames。

const SHEET_DIR := "res://assets/Darkwood Forest Platformer Free Asset/Free Character Animations/"
const FRAME := Vector2i(16, 16)

static func build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", "idle}.png", 15, 6.0, true)
	_add_animation(frames, "run", "go}.png", 10, 12.0, true)
	_add_animation(frames, "jump", "jump}.png", 10, 10.0, false)
	_add_animation(frames, "attack", "steel-atack}.png", 5, 14.0, false)
	_add_animation(frames, "damaged", "damaged}.png", 7, 8.0, false)
	_add_animation(frames, "death", "death}.png", 10, 8.0, false)
	return frames

static func _add_animation(frames: SpriteFrames, anim: String, file: String, count: int, speed: float, loop: bool) -> void:
	var sheet := load(SHEET_DIR + file) as Texture2D
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, speed)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
		frames.add_frame(anim, atlas)
```

在 `player.gd` 的 `_ready()` 中构建并播放：
```gdscript
func _ready() -> void:
	sprite.sprite_frames = PlayerAnimations.build_sprite_frames()
	sprite.play("idle")
```

`_update_visual()` 扩展为状态机：
```gdscript
func _update_visual() -> void:
	sprite.flip_h = facing < 0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing
	bow_spawn.position.x = absf(bow_spawn.position.x) * facing
	if is_attacking:
		sprite.play("attack")
	elif not is_on_floor():
		sprite.play("jump")
	elif absf(velocity.x) > 10.0:
		sprite.play("run")
	else:
		sprite.play("idle")
```

- [ ] **Step 4: 运行确认通过**

Run: `godot --headless --path . --script res://tests/test_player_animations.gd`
Expected: `[PASS] test_player_animations: 6 断言全部通过`。

- [ ] **Step 5: 提交**

```bash
git add scripts/player/player_animations.gd scripts/player/player.gd tests/test_player_animations.gd
git commit -m "feat: 玩家动画状态机（idle/run/jump/attack）"
```

---

### Task 5: 近战攻击

**Files:**
- Create: `tests/test_player_attack.gd`

**Interfaces:**
- Consumes: `Player.try_attack()` / `Player.is_attacking` / `Player.attack_hitbox.monitoring`。

- [ ] **Step 1: 写失败测试**

`tests/test_player_attack.gd`:
```gdscript
func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	Input.action_press("attack")
	await process_frame
	await physics_frame
	check(p.is_attacking, "按下攻击后 is_attacking 应为 true")
	check(p.attack_hitbox.monitoring, "攻击期间命中框应启用")
	var vy := p.velocity.y
	Input.action_press("jump")
	await process_frame
	await physics_frame
	check(p.velocity.y < 0, "攻击不影响跳跃输入")
	# 等冷却结束再攻击一次
	await _wait_seconds(p.attack_cooldown + 0.3)
	Input.action_press("attack")
	await process_frame
	await physics_frame
	check(p.is_attacking, "冷却结束后可再次攻击")
	_finish()

func _wait_seconds(sec: float) -> void:
	for i in int(sec * 60):
		await physics_frame
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_player_attack.gd`
Expected: 失败（攻击未实现）。

- [ ] **Step 3: 最小实现**

Task 2 的 `player.gd` 已含 `try_attack()`；若失败，核对 `attack_hitbox` 节点路径与 monitoring 切换。

- [ ] **Step 4: 运行确认通过**

Run: `godot --headless --path . --script res://tests/test_player_attack.gd`
Expected: `[PASS] test_player_attack: 4 断言全部通过`。

- [ ] **Step 5: 提交**

```bash
git add tests/test_player_attack.gd scripts/player/player.gd
git commit -m "feat: 玩家近战攻击状态与命中框"
```

---

### Task 6: 弓箭射击

**Files:**
- Create: `scenes/player/arrow.tscn`
- Create: `scripts/player/arrow.gd`
- Create: `tests/test_player_bow.gd`

**Interfaces:**
- Produces: `Arrow.setup(direction: Vector2, speed: float)`；箭矢加入 `"arrows"` 组。

- [ ] **Step 1: 写失败测试**

`tests/test_player_bow.gd`:
```gdscript
func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	Input.action_press("bow")
	await process_frame
	await physics_frame
	var arrows := get_nodes_in_group("arrows")
	check(arrows.size() == 1, "射箭后应生成 1 支箭")
	if arrows.size() == 1:
		var arrow := arrows[0] as Area2D
		check(arrow.global_position.x > p.global_position.x, "朝右射箭应生成在玩家右侧")
		var ax := arrow.global_position.x
		await physics_frame
		await physics_frame
		check(arrow.global_position.x > ax, "箭矢应向右移动")
	_finish()
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_player_bow.gd`
Expected: 失败（无箭矢生成）。

- [ ] **Step 3: 最小实现**

`scenes/player/arrow.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player/arrow.gd" id="1_arrow"]

[sub_resource type="RectangleShape2D" id="Rect_arrow"]
size = Vector2(10, 24)

[node name="Arrow" type="Area2D"]
script = ExtResource("1_arrow")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Rect_arrow")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -5.0
offset_top = -12.0
offset_right = 5.0
offset_bottom = 12.0
color = Color(1, 0.8, 0.35, 1)
```

`scripts/player/arrow.gd`:
```gdscript
class_name Arrow
extends Area2D

var direction := Vector2.RIGHT
var speed := 520.0
var lifetime := 2.0

func setup(dir: Vector2, spd: float) -> void:
	direction = dir.normalized()
	speed = spd

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	queue_free()
```

`player.gd` 实现 `try_shoot_bow()` 与箭矢朝向：
```gdscript
func try_shoot_bow() -> void:
	if bow_cooldown_timer > 0.0:
		return
	bow_cooldown_timer = bow_cooldown
	var arrow: Arrow = arrow_scene.instantiate()
	arrow.add_to_group("arrows")
	get_parent().add_child(arrow)
	arrow.global_position = bow_spawn.global_position
	arrow.setup(Vector2(facing, 0), arrow_speed)
```

- [ ] **Step 4: 运行确认通过**

Run: `godot --headless --path . --script res://tests/test_player_bow.gd`
Expected: `[PASS] test_player_bow: 3 断言全部通过`。

- [ ] **Step 5: 提交**

```bash
git add scenes/player/arrow.tscn scripts/player/arrow.gd scripts/player/player.gd tests/test_player_bow.gd
git commit -m "feat: 玩家弓箭射击与箭矢投射物"
```

---

### Task 7: 城镇集成与全量验证

**Files:**
- Modify: `scenes/town/town.tscn`（加入玩家、地面与边界碰撞）
- Modify: `tests/run_all.gd`（注册全部测试）
- Create: `tests/test_town_scene.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_town_scene.gd`:
```gdscript
func _run() -> void:
	await process_frame
	var town := load("res://scenes/town/town.tscn").instantiate()
	root.add_child(town)
	await physics_frame
	await physics_frame
	var player := town.get_node_or_null("Player")
	check(player is Player, "城镇场景应包含 Player 节点")
	check(town.get_node_or_null("GroundBody") != null, "城镇应有地面碰撞体")
	if player is Player:
		check(player.global_position.y > 0, "玩家应在地面上方生成")
	_finish()
```

- [ ] **Step 2: 运行确认失败**

Run: `godot --headless --path . --script res://tests/test_town_scene.gd`
Expected: 失败（town 尚无 Player）。

- [ ] **Step 3: 实现城镇集成**

`scenes/town/town.tscn` 增加：
- `GroundBody`：StaticBody2D + RectangleShape2D（1920x40，位置 y=900）作为地面碰撞。
- `Player`：实例化 `res://scenes/player/player.tscn`，位置 (400, 860)。
- 保留原 Background / Ground 视觉与 SceneLabel。

- [ ] **Step 4: 更新运行器并全量运行**

`tests/run_all.gd` 的 `TEST_SCRIPTS` 更新为全部 7 个测试脚本。

Run: `godot --headless --path . --script res://tests/run_all.gd`
Expected: 全部 `[PASS]`，退出码 0。

- [ ] **Step 5: 游戏主场景冒烟运行**

Run: `godot --headless --path . --quit-after 30`
Expected: 无脚本错误输出。

- [ ] **Step 6: 更新文档并提交**

- `README.md`：当前状态勾选玩家移动/战斗；补充操作说明（A/D 移动、Space 跳、J/左键近战、K/右键弓箭）。
- `docs/design/2026-08-05-demo-design.md`：玩家系统补充操作与参数位置说明。

```bash
git add -A && git commit -m "feat: 城镇场景集成玩家并全量验证"
```
