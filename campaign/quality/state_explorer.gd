extends SceneTree
## Exhaustive finite objective-state exploration, NOT a physics/TLA+ proof.
## Real interact() transitions; plate/breaker success is an explicit fixture edge.
class Facts extends Node:
	var values:Dictionary={}
	func goal_done(id:String)->bool:return values.get(id,false)
var failures:Array[String]=[]
var checks:=0
var total_states:=0
var total_edges:=0
var summaries:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var source=load("res://campaign/logic/objective.gd")
	var districts:Array=load("res://campaign/logic/campaign_data.gd").sectors()
	# Deliberately broken injected scripts prove guards detect silent mutation.
	# Never alter a production file for a negative control.
	for arg in OS.get_cmdline_user_args():
		if arg in ["--mutation=dependency","--mutation=physical"]:
			source=GDScript.new()
			source.source_code='extends "res://campaign/logic/objective.gd"\nfunc interact()->bool:\n\tcompleted=true\n\tsetting=2\n\treturn false\n'
			check(source.reload()==OK,"negative-control script compiles")
			districts=[{"id":"negative_control","objectives":[{"id":"bad","label":"bad","at":Vector2.ZERO,"kind":"breaker" if arg.ends_with("physical") else "terminal","requires":[] if arg.ends_with("physical") else ["missing"]}]}]
	for district in districts:
		var facts:=Facts.new()
		var nodes:Array=[]
		var initial:Array=[]
		for spec in district.get("objectives",[]):
			var objective=source.new();objective.configure(spec,facts)
			nodes.append(objective);initial.append(-1 if objective.kind=="route" else 0)
		var queue:Array=[initial];var seen:Dictionary={JSON.stringify(initial):true}
		var cursor:=0;var edges:=0;var can_finish:=false;var can_complete_all:=false
		while cursor<queue.size():
			var state:Array=queue[cursor];cursor+=1
			var all_done:=true;var required_done:=true
			for i in nodes.size():
				var done:bool=state[i]==nodes[i].target if nodes[i].kind=="route" else state[i]==1
				all_done=all_done and done
				required_done=required_done and (nodes[i].optional or done)
			can_finish=can_finish or required_done;can_complete_all=can_complete_all or all_done
			for action in nodes.size():
				facts.values.clear()
				for i in nodes.size():
					nodes[i].setting=state[i] if nodes[i].kind=="route" else -1
					nodes[i].completed=state[i]==nodes[i].target if nodes[i].kind=="route" else state[i]==1
					facts.values[nodes[i].objective_id]=nodes[i].completed
				var node=nodes[action]
				var available:bool=node.required_ids.all(func(id):return facts.goal_done(id))
				var before_setting:int=node.setting
				var before_completed:bool=node.completed
				var accepted:bool=node.interact()
				check(not accepted or available,district.id+" prerequisite bypass")
				if not available:
					check(node.setting==before_setting and node.completed==before_completed,district.id+" blocked interaction mutated selected objective")
				if node.kind in ["plate","breaker"]:
					check(not accepted,district.id+" physical objective accepted E")
					check(node.setting==before_setting and node.completed==before_completed,district.id+" physical E mutated selected objective")
					# Abstract external physical success only when dependencies hold.
					if available:node.completed=true
				var next:Array=[]
				for i in nodes.size():
					next.append(nodes[i].setting if nodes[i].kind=="route" else int(nodes[i].completed))
					if i!=action:check(next[i]==state[i],district.id+" unrelated objective changed")
				if node.kind=="route" and accepted:
					check(node.setting==(int(state[action])+1)%3 and node.completed==(node.setting==node.target),district.id+" route cycle")
				elif node.kind!="route":check(not bool(state[action]) or node.completed,district.id+" latched objective lost")
				edges+=1
				var key:=JSON.stringify(next)
				if not seen.has(key):seen[key]=true;queue.append(next)
			check(queue.size()<=100000,district.id+" exploration state budget exceeded")
			if queue.size()>100000:break
		check(can_finish,district.id+" no reachable required-goal completion")
		check(can_complete_all,district.id+" no reachable all-objective completion")
		summaries.append({"district":district.id,"states":seen.size(),"edges":edges,"required_reachable":can_finish,"all_reachable":can_complete_all})
		total_states+=seen.size();total_edges+=edges
		for node in nodes:node.free()
		facts.free()
	var result={"passed":failures.is_empty(),"checks":checks,"states":total_states,"edges":total_edges,"districts":summaries,"failures":failures,"scope":"Finite objective state graph; actual interact transitions. Physical success abstracted; does not prove movement, captain seals, freight, full campaign, timing or cross-platform determinism."}
	print("STATE_EXPLORER_RESULT "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
