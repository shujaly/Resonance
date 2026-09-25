extends Node2D

const Levels = preload("res://levels.gd")
const UI_FONT = preload("res://art/Alegreya.ttf")
const VIEW = Vector2(1280, 720)
const BODY = Vector2(30, 42)
const FOOT_HALF_WIDTH = 14.0
const SAVE_PATH = "user://one_more_bell_resonance.cfg"
const ACTIONS = ["move_left", "move_right", "jump", "ring"]
const ACTION_NAMES = ["Move left", "Move right", "Jump", "Ring bell"]
const DEFAULT_KEYS = [KEY_A, KEY_D, KEY_SPACE, KEY_J]
const NAMES = ["Bellkeeper", "Clockwork", "Moth", "Lantern"]
const RESOLUTIONS = [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]

var state = "menu"
var previous_state = "menu"
var level_index = 0
var level = {}
var platforms = []
var notes_taken = []
var player = Vector2.ZERO
var velocity = Vector2.ZERO
var facing = 1.0
var grounded = false
var coyote = 0.0
var jump_buffer = 0.0
var jump_held = false
var ring_cooldown = 0.0
var reject_anim = 0.0
var ring_anim = 0.0
var land_anim = 0.0
var invulnerable = 0.0
var world_time = 0.0
var run_time = 0.0
var camera = Vector2.ZERO
var waves = []
var delayed_waves = []
var particles = []
var split_index = 0
var section_times = []
var flash = 0.0
var shake = 0.0
var deaths = 0
var result_medal = ""
var result_comparison = []
var ghost_samples = []
var ghost_tick = 0.0
var records = {}
var completed = [false, false, false, false, false]
var config = ConfigFile.new()
var settings = {"master": 0.8, "music": 0.65, "effects": 0.85, "ambience": 0.48, "ghost": true, "flash": true, "shake": 0.55, "particles": true, "contrast": false, "parallax": true, "character": 0, "display": 0, "resolution": 0, "vsync": true, "bell_delay": 1, "glass_time": 1, "speed": 1}
var keys = DEFAULT_KEYS.duplicate()
var capturing = -1
var ui: Control
var music_base: AudioStreamPlayer
var music_high: AudioStreamPlayer
var ambience: AudioStreamPlayer
var audio_streams = {}
var art = []
var rng = RandomNumberGenerator.new()
var selected_level = 0
var settings_page = 0
var story_mode = false
var cinematic_time = 0.0

func _ready():
	rng.randomize()
	load_save()
	install_controls()
	for path in ["res://art/arcade.png", "res://art/pendulum.png", "res://art/mirror.png", "res://art/shaft.png", "res://art/belfry.png", "res://art/escape.png"]:
		art.append(load(path))
	for name in ["music_base", "music_high", "rain", "ring", "jump", "land", "collect", "fail", "start", "finish", "reject", "bronze", "echo", "glass", "stone", "menu"]:
		var path = "res://audio/%s.wav" % name
		if ResourceLoader.exists(path): audio_streams[name] = load(path)
	music_base = make_loop("music_base")
	music_high = make_loop("music_high")
	ambience = make_loop("rain")
	music_base.play()
	music_high.play()
	ambience.play()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 19
	ui.theme = theme
	add_child(ui)
	apply_settings()
	show_menu()

func load_save():
	if config.load(SAVE_PATH) != OK: return
	for key in settings.keys():
		settings[key] = config.get_value("settings", key, settings[key])
	for i in range(4): keys[i] = int(config.get_value("controls", ACTIONS[i], keys[i]))
	for i in range(5):
		records[str(i)] = {"best": float(config.get_value("level_%d" % i, "best", 0.0)), "all_notes": float(config.get_value("level_%d" % i, "all_notes", 0.0)), "ghost": config.get_value("level_%d" % i, "ghost", []), "splits": config.get_value("level_%d" % i, "splits", [])}
		completed[i] = bool(config.get_value("level_%d" % i, "completed", records[str(i)].best > 0.0))

func save_data():
	for key in settings.keys(): config.set_value("settings", key, settings[key])
	for i in range(4): config.set_value("controls", ACTIONS[i], keys[i])
	for i in range(5):
		var rec = get_record(i)
		config.set_value("level_%d" % i, "best", rec.best)
		config.set_value("level_%d" % i, "all_notes", rec.all_notes)
		config.set_value("level_%d" % i, "ghost", rec.ghost)
		config.set_value("level_%d" % i, "splits", rec.splits)
		config.set_value("level_%d" % i, "completed", completed[i])
	config.save(SAVE_PATH)

func get_record(i):
	if not records.has(str(i)): records[str(i)] = {"best": 0.0, "all_notes": 0.0, "ghost": [], "splits": []}
	return records[str(i)]

func install_controls():
	for i in range(4):
		if not InputMap.has_action(ACTIONS[i]): InputMap.add_action(ACTIONS[i])
		InputMap.action_erase_events(ACTIONS[i])
		var key = InputEventKey.new()
		key.physical_keycode = keys[i]
		InputMap.action_add_event(ACTIONS[i], key)
	var arrows = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_SHIFT]
	for i in range(4):
		var key = InputEventKey.new()
		key.physical_keycode = arrows[i]
		InputMap.action_add_event(ACTIONS[i], key)
	for action in ["jump", "ring"]:
		var button = InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_A if action == "jump" else JOY_BUTTON_X
		InputMap.action_add_event(action, button)
	var left = InputEventJoypadMotion.new(); left.axis = JOY_AXIS_LEFT_X; left.axis_value = -1.0
	var right = InputEventJoypadMotion.new(); right.axis = JOY_AXIS_LEFT_X; right.axis_value = 1.0
	InputMap.action_add_event("move_left", left)
	InputMap.action_add_event("move_right", right)

func make_loop(name):
	var player_node = AudioStreamPlayer.new()
	player_node.stream = audio_streams[name]
	player_node.finished.connect(func(): player_node.play())
	add_child(player_node)
	return player_node

func play_sfx(name, pitch=1.0, volume=1.0):
	if not audio_streams.has(name): return
	var a = AudioStreamPlayer.new()
	a.stream = audio_streams[name]
	a.pitch_scale = pitch
	a.volume_db = linear_to_db(max(0.001, float(settings.effects) * volume))
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()

func apply_settings():
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, float(settings.master))))
	if music_base:
		music_base.volume_db = linear_to_db(max(0.001, float(settings.music) * (0.55 if state in ["intro","outro"] else 0.9)))
		music_high.volume_db = linear_to_db(max(0.001, float(settings.music) * (0.08 if state in ["menu","intro","outro"] else 0.75)))
		ambience.volume_db = linear_to_db(max(0.001, float(settings.ambience) * 0.65))
	if DisplayServer.get_name() != "headless":
		var size = RESOLUTIONS[clampi(int(settings.resolution), 0, RESOLUTIONS.size()-1)]
		if int(settings.display) == 0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(size)
		elif int(settings.display) == 1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	queue_redraw()

func start_level(i):
	level_index = i
	level = Levels.make(i)
	platforms = level.platforms.duplicate(true)
	notes_taken = [false, false, false]
	waves.clear(); delayed_waves.clear(); particles.clear()
	run_time = 0.0; world_time = 0.0; ghost_tick = 0.0
	velocity = Vector2.ZERO; ring_cooldown = 0.0; reject_anim = 0.0; ring_anim = 0.0; invulnerable = 0.0
	grounded = false; coyote = 0.0; jump_buffer = 0.0; jump_held = false
	split_index = 0; section_times = []
	deaths = 0; ghost_samples.clear()
	result_comparison.clear()
	player = level.spawn
	camera = camera_target()
	state = "play"
	clear_ui()
	apply_settings()
	play_sfx("start")
	queue_redraw()

func camera_target():
	return Vector2(clamp(player.x - 480, 0.0, max(0.0, level.length - VIEW.x)), clamp(player.y - 405, 0.0, max(0.0, level.height - VIEW.y)))

func gameplay_modified():
	return int(settings.bell_delay) != 1 or int(settings.glass_time) != 1 or int(settings.speed) != 1

