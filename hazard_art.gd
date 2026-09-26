extends RefCounted

static func polygon(canvas, origin, points, color):
	var vertices = PackedVector2Array()
	for point in points: vertices.append(origin+point)
	canvas.draw_colored_polygon(vertices,color)

static func bolt(canvas, center, radius=2.0):
	canvas.draw_circle(center,radius+0.6,Color("17212a"))
	canvas.draw_circle(center+Vector2(0,-0.4),radius,Color("ad9977"))
	canvas.draw_line(center+Vector2(-radius*0.5,0),center+Vector2(radius*0.5,0),Color("514d46"),0.8,true)

static func pipe(canvas, points, width=12.0):
	canvas.draw_polyline(points,Color("111c27"),width+4,true)
	canvas.draw_polyline(points,Color("594b3c"),width,true)
	var highlight = PackedVector2Array()
	for point in points: highlight.append(point+Vector2(-width*0.19,-1))
	canvas.draw_polyline(highlight,Color("ac8756"),width*0.32,true)
	for point in points:
		canvas.draw_circle(point,width*0.46,Color("594b3c"))
		canvas.draw_arc(point+Vector2(-1,-1),width*0.28,PI,TAU,10,Color("bc9761"),1.2,true)

static func collar(canvas, center, width=18.0):
	canvas.draw_rect(Rect2(center-Vector2(width/2,3),Vector2(width,7)),Color("202a31"))
	canvas.draw_line(center+Vector2(-width/2,-3),center+Vector2(width/2,-3),Color("c1a275"),1.5,true)
	canvas.draw_line(center+Vector2(-width/2,3),center+Vector2(width/2,3),Color("736452"),1.2,true)

static func spikes(canvas, origin, style=0, contrast=false):
	var light = Color("fff0c6") if contrast else Color("c2c7c0")
	var steel = Color("879493")
	var shade = Color("3d4a50")
	polygon(canvas,origin,[Vector2(-27,2),Vector2(27,2),Vector2(24,15),Vector2(-23,15)],Color("19252e"))
	canvas.draw_rect(Rect2(origin+Vector2(-25,3),Vector2(52,7)),Color("706047"))
	canvas.draw_line(origin+Vector2(-23,13),origin+Vector2(23,13),Color("a48556"),1.2,true)
	for x in [-19,0,20]: bolt(canvas,origin+Vector2(x,6),1.6)
	var count = 4 if style==0 else 3
	var width = 52.0/count
	for i in range(count):
		var x = -25.0+i*width
		var tip = Vector2(x+width*0.54,-25.0+(1.0 if i%2==0 else 0.0))
		var left = Vector2(x,-1)
		var right = Vector2(x+width,-1)
		var shoulder = Vector2(x+width*0.27,-12)
		var heel = Vector2(x+width*0.76,-8)
		match style:
			0:
				tip.x += 2.0
				polygon(canvas,origin,[left,shoulder,tip,tip+Vector2(-1,8),heel,right],Color("17252e"))
				var ridge = tip+Vector2(-1,12)
				polygon(canvas,origin,[left+Vector2(1,0),shoulder,tip,ridge,Vector2(x+width*0.48,-2)],steel)
				polygon(canvas,origin,[Vector2(x+width*0.48,-2),ridge,tip+Vector2(-1,8),heel,right],shade)
				canvas.draw_line(origin+Vector2(x+4,-5),origin+Vector2(x+7,-7),Color("475a5e"),1.0,true)
			1:
				polygon(canvas,origin,[left,Vector2(x+3,-7),Vector2(x+2,-14),tip,Vector2(x+width-2,-14),Vector2(x+width-3,-7),right],shade)
				polygon(canvas,origin,[Vector2(x+3,-13),tip,Vector2(tip.x,-3),left],steel)
				canvas.draw_line(origin+tip,origin+Vector2(tip.x,-4),Color("b09a75"),1.0,true)
				canvas.draw_line(origin+Vector2(x+4,-8),origin+Vector2(x+width-4,-8),Color("ac9670"),2.0,true)
			2:
				tip.x = x+width*0.72
				polygon(canvas,origin,[left,Vector2(x+2,-10),tip,Vector2(x+width*0.82,-14),Vector2(x+width-2,-14),right],shade)
				polygon(canvas,origin,[left,Vector2(x+2,-10),tip,Vector2(x+width*0.47,-8)],Color("a69b80"))
				canvas.draw_line(origin+Vector2(x+4,-5),origin+Vector2(x+width*0.62,-14),Color("d0bd91"),1.0,true)
		canvas.draw_line(origin+shoulder,origin+tip,light,1.2,true)
		canvas.draw_line(origin+Vector2(x+3,-2),origin+Vector2(x+width-2,-2),Color("b29a73"),2.0,true)
	canvas.draw_line(origin+Vector2(-25,0),origin+Vector2(27,0),Color("272f31"),2.0,true)

