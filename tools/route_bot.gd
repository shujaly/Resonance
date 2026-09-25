extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.completed = [false,false,false,false,false]
	for level_index in range(5):
		game.start_level(level_index)
		Input.action_press("move_right")
		var jumps = 0
		var last_jump = -2.0
		var last_x = game.player.x
		var stuck = 0.0
		var last_deaths = 0
		var max_x = game.player.x
		for frame in range(120*60):
			if game.state in ["results","outro","finale"]: break
			var dt = 1.0/60.0
			if game.run_time < fmod(game.deaths * 0.37, 2.6) or game.player.x >= game.level.finish.x-48: Input.action_release("move_right")
			else: Input.action_press("move_right")
			if game.ring_cooldown <= 0.0: game.try_ring()
			var current = null
			for platform in game.platforms:
				if platform.x-2 <= game.player.x and platform.x+platform.w+2 >= game.player.x and abs(game.player.y+42-platform.y) < 5:
					current = platform
					break
			if game.grounded and current != null and game.run_time-last_jump > 0.22:
				var next = null
				for platform in game.platforms:
					if platform.x >= current.x+current.w-3 and platform.x < current.x+current.w+185:
						if next == null or platform.x < next.x: next = platform
				var trigger = current.x+current.w-36
				if game.player.x >= trigger:
					game.jump_buffer = 0.16
					game.jump_held = true
					last_jump = game.run_time
					jumps += 1
			for obstacle in game.level.obstacles:
				if game.grounded and game.run_time-last_jump > 0.24 and obstacle.x-game.player.x > 0 and obstacle.x-game.player.x < 75 and abs(obstacle.y-game.player.y-42) < 100:
					game.jump_buffer = 0.16
					game.jump_held = true
					last_jump = game.run_time
					jumps += 1
			if game.run_time-last_jump > 0.39 and game.jump_held:
				game.jump_held = false
				if game.velocity.y < -220: game.velocity.y = -220
			game.update_game(dt)
			max_x = max(max_x,game.player.x)
			if game.deaths > last_deaths:
				if game.deaths <= 3: print("  fall at x=%.0f t=%.2f" % [last_x,game.run_time])
				last_deaths = game.deaths
				last_jump = -2.0
				last_x = game.player.x
				stuck = 0.0
			if game.player.x > last_x + 15:
				last_x = game.player.x
				stuck = 0.0
			else:
				stuck += dt
			if stuck > 12.0 or game.deaths > 49: break
		if game.state == "outro": game.update_cinematic(9.1)
		print("COURSE %d: state=%s time=%.2f x=%.0f max=%.0f deaths=%d jumps=%d notes=%d" % [level_index+1,game.state,game.run_time,game.player.x,max_x,game.deaths,jumps,game.notes_taken.count(true)])
		Input.action_release("move_right")
	game.queue_free()
	await process_frame
	quit()