func bell_delay():
	return [0.9, 1.3, 1.7][int(settings.bell_delay)]

func glass_duration():
	return [5.0, 3.6, 2.7][int(settings.glass_time)]

func speed_mult():
	return [0.85, 1.0, 1.15][int(settings.speed)]

func begin_intro():
	story_mode = true
	state = "intro"
	cinematic_time = 0.0
	velocity = Vector2(90,0)
	grounded = true
	facing = 1.0
	clear_ui()
	apply_settings()
	make_button(ui,"SKIP  →",Vector2(1087,663),Vector2(150,40),func(): skip_cinematic(),Color("87775e"))

func begin_outro():
	state = "outro"
	cinematic_time = 0.0
	velocity = Vector2(110,0)
	grounded = true
	facing = 1.0
	ring_anim = 0.0
	clear_ui()
	apply_settings()
	make_button(ui,"SKIP  →",Vector2(1087,663),Vector2(150,40),func(): skip_cinematic(),Color("87775e"))

func skip_cinematic():
	if state == "intro": start_level(0)
	elif state == "outro": show_finale()

func update_cinematic(delta):
	var next_time = cinematic_time + delta
	if state == "intro":
		if cinematic_time < 9.0 and next_time >= 9.0: play_sfx("menu",0.72,0.35)
		if cinematic_time < 14.0 and next_time >= 14.0: play_sfx("echo",1.15,0.5)
		if cinematic_time < 20.5 and next_time >= 20.5: play_sfx("stone",0.65,0.65)
		if cinematic_time < 25.5 and next_time >= 25.5: play_sfx("ring",0.92,0.55)
		cinematic_time = next_time
		if cinematic_time >= 30.0: start_level(0)
	elif state == "outro":
		if cinematic_time < 3.0 and next_time >= 3.0: play_sfx("ring",0.9,0.8)
		if cinematic_time < 5.0 and next_time >= 5.0: play_sfx("finish",1.15,0.65)
		cinematic_time = next_time
		if cinematic_time >= 9.0: show_finale()

func _input(event):
	if capturing >= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				capturing = -1; show_settings()
			else:
				keys[capturing] = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				capturing = -1
				install_controls(); save_data(); show_settings()
		get_viewport().set_input_as_handled()
		return
	if state in ["intro","outro"]:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
			skip_cinematic()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if state == "play": pause_game()
		elif state == "pause": resume_game()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if state == "play": pause_game()
		elif state == "pause": resume_game()
		elif state == "settings": show_menu() if previous_state == "menu" else show_pause()
		elif state == "select" or state == "help" or state == "results" or state == "finale": show_menu()
		get_viewport().set_input_as_handled()
		return
	if state != "play": return
	if event.is_action_pressed("jump") and not event.is_echo():
		jump_buffer = 0.16
		jump_held = true
	elif event.is_action_released("jump"):
		jump_held = false
		if velocity.y < -220: velocity.y = -220
	if event.is_action_pressed("ring") and not event.is_echo():
		try_ring()

func try_ring():
	if ring_cooldown > 0.0:
		if reject_anim <= 0.05: play_sfx("reject", 0.98, 0.55)
		reject_anim = 0.48
		spawn_particles(player + Vector2(16,-24), Color("d4a58a"), 4)
		return
	ring_cooldown = bell_delay()
	ring_anim = 0.37
	spawn_wave(player + Vector2(0,-22), true)
	play_sfx("ring", rng.randf_range(0.98,1.025), 0.83)
	spawn_particles(player + Vector2(0,-20), level.theme, 10)
	shake = max(shake, 2.3)

func spawn_wave(origin, can_echo):
	waves.append({"origin": origin, "radius": 0.0, "age": 0.0, "echo": can_echo, "hit_platforms": [], "hit_echoes": []})

func _physics_process(delta):
	world_time += delta
	if state == "play": update_game(delta)
	elif state in ["intro","outro"]: update_cinematic(delta)
	if flash > 0: flash = max(0.0, flash - delta * 2.6)
	if shake > 0: shake = max(0.0, shake - delta * 13)
	if state != "play":
		update_particles(delta)
	queue_redraw()

func update_game(delta):
	run_time += delta
	var was_charging = ring_cooldown > 0.0
	ring_cooldown = max(0.0, ring_cooldown - delta)
	if was_charging and ring_cooldown <= 0.0:
		play_sfx("glass", 1.35, 0.35)
		spawn_particles(player + Vector2(facing*19,24), Color("9dfff1"), 5)
	reject_anim = max(0.0, reject_anim - delta)
	ring_anim = max(0.0, ring_anim - delta)
	land_anim = max(0.0, land_anim - delta)
	invulnerable = max(0.0, invulnerable - delta)
	jump_buffer = max(0.0, jump_buffer - delta)
	coyote = max(0.0, coyote - delta)
	var axis = Input.get_axis("move_left", "move_right")
	if abs(axis) > 0.08: facing = sign(axis)
	var target_speed = axis * 290.0 * speed_mult()
	velocity.x = move_toward(velocity.x, target_speed, (2500.0 if grounded else 1600.0) * delta)
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -685.0
		grounded = false; coyote = 0.0; jump_buffer = 0.0
		play_sfx("jump", rng.randf_range(0.96,1.04), 0.78)
		spawn_particles(player + Vector2(0,0), Color("9fd7df"), 6)
	var gravity = 1650.0
	if velocity.y < 0 and jump_held: gravity *= 0.77
	if abs(velocity.y) < 90: gravity *= 0.84
	velocity.y = min(900.0, velocity.y + gravity * delta)
	var was_grounded = grounded
	var old_bottom = player.y + BODY.y
	player.x = clamp(player.x + velocity.x * delta, 15.0, level.length - 15.0)
	player.y += velocity.y * delta
	grounded = false
	var landed = null
	if velocity.y >= 0:
		for platform in platforms:
			if platform.kind == "glass" and platform.until <= run_time: continue
			if can_land_on(platform, old_bottom, player.y + BODY.y, player.x):
				if landed == null or platform.y < landed.y: landed = platform
	if landed != null:
		player.y = landed.y - BODY.y
		velocity.y = 0
		grounded = true; coyote = 0.115
		if not was_grounded:
			land_anim = 0.22
			spawn_particles(player + Vector2(0,BODY.y), Color("c5d3d2") if landed.kind == "stone" else level.theme, 8)
			play_sfx("glass" if landed.kind == "glass" else "stone" if landed.kind == "stone" else "bronze", rng.randf_range(0.95,1.06), 0.72)
			shake = max(shake, 1.3)
		if landed.kind == "bronze" and not was_grounded:
			velocity.y = -890.0
			grounded = false; coyote = 0.0
			ring_cooldown = 0.0
			spawn_particles(player + Vector2(0,BODY.y), Color("ffcf7f"), 18)
	if was_grounded and not grounded and velocity.y >= 0: coyote = 0.115
	if player.y > level.height + 100:
		respawn()
		return
	for i in range(3):
		if not notes_taken[i] and player.distance_to(level.notes[i]) < 35:
			notes_taken[i] = true
			play_sfx("collect", 1.0 + i*0.12, 0.78)
			spawn_particles(level.notes[i], Color("ffe8a8"), 18)
	for i in range(split_index, 2):
		if player.x >= level.splits[i]:
			split_index = i + 1
			section_times.append(run_time - (section_times.reduce(func(a,b): return a+b, 0.0) if section_times.size() > 0 else 0.0))
			break
	update_waves(delta)
	if update_hazards(): return
	update_particles(delta)
	if player.distance_to(level.finish) < 58: finish_level()
	camera = camera.lerp(camera_target(), min(1.0, delta * 5.0))
	ghost_tick += delta
	if ghost_tick >= 0.06:
		ghost_tick -= 0.06
		ghost_samples.append(player)
	if ghost_samples.size() > 8000: ghost_samples.pop_front()
	if music_high:
		var fraction = clamp(player.x / level.length, 0.0, 1.0)
		music_high.volume_db = linear_to_db(max(0.001, float(settings.music) * (0.18 + 0.65 * fraction)))

