extends SceneTree
## Labelled direct-state integration fixture, NOT movement/route evidence.
## Position resets and AI-disabled setup isolate normal host key handlers,
## actual shutter collision sweeps, retry and fresh-host Continue contracts.
class Dispatch extends Node:
 signal applied
 var pending: Callable
 func _process(_dt):
  if pending.is_valid():
   var call=pending;pending=Callable();call.call();applied.emit()
var host
var dispatch:Dispatch
var hz:=60
var checks:Array=[]
var failures:Array=[]
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--hz='):hz=int(arg.trim_prefix('--hz='))
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func check(ok:bool,label:String):
 checks.append({'label':label,'passed':ok})
 if not ok:failures.append(label);print('FAIL ',label)
func frames(n:int):
 for i in n:await physics_frame;await process_frame
func action(call:Callable):
 dispatch.pending=call
 await dispatch.applied
func send_key(code:int):
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true
 host._unhandled_key_input(e)
func stop_ai():
 for enemy in host.enemies:enemy.ai_enabled=false
func make_host():
 host=load('res://demo/mission.tscn').instantiate();root.add_child(host);host.input_override={}
func run():
 dispatch=Dispatch.new();dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(dispatch)
 make_host()
 await action(func():host.start_new(true);host.load_sector(1);stop_ai())
 await frames(3)
 var d:Dictionary=host.sectors[1]
 check(not d.get('lock',false),'Intake intentionally no longer requires all guard defeats')
 check(host.enemies.size()==8 and host.remaining_enemies()==8,'all eight original guards initially alive')
 check(host.room.shutters.size()==1,'one real relay-operated crossing shutter')
 var shutter=host.room.shutters[0]
 check(not shutter.is_open and not host.room.gate_open and host.relay_states.is_empty(),'fresh relay and shutter and logical gate closed')
 var probe:=CharacterBody2D.new();probe.collision_layer=0;probe.collision_mask=1
 var shape:=CollisionShape2D.new();shape.shape=RectangleShape2D.new();shape.shape.size=Vector2(10,10);probe.add_child(shape);root.add_child(probe)
 probe.position=shutter.global_position-Vector2(80,0)
 await frames(2)
 check(probe.test_move(probe.global_transform,Vector2(160,0)),'closed shutter blocks real body sweep at its crossing')
 await action(func():host.player.reset_actor(d.relay+Vector2(45,0),1);send_key(KEY_E))
 check(host.relay_states.is_empty(),'E exactly at45px remains out of strict interaction range')
 await action(func():host.player.reset_actor(d.relay,1);send_key(KEY_E))
 await frames(3)
 check(host.relay_states==[0] and host.relay_on,'nearby E uses original relay activation handler')
 check(shutter.is_open and shutter.collision_shape.disabled,'relay opens actual physical shutter')
 check(not probe.test_move(probe.global_transform,Vector2(160,0)),'opened crossing permits actual body sweep')
 check(host.room.gate_open and host.remaining_enemies()==8,'relay opens logical exit despite all guards surviving')
 await action(func():host.player.reset_actor(d.cache,1);send_key(KEY_E))
 check(host.state=='archive' and paused and host.caches.has(1),'normal cache interaction persists archive and pauses')
 await action(func():send_key(KEY_E))
 check(host.state=='playing' and not paused,'archive closes through normal key handler')
 var room_id=host.room.get_instance_id()
 await action(func():send_key(KEY_R))
 await frames(3)
 stop_ai()
 check(host.room.get_instance_id()!=room_id and host.sector==1,'R replaces current Intake room through ordinary retry')
 check(host.relay_states.is_empty() and not host.room.shutters[0].is_open and not host.room.gate_open,'retry resets relay and real shutter and logical exit')
 check(host.remaining_enemies()==8,'retry restores original full guard roster')
 check(host.caches.has(1) and host.room.cache_found,'retry preserves collected cache')
 check(host._valid_save(),'normal checkpoint file remains valid')
 probe.free()
 await action(func():host.free();make_host())
 check(host.continue_available and host.state=='title','fresh host offers checkpoint Continue')
 await action(func():send_key(KEY_C))
 await frames(3)
 stop_ai()
 check(host.sector==1 and host.state=='playing','C resumes normal Intake checkpoint')
 check(host.caches.has(1) and host.room.cache_found,'fresh-host Continue preserves archive')
 check(host.relay_states.is_empty() and not host.room.shutters[0].is_open and not host.room.gate_open,'Continue rebuilds relay and shutter closed as existing checkpoint rule')
 check(host.remaining_enemies()==8,'Continue restores original guard roster')
 # Explicit initial right-ground placement; all subsequent movement is controller input.
 await action(func():host.player.reset_actor(Vector2(1800,300),-1);host.input_override={"left":1.0})
 await frames(hz)
 host.input_override={}
 check(host.player.position.x<1700 and host.player.position.y>280 and not host.room.shutters[0].is_open,'actual left input recovers underneath closed crossing from right ground')
 var deaths_before:int=host.deaths
 var damage_receipts:Array=[]
 host.health.damage_processed.connect(func(receipt):damage_receipts.append(receipt.duplicate(true)))
 # Explicit below-floor/outside-wall starting fixture, still above boundary420.
 # No velocity, Health or defeat write after reset: gravity crosses the real boundary.
 await action(func():host.player.reset_actor(Vector2(-80,340),1);host.input_override={})
 for i in hz*2:
  await frames(1)
  if host.state=='dead':break
 check(host.player.position.y>420,'real gravity crosses existing boundary from labelled unsupported start')
 check(host.health.current_health==0,'boundary crossing reaches zero through actual Health receiver')
 check(host.player.get_node('DefeatResponse').active,'actual DefeatResponse is active after boundary crossing')
 check(host.state=='dead' and paused and host.deaths==deaths_before+1,'mission accepts one actual defeat receipt and pauses')
 check(not damage_receipts.is_empty(),'Health emits actual processed boundary damage receipt')
 await action(func():send_key(KEY_R))
 await frames(3)
 check(host.state=='playing' and host.health.current_health==host.health.capacity and host.relay_states.is_empty() and not host.room.shutters[0].is_open and host.caches.has(1),'R after physical defeat restores health/closed route and preserves archive')
 var report={'hz':hz,'checks':checks,'failures':failures,'damage_receipts':damage_receipts,'scope':'Direct-state setup with AI disabled; normal host key handlers, actual sweeps, controller ground-return and gravity-boundary defeat, retry/fresh-host Continue. NOT full input route evidence.'}
 var f=FileAccess.open('user://intake_lifecycle_%d.json'%hz,FileAccess.WRITE);f.store_string(JSON.stringify(report,'\t'));f.close()
 print('INTAKE LIFECYCLE ',JSON.stringify(report))
 paused=false;host.free();dispatch.free();quit(0 if failures.is_empty() else 1)
