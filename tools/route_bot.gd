extends SceneTree

var game

func _initialize():
	call_deferred("run")

func replay(index, mode="timed"):
	game.start_level(index)
	var path = "res://tools/route_%d.json" % index
	var inputs = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not inputs is Array:
		push_error("Missing route fixture: "+path)
		return false
	for frame in range(inputs.size()):
		var input = inputs[frame]
		Input.action_release("move_left"); Input.action_release("move_right")
		var axis = float(input[0])
		if axis>0: Input.action_press("move_right",axis)
		if axis<0: Input.action_press("move_left",-axis)
		if input[1]: game.jump_buffer = 0.16
		if game.jump_held and not input[2] and game.velocity.y < -220: game.velocity.y = -220
		game.jump_held = input[2]
		var ring = mode=="automatic" or input[3]
		if mode=="late" and frame==161: ring = false
		if ring and game.ring_cooldown<=0: game.try_ring()
		game.update_game(1.0/60.0)
		if game.deaths>0 or game.state!="play": break
	Input.action_release("move_left"); Input.action_release("move_right")
	var passed = game.state in ["results","outro"] and game.notes_taken.all(func(v): return v) and game.deaths==0
	print("COURSE %d %s: %s / %.2fs / %d notes / %d deaths" % [index+1,mode.to_upper(),game.state,game.run_time,game.notes_taken.count(true),game.deaths])
	return passed

func run():
	game = load("res://tools/test_game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio_streams.clear()
	game.settings.particles = false
	game.settings.bell_delay = 1; game.settings.glass_time = 1; game.settings.speed = 1
	game.completed = [false,false,false,false,false]
	var failures = 0
	for index in range(5):
		if not replay(index): failures += 1
	for index in range(5):
		var automatic_finish = replay(index,"automatic")
		if index==2 and automatic_finish:
			push_error("Automatic ringing unexpectedly reproduces the Mirror Gallery route")
			failures += 1
	if replay(4,"late"):
		push_error("The final shortcut no longer distinguishes a pre-launch ring from a late ring")
		failures += 1
	else:
		print("PASS: moving the pre-launch ring until after the bounce misses the upper route")
	game.free()
	game = null
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