func update_waves(delta):
	for delayed in delayed_waves:
		delayed.delay -= delta
	for delayed in delayed_waves.duplicate():
		if delayed.delay <= 0:
			spawn_wave(delayed.origin, false)
			play_sfx("echo", 1.08, 0.8)
			delayed_waves.erase(delayed)
	for wave in waves.duplicate():
		wave.age += delta
		wave.radius = wave.age * 1040.0
		for i in range(platforms.size()):
			var platform = platforms[i]
			if platform.kind != "glass" or i in wave.hit_platforms: continue
			var center = Vector2(platform.x + platform.w/2, platform.y)
			if abs(center.distance_to(wave.origin) - wave.radius) < max(45.0, 1040.0*delta):
				platform.until = max(platform.until, run_time + glass_duration())
				wave.hit_platforms.append(i)
				play_sfx("glass", 1.12 + float(i%5)*0.11, 0.30)
		if wave.echo:
			for i in range(level.echoes.size()):
				if i in wave.hit_echoes: continue
				if abs(level.echoes[i].distance_to(wave.origin) - wave.radius) < max(40.0, 1040.0*delta):
					wave.hit_echoes.append(i)
					delayed_waves.append({"origin": level.echoes[i], "delay": 0.48})
					spawn_particles(level.echoes[i], Color("c79bff"), 12)
		if wave.age > 1.2: waves.erase(wave)

func hazard_pos(hazard):
	var angle = sin(run_time * 1.85 + hazard.phase) * atan(hazard.span / 145.0)
	return Vector2(hazard.x, hazard.y - 145.0) + Vector2(sin(angle), cos(angle)) * 145.0

func can_land_on(platform, previous_bottom, new_bottom, at_x):
	return previous_bottom <= platform.y + 8.0 and new_bottom >= platform.y and at_x + FOOT_HALF_WIDTH > platform.x and at_x - FOOT_HALF_WIDTH < platform.x + platform.w

func player_hurtbox(at):
	return Rect2(at.x - 13.0, at.y - 7.0, 26.0, 50.0)

