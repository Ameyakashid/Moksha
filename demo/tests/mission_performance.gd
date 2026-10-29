extends "res://demo/mission.gd"
## Native steady-state rendering fixture. No gameplay duration/route claim.
var benchmark_clock:=0.0
var next_tap:=0.0
var samples: Array[Dictionary]=[]
var frame_count:=0
func _ready()->void:
	super._ready()
	save_enabled=false
	load_sector(3)
	player.reset_actor(Vector2(800,-500),1)
	input_override={}
	chapter_left=0
func _process(dt:float)->void:
	super._process(dt)
	benchmark_clock+=dt
	frame_count+=1
	if benchmark_clock>7 and not blind:
		blind=true
		_apply_trade()
		sonar.set_blind(true)
	if benchmark_clock>=next_tap:
		next_tap=benchmark_clock+0.5
		tap_weapon()
	if frame_count%15==0 and ((benchmark_clock>2 and benchmark_clock<7) or benchmark_clock>9):
		samples.append({"blind":blind,"fps":Engine.get_frames_per_second(),"frame_ms":dt*1000,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"segments":sonar.last_draw_segments})
	if benchmark_clock>15:
		var file=FileAccess.open("res://demo/evidence/native_steady_performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(samples,"\t"))
		print("STEADY NATIVE BENCHMARK COMPLETE ",samples.size()," samples")
		get_tree().quit()
