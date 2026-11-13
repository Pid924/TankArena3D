extends Control
## Draws the corner minimap (live from the level grid) and the HP pips.

var main = null
const CS := 8.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.W == 0:
		return
	var vp := get_viewport_rect().size
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
			"T": col = Color(0.9, 0.9, 1.0)
			"W": col = Color(0.2, 0.45, 0.9)
			"G": col = Color(0.12, 0.6, 0.22)
			"I": col = Color(0.75, 0.92, 1.0)
			"H": col = Color(0.58, 0.52, 0.3)
			">", "<", "^", "v": col = Color(0.48, 0.42, 0.28)
		if col.a > 0.0:
			draw_rect(Rect2(o + Vector2(c.x, c.y) * CS, Vector2(CS, CS)), col)
	var tm := Time.get_ticks_msec() / 1000.0
	for sp in main.enemy_spawns:
		draw_rect(Rect2(o + Vector2(sp.x, sp.y) * CS, Vector2(CS, CS)), Color(1, 0.3, 0.3, 0.35), false, 1.0)
	for it in main.items:
		if is_instance_valid(it.node) and fmod(tm, 0.5) < 0.32:
			var ip: Vector3 = it.node.global_position
			draw_rect(Rect2(o + Vector2(ip.x, ip.z) * CS - Vector2(3.5, 3.5), Vector2(7, 7)), it.color)
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		if e.kind == "stealth" and main.radar_t <= 0.0:
			continue
		var ecol := Color(1, 0.22, 0.22)
		if e.kind == "stealth":
			ecol = Color(0.75, 0.4, 1.0)
		if e.carrier and fmod(tm, 0.3) < 0.15:
			ecol = Color(1, 1, 1)
		draw_circle(o + Vector2(e.global_position.x, e.global_position.z) * CS, 3.5, ecol)
	var pl = main.player
	if pl != null and is_instance_valid(pl):
		var pp := o + Vector2(pl.global_position.x, pl.global_position.z) * CS
		var f := Vector2(pl.facing.x, pl.facing.z).normalized()
		var side := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pp + f * 6.0, pp - f * 4.0 + side * 4.0, pp - f * 4.0 - side * 4.0]), Color(0.3, 1.0, 0.6))
	if main.radar_t > 0.0:
		draw_string(ThemeDB.fallback_font, o + Vector2(2, mh + 18), "RADAR %d" % ceili(main.radar_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 1, 0.5))
	# HP pips
	if main.state != "title" and pl != null and is_instance_valid(pl):
		for i in maxi(pl.hp, 3):
			var filled: bool = i < pl.hp
			var c2 := Vector2(28 + i * 26, 24)
			draw_circle(c2, 10.0, Color(0, 0, 0, 0.6))
			draw_circle(c2, 8.0, Color(1.0, 0.28, 0.35) if filled else Color(0.3, 0.3, 0.3))