func circle_overlaps_rect(center, radius, rect):
	var nearest = Vector2(clamp(center.x,rect.position.x,rect.end.x),clamp(center.y,rect.position.y,rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func obstacle_active(obstacle):
	return fposmod(run_time + obstacle.phase, 2.8) < 0.72

func steam_pressure(obstacle):
	return clamp((fposmod(run_time+obstacle.phase,2.8)-1.95)/0.85,0.0,1.0)

func piston_pos(obstacle):
	var phase = fposmod(run_time + obstacle.phase, 3.2) / 3.2
	var plunge = pow(max(0.0, sin(phase * TAU)), 4.0)
	return Vector2(obstacle.x, obstacle.y + plunge * 85.0)

func obstacle_hits_player(obstacle, at):
	var hurtbox = player_hurtbox(at)
	match obstacle.kind:
		"steam":
			return obstacle_active(obstacle) and hurtbox.intersects(Rect2(obstacle.x-23.0,obstacle.y-85.0,46.0,87.0))
		"piston":
			var head = piston_pos(obstacle)
			return hurtbox.intersects(Rect2(head.x-27.0,head.y-15.0,54.0,40.0))
		"spikes":
			return hurtbox.intersects(Rect2(obstacle.x-25.0,obstacle.y-25.0,54.0,30.0))
	return false

func update_hazards():
	if invulnerable > 0: return false
	var hurtbox = player_hurtbox(player)
	for hazard in level.hazards:
		if circle_overlaps_rect(hazard_pos(hazard),22.0,hurtbox):
			respawn()
			return true
	for obstacle in level.obstacles:
		if obstacle_hits_player(obstacle,player):
			respawn()
			return true
	return false

func respawn():
	deaths += 1
	player = level.spawn
	run_time = 0.0
	split_index = 0
	section_times.clear()
	notes_taken = [false, false, false]
	ghost_samples.clear()
	velocity = Vector2.ZERO
	grounded = false; coyote = 0.0; jump_buffer = 0.0
	ring_cooldown = 0.0; ring_anim = 0.0; reject_anim = 0.0
	invulnerable = 0.28
	flash = 0.10 if settings.flash else 0.0
	shake = 2.0
	play_sfx("fail", 1.0, 0.78)
	for platform in platforms:
		if platform.kind == "glass": platform.until = 0.0
	waves.clear(); delayed_waves.clear()
	camera = camera_target()

func finish_level():
	if state != "play": return
	state = "results"
	play_sfx("finish", 1.0, 0.95)
	flash = 0.45 if settings.flash else 0.0
	shake = 7.0
	var all_notes = notes_taken.all(func(v): return v)
	section_times.append(run_time - (section_times.reduce(func(a,b): return a+b, 0.0) if section_times.size() > 0 else 0.0))
	result_comparison = get_record(level_index).splits.duplicate()
	result_medal = "GOLD" if run_time <= level.gold else "SILVER" if run_time <= level.silver else "BRONZE" if run_time <= level.bronze else "FINISHED"
	var already_complete = completed.all(func(v): return v)
	completed[level_index] = true
	if not gameplay_modified():
		var rec = get_record(level_index)
		if rec.best <= 0 or run_time < rec.best:
			rec.best = run_time
			rec.ghost = ghost_samples.duplicate()
			rec.splits = section_times.duplicate()
		if all_notes and (rec.all_notes <= 0 or run_time < rec.all_notes): rec.all_notes = run_time
	save_data()
	if (story_mode and level_index == 4) or (not already_complete and completed.all(func(v): return v)):
		begin_outro()
	else:
		show_results()

func update_particles(delta):
	for part in particles.duplicate():
		part.life -= delta
		part.pos += part.vel * delta
		part.vel.y += 550 * delta
		if part.life <= 0: particles.erase(part)

func spawn_particles(pos, color, count):
	if not settings.particles: return
	for i in range(count):
		var angle = rng.randf_range(-PI,0)
		var speed = rng.randf_range(35,190)
		particles.append({"pos": pos, "vel": Vector2(cos(angle),sin(angle))*speed, "life": rng.randf_range(0.22,0.65), "max": 0.65, "color": color, "size": rng.randf_range(2.0,5.0)})

func format_time(value):
	return "%02d:%05.2f" % [int(value / 60.0), fmod(value, 60.0)]

func pause_game():
	state = "pause"
	show_pause()

func resume_game():
	state = "play"
	clear_ui()

func clear_ui():
	for child in ui.get_children(): child.queue_free()

func style(fill=Color("111b2a"), edge=Color("a88c62"), radius=4):
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func make_label(parent, message, position, size=24, color=Color.WHITE, width=600):
	var label = Label.new()
	label.text = message
	label.position = position
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func make_button(parent, message, position, size, callback, accent=Color("c9ad7b")):
	var button = Button.new()
	button.text = message
	button.position = position
	button.custom_minimum_size = size
	button.size = size
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("f1e7cf"))
	button.add_theme_color_override("font_hover_color", Color("fff6da"))
	button.add_theme_stylebox_override("normal", style(Color(0.04,0.07,0.11,0.88), Color(accent.r,accent.g,accent.b,0.65), 3))
	button.add_theme_stylebox_override("hover", style(Color(0.16,0.18,0.20,0.96), accent, 3))
	button.add_theme_stylebox_override("pressed", style(Color(0.22,0.19,0.13,0.96), accent, 3))
	button.add_theme_stylebox_override("focus", style(Color(0,0,0,0), Color("f3d99e"), 3))
	button.pressed.connect(func(): play_sfx("menu", 1.0, 0.4); callback.call())
	parent.add_child(button)
	return button

func show_menu():
	state = "menu"
	story_mode = false
	level_index = 4
	level = Levels.make(4)
	clear_ui()
	apply_settings()
	make_label(ui, "ONE MORE BELL", Vector2(91,111), 68, Color("f2e2bc"), 850)
	make_label(ui, "R E S O N A N C E", Vector2(96,188), 25, Color("c2a97b"), 500)
	var first = make_button(ui, "PLAY", Vector2(96,285), Vector2(292,49), func(): begin_intro())
	make_button(ui, "COURSES", Vector2(410,285), Vector2(161,49), func(): show_select(),Color("817767"))
	make_button(ui, "SETTINGS", Vector2(96,350), Vector2(292,49), func(): show_settings())
	make_button(ui, "HOW TO PLAY", Vector2(96,415), Vector2(292,49), func(): show_help())
	make_button(ui, "QUIT", Vector2(96,480), Vector2(292,49), func(): get_tree().quit())
	first.grab_focus()

func show_select():
	state = "select"
	story_mode = false
	clear_ui()
	make_label(ui, "Courses", Vector2(76,58), 51, Color("f2e2bc"))
	make_label(ui, "Select a route", Vector2(80,125), 18, Color("baad98"))
	var chosen: Button
	for i in range(5):
		var data = Levels.make(i)
		var label = "%02d     %s" % [i+1,data.name.capitalize()]
		var index = i
		var row = make_button(ui, label, Vector2(79,182+i*76), Vector2(485,60), func(): selected_level = index; show_select(), data.theme if i == selected_level else Color("776e68"))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == selected_level: chosen = row
	var detail = Panel.new()
	detail.position = Vector2(615,165)
	detail.size = Vector2(575,430)
	detail.add_theme_stylebox_override("panel", style(Color(0.035,0.055,0.09,0.95), Color("9c8666"), 4))
	ui.add_child(detail)
	var i = selected_level
	var data = Levels.make(i)
	var picture = TextureRect.new()
	picture.texture = art[i]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.position = Vector2(17,17)
	picture.size = Vector2(541,228)
	detail.add_child(picture)
	make_label(detail, "%02d   %s" % [i+1,data.name.capitalize()], Vector2(24,257), 31, Color("f2e2bc"), 510)
	make_label(detail, data.subtitle, Vector2(25,302), 18, Color("c5b9a7"), 510)
	var rec = get_record(i)
	make_label(detail, "BEST   %s" % (format_time(rec.best) if rec.best>0 else "—"), Vector2(25,342), 19, Color("d9c499"), 240)
	make_label(detail, "ALL NOTES   %s" % (format_time(rec.all_notes) if rec.all_notes>0 else "—"), Vector2(272,342), 19, Color("d9c499"), 260)
	make_label(detail, "GOLD  < %.0fs" % data.gold, Vector2(25,379), 16, Color("ad9d81"), 220)
	make_button(ui, "PLAY COURSE  →", Vector2(913,617), Vector2(275,51), func(): start_level(selected_level), data.theme)
	make_button(ui, "←  BACK", Vector2(79,617), Vector2(170,51), func(): show_menu())
	if chosen: chosen.grab_focus()

func show_pause():
	state = "pause"
	clear_ui()
	make_label(ui, "Paused", Vector2(91,138), 54, Color("f2e2bc"))
	make_label(ui, level.name.capitalize(), Vector2(96,210), 23, level.theme)
	var first = make_button(ui, "RESUME", Vector2(96,292), Vector2(300,50), func(): resume_game())
	make_button(ui, "RESTART", Vector2(96,354), Vector2(300,50), func(): start_level(level_index))
	make_button(ui, "SETTINGS", Vector2(96,416), Vector2(300,50), func(): show_settings())
	make_button(ui, "COURSES", Vector2(96,478), Vector2(300,50), func(): show_select())
	first.grab_focus()

func show_results():
	clear_ui()
	var panel = Panel.new()
	panel.position = Vector2(228,91)
	panel.size = Vector2(824,538)
	panel.add_theme_stylebox_override("panel",style(Color(0.035,0.055,0.09,0.97),Color("9e896b"),4))
	ui.add_child(panel)
	make_label(panel, "COURSE CLEARED", Vector2(37,31), 19, Color("c3ac81"), 350)
	make_label(panel, level.name.capitalize(), Vector2(37,66), 38, Color("f2e2bc"), 730)
	make_label(panel, format_time(run_time), Vector2(37,131), 69, Color("fff8e8"), 410)
	make_label(panel, result_medal.capitalize(), Vector2(574,164), 31, Color("d3ae70"), 200)
	make_label(panel, "ECHO NOTES   %d / 3" % notes_taken.count(true), Vector2(40,254), 21, Color("d7d0c2"), 300)
	make_label(panel, "FALLS   %d" % deaths, Vector2(434,254), 21, Color("d7d0c2"), 250)
	make_label(panel, "GOLD < %.0fs   ·   SILVER < %.0fs   ·   BRONZE < %.0fs" % [level.gold,level.silver,level.bronze], Vector2(40,297), 16, Color("a79a86"), 740)
	var rec = get_record(level_index)
	make_label(panel, "PERSONAL BEST   %s" % (format_time(rec.best) if rec.best > 0 else "—"), Vector2(40,341), 18, Color("c4b89e"), 370)
	make_label(panel, "ALL NOTES   %s" % (format_time(rec.all_notes) if rec.all_notes > 0 else "—"), Vector2(434,341), 18, Color("c4b89e"), 320)
	if gameplay_modified(): make_label(panel, "CUSTOM TIMING · THIS RUN DID NOT SET A RECORD", Vector2(40,376), 15, Color("baa88b"), 740)
	var first = make_button(panel, "REPLAY", Vector2(38,449), Vector2(225,51), func(): start_level(level_index), level.theme)
	if level_index < 4: make_button(panel, "NEXT COURSE", Vector2(298,449), Vector2(225,51), func(): start_level(level_index+1), level.theme)
	make_button(panel, "COURSES", Vector2(559,449), Vector2(225,51), func(): show_select())
	first.grab_focus()

func show_finale():
	state = "finale"
	story_mode = false
	clear_ui()
	var panel = Panel.new()
	panel.position = Vector2(215,122)
	panel.size = Vector2(850,476)
	panel.add_theme_stylebox_override("panel",style(Color(0.035,0.055,0.09,0.97),Color("cfb37d"),4))
	ui.add_child(panel)
	make_label(panel, "FIVE COURSES COMPLETE", Vector2(54,57), 20, Color("c4a878"), 740)
	make_label(panel, "You made it out.", Vector2(54,104), 52, Color("f5e6c2"), 740)
	make_label(panel, "The door opened. Morning found the little bellkeeper.", Vector2(58,195), 22, Color("c9c0ae"), 740)
	make_label(panel, "The tower still stands, if you want another run.", Vector2(58,232), 20, Color("a9a090"), 740)
	make_button(panel, "COURSES", Vector2(55,370), Vector2(330,54), func(): show_select()).grab_focus()
	make_button(panel, "MAIN MENU", Vector2(465,370), Vector2(330,54), func(): show_menu())

func show_help():
	state = "help"
	clear_ui()
	make_label(ui, "HOW TO PLAY", Vector2(77,65), 48, Color("fff0c4"))
	make_label(ui, "A / D or ← / →      Move", Vector2(81,166), 23, Color("e7f1f5"))
	make_label(ui, "SPACE or ↑              Jump · hold for height", Vector2(81,213), 23, Color("e7f1f5"))
	make_label(ui, "J or SHIFT              Ring the handbell", Vector2(81,260), 23, Color("e7f1f5"))
	make_label(ui, "ESC                         Pause", Vector2(81,307), 23, Color("e7f1f5"))
	make_label(ui, "GLASS     Solid for a few seconds after the soundwave reaches it.", Vector2(81,381), 20, Color("9ae8f4"), 1100)
	make_label(ui, "BRONZE  Launches you upward and restores the bell immediately.", Vector2(81,420), 20, Color("ffd18c"), 1100)
	make_label(ui, "ECHO       Repeats your wave after a short delay.", Vector2(81,459), 20, Color("d2aaff"), 1100)
	make_label(ui, "The bell recharges over time. Ringing early gets a head shake.", Vector2(81,518), 18, Color("c9d6df"), 1100)
	make_button(ui, "←  BACK", Vector2(80,620), Vector2(200,56), func(): show_menu()).grab_focus()

func setting_title(parent, title):
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 27)
	label.add_theme_color_override("font_color", Color("e4cc9e"))
	label.custom_minimum_size = Vector2(0,57)
	parent.add_child(label)

