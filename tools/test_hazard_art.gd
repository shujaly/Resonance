extends SceneTree

class GeometryProbe extends RefCounted:
	var failures = 0
	var polygons = 0
	func draw_colored_polygon(points, _color):
		polygons += 1
		if Geometry2D.triangulate_polygon(points).is_empty():
			failures += 1
			push_error("Hazard mesh cannot be triangulated")
		for point in points:
			if not point.is_finite(): failures += 1
	func draw_rect(_rect, _color): pass
	func draw_circle(_center, _radius, _color): pass
	func draw_line(_a, _b, _color, _width=1.0, _antialiased=false): pass
	func draw_arc(_center, _radius, _start, _end, _count, _color, _width=1.0, _antialiased=false): pass
	func draw_polyline(_points, _color, _width=1.0, _antialiased=false): pass

func _initialize():
	var art = load("res://hazard_art.gd")
	var probe = GeometryProbe.new()
	for style in range(3):
		for contrast in [false,true]:
			art.spikes(probe,Vector2.ZERO,style,contrast)
			for frame in range(168):
				var clock = frame/60.0
				var pressure = clamp((clock-1.95)/0.85,0.0,1.0)
				art.steam(probe,Vector2(500,500),style,clock,pressure,clock<0.72,contrast)
	print("HAZARD GEOMETRY: %d polygons checked / %d failures" % [probe.polygons,probe.failures])
	quit(0 if probe.failures==0 else 1)
