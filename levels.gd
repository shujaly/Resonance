extends RefCounted

static func p(x, y, w, kind="stone"):
	return {"x": float(x), "y": float(y), "w": float(w), "kind": kind, "until": 0.0}

static func h(x, y, span, phase=0.0):
	return {"x": float(x), "y": float(y), "span": float(span), "phase": float(phase)}

static func o(kind, x, y, phase=0.0):
	return {"kind": kind, "x": float(x), "y": float(y), "phase": float(phase)}

static func make(index):
	var d = {"name": "", "subtitle": "", "bg": "", "length": 2600.0, "height": 900.0, "spawn": Vector2(98, 548), "finish": Vector2(2440, 500), "platforms": [], "hazards": [], "obstacles": [], "notes": [], "echoes": [], "splits": [840.0, 1660.0], "par": [95.0, 150.0, 210.0], "gold": 53.0, "silver": 68.0, "bronze": 90.0, "theme": Color("f8bd67")}
	match index:
		0:
			d.name = "THE RAIN ARCADE"
			d.subtitle = "Listen. Leap. Ring."
			d.bg = "res://art/arcade.png"
			d.theme = Color("6fd6ee")
			d.platforms = [p(0,610,330),p(348,610,115,"glass"),p(480,570,125),p(626,535,100,"glass"),p(746,550,155),p(918,550,125,"glass"),p(1058,505,130),p(1208,470,105,"bronze"),p(1335,510,125,"glass"),p(1482,550,160),p(1660,550,120,"glass"),p(1800,515,135),p(1954,485,110,"glass"),p(2084,520,160),p(2258,560,300),p(770,380,95),p(1570,365,95,"glass")]
			d.notes = [Vector2(817,337),Vector2(1250,425),Vector2(1618,322)]
			d.hazards = [h(790,300,80,0.2)]
			d.obstacles = [o("steam",545,570,0.1),o("spikes",1535,550),o("steam",1890,515,1.4)]
			d.finish = Vector2(2400,516)
			d.gold = 14.0; d.silver = 23.0; d.bronze = 35.0
		1:
			d.name = "PENDULUM HALL"
			d.subtitle = "Move with the mechanism."
			d.bg = "res://art/pendulum.png"
			d.theme = Color("f4b060")
			d.platforms = [p(0,610,240),p(260,580,120),p(405,540,100,"glass"),p(525,500,150),p(690,535,115,"bronze"),p(825,485,130,"glass"),p(974,455,145),p(1135,505,110,"glass"),p(1260,545,150),p(1428,505,105,"bronze"),p(1550,460,120,"glass"),p(1685,430,145),p(1848,480,105,"glass"),p(1968,530,155),p(2138,565,135,"glass"),p(2290,590,275),p(875,300,85),p(1740,270,100)]
			d.notes = [Vector2(923,257),Vector2(1480,462),Vector2(1790,227)]
			d.hazards = [h(590,270,120,0.0),h(1090,350,140,1.7),h(1740,170,95,2.9),h(2050,425,90,0.7)]
			d.obstacles = [o("steam",323,580,0.5),o("spikes",1050,455),o("piston",1330,425,1.0),o("steam",2010,530,1.7)]
			d.finish = Vector2(2420,546)
			d.gold = 17.0; d.silver = 27.0; d.bronze = 40.0
		2:
			d.name = "MIRROR GALLERY"
			d.subtitle = "Let an echo open the way."
			d.bg = "res://art/mirror.png"
			d.theme = Color("bd9eff")
			d.platforms = [p(0,610,280),p(298,610,125,"glass"),p(440,580,145),p(600,550,110,"glass"),p(728,520,150),p(898,520,135,"glass"),p(1050,470,140,"glass"),p(1210,490,135),p(1360,530,110,"glass"),p(1490,570,150),p(1655,535,120,"glass"),p(1794,500,120,"glass"),p(1928,525,140),p(2082,560,120,"bronze"),p(2220,590,350),p(550,360,120,"glass"),p(1170,315,100,"glass"),p(1740,325,125,"glass")]
			d.echoes = [Vector2(760,468),Vector2(1550,518)]
			d.notes = [Vector2(610,318),Vector2(1220,273),Vector2(1800,283)]
			d.hazards = [h(2040,360,100,2.0)]
			d.obstacles = [o("steam",500,580,0.2),o("piston",1200,230,0.6),o("spikes",1800,325),o("steam",2270,590,1.4)]
			d.finish = Vector2(2410,546)
			d.gold = 18.0; d.silver = 29.0; d.bronze = 43.0
		3:
			d.name = "CLOCKWORK SHAFT"
			d.subtitle = "Climb above the storm."
			d.bg = "res://art/shaft.png"
			d.height = 1250.0
			d.spawn = Vector2(95,958)
			d.theme = Color("79deb7")
			d.platforms = [p(0,1020,260),p(280,975,130),p(430,925,115,"glass"),p(565,870,120),p(705,820,115,"bronze"),p(840,770,120,"glass"),p(980,720,145),p(1145,670,110,"glass"),p(1270,625,140),p(1425,575,115,"bronze"),p(1560,525,130,"glass"),p(1710,475,140),p(1870,435,110,"glass"),p(2000,390,125),p(2145,355,115,"glass"),p(2280,325,280),p(910,565,95,"glass"),p(1630,340,90,"glass")]
			d.notes = [Vector2(960,523),Vector2(1480,530),Vector2(1680,298)]
			d.hazards = [h(1790,410,120,1.8)]
			d.obstacles = [o("steam",625,870,0.8),o("piston",910,490,0.5),o("spikes",1745,475),o("steam",2060,390,1.7)]
			d.finish = Vector2(2420,280)
			d.splits = [900.0, 1700.0]
			d.gold = 18.0; d.silver = 29.0; d.bronze = 43.0
		4:
			d.name = "THE GREAT BELFRY"
			d.subtitle = "One final chord."
			d.bg = "res://art/belfry.png"
			d.height = 1050.0
			d.spawn = Vector2(95,788)
			d.theme = Color("ffe3a1")
			d.platforms = [p(0,850,240),p(260,810,110,"glass"),p(390,765,130),p(540,720,100,"bronze"),p(660,680,120,"glass"),p(800,645,145),p(962,610,110,"glass"),p(1095,575,130),p(1245,540,105,"bronze"),p(1368,505,115,"glass"),p(1500,465,120),p(1638,430,115,"glass"),p(1772,400,125),p(1915,365,110,"glass"),p(2042,330,110,"bronze"),p(2170,300,130,"glass"),p(2315,270,245),p(730,450,100,"glass"),p(1540,280,100,"glass")]
			d.echoes = [Vector2(870,594),Vector2(1780,347)]
			d.notes = [Vector2(790,408),Vector2(1570,238),Vector2(2095,280)]
			d.hazards = [h(720,580,110,0.3),h(1730,235,110,2.2),h(2220,225,90,3.1)]
			d.obstacles = [o("steam",730,450,0.2),o("piston",1180,470,1.2),o("spikes",1590,280),o("steam",2350,270,1.7)]
			d.finish = Vector2(2440,226)
			d.gold = 17.0; d.silver = 28.0; d.bronze = 42.0
	return d