func settings_row(parent, label_text):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0,45)
	parent.add_child(row)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(300,35)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("d5d0c5"))
	row.add_child(label)
	return row

func add_slider(parent, title, key, max_value=1.0):
	var row = settings_row(parent,title)
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(390,32)
	slider.min_value = 0.0
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = float(settings[key])
	row.add_child(slider)
	var number = Label.new()
	number.custom_minimum_size = Vector2(70,32)
	number.text = "%d%%" % roundi(slider.value*100)
	row.add_child(number)
	slider.value_changed.connect(func(value): settings[key] = value; number.text = "%d%%" % roundi(value*100); apply_settings(); save_data())

func add_toggle(parent, title, key):
	var row = settings_row(parent,title)
	var box = CheckBox.new()
	box.button_pressed = bool(settings[key])
	box.add_theme_color_override("font_color",Color("d7c39a"))
	row.add_child(box)
	box.toggled.connect(func(pressed): settings[key] = pressed; apply_settings(); save_data())

func add_choice(parent, title, key, choices):
	var row = settings_row(parent,title)
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(404,38)
	option.add_theme_stylebox_override("normal",style(Color("131e2b"),Color("6c6255"),3))
	option.add_theme_stylebox_override("hover",style(Color("202a35"),Color("bd9f6e"),3))
	option.add_theme_color_override("font_color",Color("eee4d1"))
	for item in choices: option.add_item(item)
	option.selected = int(settings[key])
	row.add_child(option)
	option.item_selected.connect(func(index): settings[key] = index; apply_settings(); save_data())

func show_settings():
	if state != "settings": previous_state = state
	state = "settings"
	clear_ui()
	make_label(ui, "Settings", Vector2(80,57), 51, Color("f2e2bc"))
	var pages = ["Audio","Gameplay","Video","Comfort","Controls"]
	for i in range(pages.size()):
		var index = i
		var entry = make_button(ui,pages[i].to_upper(),Vector2(81,161+i*76),Vector2(235,59),func(): settings_page = index; show_settings(),Color("c9ad7b") if i == settings_page else Color("6f6b64"))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var panel = Panel.new()
	panel.position = Vector2(346,154)
	panel.size = Vector2(850,454)
	panel.add_theme_stylebox_override("panel",style(Color(0.035,0.055,0.09,0.97),Color("8d7b65"),4))
	ui.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(28,20)
	vbox.custom_minimum_size = Vector2(790,405)
	vbox.add_theme_constant_override("separation",8)
	panel.add_child(vbox)
	match settings_page:
		0:
			setting_title(vbox,"Sound")
			add_slider(vbox,"Master volume","master")
			add_slider(vbox,"Music volume","music")
			add_slider(vbox,"Effects volume","effects")
			add_slider(vbox,"Ambience volume","ambience")
		1:
			setting_title(vbox,"Timing & replay")
			add_toggle(vbox,"Personal-best ghost","ghost")
			add_choice(vbox,"Bell recharge","bell_delay",["Quick · 0.9 s", "Standard · 1.3 s", "Deliberate · 1.7 s"])
			add_choice(vbox,"Glass duration","glass_time",["Forgiving · 5.0 s", "Standard · 3.6 s", "Tight · 2.7 s"])
			add_choice(vbox,"Movement speed","speed",["Measured", "Standard", "Swift"])
			make_label(vbox,"Custom timing settings do not set timed records.",Vector2.ZERO,16,Color("ab9a7e"),730)
		2:
			setting_title(vbox,"Display")
			add_choice(vbox,"Screen mode","display",["Windowed", "Fullscreen", "Borderless fullscreen"])
			add_choice(vbox,"Resolution","resolution",["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"])
			add_toggle(vbox,"Vertical sync","vsync")
			add_toggle(vbox,"Parallax","parallax")
			make_label(vbox,"Parallax moves the distant scenery more slowly than the course,",Vector2.ZERO,16,Color("ab9a7e"),770)
			make_label(vbox,"making the tower feel deeper as you travel.",Vector2.ZERO,16,Color("ab9a7e"),770)
		3:
			setting_title(vbox,"Comfort")
			add_slider(vbox,"Camera shake","shake")
			add_toggle(vbox,"Screen flashes","flash")
			add_toggle(vbox,"Particles","particles")
			add_toggle(vbox,"High-contrast ledges","contrast")
		4:
			setting_title(vbox,"Character & keys")
			add_choice(vbox,"Character model","character",NAMES)
			for i in range(4):
				var row = settings_row(vbox,ACTION_NAMES[i])
				var action_index = i
				var button = Button.new()
				button.text = OS.get_keycode_string(keys[i]) + "   ·   CHANGE"
				button.custom_minimum_size = Vector2(260,36)
				button.add_theme_stylebox_override("normal",style(Color("131e2b"),Color("746952"),3))
				button.add_theme_stylebox_override("hover",style(Color("222d38"),Color("c9ad7b"),3))
				row.add_child(button)
				button.pressed.connect(func(): capturing = action_index; button.text = "PRESS A KEY · ESC CANCELS")
			make_label(vbox,"Arrow keys, Shift and gamepad remain available.",Vector2.ZERO,16,Color("ab9a7e"),730)
	make_button(ui, "←  BACK", Vector2(81,637), Vector2(191,50), func(): leave_settings())

func leave_settings():
	if previous_state == "pause": show_pause()
	else: show_menu()

func cinematic_ease(value):
	var t = clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func draw_cinematic():
	var t = cinematic_time
	var intro = state == "intro"
	var scene = 0 if t < 9.0 else 1 if t < 18.0 else 2
	var scene_time = t if scene == 0 else t-9.0 if scene == 1 else t-18.0
	var drift = scene_time*3.0 if intro else t*2.0
	if intro:
		draw_texture_rect(art[[0,2,1][scene]],Rect2(-80-drift,-40,1440,810),false)
	else:
		var frame = Rect2(-80-drift,-166,1440,810)
		draw_texture_rect(art[4],frame,false)
		draw_texture_rect(art[5],frame,false,Color(1,1,1,cinematic_ease((t-2.9)/2.3)))
	draw_rect(Rect2(0,0,1280,720),Color(0.015,0.025,0.055,0.48 if intro else 0.32))
	if intro:
		if scene == 0: draw_intro_approach(scene_time)
		elif scene == 1: draw_intro_echo(scene_time)
		else: draw_intro_trap(scene_time)
	else:
		draw_escape(t)
	draw_rect(Rect2(0,0,1280,52),Color(0.012,0.021,0.035,0.95))
	draw_rect(Rect2(0,650,1280,70),Color(0.012,0.021,0.035,0.95))
	var caption = ""
	if intro:
		if scene == 0: caption = "A chime called through the rain."
		elif scene == 1: caption = "He followed its echo inside."
		elif scene_time < 7.0: caption = "The door sealed behind him."
		else: caption = "The only way out was above."
	else:
		caption = "One last ring." if t < 7.0 else "And he was free."
	var caption_age = scene_time if intro else t
	var caption_alpha = cinematic_ease((caption_age-0.7)/0.7)
	if intro and scene == 2 and scene_time >= 7.0: caption_alpha = cinematic_ease((scene_time-7.0)/0.6)
	draw_string(UI_FONT,Vector2(78,622),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,33,Color(0.96,0.90,0.77,caption_alpha))
	var fade = 0.0
	if intro:
		fade = max(1.0-cinematic_ease(t/1.0),cinematic_ease((t-28.5)/1.5))
		fade = max(fade,(1.0-abs(t-9.0)/0.42)*0.92,(1.0-abs(t-18.0)/0.42)*0.92)
	else:
		fade = cinematic_ease((t-8.0)/1.0)
	draw_rect(Rect2(0,0,1280,720),Color(0.005,0.012,0.025,clampf(fade,0.0,1.0)))

func draw_cinematic_floor(y):
	draw_rect(Rect2(0,y,1280,720-y),Color(0.055,0.078,0.105,0.94))
	draw_line(Vector2(0,y),Vector2(1280,y),Color("c6a678"),4)
	draw_line(Vector2(0,y+13),Vector2(1280,y+13),Color("52606a"),2)
	for i in range(21):
		draw_circle(Vector2(i*64.0+14.0,y+9),1.6,Color("a48c6c"))

