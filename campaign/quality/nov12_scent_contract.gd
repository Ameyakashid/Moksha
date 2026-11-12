extends SceneTree
const Query=preload("res://campaign/perception/local_scent_query.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var original:=[{"kind":"life","offset":Vector2(230,0),"wounded":true,"health":2,"identity":999}]
	var before:=original.duplicate(true)
	var marks:=Query.sample(original)
	check(original==before,"pure query leaves facts untouched")
	check(marks==[{"kind":"life","bearing":0,"band":"faint","wounded":true}],"coarse output only")
	check(Query.sample([{"kind":"life","offset":Vector2(260,15),"wounded":true}])==marks,"nearby source movement does not track exact location")
	check(Query.sample([{"kind":"life","offset":Vector2(421,0)}]).is_empty(),"out of range")
	check(Query.sample([{"kind":"supply","offset":Vector2(301,0)}]).is_empty(),"supply shorter range")
	check(Query.sample([{"kind":"life","offset":Vector2(NAN,0)},{"kind":"attack","offset":Vector2.ZERO}]).is_empty(),"invalid facts excluded")
	check(Query.sample(original+original).size()==1,"sources aggregate, no count")
	var many:Array=[]
	for i in 8:
		many.append({"kind":"life","offset":Vector2.from_angle(i*PI/4)*200})
		many.append({"kind":"supply","offset":Vector2.from_angle(i*PI/4)*200})
	check(Query.sample(many).size()==6,"bounded marks")
	for mark in Query.sample(many):check(Query.valid_mark(mark),"schema valid")
	check(not Query.valid_mark({"kind":"life","band":"near","bearing":0,"wounded":false,"position":Vector2.ZERO}),"presenter rejects precise extra field")
	var h=load("res://campaign/campaign.tscn").instantiate();h.save_enabled=false;root.add_child(h)
	h.start_new(true)
	for i in 3:await process_frame
	var index:=-1
	for i in h.sectors.size():
		if h.sectors[i].id=="l3_inundated_market":index=i
	check(index>=0,"real market exists")
	h.load_sector(index)
	for i in 3:await process_frame
	var o=h.scent
	o.set_process(false)
	# Seeded adapter fixture: placement is setup, not a traversal claim.
	h.player.position=Vector2(2700,-90);o._process(.3)
	var snap:Array=o.read_snapshot()
	check(snap.any(func(m):return m.kind=="supply"),"existing optional record produces supply scent")
	for m in snap:check(Query.valid_mark(m),"real snapshot discloses coarse fields only")
	var record:Node
	for goal in h.goals:
		if goal.objective_id=="records":record=goal
	check(record!=null and record.optional and record.kind=="recover","real optional reward identified")
	record.interact();o._process(.3)
	check(h.rewards.has("l3_inundated_market/records"),"real claim enters retained reward ledger")
	check(not o.read_snapshot().any(func(m):return m.kind=="supply"),"claimed optional record stops smelling")
	h.load_sector(index);h.player.position=Vector2(2700,-90);o._process(.3)
	check(not o.read_snapshot().any(func(m):return m.kind=="supply"),"retained reward cannot smell unclaimed after retry")
	var enemy=h.enemies[0]
	h.player.position=enemy.position-Vector2(90,0);o._process(.3)
	check(o.read_snapshot().any(func(m):return m.kind=="life" and not m.wounded),"living enemy scent")
	# Real health provider receives its admitted damage receipt, not a wound flag.
	var health_before:float=enemy._health.current_health
	enemy.take_hit(1.0,1.0) # Real compatibility damage path; not a physical-collision proof.
	check(enemy._health.current_health<health_before,"actual committed health debit")
	check(o.snapshot.is_empty(),"health change clears old mark immediately")
	o._process(.3)
	check(o.read_snapshot().any(func(m):return m.kind=="life" and m.wounded),"wound from actual health")
	var health_after:float=enemy._health.current_health
	for i in 10:o._process(.1)
	check(enemy._health.current_health==health_after,"observer cannot damage")
	h.blind=true;o._process(.3)
	check(not o.read_snapshot().is_empty(),"scent survives blind state independently")
	h.state="journal"
	check(o.read_snapshot().is_empty(),"same-frame modal snapshot fenced")
	o._process(.01);check(o.sources.is_empty() and o.snapshot.is_empty(),"menu retires registry and snapshot")
	h.state="playing";o._process(.3)
	h.session_generation+=1
	check(o.read_snapshot().is_empty(),"same-frame New/Continue generation fence")
	o._process(.3);check(o.observed_session==h.session_generation,"session rebind")
	h.state="dead";check(o.read_snapshot().is_empty(),"death presentation fence");o._process(.01)
	h.state="playing";o._process(.3)
	enemy=h.enemies[0]
	enemy.queue_free()
	await process_frame
	o._process(.3)
	check(o.collect().all(func(f):return f.kind!="life" or f.offset.is_finite()),"freed source excluded without invalid access")
	h.load_sector(index);check(o.snapshot.is_empty() and o.sources.is_empty(),"retry retires before room replacement")
	o._process(.3);o.enabled=false;o._process(.01)
	check(o.read_snapshot().is_empty() and o.sources.is_empty(),"disabled observer retires")
	h.free();await process_frame
	print("SCENT_CONTRACT_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure query and seeded real-host adapter fixtures; not traversal or native readability"}))
	quit(0 if failures.is_empty() else 1)
