extends Node
## Reproduce música de ambiente de forma continua entre escenas.

const _VILLAGE_THEME: AudioStreamMP3 = preload("res://assets/audio/JobLab Studio - Village__JobLab Studio - Village__e7a4c520454c.mp3")

var _music_player: AudioStreamPlayer


func _ready() -> void:
	var music_track := _VILLAGE_THEME
	music_track.loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusic"
	_music_player.bus = &"Music"
	_music_player.stream = music_track
	add_child(_music_player)
	_music_player.play()
