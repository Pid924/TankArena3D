extends CharacterBody3D
## Player and enemy tank. Built entirely from primitive meshes.

const GRAVITY := 22.0
const DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const WATER_LAYER := 8

const KIND_COLORS := {
	"player1": Color(0.22, 0.78, 0.56),
	"player2": Color(0.35, 0.55, 1.0),
	"basic": Color(0.78, 0.74, 0.68),
	"fast": Color(0.96, 0.55, 0.16),
	"heavy": Color(0.5, 0.36, 0.68),
	"artillery": Color(0.62, 0.48, 0.26),
	"stealth": Color(0.18, 0.24, 0.4),
	"hover": Color(0.2, 0.75, 0.8),
	"miner": Color(0.45, 0.5, 0.2),
	"thief": Color(0.95, 0.35, 0.7),
	"flamer": Color(0.85, 0.22, 0.12),
	"twin": Color(0.55, 0.62, 0.7),
}
const KIND_HP := {"basic": 1, "fast": 1, "heavy": 4, "artillery": 2, "stealth": 1, "hover": 2, "miner": 2, "thief": 1, "flamer": 2, "twin": 2}
const KIND_SPEED := {"basic": 3.0, "fast": 5.3, "heavy": 2.0, "artillery": 1.8, "stealth": 3.6, "hover": 3.4, "miner": 2.8, "thief": 4.2, "flamer": 2.8, "twin": 2.6}
const KIND_SCORE := {"basic": 100, "fast": 200, "heavy": 400, "artillery": 300, "stealth": 300, "hover": 250, "miner": 250, "thief": 300, "flamer": 350, "twin": 300}

var main = null
var is_player := false
var player_idx := 0
var kind := "basic"
var hp := 1
var max_hp := 1
var speed := 3.0
var bullet_speed := 11.0
var facing := Vector3(0, 0, 1)
var carrier := false
var invuln := 0.0
var shield := 0.0
var fire_cd := 0.0
var weapon := 0
var my_bullets: Array = []
var dead := false
var water_pass := false

# AI state
var ai_dir := Vector3(0, 0, 1)
var ai_timer := 0.0
var ai_fire := 1.5
var stuck_t := 0.0
var art_timer := 2.5
var art_pause := 0.0
var mine_timer := 2.5
var reveal_t := 0.0
var flash_t := 0.0
var alpha := 1.0
var score_value := 100

# visuals
var visual: Node3D
var hull_mat: StandardMaterial3D
var all_mats: Array = []
var base_color := Color.WHITE
var shield_mesh: MeshInstance3D
var floater: MeshInstance3D
var flame: Node3D
var flame_own := false
var flame_cycle := 2.0
var flame_tick := 0.0


func setup(m, player: bool, k: String, idx := 0) -> void:
	main = m
	is_player = player
	player_idx = idx
	kind = k
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | WATER_LAYER
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.42
	cs.shape = sh
	cs.position.y = 0.42
	add_child(cs)
	set_meta("tank", true)
	if is_player:
		hp = 3
		speed = 4.6
		base_color = KIND_COLORS["player%d" % (idx + 1)]
		facing = Vector3(0, 0, -1)
	else:
		hp = KIND_HP[kind]
		speed = KIND_SPEED[kind]
		base_color = KIND_COLORS[kind]
		score_value = KIND_SCORE[kind]
		if kind == "fast":
			bullet_speed = 14.0
	max_hp = hp
	build_visual()


func set_bonus_hp(bonus: int) -> void:
	hp += bonus
	max_hp = hp


func mk_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	if kind == "stealth":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	all_mats.append(m)
	return m


func add_box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	visual.add_child(mi)
	return mi


