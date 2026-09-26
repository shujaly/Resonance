extends SceneTree

var failures = 0

func _initialize():
	call_deferred("run")

func check(ok, message):
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error(message)

func advance(game, seconds, dt=1.0/60.0):
	for frame in range(int(ceil(seconds/dt))):
		game.run_time += dt
		game.update_waves(dt)

func run():
	var game = load("res://tools/test_game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.settings.particles = false
	game.settings.glass_time = 1
	game.settings.bell_delay = 1
	game.audio_streams.clear()
	for dt in [1.0/30.0,1.0/60.0,1.0/120.0]:
		game.start_level(0)
		game.level.echoes = []
		game.platforms = [game.Levels.p(150,500,100,"glass"),game.Levels.p(500,500,100,"glass")]
		game.spawn_wave(Vector2(0,500),true)
		advance(game,0.8,dt)
		check(game.platforms[0].until>game.run_time and game.platforms[1].until==0,"bounded wave at %d Hz" % round(1.0/dt))
		var expiry = game.platforms[0].until
		game.spawn_wave(Vector2(200,500),true)
		advance(game,0.5,dt)
		check(is_equal_approx(game.platforms[0].until,expiry),"repeated ring does not prolong a lit ledge")
		game.run_time = expiry+0.01
		game.spawn_wave(Vector2(200,500),true)
		advance(game,0.1,dt)
		check(game.platforms[0].until>game.run_time,"faded glass can be lit again")
	for index in range(5):
		game.start_level(index)
		for ledge in game.platforms:
			if not ledge.has("relay"): continue
			var fixture = game.level.echoes[ledge.relay]
			check(fixture.distance_to(Vector2(ledge.x+ledge.w/2,ledge.y))<=game.ECHO_REACH,"course %d connected shortcut within echo reach" % (index+1))
		var branch = game.platforms.filter(func(p): return p.has("relay"))[0]
		game.spawn_wave(Vector2(branch.x+branch.w/2,branch.y),true)
		advance(game,0.42)
		check(branch.until==0,"course %d direct bell cannot bypass echo timing" % (index+1))
		advance(game,1.0)
		check(branch.until>game.run_time,"course %d delayed echo opens upper route" % (index+1))
		game.respawn()
		check(game.delayed_waves.is_empty() and game.relay_ready.all(func(t): return t==0),"retry clears pending echo and fixture lock")
		game.spawn_wave(game.level.echoes[0],true)
		game.spawn_wave(game.level.echoes[0],true)
		advance(game,0.05)
		check(game.delayed_waves.size()==1,"fixture coalesces repeated pulses")
		game.player = Vector2(100,400)
		game.velocity = Vector2(220,-430)
		game.grounded = false
		game.update_character_motion(0.1)
		var rising = game.character_pose()
		game.velocity.y = 600
		game.update_character_motion(0.1)
		var falling = game.character_pose()
		check(rising.rise>0 and falling.fall>0 and rising.scarf!=falling.scarf,"rising and falling have separate poses")
		game.respawn()
		check(game.stride==0 and game.takeoff_anim==0 and game.land_anim==0,"retry resets animation state")
	game.start_level(0)
	game.try_ring()
	var remaining = game.ring_cooldown
	var count = game.waves.size()
	game.try_ring()
	check(game.reject_anim>0 and game.waves.size()==count and game.ring_cooldown==remaining,"premature press shakes head without extra pulse or extra penalty")
	var old_player = game.player
	var old_hurtbox = game.player_hurtbox(game.player)
	for i in range(60): game.update_character_motion(1.0/60.0)
	check(game.player==old_player and game.player_hurtbox(game.player)==old_hurtbox,"cosmetic animation cannot move hitboxes")
	game.free()
	game = null
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
