extends SceneTree
## Read-only presentation fixtures. They are not campaign traversal or human QA.
const HUD=preload("res://campaign/views/campaign_hud.gd")
const Owner=preload("res://campaign/views/campaign_hud_owner.gd")
const Caption=preload("res://campaign/views/objective_caption.gd")
var failures:Array[String]=[]
var checks:=0
var worst_header:=0.0
var worst_panel:=0.0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func line_width(line:String,size:int)->float:
	return ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
func check_panel(view:Node2D,snapshot:Dictionary,label:String)->void:
	var layout:Dictionary=view.panel_layout(snapshot.panel_title,snapshot.panel_body,snapshot.panel_footer)
	var body_bottom:float=layout.body_top+(layout.body_lines.size()-1)*(layout.body_size+3)
	worst_panel=maxf(worst_panel,body_bottom)
	check(body_bottom<=276,label+" body clear of footer")
	for line in layout.body_lines:check(line_width(line,layout.body_size)<=528.01,label+" bounded body")
	for line in layout.title_lines:check(line_width(line,layout.title_size)<=532.01,label+" bounded title")
	for line in layout.footer_lines:check(line_width(line,11)<=532.01,label+" bounded footer")
	check(layout.footer_lines.size()<=3,label+" footer clear of bottom")
func run()->void:
	var view:=HUD.new()
	var token:="long_".repeat(90)
	for width in [40.0,160.0,528.0]:
		for size in [9,11,16]:
			var lines:Array=view.panel_lines("a\n\n"+token,size,width)
			check(lines[0]=="a" and lines[1].is_empty(),"paragraph spacing retained")
			check("".join(lines.slice(2))==token,"long token no characters lost")
			for line in lines:check(line_width(line,size)<=width+.01,"long token bounded")
	var keyboard_token:=RegEx.new();keyboard_token.compile("\\b(E|J|Q|K|TAB|Space|Shift)\\b|W/S")
	for district in load("res://campaign/logic/campaign_data.gd").sectors():
		for field in ["text","hint"]:
			check(keyboard_token.search(HUD.device_text(str(district.get(field,"")),true))==null,"controller chapter prose no stale keyboard keys "+str(district.id)+"/"+field)
	var host=load("res://campaign/campaign.tscn").instantiate()
	root.add_child(host);host.save_enabled=false;host.start_new(true)
	var real_view:Node2D=host.hud.get_node("View")
	await process_frame;await process_frame
	check(host.hud.get_script()==Owner,"production campaign uses typed campaign HUD owner")
	for key in Owner.CAMPAIGN_FIELDS:
		check(real_view.data.has(key),"real host owner view pipeline retains "+key)
		check(real_view.data.get(key)==host._hud_snapshot().get(key),"real pipeline value "+key)
	var accepted:Dictionary=host.hud.get_snapshot()
	for key in Owner.CAMPAIGN_FIELDS:
		var rejected:Dictionary=host._hud_snapshot();rejected[key]=[]
		check(not host.hud.set_snapshot(rejected),"typed owner rejects invalid "+key)
		check(host.hud.get_snapshot()==accepted and real_view.data==accepted,"bad field keeps owner and view unchanged "+key)
	var bad_base:Dictionary=host._hud_snapshot();bad_base.health_capacity=0
	check(not host.hud.set_snapshot(bad_base),"base validation still authoritative")
	check(host.hud.get_snapshot()==accepted and real_view.data==accepted,"base rejection is atomic with campaign fields")
	for controller in [false,true]:
		for row in view.pause_controls(controller):
			check(line_width(row.key,9)<=row.key_box.size.x-12,"pause key label fits separate box")
			check(line_width(row.action,11)<=row.action_width,"pause action fits column")
			check(row.key_box.end.x<row.action_at.x,"pause key/action have deliberate separation")
			check(row.action_at.y<=233,"pause controls clear of retry explanation")
	check(HUD.device_text("[E] use · [J] strike · Q taps · E at its cradle",true)=="[Y] use · [X] strike · B taps · Y at its cradle","controller explicit actions accurately translated")
	check(HUD.device_text("The operative's journey is not finished.",true)=="The operative's journey is not finished.","controller conversion leaves prose untouched")
	check(HUD.device_text("[E] use",false)=="[E] use","keyboard hint retained")
	var duplicate_command:="BREAK AUTHORITY FEED / J [J]"
	check(HUD.device_text(duplicate_command,false)=="BREAK AUTHORITY FEED [J]","keyboard duplicated authored strike suffix normalized")
	check(HUD.device_text(duplicate_command,true)=="BREAK AUTHORITY FEED [X]","controller duplicated authored strike suffix normalized")
	check(HUD.device_text(duplicate_command+" · TAB journal",false)=="BREAK AUTHORITY FEED [J] · TAB journal","suffix normalization retains surrounding guidance")
	check(HUD.device_text("BREAK AUTHORITY FEED / J",false)=="BREAK AUTHORITY FEED / J","authored standalone command suffix retained")
	check(HUD.normalize_command_suffix("J / K [J] and [E] use")=="J / K [J] and [E] use","unrelated control pairs and prompts unchanged")
	var duplicate_snapshot:={"guidance":duplicate_command,"input_device":"controller"}
	check(" ".join(view.playing_layout(duplicate_snapshot).guidance)=="BREAK AUTHORITY FEED [X]","real playing layout consumes normalized device text")
	check(duplicate_snapshot.guidance==duplicate_command,"normalizing view leaves authored snapshot unchanged")
	for state in ["title","intro","journal","choice","archive","upgrade","final_choice","dead","complete"]:
		var footer:String=view.controller_footer(state,"")
		check(not footer.is_empty(),"controller footer for "+state)
		check(line_width(footer,11)<=532,"controller footer fits "+state)
	var keyboard_footers:=["J  Trade sight     K / Esc  Keep sight","J / K / L  Choose and ascend","J  PUBLIC RECORD    K  LOCAL CUSTODY","A / D or arrows Pages    TAB / ESC Return","R / Enter  Retry checkpoint     N  Title","ENTER New campaign   C Previous checkpoint"]
	for footer in keyboard_footers:
		var separated:=HUD.footer_groups(footer)
		check(line_width(" ".join(view.panel_lines(separated,11,532)),11)<=532,"keyboard grouped footer fits")
		check(view.panel_layout("Fixture","",footer).footer_lines==view.panel_lines(separated,11,532),"actual panel uses grouped footer")
	check(HUD.footer_groups("J  Trade sight     K / Esc  Keep sight")=="J  Trade sight · K / Esc  Keep sight","keyboard choice separates commands, not key and action")
	check(HUD.footer_groups("X Force  Y Agility  B Vitality")=="X Force · Y Agility · B Vitality","two-space command groups separated")
	check(HUD.footer_groups("A Return\n\n  X Select  Y Back")=="A Return\n\n  X Select · Y Back","footer line breaks and leading padding preserved")
	check(HUD.footer_groups("A single-space prose line.")=="A single-space prose line.","footer single-space prose unchanged")
	check(view.controller_footer("choice","")=="X Trade sight · B Keep sight","controller choice has visible group separator")
	check(view.controller_footer("upgrade","")=="X Force · Y Agility · B Vitality","controller upgrades have visible group separators")
	for state in ["journal","choice","upgrade","final_choice","dead"]:
		check(" · " in view.controller_footer(state,""),"controller multiple-command footer separated "+state)
	var long_notice:Dictionary=view.playing_layout({"notice_visible":true,"notice":"A very long external notice ".repeat(100)})
	check(long_notice.context.size()==2 and long_notice.context_truncated,"oversize nonauthored notice remains two lines")
	check(long_notice.context[-1].ends_with("…"),"oversize notice visibly indicates shortening")
	check(line_width("BACK journal   START pause",9)<=148,"pad controls fit right footer")
	check(line_width("Stick / D-pad move   A jump   X strike   LB guard   RB roll   B sonar   Y use",9)<=450,"pad controls clear right footer")
	for i in host.sectors.size():
		host.state="playing";paused=false;host.load_sector(i)
		host.upgrades.assign(["force","agility","vitality","force"])
		var snapshot:Dictionary=host._hud_snapshot()
		var before:=snapshot.duplicate(true)
		var layout:Dictionary=view.playing_layout(snapshot)
		worst_header=maxf(worst_header,layout.header_height)
		check(layout.header_height<=85,"header preserves playfield "+str(i))
		for line in layout.guidance:check(line_width(line,11)<=563.01,"full readable goal "+str(i))
		check(before==snapshot,"layout does not mutate snapshot")
		real_view.set_snapshot(snapshot);await process_frame
		for goal in host.goals:
			host.player.position=goal.position
			snapshot=host._hud_snapshot();layout=view.playing_layout(snapshot)
			check(layout.context_top>=305 or layout.context_notice,"nearby prompt stays below floor feet "+str(i))
			check(not layout.context_truncated,"authored nearby prompt fully retained "+str(i))
			for line in layout.context:check(line_width(line,11)<=588.01,"nearby prompt bounded")
			var notice:Dictionary=snapshot.duplicate(true)
			notice.notice_visible=true;notice.notice=goal.label+" · COMPLETE — "+str(goal.specification.get("text",""))
			layout=view.playing_layout(notice)
			check(layout.context_notice and layout.context_top>=layout.header_height,"completion notice is below HUD "+str(i))
			check(layout.context_top+layout.context_height<160,"completion notice clear of floor actor "+str(i))
			check(layout.context.size()<=2,"completion notice at most two lines "+str(i))
			check(not layout.context_truncated,"authored completion prose fully retained "+str(i))
			real_view.set_snapshot(notice);await process_frame
		host.state="journal"
		for page in maxi(1,ceili(host._journal_rows().size()/5.0)):
			host.journal_page=page;snapshot=host._hud_snapshot()
			check_panel(view,snapshot,"journal %d/%d"%[i,page])
			real_view.set_snapshot(snapshot);await process_frame
	for device in ["keyboard","controller"]:
		# Explicit device fixture; event-routing tests belong to controller suite.
		host.gamepad_navigation.input_device=device
		for state in ["title","paused","upgrade","final_choice","complete"]:
			host.state=state
			var snapshot:Dictionary=host._hud_snapshot()
			check_panel(view,snapshot,state+" / "+device)
			check(host.hud.set_snapshot(snapshot),"production owner accepts "+device+" modal")
			await process_frame;await process_frame
			check(real_view.data.get("input_device")==device,"modal device reaches actual View")
	for health in [-1.0,0.0,.01,18.0,18.1,60.0,100.0]:
		var layout:Dictionary=view.playing_layout({"health_current":health,"health_capacity":60})
		check(layout.health_ratio>=0 and layout.health_ratio<=1,"health bar clamped")
		check(layout.low_health==(health>0 and health<=18),"low health threshold")
		check(layout.health_current>0 if health>0 else layout.health_current==0,"living player not shown as zero HP")
	for kind in ["route","breaker","plate","terminal","recover","rescue","install"]:
		for completed in [false,true]:
			for available in [false,true]:
				for optional in [false,true]:
					var description:Dictionary=Caption.describe(kind,"Fixture goal",completed,available,-1,2,optional)
					check(description.title=="Fixture goal","caption preserves name")
					check(("OPTIONAL" in description.detail)==optional,"optional goals explicit")
					if not completed and not available:check("LOCKED" in description.detail and "E ·" not in description.detail and "J ·" not in description.detail,"locked action not advertised")
					if completed and kind=="route":check(("E CHANGES ROUTE" if available else "INPUT LOCKED") in description.detail,"matched route explains legal input")
					elif completed:check("COMPLETE" in description.detail,"completed goal text")
					elif available and kind=="breaker":check(description.detail.contains("J ·"),"breaker never E")
					elif available and kind=="plate":check(description.detail.contains("CARGO"),"plate never E")
	for kind in ["route","breaker","terminal","rescue"]:
		var description:Dictionary=Caption.describe(kind,"Fixture / J",false,true,-1,2,false,true)
		check("E ·" not in description.detail and "J ·" not in description.detail and "E →" not in description.detail,"controller caption no keyboard actions")
		check(description.title=="Fixture / X","controller caption authored strike suffix")
	for setting in [-1,0,1,2]:
		var description:Dictionary=Caption.describe("route","Route",false,true,setting,2)
		check("E → %d"%[(setting+1)%3] in description.detail,"route predicts next exact state")
	for x in [4,320,636]:
		for y in [4,180,356]:
			for zoom in [.5,1.0,2.0]:
				var transform:=Transform2D(Vector2(zoom,0),Vector2(0,zoom),Vector2(x,y))
				var result:Dictionary=Caption.place_block(Vector2(-60,-100),Vector2(200,60),10,transform,Rect2(0,0,640,360))
				check(result.draw,"onscreen objective still draws")
				check(result.screen_box.position.x>=7.99 and result.screen_box.end.x<=632.01,"caption block horizontal bounds")
				check(result.screen_box.position.y>=7.99 and result.screen_box.end.y<=352.01,"caption block vertical bounds")
	print("NOV6_PRESENTATION checks=",checks," failures=",failures," worst_header=",worst_header," worst_panel_baseline=",worst_panel)
	view.free();host.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
