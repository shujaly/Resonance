extends SceneTree

var failures = 0

func _initialize():
	call_deferred("run")

func check(ok, message):
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func replay(game, index, trace):
	game.start_level(index)
	var inputs = JSON.parse_string(FileAccess.get_file_as_string("res://tools/route_%d.json" % index))
	trace.append([game.run_time, game.player, game.stride])
	for frame in range(inputs.size()):
		var input = inputs[frame]
		Input.action_release("move_left"); Input.action_release("move_right")
		var axis = float(input[0])
		if axis > 0: Input.action_press("move_right", axis)
		if axis < 0: Input.action_press("move_left", -axis)
		if input[1]: game.jump_buffer = 0.16
		if game.jump_held and not input[2] and game.velocity.y < -220: game.velocity.y = -220
		game.jump_held = input[2]
		if input[3] and game.ring_cooldown <= 0: game.try_ring()
		game.update_game(1.0/60.0)
		if game.state != "play": break
		trace.append([game.run_time, game.player, game.stride])
	Input.action_release("move_left"); Input.action_release("move_right")

func sweep(game, duration):
	var largest_step = 0.0
	var backwards_stride = 0
	var previous = game.ghost_state(0.0)
	var time = 0.0
	while time + 1.0/240.0 < duration:
		time += 1.0/240.0
		var current = game.ghost_state(time)
		if current == null or previous == null: break
		largest_step = max(largest_step, current.pos.distance_to(previous.pos))
		if current.stride < previous.stride - 0.0001: backwards_stride += 1
		previous = current
	return [largest_step, backwards_stride]

func run():
	var game = load("res://tools/test_game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio_streams.clear()
	game.settings.particles = false
	game.settings.bell_delay = 1; game.settings.glass_time = 1; game.settings.speed = 1
	for index in range(5):
		game.records.erase(str(index))
		var trace = []
		replay(game, index, trace)
		var rec = game.get_record(index)
		check(rec.ghost is PackedFloat32Array and rec.ghost.size() % game.GHOST_FIELDS == 0 and rec.ghost.size() > 0, "course %d stores a full-motion ghost" % (index+1))
		game.start_level(index)
		var worst = 0.0
		var stride_error = 0.0
		for sample in trace:
			var ghost = game.ghost_state(sample[0])
			if ghost == null: continue
			worst = max(worst, ghost.pos.distance_to(sample[1]))
			stride_error = max(stride_error, abs(ghost.stride - sample[2]))
		check(worst < 0.01, "course %d ghost matches the recorded run exactly (%.3f px)" % [index+1, worst])
		check(stride_error < 0.001, "course %d ghost stride matches the player's stride" % (index+1))
		var motion = sweep(game, rec.best)
		check(motion[0] < 5.0, "course %d ghost moves without jumps at 240 Hz (largest step %.2f px)" % [index+1, motion[0]])
		check(motion[1] == 0, "course %d ghost legs never run backwards" % (index+1))
		var saved = ConfigFile.new()
		saved.set_value("routes_2_%d" % index, "ghost", rec.ghost)
		var loaded = ConfigFile.new()
		check(loaded.parse(saved.encode_to_text()) == OK and loaded.get_value("routes_2_%d" % index, "ghost") == rec.ghost, "course %d ghost survives a save and load" % (index+1))
		var legacy = []
		for i in range(trace.size()):
			if i > 0 and i % 4 == 0: legacy.append(trace[i][1])
		rec.ghost = legacy
		game.start_level(index)
		check(game.ghost_step == game.LEGACY_GHOST_STEP, "course %d older position-only ghosts still load" % (index+1))
		var legacy_motion = sweep(game, legacy.size() * game.LEGACY_GHOST_STEP)
		check(legacy_motion[0] < 5.0 and legacy_motion[1] == 0, "course %d older ghosts also play smoothly (largest step %.2f px)" % [index+1, legacy_motion[0]])
	game.start_level(0)
	for i in range(30): game.update_game(1.0/60.0)
	game.respawn()
	check(game.ghost_samples.size() == game.GHOST_FIELDS and is_equal_approx(game.ghost_samples[0], game.level.spawn.x), "retry restarts the recording at spawn")
	game.settings.speed = 0
	game.records.erase("0")
	game.start_level(0)
	for i in range(30): game.update_game(1.0/60.0)
	game.finish_level()
	check(game.get_record(0).ghost.is_empty(), "custom movement runs do not replace the ghost")
	game.free()
	game = null
	await process_frame
	await process_frame
	print("GHOST CHECKS PASSED" if failures == 0 else "%d GHOST CHECKS FAILED" % failures)
	quit(0 if failures == 0 else 1)