func build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	hull_mat = mk_mat(base_color)
	hull_mat.emission_enabled = true
	hull_mat.emission = Color.BLACK
	var track_mat := mk_mat(base_color.darkened(0.65))
	var top_mat := mk_mat(base_color.lightened(0.18))
	var dark_mat := mk_mat(Color(0.12, 0.12, 0.14))
	match kind:
		"heavy":
			add_box(Vector3(0.22, 0.32, 1.0), Vector3(-0.37, 0.17, 0), track_mat)
			add_box(Vector3(0.22, 0.32, 1.0), Vector3(0.37, 0.17, 0), track_mat)
			add_box(Vector3(0.58, 0.3, 0.92), Vector3(0, 0.32, 0), hull_mat)
			add_box(Vector3(0.5, 0.24, 0.5), Vector3(0, 0.58, 0.06), top_mat)
			add_box(Vector3(0.08, 0.08, 0.5), Vector3(-0.08, 0.58, -0.38), dark_mat)
			add_box(Vector3(0.08, 0.08, 0.5), Vector3(0.08, 0.58, -0.38), dark_mat)
		"fast":
			add_box(Vector3(0.16, 0.22, 0.9), Vector3(-0.32, 0.13, 0), track_mat)
			add_box(Vector3(0.16, 0.22, 0.9), Vector3(0.32, 0.13, 0), track_mat)
			add_box(Vector3(0.48, 0.18, 0.86), Vector3(0, 0.24, 0), hull_mat)
			add_box(Vector3(0.32, 0.14, 0.36), Vector3(0, 0.4, 0.08), top_mat)
			add_box(Vector3(0.06, 0.06, 0.48), Vector3(0, 0.4, -0.3), dark_mat)
			add_box(Vector3(0.5, 0.04, 0.12), Vector3(0, 0.42, 0.42), dark_mat)
		"artillery":
			add_box(Vector3(0.2, 0.26, 0.95), Vector3(-0.35, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.26, 0.95), Vector3(0.35, 0.15, 0), track_mat)
			add_box(Vector3(0.52, 0.24, 0.9), Vector3(0, 0.28, 0), hull_mat)
			add_box(Vector3(0.36, 0.16, 0.36), Vector3(0, 0.46, 0.15), top_mat)
			add_box(Vector3(0.2, 0.2, 0.55), Vector3(0, 0.62, -0.05), dark_mat, Vector3(deg_to_rad(45), 0, 0))
		"stealth":
			add_box(Vector3(0.18, 0.2, 0.9), Vector3(-0.34, 0.12, 0), track_mat)
			add_box(Vector3(0.18, 0.2, 0.9), Vector3(0.34, 0.12, 0), track_mat)
			add_box(Vector3(0.52, 0.16, 0.9), Vector3(0, 0.22, 0), hull_mat)
			add_box(Vector3(0.36, 0.12, 0.44), Vector3(0, 0.36, 0.05), top_mat, Vector3(0, deg_to_rad(45), 0))
			add_box(Vector3(0.06, 0.06, 0.5), Vector3(0, 0.36, -0.32), dark_mat)
		"hover":
			# inflatable skirt instead of tracks, fan at the back
			add_box(Vector3(0.84, 0.16, 0.95), Vector3(0, 0.1, 0), track_mat)
			add_box(Vector3(0.6, 0.2, 0.8), Vector3(0, 0.27, 0), hull_mat)
			add_box(Vector3(0.36, 0.16, 0.34), Vector3(0, 0.45, 0.0), top_mat)
			add_box(Vector3(0.08, 0.08, 0.45), Vector3(0, 0.45, -0.32), dark_mat)
			add_box(Vector3(0.5, 0.36, 0.06), Vector3(0, 0.45, 0.42), dark_mat)
		"miner":
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(-0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.5, 0.28, 0.86), Vector3(0, 0.3, 0), hull_mat)
			add_box(Vector3(0.36, 0.18, 0.3), Vector3(0, 0.52, -0.1), top_mat)
			add_box(Vector3(0.08, 0.08, 0.4), Vector3(0, 0.52, -0.38), dark_mat)
			# mine rack at the back
			for i in 3:
				add_box(Vector3(0.14, 0.1, 0.14), Vector3(-0.17 + i * 0.17, 0.5, 0.3), mk_mat(Color(0.9, 0.2, 0.15)))
		"thief":
			add_box(Vector3(0.16, 0.22, 0.85), Vector3(-0.32, 0.13, 0), track_mat)
			add_box(Vector3(0.16, 0.22, 0.85), Vector3(0.32, 0.13, 0), track_mat)
			add_box(Vector3(0.46, 0.2, 0.8), Vector3(0, 0.25, 0), hull_mat)
			add_box(Vector3(0.3, 0.16, 0.3), Vector3(0, 0.42, 0.08), top_mat)
			add_box(Vector3(0.06, 0.06, 0.36), Vector3(0, 0.42, -0.24), dark_mat)
			# grabber claw
			add_box(Vector3(0.05, 0.05, 0.3), Vector3(-0.15, 0.25, -0.5), dark_mat)
			add_box(Vector3(0.05, 0.05, 0.3), Vector3(0.15, 0.25, -0.5), dark_mat)
		"flamer":
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(-0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.5, 0.25, 0.86), Vector3(0, 0.3, 0), hull_mat)
			# fuel tanks and a wide nozzle
			add_box(Vector3(0.16, 0.24, 0.4), Vector3(-0.12, 0.54, 0.18), mk_mat(Color(0.95, 0.8, 0.2)))
			add_box(Vector3(0.16, 0.24, 0.4), Vector3(0.12, 0.54, 0.18), mk_mat(Color(0.95, 0.8, 0.2)))
			add_box(Vector3(0.18, 0.14, 0.45), Vector3(0, 0.46, -0.32), dark_mat)
		"twin":
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(-0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.5, 0.25, 0.86), Vector3(0, 0.3, 0), hull_mat)
			add_box(Vector3(0.42, 0.2, 0.42), Vector3(0, 0.52, 0.0), top_mat)
			add_box(Vector3(0.1, 0.1, 0.45), Vector3(0, 0.52, -0.38), dark_mat)
			add_box(Vector3(0.1, 0.1, 0.45), Vector3(0, 0.52, 0.38), dark_mat)
		_:
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(-0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.5, 0.25, 0.86), Vector3(0, 0.3, 0), hull_mat)
			add_box(Vector3(0.42, 0.2, 0.42), Vector3(0, 0.52, 0.05), top_mat)
			add_box(Vector3(0.1, 0.1, 0.5), Vector3(0, 0.52, -0.36), dark_mat)
			if is_player:
				var flag := Color(1.0, 0.85, 0.2) if player_idx == 0 else Color(1, 1, 1)
				add_box(Vector3(0.2, 0.05, 0.2), Vector3(0, 0.64, 0.05), mk_mat(flag))
	shield_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	shield_mesh.mesh = sm
	var shm := StandardMaterial3D.new()
	shm.albedo_color = Color(0.4, 0.85, 1.0, 0.28) if is_player else Color(1.0, 0.35, 0.35, 0.3)
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mesh.material_override = shm
	shield_mesh.position.y = 0.4
	shield_mesh.visible = false
	add_child(shield_mesh)
	visual.rotation.y = atan2(-facing.x, -facing.z)
	# float ring shown while a tank drives on water
	floater = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.62
	fm.bottom_radius = 0.66
	fm.height = 0.12
	floater.mesh = fm
	var flm := StandardMaterial3D.new()
	flm.albedo_color = Color(1.0, 0.55, 0.15)
	flm.emission_enabled = true
	flm.emission = Color(0.35, 0.15, 0.0)
	floater.material_override = flm
	floater.position.y = 0.12
	floater.visible = false
	add_child(floater)
	# flamethrower fireball, one cell in front of the barrel
	flame = Node3D.new()
	flame.position = Vector3(0, 0.42, -1.0)
	for i in 3:
		var fs := SphereMesh.new()
		fs.radius = 0.46 - i * 0.11
		fs.height = fs.radius * 2.0
		fs.radial_segments = 10
		fs.rings = 5
		var fmi := MeshInstance3D.new()
		fmi.mesh = fs
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.albedo_color = [Color(1.0, 0.25, 0.05, 0.55), Color(1.0, 0.55, 0.1, 0.75), Color(1.0, 0.95, 0.5, 0.95)][i]
		fmi.material_override = fmat
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(fmi)
	# a short stream from the barrel to the fireball
	var stream := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(0.14, 0.14, 0.6)
	stream.mesh = sbm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.6, 0.15)
	stream.material_override = smat
	stream.position = Vector3(0, 0, 0.45)
	flame.add_child(stream)
	flame.visible = false
	visual.add_child(flame)


