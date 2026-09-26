extends "res://main.gd"

func load_save():
	pass

func save_data():
	pass

func play_sfx(_name, _pitch=1.0, _volume=1.0):
	pass

func make_loop(_name):
	var node = AudioStreamPlayer.new()
	add_child(node)
	return node
