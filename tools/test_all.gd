extends SceneTree

func _initialize():
	call_deferred("run_tests")

func run_tests():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.state == "menu", "menu opens")
	var play_button: Button
	for child in game.ui.get_children():
		if child is Button and child.text == "PLAY": play_button = child
	check(play_button != null, "menu has story play button")
	play_button.pressed.emit()
	check(game.state == "intro" and game.story_mode, "play opens story")
	game.update_cinematic(29.9)
	check(game.state == "intro", "intro lasts about thirty seconds")
	game.update_cinematic(0.2)
	check(game.state == "play" and game.level_index == 0, "intro flows into first course")
	game.show_select()
	check(not game.story_mode, "course select remains a separate replay path")
	check(game.ui.get_child_count() > 10, "course select populated")
	check(game.RESOLUTIONS.has(Vector2i(2560,1440)), "1440p resolution available")
	game.show_settings()
	check(game.state == "settings", "settings opens")
	game.leave_settings()
	var spike = {"kind":"spikes","x":100.0,"y":300.0,"phase":0.0}
	check(game.obstacle_hits_player(spike,Vector2(140,280)), "spike tooth edge registers contact")
	check(not game.obstacle_hits_player(spike,Vector2(144,280)), "spike near miss stays safe")
	var steam = {"kind":"steam","x":100.0,"y":300.0,"phase":0.0}
	game.run_time = 2.5
	check(game.steam_pressure(steam) > 0.5 and not game.obstacle_hits_player(steam,Vector2(100,250)), "steam warning is visible but nonlethal")
	game.run_time = 0.1
	check(game.obstacle_hits_player(steam,Vector2(100,250)), "steam burst covers visible plume")
	var piston = {"kind":"piston","x":100.0,"y":300.0,"phase":0.0}
	game.run_time = 0.0
	check(game.obstacle_hits_player(piston,Vector2(138,300)), "piston tooth edge registers contact")
	check(not game.obstacle_hits_player(piston,Vector2(142,300)), "piston near miss stays safe")
	check(game.circle_overlaps_rect(Vector2(100,100),22.0,game.player_hurtbox(Vector2(134,100))), "pendulum edge registers contact")
	check(not game.circle_overlaps_rect(Vector2(100,100),22.0,game.player_hurtbox(Vector2(136,100))), "pendulum near miss stays safe")
	game.completed = [false,false,false,false,false]
	for i in range(5):
		game.start_level(i)
		await process_frame
		var data = game.level
		check(data.platforms.size() >= 15, "course %d has substantial layout" % i)
		check(data.notes.size() == 3, "course %d has three notes" % i)
		check(data.obstacles.size() >= 3, "course %d has varied obstacles" % i)
		if data.hazards.size() > 0:
			var hazard = data.hazards[0]
			var anchor = Vector2(hazard.x,hazard.y-145)
			game.run_time = 0.0
			var d0 = game.hazard_pos(hazard).distance_to(anchor)
			game.run_time = 0.8
			var d1 = game.hazard_pos(hazard).distance_to(anchor)
			check(abs(d0-145) < 0.1 and abs(d1-145) < 0.1, "course %d pendulum rod stays fixed length" % i)
			game.run_time = 0.0
		check(data.finish.x > 2300, "course %d has finish" % i)
		check(game.ring_cooldown == 0, "course %d starts charged" % i)
		game.try_ring()
		check(game.ring_cooldown > 1.0, "course %d bell cooldown" % i)
		game.try_ring()
		check(game.reject_anim > 0, "course %d early ring shake" % i)
		for tick in range(48): game.update_waves(0.025)
		var active = 0
		for platform in game.platforms:
			if platform.kind == "glass" and platform.until > 0: active += 1
		check(active > 0, "course %d glass responds to wave" % i)
		if data.echoes.size() > 0:
			game.spawn_wave(data.echoes[0] + Vector2(-100,0), true)
			for tick in range(8): game.update_waves(0.025)
			check(game.delayed_waves.size() > 0, "course %d echo schedules repeat" % i)
		var bronze = null
		for platform in game.platforms:
			if platform.kind == "bronze": bronze = platform; break
		if bronze != null:
			game.player = Vector2(bronze.x+bronze.w/2,bronze.y-45)
			game.velocity = Vector2(0,100)
			game.ring_cooldown = 0.9
			game.grounded = false
			game.update_game(0.05)
			check(game.velocity.y < -800 and game.ring_cooldown == 0, "course %d bronze launch and recharge" % i)
		var ground = game.platforms[0]
		game.player = Vector2(ground.x + 90, ground.y - 45)
		game.velocity = Vector2(0,80)
		game.grounded = false
		game.update_game(0.05)
		check(game.grounded, "course %d platform collision" % i)
		check(game.can_land_on(ground,ground.y-4,ground.y+2,ground.x-10), "course %d platform edge landing" % i)
		check(not game.can_land_on(ground,ground.y-4,ground.y+2,ground.x-15), "course %d platform edge near miss" % i)
		check(not game.can_land_on(ground,ground.y+2,ground.y-4,ground.x+50), "course %d rising through platform" % i)
		var course_spike = null
		for obstacle in data.obstacles:
			if obstacle.kind == "spikes": course_spike = obstacle; break
		if course_spike != null:
			game.player = Vector2(course_spike.x,course_spike.y-10)
			game.invulnerable = 0.0
			check(game.update_hazards() and game.player == data.spawn, "course %d actual spike restarts run" % i)
		game.run_time = 7.0
		game.notes_taken[0] = true
		game.player = Vector2(2000,game.level.height+150)
		game.update_game(0.05)
		check(game.player == data.spawn and game.run_time == 0.0 and not game.notes_taken[0], "course %d fall restarts complete attempt" % i)
		check(game.invulnerable <= 0.3, "course %d short spawn protection" % i)
		game.finish_level()
		check(game.state == ("outro" if i == 4 else "results"), "course %d completion" % i)
	game.update_cinematic(8.9)
	check(game.state == "outro", "escape plays before congratulations")
	game.update_cinematic(0.2)
	check(game.state == "finale", "escape ends at congratulations")
	game.start_level(4)
	game.finish_level()
	check(game.state == "results", "repeat run shows results rather than replaying finale")
	game.show_menu()
	game.begin_intro()
	game.skip_cinematic()
	check(game.state == "play" and game.story_mode, "opening can be skipped")
	game.start_level(4)
	game.finish_level()
	check(game.state == "outro", "story escape replays after prior completion")
	game.skip_cinematic()
	check(game.state == "finale", "escape can be skipped")
	game.show_menu()
	print("ALL FIVE COURSES PASSED")
	game.queue_free()
	await process_frame
	quit()

func check(condition, message):
	if condition:
		print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		quit(1)
