extends SceneTree
## Headless smoke test: godot --headless --script res://tests/smoke_test.gd

var main
var frame := 0
var errors: Array = []
var phase := 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func check(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.load_level(0, true)
		main.player.shield = 9999.0
	if frame == 200:
		check(main.enemies.size() > 0, "enemies spawned")
		for t in main.ITEM_TYPES:
			main.apply_item(t)
		check(main.player.weapon == 1, "star raises weapon")
		check(main.freeze_t > 0.0 and main.radar_t > 0.0, "freeze + radar active")
		check(main.kills > 0, "bomb killed enemies")
		main.spawn_item_random()
		check(main.items.size() == 1, "item spawned")
	if frame == 260:
		# walk player over the item
		main.player.global_position = main.items[0].node.global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
	if frame == 280:
		check(main.items.is_empty(), "item picked up")
	if frame > 300 and phase == 0:
		if main.state == "playing" and frame % 30 == 0:
			main.apply_item("bomb")
			main.player.shield = 9999.0
		if main.level_idx == 2 and main.state == "playing":
			phase = 1
			frame = 2999
		elif frame > 9000:
			check(false, "reached level 3")
			quit(1)
	if phase == 1 and frame == 3000:
		check(main.level_idx == 2, "advanced to level 3 (level=%d state=%s)" % [main.level_idx, main.state])
		# put player on a ramp and drive up onto high ground
		var ramp := Vector2i(10, 8)
		main.player.global_position = main.cell_center(ramp) + Vector3(0, 0.4, 0.3)
		main.player.shield = 9999.0
	if phase == 1 and frame > 3000 and frame < 3030:
		Input.action_press("move_up")
	if phase == 1 and frame == 3030:
		Input.action_release("move_up")
		check(main.player.global_position.y > 0.5 and main.player.is_on_floor(), "player climbed ramp to high ground (y=%.2f)" % main.player.global_position.y)
	if phase == 1 and frame == 3130:
		print("RESULT: ", "PASS" if errors.is_empty() else "FAIL %s" % [errors])
		quit(0 if errors.is_empty() else 1)
	return false
