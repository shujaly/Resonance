extends RefCounted

static func pose(velocity, facing, grounded, clock, stride, landing=0.0, ring=0.0, reject=0.0, lean=0.0, scarf=0.0, takeoff=0.0, delight=0.0):
	var speed = clamp(abs(velocity.x)/290.0,0.0,1.0)
	var run = speed if grounded else 0.0
	var rise = clamp(-velocity.y/685.0,0.0,1.0) if not grounded else 0.0
	var fall = clamp(velocity.y/900.0,0.0,1.0) if not grounded else 0.0
	var compression = sin(clamp(landing/0.22,0.0,1.0)*PI*0.5)*0.19
	var stretch = min(takeoff/0.26,1.0)*0.1
	var swing = sin((1.0-clamp(ring/0.42,0.0,1.0))*TAU)*0.95 if ring>0 else 0.0
	return {"facing":facing,"clock":clock,"stride":stride,"run":run,"rise":rise,"fall":fall,"lean":lean,"scarf":scarf,"sx":1.0+compression*0.65-stretch*0.4,"sy":1.0-compression+stretch,"bob":-abs(sin(stride))*1.7*run+sin(clock*2.4)*0.65*(1.0-run),"head":sin((0.48-reject)*32.0)*5.0*min(1.0,reject/0.15) if reject>0 else 0.0,"ring":swing,"delight":delight,"blink":fposmod(clock,4.7)>4.54,"speed":speed}

static func point(origin, local, pose_data):
	return origin + Vector2(local.x*pose_data.sx+pose_data.lean*(42.0-local.y)/42.0,42.0+(local.y-42.0)*pose_data.sy+pose_data.bob)

static func polygon(canvas, origin, coords, pose_data, color):
	var points = PackedVector2Array()
	for p in coords: points.append(point(origin,p,pose_data))
	canvas.draw_colored_polygon(points,color)

static func line(canvas, origin, a, b, pose_data, color, width=1.0):
	canvas.draw_line(point(origin,a,pose_data),point(origin,b,pose_data),color,width,true)

static func circle(canvas, origin, center, radius, pose_data, color):
	canvas.draw_circle(point(origin,center,pose_data),radius,color)

