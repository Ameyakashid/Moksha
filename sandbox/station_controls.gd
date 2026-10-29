extends Node2D
## Test-bench shell only. Stations are authored scene compositions, not generated rooms.
@export var station_title:="MODULE BENCH"
@export_multiline var station_description:=""
@export_node_path("Node2D") var player_path:=NodePath("Player")
@export_node_path("Node2D") var cradle_path:=NodePath("")
const STATIONS=["res://sandbox/stations/traversal.tscn","res://sandbox/stations/combat.tscn","res://sandbox/stations/freight.tscn"]
var status:Label
func _ready()->void:
	var title=get_node_or_null("Overlay/Title")
	var text=get_node_or_null("Overlay/Description")
	status=get_node_or_null("Overlay/Status")
	if is_instance_valid(title):title.text=station_title
	if is_instance_valid(text):text.text=station_description+"\n1 Traversal   2 Combat   3 Freight   R reset station"
func _process(_dt:float)->void:
	if not is_instance_valid(status):return
	var player=get_node_or_null(player_path)
	if not is_instance_valid(player):status.text="Player module absent; other pieces remain independent.";return
	var health=player.get_node_or_null("Health")
	status.text="PC health %.0f | %s | A/D move  Space jump  J attack  K guard  W/S climb"%[health.current_health,player.main_action]
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
		get_tree().change_scene_to_file(STATIONS[event.physical_keycode-KEY_1])
	elif event.physical_keycode==KEY_R:get_tree().reload_current_scene()
	elif event.physical_keycode==KEY_E and not cradle_path.is_empty():
		var cradle=get_node_or_null(cradle_path);var player=get_node_or_null(player_path)
		if is_instance_valid(cradle) and is_instance_valid(player):cradle.interact(player)
