# assets — 原始素材

将美术、音频、字体放入对应子目录，Godot 会在首次导入时生成 `.godot/imported/` 缓存。

## 目录约定

- `art/characters/`：玩家、居民、敌人角色素材
- `art/environment/`：地形、树木、岩石、建筑、地下通道入口等场景素材
- `art/ui/`：按钮、图标、面板等界面素材
- `art/effects/`：攻击、死亡、火焰等特效
- `audio/music/`：背景音乐（建议 OGG）
- `audio/sfx/`：音效（建议 WAV/OGG）
- `fonts/`：字体文件

## 命名规范

- 文件名使用小写英文字母 + 下划线，例如 `player_sword_attack_01.png`。
- 同一个动画序列使用统一前缀 + 序号。
- 素材放置后可在 `FileSystem` 面板直接拖入场景使用。

## 第三方素材

- `Darkwood Forest Platformer Free Asset/`：免费公开素材包（背景、环境、角色动画等）。
  素材包内未附带许可文件，正式发布前请确认其使用条款与署名要求。
