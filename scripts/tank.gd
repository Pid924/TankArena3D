extends CharacterBody3D
## Player and enemy tank. Built entirely from primitive meshes.

const GRAVITY := 22.0
const DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]

var main = null
var is_player := false
var kind := "basic"
var hp := 1
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

# AI state
var ai_dir := Vector3(0, 0, 1)
var ai_timer := 0.0
var ai_fire := 1.5
var stuck_t := 0.0
var art_timer := 2.5
var art_pause := 0.0
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


func setup(m, player: bool, k: String) -> void:
	main = m
	is_player = player
	kind = k
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.42
	cs.shape = sh
	cs.position.y = 0.42
	add_child(cs)
	set_meta("tank", true)
	match kind:
		"player":
			hp = 3
			speed = 4.6
			base_color = Color(0.22, 0.78, 0.56)
			facing = Vector3(0, 0, -1)
		"basic":
			hp = 1
			speed = 3.0
			base_color = Color(0.78, 0.74, 0.68)
			score_value = 100
		"fast":
			hp = 1
			speed = 5.3
			bullet_speed = 14.0
			base_color = Color(0.96, 0.55, 0.16)
			score_value = 200
		"heavy":
			hp = 4
			speed = 2.0
			base_color = Color(0.5, 0.36, 0.68)
			score_value = 400
		"artillery":
			hp = 2
			speed = 1.8
			base_color = Color(0.62, 0.48, 0.26)
			score_value = 300
		"stealth":
			hp = 1
			speed = 3.6
			base_color = Color(0.18, 0.24, 0.4)
			score_value = 300
	build_visual()


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
		_:
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(-0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.2, 0.28, 0.95), Vector3(0.34, 0.15, 0), track_mat)
			add_box(Vector3(0.5, 0.25, 0.86), Vector3(0, 0.3, 0), hull_mat)
			add_box(Vector3(0.42, 0.2, 0.42), Vector3(0, 0.52, 0.05), top_mat)
			add_box(Vector3(0.1, 0.1, 0.5), Vector3(0, 0.52, -0.36), dark_mat)
			if is_player:
				add_box(Vector3(0.2, 0.05, 0.2), Vector3(0, 0.64, 0.05), mk_mat(Color(1.0, 0.85, 0.2)))
	shield_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	shield_mesh.mesh = sm
	var shm := StandardMaterial3D.new()
	shm.albedo_color = Color(0.4, 0.85, 1.0, 0.28)
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mesh.material_override = shm
	shield_mesh.position.y = 0.4
	shield_mesh.visible = false
	add_child(shield_mesh)
	visual.rotation.y = atan2(-facing.x, -facing.z)


func _physics_process(delta: float) -> void:
	if dead or main == null or main.state != "playing":
		return
	invuln = maxf(0.0, invuln - delta)
	shield = maxf(0.0, shield - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	reveal_t = maxf(0.0, reveal_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	my_bullets = my_bullets.filter(func(b): return is_instance_valid(b))
	if is_player:
		player_update(delta)
	else:
		enemy_update(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if not is_player and main.freeze_t <= 0.0 and art_pause <= 0.0:
		var rv := get_real_velocity()
		if Vector2(rv.x, rv.z).length() < speed * 0.3:
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
	update_visual(delta)


func ground_type() -> String:
	return main.cells.get(main.cell_of(global_position), ".")


func player_update(delta: float) -> void:
	var inp := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if main.touch_vec.length() > 0.2:
		inp = Vector3(main.touch_vec.x, 0, main.touch_vec.y)
	if inp.length() > 1.0:
		inp = inp.normalized()
	if inp.length() > 0.15:
		facing = inp.normalized()
	var acc := 1.6 if ground_type() == "I" else 16.0
	var h := Vector3(velocity.x, 0, velocity.z).lerp(inp * speed, minf(1.0, acc * delta))
	velocity.x = h.x
	velocity.z = h.z
	if Input.is_action_pressed("fire") or main.touch_fire:
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
	if my_bullets.size() >= max_b:
		return
	fire_cd = 0.2 if is_player else 0.5
	my_bullets.append(main.spawn_bullet(self, facing, spd, power))
	reveal_t = 0.8


func enemy_update(delta: float) -> void:
	if main.freeze_t > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var pl = main.player
	var pvis: bool = pl != null and is_instance_valid(pl) and not pl.dead and not main.player_hidden()
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
	ai_timer -= delta
	if ai_timer <= 0.0:
		choose_dir(false)
	facing = ai_dir
	var tv := ai_dir * speed
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


func choose_dir(stuck: bool) -> void:
	var pl = main.player
	var pvis: bool = pl != null and is_instance_valid(pl) and not pl.dead and not main.player_hidden()
	var choice: Vector3 = DIRS[randi() % 4]
	if pvis and randf() < 0.5:
		var to: Vector3 = pl.global_position - global_position
		var use_x := absf(to.x) > absf(to.z)
		if randf() < 0.3:
			use_x = not use_x
		if use_x and absf(to.x) > 0.3:
			choice = Vector3(signf(to.x), 0, 0)
		elif absf(to.z) > 0.3:
			choice = Vector3(0, 0, signf(to.z))
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
		main.on_player_hit()
		if hp <= 0:
			die()
	else:
		reveal_t = 1.0
		flash_t = 0.12
		if carrier:
			carrier = false
			main.spawn_item_random()
		hp -= power
		if hp <= 0:
			die()
		elif kind == "heavy":
			hull_mat.albedo_color = base_color.lerp(Color(0.95, 0.3, 0.3), (4.0 - hp) / 4.0)


func die() -> void:
	if dead:
		return
	dead = true
	main.on_tank_destroyed(self)
	queue_free()


func update_visual(delta: float) -> void:
	var target := atan2(-facing.x, -facing.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target, minf(1.0, 14.0 * delta))
	shield_mesh.visible = shield > 0.0
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
	hull_mat.emission = em
	if kind == "stealth":
		var want := 0.07
		var pl = main.player
		var near: bool = pl != null and is_instance_valid(pl) and pl.global_position.distance_to(global_position) < 2.5
		if reveal_t > 0.0 or main.radar_t > 0.0 or near:
			want = 1.0 if main.radar_t <= 0.0 or reveal_t > 0.0 or near else 0.6
		alpha = lerpf(alpha, want, minf(1.0, 6.0 * delta))
		for m in all_mats:
			m.albedo_color.a = alpha