func draw_cinematic_chime(center, pulse):
	var glow = 0.4+0.25*sin(world_time*2.4)
	draw_circle(center,43+pulse*8,Color(0.86,0.72,0.43,0.06+glow*0.11))
	draw_arc(center,28+pulse*5,0,TAU,48,Color(0.98,0.82,0.53,0.48),2)
	var diamond = PackedVector2Array([center+Vector2(0,-17),center+Vector2(13,0),center+Vector2(0,17),center+Vector2(-13,0)])
	draw_colored_polygon(diamond,Color("efcf89"))
	draw_circle(center,5,Color("fff4d6"))

func draw_intro_approach(t):
	var x = 125.0+370.0*cinematic_ease(t/8.3)
	draw_cinematic_chime(Vector2(954,219),sin(t*1.3))
	draw_cinematic_floor(570)
	draw_character(Vector2(x,527))
	for i in range(46):
		var rx = fposmod(i*97.0+world_time*18.0,1320.0)
		var ry = fposmod(i*73.0+world_time*170.0,580.0)
		draw_line(Vector2(rx,ry),Vector2(rx-7,ry+22),Color(0.72,0.85,0.95,0.22),1)

func draw_intro_echo(t):
	var x = 270.0+425.0*cinematic_ease(t/8.0)
	draw_cinematic_chime(Vector2(838,332),sin(t*1.6))
	if t > 4.0:
		var radius = fmod((t-4.0)*112.0,510.0)
		draw_arc(Vector2(838,332),radius,0,TAU,100,Color(0.78,0.88,1.0,0.32*(1.0-radius/510.0)),2)
	draw_cinematic_floor(565)
	draw_character(Vector2(x,522))

func draw_intro_trap(t):
	var beam = PackedVector2Array([Vector2(1010,0),Vector2(1128,0),Vector2(1220,558),Vector2(905,558)])
	draw_colored_polygon(beam,Color(0.95,0.81,0.55,0.10+0.05*sin(world_time*2.3)))
	draw_cinematic_chime(Vector2(1068,142),sin(t*1.8))
	draw_cinematic_floor(560)
	var gate_top = lerpf(-250.0,174.0,cinematic_ease((t-1.1)/2.3))
	for i in range(7):
		var gx = 151.0+i*30.0
		draw_line(Vector2(gx,gate_top),Vector2(gx,gate_top+382),Color("282b2c"),10)
		draw_line(Vector2(gx-2,gate_top),Vector2(gx-2,gate_top+382),Color("9b835f"),2)
	draw_rect(Rect2(138,gate_top,198,17),Color("4e453b"))
	draw_rect(Rect2(138,gate_top+367,198,16),Color("4e453b"))
	draw_character(Vector2(555.0+118.0*cinematic_ease(t/9.0),517))
	if t > 7.0:
		var radius = (t-7.0)*200.0
		draw_arc(Vector2(687,532),radius,0,TAU,100,Color(0.75,0.89,0.99,0.35*(1.0-cinematic_ease((t-7.0)/4.0))),3)

func draw_escape(t):
	var opening = cinematic_ease((t-3.0)/2.0)
	draw_rect(Rect2(0,592,1280,58),Color(0.02,0.03,0.045,0.82))
	draw_line(Vector2(0,585),Vector2(1280,585),Color(0.89,0.75,0.52,0.55),2)
	if t >= 3.0:
		var wave_radius = (t-3.0)*155.0
		draw_arc(Vector2(527,534),wave_radius,0,TAU,120,Color(0.95,0.85,0.65,0.55*(1.0-cinematic_ease((t-3.0)/4.0))),3)
	var x = 260.0+920.0*cinematic_ease(t/8.4)
	draw_character(Vector2(x,537),1.0-cinematic_ease((t-7.0)/1.4))
	draw_rect(Rect2(0,0,1280,720),Color(0.89,0.81,0.60,opening*0.05))

func _draw():
	if state in ["intro","outro"]:
		draw_cinematic()
		return
	var stage = level_index if state in ["play","pause","results"] or (state == "settings" and previous_state == "pause") else 4
	var texture: Texture2D = art[5 if state == "finale" else clampi(stage,0,4)] if art.size() >= 6 else null
	if texture:
		var parallax = camera * 0.045 if bool(settings.parallax) and state in ["play","pause","results"] else Vector2.ZERO
		draw_texture_rect(texture, Rect2(-80-parallax.x,-40-parallax.y,1440,810), false)
	draw_rect(Rect2(0,0,VIEW.x,VIEW.y), Color(0.015,0.025,0.07,0.46 if state in ["play","pause","results"] else 0.62))
	draw_background_motion()
	if state in ["play","pause","results"]:
		var sh = Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake)) * float(settings.shake)
		draw_set_transform(-camera + sh, 0, Vector2.ONE)
		draw_world()
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if state in ["play","pause"]: draw_hud()
	if state == "pause" or state == "settings":
		draw_rect(Rect2(0,0,VIEW.x,VIEW.y), Color(0.01,0.018,0.045,0.53))
	if state == "results": draw_rect(Rect2(0,0,VIEW.x,VIEW.y), Color(0.01,0.02,0.055,0.75))
	if state == "finale": draw_rect(Rect2(0,0,VIEW.x,VIEW.y), Color(0.01,0.02,0.055,0.45))
	if flash > 0 and settings.flash: draw_rect(Rect2(0,0,VIEW.x,VIEW.y), Color(1,0.95,0.8,flash*0.45))

func draw_background_motion():
	var color = Color("9fcfe0") if state in ["play","pause","results"] else Color("e2c48f")
	for i in range(30):
		var x = fposmod(float(i*199) + sin(world_time*0.31+i)*25, 1320.0)
		var y = fposmod(float(i*127) - world_time*(5+i%7), 750.0)
		draw_circle(Vector2(x,y), 1.4 + i%3*0.4, Color(color.r,color.g,color.b,0.15))
	if state == "menu" or state == "select":
		for i in range(4):
			var center = Vector2(1010+i*93,170+i*137)
			draw_arc(center, 120+i*15, world_time*0.08+i, world_time*0.08+i+PI*1.4, 80, Color(0.93,0.76,0.46,0.15), 2.0)
		for i in range(3):
			draw_arc(Vector2(914,400), 120+i*67+fmod(world_time*68,65.0), 0, TAU, 96, Color(0.64,0.89,0.98,0.07), 2.0)

func draw_world():
	var start_x = camera.x - 80
	var end_x = camera.x + VIEW.x + 80
	for i in range(platforms.size()):
		var platform = platforms[i]
		if platform.x+platform.w < start_x or platform.x > end_x: continue
		draw_platform(platform)
	for echo in level.echoes: draw_echo(echo)
	for i in range(3):
		if not notes_taken[i]: draw_note(level.notes[i], i)
	for hazard in level.hazards: draw_hazard(hazard)
	for obstacle in level.obstacles: draw_obstacle(obstacle)
	draw_finish(level.finish)
	for wave in waves:
		var a = 1.0 - wave.age/1.2
		var wave_color = Color("c5a2ff") if not wave.echo else level.theme
		draw_arc(wave.origin,wave.radius,0,TAU,100,Color(wave_color.r,wave_color.g,wave_color.b,max(0.0,a)*0.85),4.0)
		draw_arc(wave.origin,max(0,wave.radius-15),0,TAU,100,Color(wave_color.r,wave_color.g,wave_color.b,max(0.0,a)*0.25),2.0)
	for part in particles:
		var alpha = clamp(part.life/part.max,0.0,1.0)
		var c: Color = part.color
		draw_circle(part.pos,part.size*alpha,Color(c.r,c.g,c.b,alpha))
	if settings.ghost:
		var rec = get_record(level_index)
		var ghost = rec.ghost
		var sample_index = int(run_time/0.06)
		if sample_index >= 0 and sample_index < ghost.size(): draw_character(ghost[sample_index],0.28,true)
	if invulnerable <= 0 or int(world_time*10)%2 == 0: draw_character(player,1.0,false)