static func steam(canvas, origin, style, clock, pressure, active, contrast=false):
	var rattle = sin(clock*52.0+origin.x)*2.0*pressure
	var recoil = sin(clock*70.0)*0.55 if active else 0.0
	var vent = origin+Vector2(rattle,recoil)
	var left = -1.0 if style==1 else 1.0
	if style==0:
		var bend = PackedVector2Array([origin+Vector2(0,5),origin+Vector2(0,40),origin+Vector2(3,47),origin+Vector2(11,50),origin+Vector2(32,50),origin+Vector2(32,63)])
		pipe(canvas,bend,13)
		collar(canvas,origin+Vector2(0,24),20)
		collar(canvas,origin+Vector2(32,59),19)
	elif style==1:
		for side in [-1,1]:
			pipe(canvas,PackedVector2Array([origin+Vector2(side*12,5),origin+Vector2(side*12,32),origin+Vector2(side*7,37),origin+Vector2(0,37),origin+Vector2(0,61)]),10)
			collar(canvas,origin+Vector2(side*12,24),15)
		collar(canvas,origin+Vector2(0,51),18)
	else:
		pipe(canvas,PackedVector2Array([origin+Vector2(0,4),origin+Vector2(0,58)]),17)
		for offset in [-5,5]: canvas.draw_line(origin+Vector2(offset,21),origin+Vector2(offset,48),Color("a28a62"),1.3,true)
		collar(canvas,origin+Vector2(0,22),22)
		collar(canvas,origin+Vector2(0,48),22)
		polygon(canvas,origin,[Vector2(-7,53),Vector2(0,62),Vector2(7,53)],Color("6f6048"))
	var gauge = origin+Vector2(-left*21,33)
	pipe(canvas,PackedVector2Array([origin+Vector2(0,34),gauge]),5)
	canvas.draw_circle(gauge,9,Color("15212b"))
	canvas.draw_arc(gauge,7.7,0,TAU,28,Color("b69a6a"),1.6,true)
	canvas.draw_circle(gauge,6.1,Color("d0c3a0"))
	for tick in range(5):
		var angle = PI*0.8+tick*PI*0.35
		canvas.draw_line(gauge+Vector2.from_angle(angle)*4.4,gauge+Vector2.from_angle(angle)*5.5,Color("514b3d"),0.8,true)
	var needle = PI*0.8+(1.0 if active else pressure)*PI*1.4
	canvas.draw_line(gauge,gauge+Vector2.from_angle(needle)*4.5,Color("753e32"),1.1,true)
	canvas.draw_circle(gauge,1.1,Color("423b34"))
	var valve = origin+Vector2(left*17,47)
	canvas.draw_line(origin+Vector2(0,44),valve,Color("70523e"),4,true)
	canvas.draw_arc(valve,6,0,TAU,24,Color("ae7c51"),1.8,true)
	for i in range(3):
		var angle = i*TAU/3.0+pressure*0.14
		canvas.draw_line(valve,valve+Vector2.from_angle(angle)*5,Color("ba9463"),1.2,true)
	canvas.draw_circle(valve,1.5,Color("dec191"))
	canvas.draw_rect(Rect2(origin+Vector2(-26,0),Vector2(52,9)),Color("18252e"))
	canvas.draw_rect(Rect2(origin+Vector2(-24,2),Vector2(48,4)),Color("8b7452"))
	for x in [-21,21]: bolt(canvas,origin+Vector2(x,4),1.7)
	polygon(canvas,vent,[Vector2(-20,1),Vector2(-18,-7),Vector2(-12,-10),Vector2(12,-10),Vector2(18,-7),Vector2(20,1)],Color("6d6251"))
	canvas.draw_line(vent+Vector2(-17,-7),vent+Vector2(17,-7),Color("c9b288"),2,true)
	canvas.draw_line(vent+Vector2(-15,-7),vent+Vector2(15,-7),Color("172731"),3,true)
	for x in [-10,0,10]: canvas.draw_line(vent+Vector2(x,-9),vent+Vector2(x,-4),Color("8c8e7c"),1.4,true)
	if pressure>0:
		canvas.draw_rect(Rect2(origin+Vector2(-24,-10),Vector2(48,12)),Color(0.92,0.58,0.25,pressure*0.12))
		canvas.draw_line(vent+Vector2(-14,-6),vent+Vector2(14,-6),Color(0.94,0.66,0.32,pressure*0.8),2.0,true)
		for side in [-1,1]:
			var crack = vent+Vector2(side*21,-4)
			canvas.draw_polyline(PackedVector2Array([crack+Vector2(side*1,-3),crack+Vector2(side*3,-7),crack+Vector2(side*2,-10)]),Color(0.85,0.76,0.59,pressure*0.65),1.0,true)
	if active:
		plume(canvas,origin,clock,contrast)
	elif pressure>0:
		for i in range(5):
			var rise = fposmod(clock*(18+pressure*27)+i*9,38.0)
			var x = sin(clock*4+i*2)*5+(-7.0 if i%2==0 else 7.0)
			canvas.draw_circle(vent+Vector2(x,-12-rise),2.8+rise*0.045,Color(0.79,0.84,0.8,(1.0-rise/45.0)*(0.12+pressure*0.20)))

