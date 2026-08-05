class_name PlayerAnimations
## 从素材包 16x16 序列图构建玩家 SpriteFrames。
## 动画名：idle / run / jump / attack / damaged / death。

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
