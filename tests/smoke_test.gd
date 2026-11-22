extends SceneTree
## Headless smoke test: godot --headless --fixed-fps 60 --script res://tests/smoke_test.gd

var main
var frame := 0
var errors: Array = []
var phase := 0
var p1
var p2
var flame_victim
var clash_a
var clash_b


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func check(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)


func god_mode() -> void:
	for p in main.alive_players():
		p.shield = 9999.0


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		check(main.state == "title", "starts on title screen")
		main.start_game(2)
		check(main.state == "brief", "briefing screen before the level")
		main.begin_level()
		check(main.players.size() == 2, "two players spawned")
		p1 = main.players[0]
		p2 = main.players[1]
		god_mode()
	if frame == 100:
		# a player bullet and an enemy bullet flying at each other cancel out
		var c := Vector3(10.5, 5.0, 8.5)
		clash_a = main.spawn_bullet(p1, Vector3(1, 0, 0), 12.0, 1)
		clash_a.shooter_rid = RID()
		clash_a.global_position = c - Vector3(1.5, 0, 0)
		clash_b = main.spawn_bullet(p1, Vector3(-1, 0, 0), 12.0, 1)
		clash_b.shooter_rid = RID()
		clash_b.from_player = false
		clash_b.global_position = c + Vector3(1.5, 0, 0)
	if frame == 115:
		check(not is_instance_valid(clash_a) and not is_instance_valid(clash_b), "player and enemy bullets cancel each other")
	if frame == 200:
		check(main.enemies.size() > 0, "enemies spawned")
		for t in main.ITEM_TYPES:
			main.apply_item(t)
		check(p1.weapon == 1 and p2.weapon == 1, "star upgrades both players")
		check(main.speed_t > 0.0 and main.slow_t > 0.0, "speed + slow items active")
		check(main.player_speed_mult() > 1.5 and main.enemy_speed_mult() < 0.5, "speed multipliers applied")
		check(main.kills > 0, "bomb killed enemies")
		main.spawn_item_random("star")
		check(main.items.size() == 1, "item spawned")
	if frame == 260:
		p2.global_position = main.items[0].node.global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
	if frame == 280:
		check(main.items.is_empty() and p1.weapon == 2, "player 2 pickup upgrades player 1 too")
		# thief reverse effects
		main.steal_item("star")
		check(p1.weapon == 1, "stolen star downgrades weapon")
		main.steal_item("flame")
		check(main.enemy_flame_t > 0.0, "stolen flamethrower arms the enemies")
		main.enemy_flame_t = 0.0
		main.spawn_mine(Vector3(15.5, 0, 16.5))
		check(main.mines.size() == 1, "mine placed")
	if frame == 300:
		# amphibious: player 1 drives north from land into the river at row 5
		main.apply_item("amphibious")
		p1.global_position = Vector3(1.5, 0.05, 6.5)
		p1.velocity = Vector3.ZERO
	if frame > 300 and frame < 318:
		Input.action_press("p1_up")
	if frame == 318:
		Input.action_release("p1_up")
		check(main.cells.get(main.cell_of(p1.global_position)) == "W", "amphibious tank drives onto water (z=%.2f)" % p1.global_position.z)
		main.amphibious_t = 0.0
	if frame == 330:
		check(p1.water_pass, "amphibious stays on while still on water")
		# step on the mine with full shield: mine is used up, no damage
		p2.global_position = Vector3(15.5, 0.05, 16.5)
	if frame == 340:
		check(main.mines.is_empty(), "mine triggers when driven over")
		main.freeze_t = 0.0
		main.spawn_item_random("speed")
		var th = main.TankScript.new()
		main.level_root.add_child(th)
		th.setup(main, false, "thief")
		th.global_position = main.items[0].node.global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
		main.enemies.append(th)
	if frame == 360:
		check(main.enemy_fast_t > 0.0, "thief steals speed item: enemies get faster")
		main.apply_item("flame")
		main.freeze_t = 5.0  # keep the victim still so the check is deterministic
		p2.facing = Vector3(0, 0, -1)
		var vic = main.TankScript.new()
		main.level_root.add_child(vic)
		vic.setup(main, false, "basic")
		vic.global_position = p2.global_position + Vector3(0, 0, -1.0)
		main.enemies.append(vic)
		flame_victim = vic
	if frame == 395:
		check(not is_instance_valid(flame_victim) or flame_victim.dead, "player flamethrower burns the enemy in front")
	if frame > 400 and phase == 0:
		if main.state == "playing" and frame % 30 == 0:
			main.apply_item("bomb")
			god_mode()
		if main.state == "brief":
			main.begin_level()
			god_mode()
		if main.level_idx == 2 and main.state == "playing" and main.kills == 0:
			phase = 1
			frame = 2999
		elif frame > 9000:
			check(false, "reached level 3 (level=%d state=%s)" % [main.level_idx, main.state])
			print("RESULT: FAIL")
			quit(1)
	if phase == 1 and frame == 3000:
		check(main.level_idx == 2, "advanced to level 3")
		p1 = main.players[0]
		god_mode()
		p1.global_position = main.cell_center(Vector2i(8, 11)) + Vector3(0, 0.4, 0.3)
	if phase == 1 and frame > 3000 and frame < 3030:
		Input.action_press("p1_up")
	if phase == 1 and frame == 3030:
		Input.action_release("p1_up")
		check(p1.global_position.y > 0.5 and p1.is_on_floor(), "player climbed ramp to high ground (y=%.2f)" % p1.global_position.y)
		# languages
		for l in ["th", "en", "de", "nl"]:
			main.lang = l
			check(main.tr_("btn_start") != "btn_start", "translation exists for " + l)
	if phase == 1 and frame == 3040:
		print("RESULT: ", "PASS" if errors.is_empty() else "FAIL %s" % [errors])
		quit(0 if errors.is_empty() else 1)
	return false
