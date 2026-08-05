extends Node
## 音频管理（预留）：
## 统一通过本单例播放 BGM 与音效，后续实现音频池与音量设置。

func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	# TODO: 实现音效播放池
	pass

func play_music(_stream: AudioStream) -> void:
	# TODO: 实现 BGM 播放与切换
	pass

func stop_music() -> void:
	# TODO: 停止 BGM
	pass
