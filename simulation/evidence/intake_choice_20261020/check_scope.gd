extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args()
 var old=str_to_var(FileAccess.get_file_as_string(args[0]))
 var fresh=load('res://demo/mission_data.gd').sectors()
 var failures=[]
 if old.size()!=fresh.size():failures.append('Sector count changed')
 for i in mini(old.size(),fresh.size()):
  if i!=1 and old[i]!=fresh[i]:failures.append('Other sector changed: '+str(i))
 for key in ['relay','cache','title','gate_y']:
  if old[1].get(key)!=fresh[1].get(key):failures.append('Preserved Intake identity changed: '+key)
 var old_kinds=[];var new_kinds=[]
 for entry in old[1].enemies:old_kinds.append(entry[1])
 for entry in fresh[1].enemies:new_kinds.append(entry[1])
 if old_kinds!=new_kinds:failures.append('Enemy roster/types changed')
 FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify({'failures':failures,'other_sectors_unchanged':failures.is_empty(),'scope':'Read-only authored-data invariant check; not gameplay proof'},'\t'))
 print('INTAKE SCOPE ', failures)
 quit(0 if failures.is_empty() else 1)
