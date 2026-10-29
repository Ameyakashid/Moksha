extends RefCounted
## View-only, skippable prologue. Authored timing; no controller/physics mutation.
## Cock -> hold -> release -> hold -> flight -> head dodge/catch -> hold.
static func eased(t:float,a:float,b:float)->float:
	var u:=clampf((t-a)/(b-a),0,1)
	return u*u*(3-2*u)
static func pose(t:float)->Dictionary:
	var release:=eased(t,0.40,0.55)
	var dodge:=eased(t,1.00,1.15)
	var settle:=eased(t,1.45,2.1)
	var caught:=t>=1.15
	var hand:=Vector2(590,184).lerp(Vector2(523,198),release)
	var flight:=clampf((t-0.72)/0.43,0,1)
	var tip:=hand.x-10 if t<0.72 else lerpf(513,335,flight)
	return {"throw_hand":hand,"spear_tip":Vector2(tip,198),"head":Vector2(335,198).lerp(Vector2(317,195),dodge),"catch_hand":Vector2(305,238).lerp(Vector2(335,198),dodge),"caught":caught,"settle":settle}
static func draw(c:Node2D,t:float)->void:
	var p:=pose(t)
	var quiet:=Color("47626b")
	var actor:=Color("b8dce0")
	var hostile:=Color("bf9382")
	c.draw_line(Vector2(280,274),Vector2(596,274),quiet,1)
	for i in range(12):
		var x:=286+float(i*27)
		var y:=172+fmod(float(i*13)+t*34,96)
		c.draw_line(Vector2(x,y),Vector2(x-3,y+7),Color(0.4,0.6,0.66,0.2),0.7)
	# Thrower's fixed connected body and committed throwing shoulder.
	var shoulder:=Vector2(558,213)
	var hip:=Vector2(562,245)
	c.draw_circle(Vector2(557,198),7,hostile,false,1.3,true)
	c.draw_line(Vector2(557,205),shoulder,hostile,1.3,true)
	c.draw_line(shoulder,hip,hostile,1.5,true)
	c.draw_polyline(PackedVector2Array([hip,Vector2(550,257),Vector2(542,273)]),hostile,1.4,true)
	c.draw_polyline(PackedVector2Array([hip,Vector2(576,259),Vector2(585,273)]),hostile,1.4,true)
	var hand:Vector2=p.throw_hand
	var elbow:=shoulder.lerp(hand,0.5)+Vector2(0,-7)
	c.draw_polyline(PackedVector2Array([shoulder,elbow,hand]),hostile,1.4,true)
	c.draw_polyline(PackedVector2Array([shoulder,Vector2(544,226),Vector2(533,219)]),hostile,1.2,true)
	# Neck connects to the dodging head; catching hand ends at its former position.
	var head:Vector2=p.head
	var neck:=head+Vector2(2,8)
	var chest:=Vector2(329,220)
	var pelvis:=Vector2(327,246)
	c.draw_circle(head,7,actor,false,1.5,true)
	c.draw_polyline(PackedVector2Array([neck,chest,pelvis]),actor,1.6,true)
	c.draw_polyline(PackedVector2Array([pelvis,Vector2(313,258),Vector2(303,273)]),actor,1.5,true)
	c.draw_polyline(PackedVector2Array([pelvis,Vector2(339,257),Vector2(347,273)]),actor,1.5,true)
	var catch_hand:Vector2=p.catch_hand
	c.draw_polyline(PackedVector2Array([chest,Vector2(342,219),catch_hand]),actor,1.5,true)
	c.draw_polyline(PackedVector2Array([chest,Vector2(313,230),Vector2(303,235)]),actor,1.3,true)
	var tip:Vector2=p.spear_tip
	c.draw_line(tip,tip+Vector2(67,0),Color("e8d4ad"),1.7,true)
	c.draw_polyline(PackedVector2Array([tip+Vector2(7,-3),tip,tip+Vector2(7,3)]),Color("e8d4ad"),1.2,true)
	if p.caught:
		var flash:=1.0-eased(t,1.15,1.4)
		if flash>0: c.draw_circle(catch_hand,7+3*(1-flash),Color(0.9,1,1,flash),false,1.2,true)
		c.draw_string(ThemeDB.fallback_font,Vector2(367,248),"CAUGHT.",HORIZONTAL_ALIGNMENT_LEFT,-1,10,actor)
