extends SceneTree
## Watches the CPU demo: godot --headless --fixed-fps 60 --script res://tests/demo_test.gd [-- level secs]

var main
var frame := 0
var lvl := 0
var secs := 90
var started_lvl := -1


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1:
		lvl = int(a[0])
	if a.size() >= 2:
		secs = int(a[1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.start_level = lvl
		main.start_game(2, true)
	if frame % 600 == 0:
		var hp := []
		for p in main.alive_players():
			hp.append(p.hp)
		print("t=%ds state=%s level=%d kills=%d/%d hp=%s score=%d" % [frame / 60, main.state, main.level_idx + 1, main.kills, main.total, hp, main.score])
	if frame >= secs * 60 or (frame > 10 and main.state == "title"):
		print("END state=%s level=%d kills=%d demo=%s" % [main.state, main.level_idx + 1, main.kills, main.demo])
		return true
	return false