func draw_platform(platform):
	var x = platform.x
	var y = platform.y
	var w = platform.w
	if platform.kind == "glass":
		var active = platform.until > run_time
		var blink = active and platform.until-run_time < 0.75 and int(world_time*14.0)%2 == 0
		var rim = Color("eff9ff") if settings.contrast and active else Color("b6a284") if active else Color("707980")
		var crystal = Color(0.67,0.86,1.0,0.75 if active and not blink else 0.27 if active else 0.12)
		draw_rect(Rect2(x,y+3,w,21),Color("152233"))
		draw_rect(Rect2(x+4,y+5,w-8,15),crystal)
		for j in range(int(w/36.0)):
			var xx = x+j*36.0
			var facet = PackedVector2Array([Vector2(xx+3,y+5),Vector2(xx+21,y+6),Vector2(xx+31,y+19),Vector2(xx+11,y+18)])
			draw_colored_polygon(facet,Color(0.77,0.88,0.98,0.30 if active and not blink else 0.06))
			draw_line(Vector2(xx+21,y+6),Vector2(xx+11,y+18),Color(0.12,0.27,0.40,0.5),1)
		draw_rect(Rect2(x,y,w,24),rim,false,2)
		draw_line(Vector2(x,y),Vector2(x+w,y),Color("f4f6ed") if settings.contrast and active else Color("e9e4d5") if active and not blink else Color("879ca3"),2)
	elif platform.kind == "bronze":
		draw_rect(Rect2(x,y+8,w,22),Color("23303a"))
		draw_rect(Rect2(x,y+5,w,7),Color("b78e5a"))
		draw_line(Vector2(x,y),Vector2(x+w,y),Color("fff0be") if settings.contrast else Color("f0d8a1"),3)
		for j in range(3):
			var cx = x+w*(j+0.5)/3.0
			draw_arc(Vector2(cx,y+22),16,PI*1.1,TAU*0.95,25,Color("d9b779"),2)
			draw_arc(Vector2(cx,y+22),9,PI*1.05,TAU*0.95,20,Color("68513e"),2)
			draw_circle(Vector2(cx,y+22),3,Color("e6ce99"))
	else:
		draw_rect(Rect2(x,y+7,w,24),Color("192331"))
		draw_rect(Rect2(x,y+1,w,8),Color("796b56"))
		for j in range(int(w/40.0)):
			var xx = x+8+j*40.0
			draw_line(Vector2(xx,y+10),Vector2(xx+34,y+28),Color("876f53"),2)
			draw_line(Vector2(xx+34,y+10),Vector2(xx,y+28),Color("876f53"),2)
			draw_circle(Vector2(xx+4,y+5),2,Color("e2c690"))
		draw_line(Vector2(x,y),Vector2(x+w,y),Color("ffe2a7") if settings.contrast else Color("e0bd83"),3)
		draw_line(Vector2(x,y+29),Vector2(x+w,y+29),Color("987d58"),2)

func draw_echo(pos):
	var swell = 1.0 + sin(world_time*4.0)*0.08
	draw_arc(pos,28*swell,0,TAU,40,Color("b999ff"),3.0)
	draw_arc(pos,38+swell*3,0,TAU,40,Color(0.75,0.58,1.0,0.3),2.0)
	draw_circle(pos,18,Color("583d99"))
	draw_circle(pos,8,Color("f4d6ff"))
	draw_text("ECHO",pos+Vector2(-18,-44),12,Color("e8cbff"))

func draw_note(pos,index):
	var y = sin(world_time*3.2+index)*6.0
	var center = pos + Vector2(0,y)
	draw_arc(center,24,0,TAU,32,Color(1.0,0.87,0.55,0.3),1.5)
	var points = PackedVector2Array([center+Vector2(0,-16),center+Vector2(13,0),center+Vector2(0,16),center+Vector2(-13,0)])
	draw_colored_polygon(points,Color("f2d18d"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-9),center+Vector2(7,0),center+Vector2(0,9),center+Vector2(-7,0)]),Color("fff5cf"))

func draw_hazard(hazard):
	var pos = hazard_pos(hazard)
	var anchor = Vector2(hazard.x,hazard.y-145.0)
	draw_line(anchor,pos,Color("18212b"),12)
	draw_line(anchor+Vector2(-3,0),pos+Vector2(-3,0),Color("8e754f"),2)
	draw_line(anchor+Vector2(3,0),pos+Vector2(3,0),Color("bda375"),2)
	for i in range(1,4):
		var rivet = anchor.lerp(pos,i/4.0)
		draw_circle(rivet,5,Color("3b4141"))
		draw_circle(rivet,2.4,Color("d9b779"))
	draw_circle(anchor,10,Color("141e2c"))
	draw_arc(anchor,8,0,TAU,30,Color("d9b779"),2)
	draw_circle(anchor,3,Color("f4e8cf"))
	draw_escapement_bob(pos,hazard.phase)

func draw_escapement_bob(center, phase):
	var radius = 29.0
	for i in range(16):
		var angle = i*TAU/16.0
		var width = TAU/16.0
		var tooth = PackedVector2Array([
			center+Vector2(cos(angle-width*0.32),sin(angle-width*0.32))*(radius*0.83),
			center+Vector2(cos(angle-width*0.28),sin(angle-width*0.28))*radius,
			center+Vector2(cos(angle+width*0.28),sin(angle+width*0.28))*radius,
			center+Vector2(cos(angle+width*0.32),sin(angle+width*0.32))*(radius*0.83)])
		draw_colored_polygon(tooth,Color("c4a06a"))
	draw_circle(center,radius*0.83,Color("29343a"))
	draw_arc(center,radius*0.80,0,TAU,64,Color("ead19a"),2)
	draw_circle(center,radius*0.59,Color("a48356"))
	draw_circle(center,radius*0.53,Color("182631"))
	for i in range(6):
		var angle = i*TAU/6.0-PI/2
		var direction = Vector2(cos(angle),sin(angle))
		draw_line(center+direction*(radius*0.15),center+direction*(radius*0.52),Color("d4b57d"),2.8)
	for i in range(12):
		var angle = i*TAU/12.0-PI/2
		var direction = Vector2(cos(angle),sin(angle))
		draw_line(center+direction*(radius*0.69),center+direction*(radius*0.76),Color("f4e8cf"),1.5)
	draw_circle(center,radius*0.17,Color("c19d68"))
	draw_circle(center,radius*0.085,Color("263442"))
	var hand_angle = -PI/2+run_time*0.55+phase*0.25
	draw_line(center,center+Vector2(cos(hand_angle),sin(hand_angle))*(radius*0.39),Color("f4e8cf"),1.5)