static func paint(canvas, origin, p, model, alpha=1.0, ghost=false):
	model = clampi(model,0,3)
	var cloth = Color(["384257","92704a","706087","3d7376"][model],alpha)
	var shade = Color(["20293b","514339","403650","244449"][model],alpha)
	var edge = Color(["78879b","ccaa73","a69ab8","77a5a1"][model],alpha)
	var trim = Color(["d9a36b","87bdc2","d9b8c9","dabd82"][model],alpha)
	var dark = Color("101b28",alpha)
	var light = Color("f6e1b2",alpha)
	if ghost:
		cloth = Color("9fcee1",alpha); shade = Color("75a6c0",alpha)
		edge = Color("c1e6f1",alpha); trim = edge; dark = shade; light = edge
	var face = p.facing
	var tail = -face*(23.0+p.speed*12.0)
	var flutter = sin(p.clock*9.0-p.speed*2.0)*(1.0+p.speed*2.5)+p.scarf
	polygon(canvas,origin,[Vector2(-face*4,17),Vector2(-face*14,18),Vector2(tail,16+flutter),Vector2(tail+face*5,23+flutter),Vector2(-face*12,23)],p,trim)
	line(canvas,origin,Vector2(-face*13,19),Vector2(tail+face*4,18+flutter),p,light,1.0)
	if model == 2:
		for side in [-1,1]:
			var spread = 3.0+p.fall*5.0+sin(p.clock*6)*1.5
			polygon(canvas,origin,[Vector2(side*7,21),Vector2(side*(19+spread),17),Vector2(side*23,34),Vector2(side*9,39)],p,shade)
			line(canvas,origin,Vector2(side*8,23),Vector2(side*22,30),p,trim,1.0)
	for side in [-1,1]:
		var gait = sin(p.stride+(0.0 if side==1 else PI))*p.run
		var foot = Vector2(side*6+gait*9,42.0-max(0.0,gait)*7.0)
		if p.rise>0: foot = Vector2(side*(7.0+p.rise*2.0),39.0-(p.rise*9.0 if side==int(face) else 0.0))
		if p.fall>0: foot = Vector2(side*(7.0+p.fall*2.0),41.0-p.fall*2.0)
		var knee = Vector2(side*6-gait*3,34-p.rise*3)
		line(canvas,origin,Vector2(side*6,29),knee,p,shade,5)
		line(canvas,origin,knee,foot-Vector2(0,2),p,dark,4)
		line(canvas,origin,foot-Vector2(3,0),foot+Vector2(face*5,0),p,edge,4)
	var hem = sin(p.stride-0.8)*p.run*3.0+p.fall*2.0
	polygon(canvas,origin,[Vector2(-12,17),Vector2(11,17),Vector2(17+hem,36),Vector2(8,39),Vector2(1,37),Vector2(-9,39),Vector2(-16+hem,35)],p,dark)
	polygon(canvas,origin,[Vector2(-10,18),Vector2(10,18),Vector2(14+hem,35),Vector2(7,37),Vector2(0,35),Vector2(-8,37),Vector2(-13+hem,34)],p,cloth)
	polygon(canvas,origin,[Vector2(-7,20),Vector2(-2,20),Vector2(-3,34),Vector2(-10+hem,35)],p,shade)
	line(canvas,origin,Vector2(8,20),Vector2(11+hem,33),p,edge,1.2)
	line(canvas,origin,Vector2(-11,26),Vector2(12,27),p,shade,3)
	circle(canvas,origin,Vector2(face*5,26),2,p,trim)
	var head = Vector2(p.head,8-p.rise*1.6+p.fall*1.2)
	match model:
		0:
			circle(canvas,origin,head,15.3,p,dark)
			circle(canvas,origin,head+Vector2(0,-1),14.2,p,cloth)
			polygon(canvas,origin,[head+Vector2(-13,-5),head+Vector2(-5,-18),head+Vector2(6,-13),head+Vector2(13,-5)],p,cloth)
			line(canvas,origin,head+Vector2(-10,-7),head+Vector2(-4,-15),p,edge,1)
		1:
			polygon(canvas,origin,[head+Vector2(-13,-10),head+Vector2(8,-12),head+Vector2(14,-5),head+Vector2(13,13),head+Vector2(-12,13)],p,dark)
			polygon(canvas,origin,[head+Vector2(-11,-8),head+Vector2(7,-10),head+Vector2(12,-4),head+Vector2(11,11),head+Vector2(-10,11)],p,cloth)
			line(canvas,origin,head+Vector2(-9,-7),head+Vector2(8,-7),p,edge,1)
			for side in [-1,1]: circle(canvas,origin,head+Vector2(side*12,4),3.4,p,trim)
			line(canvas,origin,head+Vector2(-3,-11),head+Vector2(-4,-17),p,trim,2)
			circle(canvas,origin,head+Vector2(-4,-18),2.5,p,light)
		2:
			circle(canvas,origin,head,14,p,dark)
			circle(canvas,origin,head+Vector2(0,-1),13,p,cloth)
			for side in [-1,1]:
				var tip = head+Vector2(side*(14+sin(p.clock*3)*1.2),-18)
				line(canvas,origin,head+Vector2(side*5,-10),tip,p,trim,2)
				circle(canvas,origin,tip,2,p,light)
		3:
			circle(canvas,origin,head,14.5,p,dark)
			circle(canvas,origin,head+Vector2(0,-1),13.5,p,cloth)
			polygon(canvas,origin,[head+Vector2(-10,-7),head+Vector2(-4,-17),head+Vector2(5,-17),head+Vector2(11,-7)],p,shade)
			line(canvas,origin,head+Vector2(-7,-13),head+Vector2(7,-13),p,trim,2)
			circle(canvas,origin,head+Vector2(0,-12),2.8,p,light)
	var mask = head+Vector2(face*3,2)
	circle(canvas,origin,mask,9.3,p,dark)
	line(canvas,origin,mask+Vector2(-6,-6),mask+Vector2(4,-7),p,edge,1)
	for eye in [-2.0,4.0]:
		var eye_pos = mask+Vector2(face*eye,0)
		if p.blink or p.delight>0.3:
			line(canvas,origin,eye_pos+Vector2(-1.5,0),eye_pos+Vector2(1.5,-0.6 if p.delight>0.3 else 0),p,light,1.4)
		else:
			circle(canvas,origin,eye_pos,1.6,p,light)
	line(canvas,origin,Vector2(-10,18),Vector2(10,18),p,trim,4)
	circle(canvas,origin,Vector2(face*6,19),2.2,p,light)
	var shoulder = Vector2(face*10,23)
	var reach = Vector2(face*12,6-p.rise*4-p.fall*6).rotated(-face*p.ring)
	var hand = shoulder+reach
	var elbow = shoulder.lerp(hand,0.5)+Vector2(-face*2,3)
	line(canvas,origin,shoulder,elbow,p,shade,5)
	line(canvas,origin,elbow,hand,p,cloth,4)
	circle(canvas,origin,hand,2.6,p,trim)
	var bell = hand+Vector2(face*1,5)
	line(canvas,origin,hand,bell,p,trim,2)
	polygon(canvas,origin,[bell+Vector2(-3,-1),bell+Vector2(3,-1),bell+Vector2(5,6),bell+Vector2(7,8),bell+Vector2(-7,8),bell+Vector2(-5,6)],p,trim)
	line(canvas,origin,bell+Vector2(-6,7),bell+Vector2(6,7),p,light,2)
	line(canvas,origin,bell+Vector2(-2,1),bell+Vector2(-3,5),p,light,1)
	circle(canvas,origin,bell+Vector2(sin(p.ring*3)*2,10),1.8,p,light)
