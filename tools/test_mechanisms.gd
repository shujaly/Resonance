extends SceneTree

var failures = 0

func _initialize():
	call_deferred("run")

func check(ok, message):
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func advance(game, seconds):
	for i in range(int(round(seconds * 60.0))):
		game.run_time += 1.0/60.0
		game.update_mechanisms(1.0/60.0)
		game.update_waves(1.0/60.0)

func push_swing(game, dir):
	var target = game.mechanism_targets()[0]
	game.strike_mechanism(target, {"origin": target.rect.get_center() - Vector2(100.0 * dir, 0.0), "facing": dir})

func swing_peak(game, seconds):
	var peak = 0.0
	for i in range(int(round(seconds * 60.0))):
		game.update_mechanisms(1.0/60.0)
		peak = max(peak, abs(game.swings[0].angle))
	return peak

func wait_for_bottom(game, moving_right):
	for i in range(600):
		var before = game.swings[0].angle
		game.update_mechanisms(1.0/60.0)
		var after = game.swings[0].angle
		if moving_right and before < 0.0 and after >= 0.0: return
		if not moving_right and before > 0.0 and after <= 0.0: return

func lit(platform, game):
	return platform.until > game.run_time

func run():
	var game = load("res://tools/test_game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio_streams.clear()
	game.settings.particles = false
	game.settings.bell_delay = 1; game.settings.glass_time = 1; game.settings.speed = 1

	game.start_level(1)
	var swing = game.level.swings[0]
	game.swings[0].angle = 0.05
	var crossings = []
	var time = 0.0
	for i in range(1200):
		var before = game.swings[0].angle
		game.update_mechanisms(1.0/60.0)
		time += 1.0/60.0
		if before < 0.0 and game.swings[0].angle >= 0.0: crossings.append(time)
	var measured = (crossings[-1] - crossings[0]) / float(crossings.size() - 1)
	var expected = TAU * sqrt(swing.length / game.GRAVITY)
	check(abs(measured - expected) / expected < 0.02, "swing period follows T = 2π√(L/g) (%.2f s vs %.2f s)" % [measured, expected])

	var exit_ledge = game.platforms.filter(func(p): return p.x > swing.x and p.kind == "stone")[0]
	game.start_level(1)
	push_swing(game, 1.0)
	var one_push = swing_peak(game, 1.2)
	var one_push_top = swing.y + swing.length * cos(one_push)
	check(one_push_top - exit_ledge.y > 179.0, "one push leaves the far ledge out of reach")
	wait_for_bottom(game, true)
	push_swing(game, 1.0)
	var two_pushes = swing_peak(game, 1.2)
	check(swing.y + swing.length * cos(two_pushes) - exit_ledge.y < 165.0, "a second push in time with the swing reaches the far ledge")
	wait_for_bottom(game, true)
	push_swing(game, 1.0)
	var three_pushes = swing_peak(game, 1.2)
	check(three_pushes > two_pushes, "rings in phase keep adding energy (%.2f → %.2f rad)" % [two_pushes, three_pushes])
	wait_for_bottom(game, false)
	push_swing(game, 1.0)
	var against = swing_peak(game, 1.2)
	check(against < three_pushes - 0.2, "a ring against the motion damps the swing (%.2f → %.2f rad)" % [three_pushes, against])

	game.start_level(1)
	game.swings[0].angle = 0.5
	var seat = game.deck("swing", 0)
	game.player = Vector2(seat.x + seat.w/2, seat.y - game.BODY.y)
	game.velocity = Vector2.ZERO
	game.grounded = true
	game.riding = seat
	for i in range(20): game.update_game(1.0/60.0)
	seat = game.deck("swing", 0)
	check(game.grounded and abs(game.player.x - (seat.x + seat.w/2)) < 1.0 and abs(game.player.y + game.BODY.y - seat.y) < 1.0, "a rider is carried by the swinging seat")
	game.respawn()
	check(game.swings[0].angle == 0.0 and game.swings[0].omega == 0.0 and game.riding == null, "retry stops the swing")

	game.start_level(2)
	var mirror = game.level.mirrors[0]
	var silver = game.platforms.filter(func(p): return p.has("silver"))
	check(silver.size() >= 2, "mirror gallery has silvered ledges")
	game.spawn_wave(Vector2(mirror.x - mirror.face * 20.0, silver[0].y + 20.0), true)
	advance(game, 1.0)
	check(silver.all(func(p): return not lit(p, game)), "silvered glass ignores a ring from behind the mirror")
	game.respawn()
	game.spawn_wave(Vector2(2060, 503), true)
	advance(game, 0.6)
	check(silver.all(func(p): return lit(p, game)), "a ring on the mirror side lights the silvered ledges by reflection")
	var ray = game.reflections[0]
	var incoming = ray.hit - ray.from
	var outgoing = ray.to - ray.hit
	check(sign(incoming.x) == -sign(outgoing.x) and abs(abs(incoming.y / incoming.x) - abs(outgoing.y / outgoing.x)) < 0.001, "angle of incidence equals angle of reflection")
	var plain = game.platforms.filter(func(p): return p.kind == "glass" and not p.has("silver") and not p.has("relay"))
	game.respawn()
	game.spawn_wave(Vector2(plain[0].x - 80.0, plain[0].y), true)
	advance(game, 0.4)
	check(lit(plain[0], game), "ordinary glass still answers the handbell directly")
	game.respawn()
	game.platforms.append(game.Levels.p(mirror.x - 200.0, 600.0, 400.0))
	game.player = Vector2(mirror.x - 100.0 * mirror.face, 558.0)
	game.grounded = true
	game.invulnerable = 10.0
	Input.action_press("move_right" if mirror.face < 0 else "move_left", 1.0)
	for i in range(90): game.update_game(1.0/60.0)
	Input.action_release("move_right"); Input.action_release("move_left")
	check(abs(game.player.x - mirror.x) >= 19.0 and sign(game.player.x - mirror.x) == mirror.face, "the mirror is a solid wall")

	game.start_level(3)
	var lift = game.level.lifts[0]
	var exit_top = game.platforms.filter(func(p): return p.x > lift.x + lift.w and p.kind == "stone")[0]
	advance(game, 1.0)
	check(game.lifts[0].offset == 0.0, "a silent lift stays down")
	var gear = Vector2(lift.x + lift.w/2, lift.y + 18.0)
	game.spawn_wave(gear - Vector2(60, 0), true)
	advance(game, game.LIFT_HUM + 0.1)
	var after_ring = game.lifts[0].offset
	check(abs(after_ring - game.LIFT_SPEED * game.LIFT_HUM) < 12.0, "a lift climbs only while the ring is sounding (%.0f px)" % after_ring)
	check(lift.y - after_ring - exit_top.y > 179.0, "one ring cannot lift the player to the exit")
	advance(game, 1.0)
	check(game.lifts[0].offset < after_ring - 40.0, "a silent lift sinks back")
	game.spawn_wave(gear - Vector2(60, 0), true)
	advance(game, 0.3)
	game.spawn_wave(gear - Vector2(60, 0), true)
	advance(game, game.LIFT_HUM + 0.1)
	check(lift.y - game.lifts[0].offset - exit_top.y < 165.0, "ringing again while it climbs reaches the exit")
	game.respawn()
	check(game.lifts[0].offset == 0.0, "retry lowers the lift")

	game.start_level(4)
	var amber = game.platforms.filter(func(p): return p.has("amber"))
	check(amber.size() >= 3 and game.level.bells.size() >= 2, "belfry has amber ledges and great bells")
	game.spawn_wave(Vector2(amber[0].x + amber[0].w/2, amber[0].y - 30.0), true)
	advance(game, 0.5)
	check(amber.all(func(p): return not lit(p, game)), "amber glass ignores the handbell")
	game.respawn()
	var bell = game.level.bells[0]
	game.spawn_wave(bell - Vector2(0, 0), false, 0)
	advance(game, 1.5)
	check(game.great_bells[0].rung < 0.0, "a violet echo pulse does not ring a great bell")
	game.respawn()
	game.spawn_wave(bell - Vector2(150, 0), true)
	advance(game, 0.3)
	check(game.great_bells[0].toll_at > game.run_time, "a great bell winds up before it tolls")
	check(amber.all(func(p): return not lit(p, game)), "nothing lights before the toll")
	advance(game, game.TOLL_DELAY + game.TOLL_REACH / game.WAVE_SPEED)
	var near = amber.filter(func(p): return Vector2(p.x + p.w/2, p.y).distance_to(bell) <= game.TOLL_REACH)
	var far = amber.filter(func(p): return Vector2(p.x + p.w/2, p.y).distance_to(bell) > game.TOLL_REACH)
	check(near.size() > 0 and near.all(func(p): return lit(p, game)), "the toll lights amber glass within reach")
	check(far.size() > 0 and far.all(func(p): return not lit(p, game)), "amber glass beyond the first bell stays dark")
	game.spawn_wave(bell - Vector2(150, 0), true)
	advance(game, 0.4)
	check(game.great_bells[0].toll_at < 0.0, "a resting bell ignores another ring")
	advance(game, 1.6)
	check(game.great_bells[1].rung > 0.0 and far.all(func(p): return lit(p, game)), "the first toll rings the next bell, which lights the far ledges")

	check(game.record_section(0) == "routes_2_0" and game.record_section(1) == "routes_3_1", "changed courses keep separate records")
	game.free()
	game = null
	await process_frame
	await process_frame
	print("MECHANISM CHECKS PASSED" if failures == 0 else "%d MECHANISM CHECKS FAILED" % failures)
	quit(0 if failures == 0 else 1)