func _physics_process(delta: float) -> void:
	if dead or main == null or main.state != "playing":
		return
	invuln = maxf(0.0, invuln - delta)
	shield = maxf(0.0, shield - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	reveal_t = maxf(0.0, reveal_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	my_bullets = my_bullets.filter(func(b): return is_instance_valid(b))
	update_water_pass()
	if is_player:
		player_update(delta)
	else:
		enemy_update(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if not is_player and main.freeze_t <= 0.0 and art_pause <= 0.0:
		var rv := get_real_velocity()
		if Vector2(rv.x, rv.z).length() < speed * main.enemy_speed_mult() * 0.3:
			stuck_t += delta
			if stuck_t > 0.3:
				stuck_t = 0.0
				if randf() < 0.5 and kind != "artillery":
					try_fire()
				choose_dir(true)
		else:
			stuck_t = 0.0
	if global_position.y < -3.0:
		die()
		return
	update_flame(delta)
	update_visual(delta)


func has_flame() -> bool:
	if is_player:
		return main.flame_t > 0.0
	if main.freeze_t > 0.0:
		return false
	return main.enemy_flame_t > 0.0 or (kind == "flamer" and flame_own)


func update_flame(delta: float) -> void:
	if kind == "flamer" and main.freeze_t <= 0.0:
		flame_cycle -= delta
		if flame_cycle <= 0.0:
			flame_own = not flame_own
			flame_cycle = randf_range(2.0, 3.5) if flame_own else randf_range(1.5, 3.5)
	var on := has_flame()
	flame.visible = on
	if not on:
		return
	var k := randf_range(0.85, 1.15)
	flame.scale = Vector3(k, randf_range(0.85, 1.15), k)
	flame_tick -= delta
	if flame_tick > 0.0:
		return
	flame_tick = 0.35
	main.sfx.play("flame", -6.0 if is_player else -12.0, 0.15)
	var c := global_position + facing * 1.0
	var targets: Array = main.enemies.duplicate() if is_player else main.alive_players()
	for t in targets:
		if not is_instance_valid(t) or t.dead or t == self:
			continue
		var d := Vector2(t.global_position.x - c.x, t.global_position.z - c.z).length()
		if d < 0.75 and absf(t.global_position.y - global_position.y) < 0.8:
			t.take_hit(1)


func ground_type() -> String:
	return main.cells.get(main.cell_of(global_position), ".")


func touching_water() -> bool:
	for off in [Vector3(0.43, 0, 0.43), Vector3(-0.43, 0, 0.43), Vector3(0.43, 0, -0.43), Vector3(-0.43, 0, -0.43)]:
		if main.cells.get(main.cell_of(global_position + off), ".") == "W":
			return true
	return false


func update_water_pass() -> void:
	# Can this tank drive on water right now? Never switch it off while still touching water.
	if main.can_pass_water(self):
		water_pass = true
	elif water_pass and not touching_water():
		water_pass = false
	collision_mask = (1 | 2 | 4) if water_pass else (1 | 2 | 4 | WATER_LAYER)
	floater.visible = water_pass and (kind != "hover") and (not is_player or main.amphibious_t > 3.0 or main.amphibious_t <= 0.0 or fmod(main.amphibious_t, 0.3) < 0.18)


func read_move() -> Vector2:
	var pre := "p%d_" % (player_idx + 1)
	var v := Vector2(Input.get_axis(pre + "left", pre + "right"), Input.get_axis(pre + "up", pre + "down"))
	if main.num_players == 1:
		v += Vector2(Input.get_axis("p2_left", "p2_right"), Input.get_axis("p2_up", "p2_down"))
		if main.touch_vec.length() > 0.2:
			v = main.touch_vec
	return v.limit_length(1.0)


func read_fire() -> bool:
	var pre := "p%d_" % (player_idx + 1)
	if Input.is_action_pressed(pre + "fire"):
		return true
	return main.num_players == 1 and (Input.is_action_pressed("p2_fire") or main.touch_fire)


func player_update(delta: float) -> void:
	var mv := read_move()
	if main.player_freeze_t > 0.0:
		mv = Vector2.ZERO
	var inp := Vector3(mv.x, 0, mv.y)
	if inp.length() > 0.15:
		facing = inp.normalized()
	var acc := 1.6 if ground_type() == "I" else 16.0
	var spd: float = speed * main.player_speed_mult()
	var h := Vector3(velocity.x, 0, velocity.z).lerp(inp * spd, minf(1.0, acc * delta))
	velocity.x = h.x
	velocity.z = h.z
	if read_fire() and main.player_freeze_t <= 0.0:
		try_fire()


func try_fire() -> void:
	if fire_cd > 0.0:
		return
	var max_b := 1
	var spd := bullet_speed
	var power := 1
	if is_player:
		spd = 17.0 if weapon >= 1 else 12.0
		max_b = 2 if weapon >= 2 else 1
		power = 2 if weapon >= 3 else 1
	if kind == "twin":
		max_b = 2
	if my_bullets.size() >= max_b:
		return
	fire_cd = 0.2 if is_player else 0.5
	main.sfx.play("shoot_p" if is_player else "shoot_e", -4.0 if is_player else -11.0)
	my_bullets.append(main.spawn_bullet(self, facing, spd, power))
	if kind == "twin":
		my_bullets.append(main.spawn_bullet(self, -facing, spd, power))
	reveal_t = 0.8


func enemy_update(delta: float) -> void:
	if main.freeze_t > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var pl = main.nearest_visible_player(global_position)
	var pvis: bool = pl != null
	if kind == "artillery":
		art_timer -= delta
		if art_pause > 0.0:
			art_pause -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			return
		if art_timer <= 0.0 and pvis:
			var d: float = pl.global_position.distance_to(global_position)
			art_timer = randf_range(3.5, 5.0)
			if d < 14.0 and d > 2.0:
				art_pause = 0.9
				var to: Vector3 = pl.global_position - global_position
				to.y = 0
				facing = to.normalized()
				var off := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
				main.spawn_shell(self, pl.global_position + pl.velocity * Vector3(0.6, 0, 0.6) + off)
				return
	if kind == "miner":
		mine_timer -= delta
		if mine_timer <= 0.0:
			mine_timer = randf_range(2.5, 4.0)
			main.spawn_mine(global_position - facing * 0.7)
	ai_timer -= delta
	if kind == "thief" and not main.items.is_empty() and ai_timer > 0.6:
		ai_timer = 0.6
	if ai_timer <= 0.0:
		choose_dir(false)
	facing = ai_dir
	var tv: Vector3 = ai_dir * speed * main.enemy_speed_mult()
	var acc := 2.0 if ground_type() == "I" else 20.0
	var h := Vector3(velocity.x, 0, velocity.z).lerp(tv, minf(1.0, acc * delta))
	velocity.x = h.x
	velocity.z = h.z
	# keep enemies centred in their lane so they fit 1-cell corridors
	var cc: Vector3 = main.cell_center(main.cell_of(global_position))
	if absf(ai_dir.x) > 0.5:
		velocity.z = (cc.z - global_position.z) * 5.0
	else:
		velocity.x = (cc.x - global_position.x) * 5.0
	if kind != "artillery":
		ai_fire -= delta
		if pvis:
			var to2: Vector3 = pl.global_position - global_position
			to2.y = 0
			var along := to2.dot(facing)
			var lat := (to2 - facing * along).length()
			if along > 0.0 and lat < 0.6 and along < 15.0:
				ai_fire = minf(ai_fire, 0.15)
		if ai_fire <= 0.0:
			try_fire()
			ai_fire = randf_range(0.7, 1.8) if kind == "fast" else randf_range(1.0, 2.5)
			if kind == "thief":
				ai_fire += 1.5


func toward(to: Vector3) -> Vector3:
	var use_x := absf(to.x) > absf(to.z)
	if randf() < 0.3:
		use_x = not use_x
	if use_x and absf(to.x) > 0.3:
		return Vector3(signf(to.x), 0, 0)
	if absf(to.z) > 0.3:
		return Vector3(0, 0, signf(to.z))
	if absf(to.x) > 0.3:
		return Vector3(signf(to.x), 0, 0)
	return DIRS[randi() % 4]


func choose_dir(stuck: bool) -> void:
	var pl = main.nearest_visible_player(global_position)
	var choice: Vector3 = DIRS[randi() % 4]
	var item = main.nearest_item(global_position) if kind == "thief" else null
	if item != null and randf() < 0.85:
		choice = toward(item.global_position - global_position)
	elif pl != null and randf() < 0.5:
		choice = toward(pl.global_position - global_position)
	elif randf() < 0.3:
		choice = Vector3(0, 0, 1)
	if stuck and choice.is_equal_approx(ai_dir):
		choice = DIRS[randi() % 4]
	ai_dir = choice
	ai_timer = randf_range(1.0, 3.0)


func take_hit(power: int) -> void:
	if dead:
		return
	if is_player:
		if invuln > 0.0 or shield > 0.0:
			return
		hp -= 1
		invuln = 1.6
		main.on_player_hit(self)
		if hp <= 0:
			die()
	else:
		reveal_t = 1.0
		if main.enemy_shield_t > 0.0:
			flash_t = 0.05
			return
		flash_t = 0.12
		if hp - power > 0:
			main.sfx.play("clank", -6.0)
		if carrier:
			carrier = false
			main.spawn_item_random()
		hp -= power
		if hp <= 0:
			die()
		elif kind == "heavy":
			hull_mat.albedo_color = base_color.lerp(Color(0.95, 0.3, 0.3), 1.0 - float(hp) / max_hp)


func die() -> void:
	if dead:
		return
	dead = true
	main.on_tank_destroyed(self)
	queue_free()


func update_visual(delta: float) -> void:
	var target := atan2(-facing.x, -facing.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target, minf(1.0, 14.0 * delta))
	if kind == "hover":
		visual.position.y = 0.04 + sin(Time.get_ticks_msec() / 150.0) * 0.03
	shield_mesh.visible = shield > 0.0 or (not is_player and main.enemy_shield_t > 0.0)
	if is_player:
		visual.visible = invuln <= 0.0 or fmod(invuln, 0.2) < 0.12
	var em := Color.BLACK
	var t := Time.get_ticks_msec() / 1000.0
	if flash_t > 0.0:
		em = Color(1, 1, 1)
	elif carrier:
		em = Color(1.0, 0.15, 0.15) if fmod(t, 0.3) < 0.15 else Color.BLACK
	elif main.freeze_t > 0.0 and not is_player:
		em = Color(0.35, 0.55, 0.8)
	elif is_player and main.player_freeze_t > 0.0:
		em = Color(0.35, 0.55, 0.8)
	hull_mat.emission = em
	if kind == "stealth":
		var want := 0.07
		var near: bool = main.nearest_player_dist(global_position) < 2.5
		if reveal_t > 0.0 or near:
			want = 1.0
		alpha = lerpf(alpha, want, minf(1.0, 6.0 * delta))
		for m in all_mats:
			m.albedo_color.a = alpha
