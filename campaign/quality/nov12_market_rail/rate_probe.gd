extends "res://campaign/quality/nov12_market_rail/contract.gd"
## Separate live-callback rate readback, not a replacement for the full matrix.
func run()->void:
 host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
 for i in host.sectors.size():
  if host.sectors[i].id=="l3_inundated_market":host.load_sector(i);break
 host.set_physics_process(false);host.state="playing";paused=false
 for enemy in host.enemies:enemy.set_physics_process(false)
 driver=Driver.new();driver.actor=host.player;driver.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(driver)
 await step({},10)
 var actual:int=Engine.physics_ticks_per_second
 var dt:float=host.player._step_delta
 var ok:bool=actual==hz and absf(dt-1.0/hz)<.000001
 print(JSON.stringify({"passed":ok,"requested_hz":hz,"engine_physics_hz":actual,"actual_player_callback_dt":dt,"scope":"Separate actual campaign callback smoke check using same inherited rate setup, not telemetry from the full matrix process"}))
 driver.free();host.free();quit(0 if ok else 1)