func draw_obstacle(obstacle):
	var pos = Vector2(obstacle.x,obstacle.y)
	if obstacle.kind == "steam":
		var pressure = steam_pressure(obstacle)
		var warning = pressure > 0.0
		var rattle = sin(world_time*52.0+obstacle.x)*2.0*pressure
		var vent = pos + Vector2(rattle,0)
		if warning:
			draw_circle(pos+Vector2(0,-9),25.0+pressure*6.0,Color(0.94,0.62,0.29,0.08+pressure*0.15))
			draw_rect(Rect2(pos+Vector2(-30,-5),Vector2(60,6)),Color(0.9,0.6,0.3,0.14+pressure*0.30))
			draw_line(vent+Vector2(-25,-10),vent+Vector2(-21,-13),Color("dbbd89"),1.3)
			draw_line(vent+Vector2(21,-13),vent+Vector2(25,-10),Color("dbbd89"),1.3)
		draw_rect(Rect2(vent+Vector2(-23,-6),Vector2(46,8)),Color("4c5861"))
		if warning: draw_rect(Rect2(vent+Vector2(-20,-6),Vector2(40,3)),Color("f6c77d"))
		for i in range(3): draw_circle(vent+Vector2(-14+i*14,-4),3,Color("eec284") if warning else Color("9d9076"))
		if obstacle_active(obstacle):
			for i in range(4):
				var drift = sin(world_time*6.0+i*1.8)*7.0
				draw_circle(pos+Vector2(drift,-16-i*18),9+i*2,Color(0.73,0.86,0.86,0.34-i*0.055))
		elif warning:
			for i in range(6):
				var wisp_y = 9.0 + fposmod(world_time*(22.0+pressure*22.0)+i*11.0,52.0)
				var wisp_x = sin(world_time*9.0+i*2.1)*7.0 + (-8.0 if i%2==0 else 8.0)
				draw_circle(vent+Vector2(wisp_x,-wisp_y),5.0+pressure*3.0,Color(0.83,0.88,0.81,0.23+pressure*0.23))
		else:
			draw_circle(pos+Vector2(0,-13),5,Color(0.75,0.85,0.86,0.18))
	elif obstacle.kind == "piston":
		var head = piston_pos(obstacle)
		var warning = fposmod(run_time+obstacle.phase,3.2) > 2.6
		draw_line(pos+Vector2(0,-120),head,Color("3b4148"),13)
		draw_line(pos+Vector2(0,-120),head,Color("b3a281"),4)
		draw_rect(Rect2(head+Vector2(-27,-15),Vector2(54,29)),Color("403b38"))
		draw_rect(Rect2(head+Vector2(-24,-11),Vector2(48,19)),Color("e0b774") if warning else Color("b08c62"))
		for i in range(3): draw_line(head+Vector2(-17+i*17,14),head+Vector2(-11+i*17,25),Color("d4bd92"),3)
	else:
		draw_rect(Rect2(pos+Vector2(-25,-2),Vector2(50,7)),Color("4e4b46"))
		for i in range(4):
			var x = pos.x-22+i*13
			draw_colored_polygon(PackedVector2Array([Vector2(x,pos.y-2),Vector2(x+6,pos.y-24),Vector2(x+12,pos.y-2)]),Color("c2b49a"))

func draw_finish(pos):
	draw_rect(Rect2(pos+Vector2(-31,-51),Vector2(62,91)),Color(0.86,0.67,0.39,0.09))
	draw_arc(pos+Vector2(0,-16),31,PI,TAU,40,Color("d6ba86"),3)
	draw_line(pos+Vector2(-31,-16),pos+Vector2(-31,40),Color("d6ba86"),3)
	draw_line(pos+Vector2(31,-16),pos+Vector2(31,40),Color("d6ba86"),3)
	draw_line(pos+Vector2(-31,40),pos+Vector2(31,40),Color("d6ba86"),3)
	draw_circle(pos+Vector2(0,-13),4,Color("f6e1ae"))

func draw_character(pos, alpha=1.0, ghost=false):
	var model = int(settings.character)
	var bob = sin(world_time*18)*2.4 if grounded and abs(velocity.x)>25 and not ghost else 0.0
	var squash = land_anim*16 if not ghost else 0.0
	var head_x = sin((0.48-reject_anim)*43)*4.0 if reject_anim>0 and not ghost else 0.0
	var body_color = [Color("313650"),Color("976746"),Color("6d5688"),Color("377f88")][model]
	var trim = [Color("eeac6a"),Color("75d5e0"),Color("e8beee"),Color("b9f4db")][model]
	if ghost:
		body_color = Color("a7e6fa")
		trim = Color("dcf5ff")
	var cloak = PackedVector2Array([pos+Vector2(-12,18+bob),pos+Vector2(12,18+bob),pos+Vector2(16,40-squash),pos+Vector2(-16,40-squash)])
	draw_colored_polygon(cloak,Color(body_color.r,body_color.g,body_color.b,alpha))
	var scarf_end = pos+Vector2(-facing*(22+abs(velocity.x)/24.0),19+bob+sin(world_time*13)*3)
	draw_line(pos+Vector2(-facing*4,18+bob),scarf_end,Color(trim.r,trim.g,trim.b,alpha),5)
	if model == 0:
		draw_circle(pos+Vector2(head_x,10+bob),15,Color(body_color.r,body_color.g,body_color.b,alpha))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(head_x-13,5+bob),pos+Vector2(head_x, -7+bob),pos+Vector2(head_x+13,5+bob)]),Color(body_color.r,body_color.g,body_color.b,alpha))
	elif model == 1:
		draw_rect(Rect2(pos+Vector2(head_x-13,-1+bob),Vector2(26,25)),Color(body_color.r,body_color.g,body_color.b,alpha))
		draw_line(pos+Vector2(head_x,-2+bob),pos+Vector2(head_x,-12+bob),Color(trim.r,trim.g,trim.b,alpha),3)
		draw_circle(pos+Vector2(head_x,-13+bob),4,Color(trim.r,trim.g,trim.b,alpha))
	elif model == 2:
		for side in [-1,1]:
			draw_colored_polygon(PackedVector2Array([pos+Vector2(head_x+side*7,1+bob),pos+Vector2(head_x+side*17,-13+bob),pos+Vector2(head_x+side*16,8+bob)]),Color(trim.r,trim.g,trim.b,alpha))
		draw_circle(pos+Vector2(head_x,11+bob),13,Color(body_color.r,body_color.g,body_color.b,alpha))
	else:
		draw_circle(pos+Vector2(head_x,9+bob),14,Color(body_color.r,body_color.g,body_color.b,alpha))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(head_x-8,0+bob),pos+Vector2(head_x+1,-16+bob),pos+Vector2(head_x+9,1+bob)]),Color(trim.r,trim.g,trim.b,alpha))
	draw_circle(pos+Vector2(head_x+facing*5,11+bob),2.5,Color(0.95,0.98,1.0,alpha))
	for side in [-1,1]:
		var lift = sin(world_time*18+side*PI)*3 if abs(velocity.x)>25 and grounded else 0.0
		draw_line(pos+Vector2(side*7,34-squash),pos+Vector2(side*9,43-squash+lift),Color(trim.r*0.55,trim.g*0.55,trim.b*0.55,alpha),4)
	var bell_pos = pos+Vector2(facing*19,25+bob+sin(world_time*22)*ring_anim*6)
	draw_line(pos+Vector2(facing*9,22+bob),bell_pos,Color(trim.r,trim.g,trim.b,alpha),3)
	draw_circle(bell_pos,7,Color("fbd885",alpha) if not ghost else Color(0.8,0.95,1.0,alpha))
	draw_rect(Rect2(bell_pos+Vector2(-8,4),Vector2(16,4)),Color("ffe7a8",alpha))

func draw_hud():
	var charge = clamp(1.0-ring_cooldown/bell_delay(),0.0,1.0)
	var bell = Vector2(45,47)
	draw_line(bell+Vector2(0,-13),bell+Vector2(0,-8),Color("e7d09e"),2)
	draw_arc(bell+Vector2(0,1),10,PI,TAU,20,Color("e7d09e"),2)
	draw_line(bell+Vector2(-10,1),bell+Vector2(-12,9),Color("e7d09e"),2)
	draw_line(bell+Vector2(10,1),bell+Vector2(12,9),Color("e7d09e"),2)
	draw_line(bell+Vector2(-12,9),bell+Vector2(12,9),Color("e7d09e"),2)
	draw_circle(bell+Vector2(0,12),2,Color("e7d09e"))
	draw_rect(Rect2(72,44,159,5),Color(0.28,0.32,0.35,0.38))
	draw_rect(Rect2(72,44,159*charge,5),Color("d7ba84") if charge>=0.99 else Color("b99164"))
	draw_circle(Vector2(45,81),10,Color("d9c395"),false,2)
	draw_line(Vector2(45,81),Vector2(45,75),Color("d9c395"),1.6)
	draw_line(Vector2(45,81),Vector2(49,84),Color("d9c395"),1.6)
	draw_line(Vector2(42,68),Vector2(48,68),Color("d9c395"),2)
	draw_text(format_time(run_time),Vector2(73,91),25,Color(0.02,0.03,0.05,0.9))
	draw_text(format_time(run_time),Vector2(72,90),25,Color("f4ead3"))

func draw_text(message, pos, size=16, color=Color.WHITE):
	draw_string(UI_FONT,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

