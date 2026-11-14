extends Control
## Draws the corner minimap (live from the level grid), HP pips and enemy HP bars.

var main = null
const CS := 8.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.W == 0:
		return
	var font: Font = main.ui_font
	var vp := get_viewport_rect().size
	var tm := Time.get_ticks_msec() / 1000.0
	var playing: bool = main.state == "playing" or main.state == "clear" or main.state == "dying"
	if main.state == "title" or main.state == "brief":
		return
	# enemy HP bars (only for tanks with more than 1 HP)
	for e in main.enemies:
		if not is_instance_valid(e) or e.max_hp <= 1 or (e.kind == "stealth" and e.alpha < 0.5):
			continue
		var wp: Vector3 = e.global_position + Vector3(0, 1.05, 0)
		if main.camera.is_position_behind(wp):
			continue
		var sp: Vector2 = main.camera.unproject_position(wp)
		var w := 34.0
		draw_rect(Rect2(sp - Vector2(w / 2 + 1, 1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(sp - Vector2(w / 2, 0), Vector2(w * float(e.hp) / e.max_hp, 5)), Color(1.0, 0.3, 0.3) if main.enemy_shield_t <= 0.0 else Color(0.5, 0.8, 1.0))
	# minimap
	var mw: float = main.W * CS
	var mh: float = main.H * CS
	var o := Vector2(vp.x - mw - 16.0, 16.0)
	draw_rect(Rect2(o - Vector2(5, 5), Vector2(mw + 10, mh + 10)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(o, Vector2(mw, mh)), Color(0.3, 0.36, 0.24, 0.85))
	for c in main.cells:
		var t: String = main.cells[c]
		var col := Color(0, 0, 0, 0)
		match t:
			"B": col = Color(0.8, 0.38, 0.22)
			"S": col = Color(0.72, 0.74, 0.8)
			"W": col = Color(0.2, 0.45, 0.9)
			"G": col = Color(0.12, 0.6, 0.22)
			"I": col = Color(0.75, 0.92, 1.0)
			"H": col = Color(0.58, 0.52, 0.3)
			">", "<", "^", "v": col = Color(0.48, 0.42, 0.28)
		if col.a > 0.0:
			draw_rect(Rect2(o + Vector2(c.x, c.y) * CS, Vector2(CS, CS)), col)
	for sp2 in main.enemy_spawns:
		draw_rect(Rect2(o + Vector2(sp2.x, sp2.y) * CS, Vector2(CS, CS)), Color(1, 0.3, 0.3, 0.35), false, 1.0)
	for m in main.mines:
		var mp: Vector3 = m.node.position
		draw_circle(o + Vector2(mp.x, mp.z) * CS, 2.0, Color(1, 0.6, 0.1))
	for it in main.items:
		if is_instance_valid(it.node) and fmod(tm, 0.5) < 0.32:
			var ip: Vector3 = it.node.global_position
			draw_texture_rect(main.item_tex[it.type], Rect2(o + Vector2(ip.x, ip.z) * CS - Vector2(7, 7), Vector2(14, 14)), false)
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		if e.kind == "stealth":
			continue
		var ecol := Color(1, 0.22, 0.22)
		if e.kind == "stealth":
			ecol = Color(0.75, 0.4, 1.0)
		elif e.kind == "thief":
			ecol = Color(1.0, 0.45, 0.8)
		if e.carrier and fmod(tm, 0.3) < 0.15:
			ecol = Color(1, 1, 1)
		draw_circle(o + Vector2(e.global_position.x, e.global_position.z) * CS, 3.5, ecol)
	for pl in main.alive_players():
		var pp := o + Vector2(pl.global_position.x, pl.global_position.z) * CS
		var f := Vector2(pl.facing.x, pl.facing.z).normalized()
		var side := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pp + f * 6.0, pp - f * 4.0 + side * 4.0, pp - f * 4.0 - side * 4.0]), pl.base_color.lightened(0.3))
	# HP pips per player
	if not playing:
		return
	for pl in main.players:
		if not is_instance_valid(pl):
			continue
		var y: float = 24.0 + pl.player_idx * 26.0
		var x0 := 28.0
		if main.num_players == 2:
			draw_string(font, Vector2(10, y + 7), "P%d" % (pl.player_idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pl.base_color.lightened(0.3))
			x0 = 52.0
		for i in maxi(pl.hp, 3):
			var filled: bool = i < pl.hp and not pl.dead
			var c2 := Vector2(x0 + i * 24, y)
			draw_circle(c2, 10.0, Color(0, 0, 0, 0.6))
			draw_circle(c2, 8.0, Color(1.0, 0.28, 0.35) if filled else Color(0.3, 0.3, 0.3))