static func plume(canvas, origin, clock, contrast):
	for layer in range(3):
		var vertices = PackedVector2Array()
		for side in [-1,1]:
			for j in range(13):
				var t = (j if side==-1 else 12-j)/12.0
				var cap = 1.0-pow(max(0.0,(t-0.72)/0.28),2.0)*0.35
				var width = (21.0-layer*5.0+sin(t*13.0-clock*19.0+layer)*1.6)*cap
				vertices.append(origin+Vector2(side*width,-t*(85.0-layer*2.5)+(3.0 if t==1.0 else 0.0)))
		var cap_y = -85.0+layer*2.5
		vertices.insert(13,origin+Vector2(0,cap_y))
		canvas.draw_colored_polygon(vertices,Color(0.77,0.87,0.85,(0.34 if contrast else 0.21)-layer*0.025))
	for i in range(9):
		var rise = fposmod(clock*150.0+i*9.5,73.0)
		var radius = 3.5+rise*0.035
		var x = sin(clock*7.0+i*2.7)*(14.0-radius)
		canvas.draw_circle(origin+Vector2(x,-7-rise),radius,Color(0.92,0.96,0.91,0.15*(1.0-rise/100.0)))
	for i in range(3):
		var streak = PackedVector2Array()
		for j in range(9):
			var y = -5.0-j*9.0
			streak.append(origin+Vector2((i-1)*11.0+sin(j*0.8-clock*15+i)*2.2,y))
		canvas.draw_polyline(streak,Color(0.92,0.96,0.91,0.26 if contrast else 0.16),1.4,true)
