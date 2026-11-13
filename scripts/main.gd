extends Node3D
## Tank Arena 3D: game manager. Builds levels procedurally from text maps,
## spawns enemies, handles items, HUD, camera and touch controls.

const TankScript = preload("res://scripts/tank.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const ShellScript = preload("res://scripts/shell.gd")
const OverlayScript = preload("res://scripts/overlay.gd")

# Map legend:
#  .  floor        B  brick (breakable)     S  steel (needs max weapon)
#  W  water        G  bush (hides player)   I  ice (slippery)
#  H  high ground  > < ^ v  ramp rising toward that direction (^ = up/north)
#  P  player start E  enemy spawn
# Enemy list: b basic, f fast, h heavy, a artillery, s stealth
const LEVELS := [
	{
		"name": "Brick Yard",
		"enemies": "bbbfbbfbhbbfbbsbhbfb",
		"map": [
			"E.........E.........E",
			"..BB..BB.....BB..BB..",
			"..BB..BB..S..BB..BB..",
			"..........S..........",
			"GG..BBBB.....BBBB..GG",
			"GG..B...........B..GG",
			"....B..SS...SS..B....",
			"..........G..........",
			"BB..WWW..GGG..WWW..BB",
			"..........G..........",
			"....B..SS...SS..B....",
			"GG..B...........B..GG",
			"GG..BBBB.....BBBB..GG",
			"..........B..........",
			"..BB..BB.BBB.BB..BB..",
			"..BB.........BB..BB..",
			"..........P..........",
		],
	},
	{
		"name": "Frozen River",
		"enemies": "bfbahbfsbbafhbsbfahb",
		"map": [
			"E.........E.........E",
			"..BBB...........BBB..",
			"..B.....GGGGG.....B..",
			"..B..SS.......SS..B..",
			"IIIIIIIIIIIIIIIIIIIII",
			"IIWWWWIIIIBIIIIWWWWII",
			"IIWWWWIIIBBBIIIWWWWII",
			"IIIIIIIIIIBIIIIIIIIII",
			"..BB....HHHHH....BB..",
			"..BB...>HHHHH<...BB..",
			"........HHHHH........",
			"GGG.....^...^.....GGG",
			"GGG..BB.......BB..GGG",
			".....B..BBBBB..B.....",
			"..SS.....B.B.....SS..",
			"..........P..........",
			"GGG...............GGG",
		],
	},
	{
		"name": "Highland Ring",
		"enemies": "fhsabfhsabfhsabfhsab",
		"map": [
			"E.........E.........E",
			"...S.....BBB.....S...",
			".GGS..HHHHHHHHH..SGG.",
			".GG...H.......H...GG.",
			"......H.BB.BB.H......",
			"WW...>H.B...B.H<...WW",
			"WW....H...v...H....WW",
			"......HHHHHHHHH......",
			"..BB......^......BB..",
			"..BBSS..IIIII..SSBB..",
			"........IIIII........",
			"GG..BB..IIIII..BB..GG",
			"GG..B...........B..GG",
			"....B..BB...BB..B....",
			"..SS...B.....B...SS..",
			".........BPB.........",
			"GGG...............GGG",
		],
	},
]

const ITEM_TYPES := ["star", "shield", "heart", "freeze", "bomb", "walls", "radar"]
const ITEM_INFO := {
	"star": ["PWR", Color(1.0, 0.85, 0.2), "WEAPON UPGRADE"],
	"shield": ["SHD", Color(0.3, 0.8, 1.0), "SHIELD 10s"],
	"heart": ["+HP", Color(1.0, 0.3, 0.4), "+1 HP"],
	"freeze": ["FRZ", Color(0.7, 0.95, 1.0), "ENEMIES FROZEN"],
	"bomb": ["BOM", Color(1.0, 0.45, 0.1), "BOMB!"],
	"walls": ["WAL", Color(0.8, 0.8, 0.88), "STEEL WALLS"],
	"radar": ["RAD", Color(0.4, 1.0, 0.5), "RADAR ONLINE"],
}
const ENEMY_KINDS := {"b": "basic", "f": "fast", "h": "heavy", "a": "artillery", "s": "stealth"}
const CARRIER_SLOTS := [3, 10, 17]
const MAX_ON_FIELD := 4
const MAX_HP := 5

var W := 0
var H := 0
var cells := {}
var blocks := {}
var enemy_spawns: Array = []
var player_spawn := Vector2i.ZERO
var level_root: Node3D
var camera: Camera3D
var cam_focus := Vector3.ZERO
var shake := 0.0
var player = null
var enemies: Array = []
var items: Array = []
var temp_walls: Array = []
var spawn_list := ""
var spawn_index := 0
var spawn_timer := 1.0
var spawn_rr := 0
var kills := 0
var total := 20
var score := 0
var level_idx := 0
var carry_hp := 3
var carry_weapon := 0
var state := "title"
var state_t := 0.0
var freeze_t := 0.0
var radar_t := 0.0
var msg_t := 0.0

var touch_vec := Vector2.ZERO
var touch_fire := false
var touch_id := -1
var fire_id := -1
var touch_origin := Vector2.ZERO
var touch_confirm := false
var pending_pick := -1

var hud_label: Label
var msg_label: Label
var center_label: Label
var overlay: Control
var mats := {}
var mesh_cache := {}


func _ready() -> void:
	randomize()
	setup_input()
	make_materials()
	setup_world()
	setup_hud()
	load_level(0, false)


# ---------------------------------------------------------------- setup

func setup_input() -> void:
	var keymap := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"fire": [KEY_SPACE, KEY_J, KEY_K],
		"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
	}
	for a in keymap:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keymap[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("fire", jb)
	var jb2 := InputEventJoypadButton.new()
	jb2.button_index = JOY_BUTTON_START
	InputMap.action_add_event("confirm", jb2)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a in axes:
		var ja := InputEventJoypadMotion.new()
		ja.axis = axes[a][0]
		ja.axis_value = axes[a][1]
		InputMap.action_add_event(a, ja)


func make_tex(w: int, h: int, fn: Callable) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, fn.call(x, y))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func std_mat(c: Color, tex: Texture2D = null, triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if tex:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
	return m


func make_materials() -> void:
	var brick_tex := make_tex(16, 16, func(x: int, y: int) -> Color:
		var row := y / 4
		var off := 4 if row % 2 == 1 else 0
		if y % 4 == 3 or (x + off) % 8 == 7:
			return Color(0.82, 0.76, 0.66)
		var v := 0.9 + 0.1 * sin(float(x * 7 + y * 13 + row * 5))
		return Color(0.78 * v, 0.33 * v, 0.2 * v))
	var steel_tex := make_tex(16, 16, func(x: int, y: int) -> Color:
		if x == 0 or y == 0:
			return Color(0.95, 0.96, 1.0)
		if x == 15 or y == 15:
			return Color(0.42, 0.44, 0.5)
		if (x == 3 or x == 12) and (y == 3 or y == 12):
			return Color(0.5, 0.52, 0.58)
		if x > 4 and x < 11 and y > 4 and y < 11:
			return Color(0.86, 0.88, 0.93)
		return Color(0.72, 0.74, 0.8))
	var water_tex := make_tex(16, 16, func(x: int, y: int) -> Color:
		var v := 0.5 + 0.5 * sin(x * 0.8 + sin(y * 0.6) * 2.0)
		return Color(0.15, 0.4 + v * 0.12, 0.8 + v * 0.15))
	var ice_tex := make_tex(16, 16, func(x: int, y: int) -> Color:
		if (x + y) % 9 == 0 or (x - y + 32) % 13 == 0:
			return Color(0.95, 1.0, 1.0)
		return Color(0.72, 0.9, 0.98))
	var grass_tex := make_tex(8, 8, func(x: int, y: int) -> Color:
		var v := 0.92 + 0.08 * sin(x * 2.3 + y * 1.7)
		return Color(0.48 * v, 0.6 * v, 0.34 * v))
	mats.brick = std_mat(Color.WHITE, brick_tex, true)
	mats.brick_dmg = std_mat(Color(0.65, 0.6, 0.6), brick_tex, true)
	mats.steel = std_mat(Color.WHITE, steel_tex, true)
	mats.steel.metallic = 0.4
	mats.steel.roughness = 0.35
	mats.temp = std_mat(Color(0.75, 0.85, 1.0), steel_tex, true)
	mats.temp.emission_enabled = true
	mats.temp.emission = Color(0.1, 0.2, 0.35)
	mats.water = std_mat(Color.WHITE, water_tex, true)
	mats.water.roughness = 0.1
	mats.ice = std_mat(Color(0.82, 0.9, 1.0), ice_tex, true)
	mats.ice.roughness = 0.35
	mats.plateau = std_mat(Color(0.75, 0.68, 0.5), grass_tex, true)
	mats.ramp = std_mat(Color(0.66, 0.58, 0.42))
	mats.bush = std_mat(Color(0.2, 0.55, 0.22))
	mats.bush2 = std_mat(Color(0.28, 0.66, 0.26))
	mats.border = std_mat(Color(0.4, 0.42, 0.46), steel_tex, true)
	mats.pad = std_mat(Color(0.85, 0.25, 0.25, 0.5))
	mats.pad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.pad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats.bullet_p = std_mat(Color(1.0, 0.95, 0.5))
	mats.bullet_p.emission_enabled = true
	mats.bullet_p.emission = Color(1.0, 0.85, 0.3)
	mats.bullet_e = std_mat(Color(1.0, 0.4, 0.3))
	mats.bullet_e.emission_enabled = true
	mats.bullet_e.emission = Color(1.0, 0.3, 0.2)
	mats.shell = std_mat(Color(0.15, 0.15, 0.15))
	mats.marker = std_mat(Color(1.0, 0.2, 0.15, 0.45))
	mats.marker.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats.debris = std_mat(Color(0.75, 0.35, 0.22))


func setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	camera.current = true


func make_label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = align
	return l


func setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.set_script(OverlayScript)
	overlay.main = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	hud_label = make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	hud_label.position = Vector2(16, 40)
	layer.add_child(hud_label)
	msg_label = make_label(34, HORIZONTAL_ALIGNMENT_CENTER)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-400, 110)
	msg_label.size = Vector2(800, 120)
	layer.add_child(msg_label)
	center_label = make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(center_label)


# ---------------------------------------------------------------- helpers

func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func ground_height(x: float, z: float) -> float:
	var c := Vector2i(floori(x), floori(z))
	var t: String = cells.get(c, ".")
	match t:
		"H": return 0.6
		">": return 0.6 * (x - c.x)
		"<": return 0.6 * (1.0 - (x - c.x))
		"^": return 0.6 * (1.0 - (z - c.y))
		"v": return 0.6 * (z - c.y)
	return 0.0


func player_hidden() -> bool:
	if player == null or not is_instance_valid(player):
		return true
	return cells.get(cell_of(player.global_position), ".") == "G"


func box_mesh(size: Vector3) -> BoxMesh:
	var key := str(size)
	if not mesh_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		mesh_cache[key] = bm
	return mesh_cache[key]


func add_mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	(parent if parent else level_root).add_child(mi)
	mi.position = pos
	return mi


func add_static(size: Vector3, pos: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	level_root.add_child(body)
	body.position = pos
	return body


func show_msg(text: String, dur := 1.6) -> void:
	msg_label.text = text
	msg_t = dur


# ---------------------------------------------------------------- level building

func load_level(idx: int, start_play: bool) -> void:
	if level_root:
		level_root.free()
	level_root = Node3D.new()
	add_child(level_root)
	cells.clear()
	blocks.clear()
	enemies.clear()
	items.clear()
	temp_walls.clear()
	enemy_spawns.clear()
	player = null
	level_idx = idx
	var L: Dictionary = LEVELS[idx]
	var rows: Array = L["map"]
	H = rows.size()
	W = 21
	for z in H:
		var row: String = rows[z]
		for x in W:
			var ch: String = row[x] if x < row.length() else "."
			var c := Vector2i(x, z)
			cells[c] = ch
			build_cell(c, ch)
	build_floor()
	spawn_list = L["enemies"]
	total = spawn_list.length()
	spawn_index = 0
	spawn_rr = 0
	kills = 0
	spawn_timer = 1.5
	freeze_t = 0.0
	radar_t = 0.0
	cam_focus = cell_center(player_spawn)
	if start_play:
		spawn_player()
		state = "playing"
		show_msg("LEVEL %d\n%s" % [idx + 1, L["name"]], 2.5)


func build_floor() -> void:
	var tex := make_tex(W, H, func(x: int, y: int) -> Color:
		var v := 0.0 if (x + y) % 2 == 0 else 0.035
		return Color(0.46 - v, 0.5 - v, 0.36 - v))
	var m := std_mat(Color.WHITE, tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pm := PlaneMesh.new()
	pm.size = Vector2(W, H)
	add_mesh(pm, m, Vector3(W / 2.0, 0.0, H / 2.0))
	add_static(Vector3(W + 4, 1.0, H + 4), Vector3(W / 2.0, -0.5, H / 2.0), 2)
	# outer frame (blocks tanks and bullets)
	var frames := [
		[Vector3(W + 2, 1.0, 1), Vector3(W / 2.0, 0.5, -0.5)],
		[Vector3(W + 2, 1.0, 1), Vector3(W / 2.0, 0.5, H + 0.5)],
		[Vector3(1, 1.0, H), Vector3(-0.5, 0.5, H / 2.0)],
		[Vector3(1, 1.0, H), Vector3(W + 0.5, 0.5, H / 2.0)],
	]
	for f in frames:
		add_static(f[0], f[1], 1)
		add_mesh(box_mesh(f[0]), mats.border, f[1])
	var outer := PlaneMesh.new()
	outer.size = Vector2(W + 40, H + 40)
	add_mesh(outer, std_mat(Color(0.2, 0.26, 0.2)), Vector3(W / 2.0, -0.02, H / 2.0))


func build_cell(c: Vector2i, ch: String) -> void:
	var p := cell_center(c)
	match ch:
		"B", "S":
			make_block(c, ch)
		"W":
			add_mesh(box_mesh(Vector3(1, 0.06, 1)), mats.water, p + Vector3(0, 0.0, 0))
			add_static(Vector3(1, 1.2, 1), p + Vector3(0, 0.6, 0), 2)
		"G":
			for i in 3:
				var sm := SphereMesh.new()
				var r := randf_range(0.32, 0.42)
				sm.radius = r
				sm.height = r * 1.7
				sm.radial_segments = 10
				sm.rings = 5
				var off := Vector3(randf_range(-0.22, 0.22), r * 0.7 + i * 0.1, randf_range(-0.22, 0.22))
				add_mesh(sm, mats.bush if i % 2 == 0 else mats.bush2, p + off)
		"I":
			add_mesh(box_mesh(Vector3(1, 0.02, 1)), mats.ice, p + Vector3(0, 0.01, 0))
		"H":
			add_static(Vector3(1, 0.6, 1), p + Vector3(0, 0.3, 0), 1)
			add_mesh(box_mesh(Vector3(1, 0.6, 1)), mats.plateau, p + Vector3(0, 0.3, 0))
		">", "<", "^", "v":
			var pm := PrismMesh.new()
			pm.left_to_right = 1.0
			pm.size = Vector3(1, 0.6, 1)
			var body := StaticBody3D.new()
			body.collision_layer = 2
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var wedge := ConvexPolygonShape3D.new()
			wedge.points = PackedVector3Array([
				Vector3(-0.5, -0.3, -0.5), Vector3(-0.5, -0.3, 0.5), Vector3(0.5, -0.3, -0.5),
				Vector3(0.5, -0.3, 0.5), Vector3(0.5, 0.3, -0.5), Vector3(0.5, 0.3, 0.5)])
			cs.shape = wedge
			body.add_child(cs)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mats.ramp
			body.add_child(mi)
			level_root.add_child(body)
			body.position = p + Vector3(0, 0.3, 0)
			var rots := {">": 0.0, "<": PI, "^": PI / 2.0, "v": -PI / 2.0}
			body.rotation.y = rots[ch]
		"P":
			player_spawn = c
			cells[c] = "."
		"E":
			enemy_spawns.append(c)
			cells[c] = "."
			var cm := CylinderMesh.new()
			cm.top_radius = 0.45
			cm.bottom_radius = 0.45
			cm.height = 0.02
			add_mesh(cm, mats.pad, p + Vector3(0, 0.02, 0))


func make_block(c: Vector2i, type: String) -> void:
	var h := 0.8 if type == "B" else 0.9
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1, h, 1)
	cs.shape = bs
	cs.position.y = h / 2.0
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(Vector3(0.98, h, 0.98))
	mi.position.y = h / 2.0
	match type:
		"B": mi.material_override = mats.brick
		"S": mi.material_override = mats.steel
		_: mi.material_override = mats.temp
	body.add_child(mi)
	body.set_meta("block", true)
	body.set_meta("cell", c)
	body.set_meta("hp", 2)
	body.set_meta("mesh", mi)
	level_root.add_child(body)
	body.position = cell_center(c)
	blocks[c] = body
	cells[c] = type


func remove_block(c: Vector2i) -> void:
	if blocks.has(c):
		var b: Node3D = blocks[c]
		debris_fx(b.global_position + Vector3(0, 0.4, 0), mats.debris if cells.get(c) == "B" else mats.steel)
		b.queue_free()
		blocks.erase(c)
	cells[c] = "."


# ---------------------------------------------------------------- spawning

func spawn_player() -> void:
	player = TankScript.new()
	level_root.add_child(player)
	player.setup(self, true, "player")
	player.global_position = cell_center(player_spawn) + Vector3(0, 0.05, 0)
	player.hp = carry_hp
	player.weapon = carry_weapon
	player.shield = 3.0


func update_spawning(delta: float) -> void:
	if spawn_index >= spawn_list.length() or enemy_spawns.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0.0 or enemies.size() >= MAX_ON_FIELD:
		return
	var sp: Vector2i = enemy_spawns[spawn_rr % enemy_spawns.size()]
	spawn_rr += 1
	var pos := cell_center(sp)
	for t in enemies + [player]:
		if t != null and is_instance_valid(t) and t.global_position.distance_to(pos) < 1.1:
			spawn_timer = 0.3
			return
	var e = TankScript.new()
	level_root.add_child(e)
	e.setup(self, false, ENEMY_KINDS.get(spawn_list[spawn_index], "basic"))
	e.carrier = spawn_index in CARRIER_SLOTS
	e.global_position = pos + Vector3(0, 0.05, 0)
	e.ai_dir = Vector3(0, 0, 1)
	e.facing = e.ai_dir
	e.ai_timer = randf_range(0.8, 2.0)
	e.scale = Vector3.ONE * 0.1
	var tw := e.create_tween()
	tw.tween_property(e, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enemies.append(e)
	spawn_index += 1
	spawn_timer = 2.2
	explode_fx(pos + Vector3(0, 0.3, 0), 1.2, Color(1, 1, 1, 0.6))


func spawn_bullet(shooter, dir: Vector3, spd: float, power: int) -> Node3D:
	var b = BulletScript.new()
	b.main = self
	b.shooter_rid = shooter.get_rid()
	b.from_player = shooter.is_player
	b.dir = Vector3(dir.x, 0, dir.z).normalized()
	b.speed = spd
	b.power = power
	var sm := SphereMesh.new()
	sm.radius = 0.09 if power < 2 else 0.13
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	add_mesh(sm, mats.bullet_p if shooter.is_player else mats.bullet_e, Vector3.ZERO, b)
	level_root.add_child(b)
	b.global_position = shooter.global_position + Vector3(0, 0.42, 0)
	return b


func spawn_shell(shooter, target: Vector3) -> void:
	target.x = clampf(target.x, 0.3, W - 0.3)
	target.z = clampf(target.z, 0.3, H - 0.3)
	target.y = ground_height(target.x, target.z)
	var s = ShellScript.new()
	s.main = self
	s.start = shooter.global_position + Vector3(0, 0.7, 0)
	s.target = target
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	add_mesh(sm, mats.shell, Vector3.ZERO, s)
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	s.marker = add_mesh(cm, mats.marker, target + Vector3(0, 0.05, 0))
	level_root.add_child(s)
	s.global_position = s.start


# ---------------------------------------------------------------- combat

func bullet_hit(b, collider, pos: Vector3) -> void:
	explode_fx(pos, 0.45, Color(1, 0.9, 0.5))
	if collider == null:
		return
	if collider.has_meta("tank"):
		if collider.is_player != b.from_player:
			collider.take_hit(b.power)
	elif collider.has_meta("block"):
		damage_block(collider, b.power)


func damage_block(body, power: int) -> void:
	var c: Vector2i = body.get_meta("cell")
	var t: String = cells.get(c, ".")
	if t == "B":
		var hp: int = body.get_meta("hp") - (2 if power >= 2 else 1)
		if hp <= 0:
			remove_block(c)
		else:
			body.set_meta("hp", hp)
			var mi: MeshInstance3D = body.get_meta("mesh")
			mi.material_override = mats.brick_dmg
			mi.scale.y = 0.75
			mi.position.y = 0.3
	elif (t == "S" or t == "T") and power >= 2:
		remove_block(c)


func artillery_impact(pos: Vector3) -> void:
	explode_fx(pos + Vector3(0, 0.3, 0), 2.2, Color(1, 0.5, 0.15))
	shake = 0.25
	if player != null and is_instance_valid(player):
		var d := Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length()
		if d < 1.1 and absf(player.global_position.y - pos.y) < 1.0:
			player.take_hit(1)
	var pc := cell_of(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := pc + Vector2i(dx, dz)
			if cells.get(c, "") == "B" and cell_center(c).distance_to(Vector3(pos.x, 0, pos.z)) < 1.2:
				remove_block(c)


func on_player_hit() -> void:
	shake = 0.35
	show_msg("HIT!  HP %d" % player.hp, 1.0)


func on_tank_destroyed(t) -> void:
	explode_fx(t.global_position + Vector3(0, 0.4, 0), 1.8, Color(1, 0.6, 0.2))
	if t == player:
		shake = 0.6
		state = "dying"
		state_t = 1.5
		return
	enemies.erase(t)
	kills += 1
	score += t.score_value
	if kills >= total and state == "playing":
		state = "clear"
		state_t = 3.5
		if player != null and is_instance_valid(player):
			carry_hp = player.hp
			carry_weapon = player.weapon
		show_msg("LEVEL CLEAR!", 3.5)


# ---------------------------------------------------------------- items

func spawn_item_random() -> void:
	var free_cells: Array = []
	for c in cells:
		var t: String = cells[c]
		if (t == "." or t == "I") and not enemy_spawns.has(c):
			free_cells.append(c)
	if free_cells.is_empty():
		return
	var c: Vector2i = free_cells[randi() % free_cells.size()]
	var type: String = ITEM_TYPES[randi() % ITEM_TYPES.size()]
	var info: Array = ITEM_INFO[type]
	var node := Node3D.new()
	level_root.add_child(node)
	node.position = cell_center(c) + Vector3(0, 0.45, 0)
	var m := std_mat(info[1])
	m.emission_enabled = true
	m.emission = info[1] * 0.5
	add_mesh(box_mesh(Vector3(0.5, 0.5, 0.5)), m, Vector3.ZERO, node)
	var lbl := Label3D.new()
	lbl.text = info[0]
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.outline_size = 16
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 0.55, 0)
	node.add_child(lbl)
	items.append({"node": node, "type": type, "t": 0.0, "color": info[1]})
	show_msg("ITEM DROPPED: " + info[0], 1.2)


func update_items(delta: float) -> void:
	for it in items.duplicate():
		var node: Node3D = it.node
		it.t += delta
		node.rotation.y += delta * 2.0
		node.position.y = 0.45 + sin(it.t * 3.0) * 0.08
		node.visible = it.t < 11.0 or fmod(it.t, 0.3) < 0.18
		if it.t > 15.0:
			node.queue_free()
			items.erase(it)
			continue
		if player != null and is_instance_valid(player):
			var d := Vector2(player.global_position.x - node.position.x, player.global_position.z - node.position.z).length()
			if d < 0.75:
				apply_item(it.type)
				explode_fx(node.global_position, 1.0, it.color)
				node.queue_free()
				items.erase(it)


func apply_item(type: String) -> void:
	show_msg(ITEM_INFO[type][2], 1.8)
	score += 50
	match type:
		"star":
			player.weapon = mini(3, player.weapon + 1)
			show_msg("WEAPON LEVEL %d" % player.weapon + (" - BREAKS STEEL!" if player.weapon >= 3 else ""), 1.8)
		"shield":
			player.shield = 10.0
		"heart":
			player.hp = mini(MAX_HP, player.hp + 1)
		"freeze":
			freeze_t = 8.0
		"bomb":
			shake = 0.5
			for e in enemies.duplicate():
				if is_instance_valid(e):
					e.die()
		"walls":
			build_temp_walls()
		"radar":
			radar_t = 15.0


func build_temp_walls() -> void:
	var pc := cell_of(player.global_position)
	var f: Vector3 = player.facing
	var front := Vector2i(int(signf(f.x)), 0) if absf(f.x) > absf(f.z) else Vector2i(0, int(signf(f.z)))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var d := Vector2i(dx, dz)
			if d == Vector2i.ZERO or d == front:
				continue
			var c := pc + d
			if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
				continue
			if cells.get(c, "") != "." or enemy_spawns.has(c):
				continue
			var occupied := false
			for e in enemies:
				if is_instance_valid(e) and cell_of(e.global_position) == c:
					occupied = true
			if occupied:
				continue
			make_block(c, "T")
			temp_walls.append({"cell": c, "t": 12.0})


func update_temp_walls(delta: float) -> void:
	for w in temp_walls.duplicate():
		w.t -= delta
		if w.t <= 0.0:
			if cells.get(w.cell, "") == "T":
				remove_block(w.cell)
			temp_walls.erase(w)


# ---------------------------------------------------------------- effects

func explode_fx(pos: Vector3, size: float, col: Color) -> void:
	if level_root == null:
		return
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := add_mesh(sm, m, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)


func debris_fx(pos: Vector3, m: Material) -> void:
	for i in 5:
		var mi := add_mesh(box_mesh(Vector3(0.2, 0.2, 0.2)), m, pos)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		var dest := pos + Vector3(randf_range(-0.8, 0.8), randf_range(-0.3, 0.5), randf_range(-0.8, 0.8))
		tw.tween_property(mi, "position", dest, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.45)
		tw.tween_property(mi, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.45)
		tw.chain().tween_callback(mi.queue_free)


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	var confirm := Input.is_action_just_pressed("confirm") or touch_confirm
	touch_confirm = false
	match state:
		"title":
			var pick := -1
			if confirm:
				pick = 0
			if pending_pick >= 0:
				pick = pending_pick
				pending_pick = -1
			if pick >= 0:
				score = 0
				carry_hp = 3
				carry_weapon = 0
				load_level(pick, true)
		"playing":
			freeze_t = maxf(0.0, freeze_t - delta)
			radar_t = maxf(0.0, radar_t - delta)
			update_spawning(delta)
			update_items(delta)
			update_temp_walls(delta)
		"dying":
			state_t -= delta
			if state_t <= 0.0:
				state = "gameover"
		"gameover":
			if confirm:
				carry_hp = 3
				carry_weapon = 0
				load_level(level_idx, true)
		"clear":
			state_t -= delta
			if state_t <= 0.0:
				if level_idx + 1 < LEVELS.size():
					load_level(level_idx + 1, true)
				else:
					state = "victory"
		"victory":
			if confirm:
				state = "title"
				load_level(0, false)
	update_camera(delta)
	update_hud(delta)


func update_camera(delta: float) -> void:
	var target := Vector3(W / 2.0, 0, H / 2.0)
	if state != "title" and player != null and is_instance_valid(player):
		target = player.global_position
		target.x = clampf(target.x, 6.0, W - 6.0)
		target.z = clampf(target.z, 3.0, H - 4.5)
	target.y = 0.0
	cam_focus = cam_focus.lerp(target, minf(1.0, 4.0 * delta))
	var dist := 17.0 if state == "title" else 13.0
	camera.position = cam_focus + Vector3(0, dist, dist * 0.62)
	camera.look_at(cam_focus)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		camera.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.5


func update_hud(delta: float) -> void:
	msg_t = maxf(0.0, msg_t - delta)
	msg_label.visible = msg_t > 0.0 and state != "title"
	center_label.text = ""
	match state:
		"title":
			hud_label.text = ""
			center_label.text = "TANK ARENA 3D\n\nDestroy every enemy tank. You can take 3 hits.\nShoot flashing tanks to make them drop items.\n\nMove: WASD / Arrows     Fire: Space / J\nTouch: drag left side to move, hold right side to fire\n\nPress ENTER or tap to start  (or 1-%d to pick a level)" % LEVELS.size()
			return
		"gameover":
			center_label.text = "GAME OVER\n\nScore %d\n\nPress ENTER or tap to retry level %d" % [score, level_idx + 1]
		"victory":
			center_label.text = "VICTORY!\n\nAll arenas cleared\nFinal score %d\n\nPress ENTER or tap to play again" % score
	var lines: Array = []
	lines.append("LEVEL %d  %s" % [level_idx + 1, LEVELS[level_idx]["name"]])
	lines.append("ENEMIES LEFT %d" % (total - kills))
	lines.append("SCORE %d" % score)
	if player != null and is_instance_valid(player):
		lines.append("WEAPON Lv %d" % player.weapon)
		if player.shield > 0.0:
			lines.append("SHIELD %d" % ceili(player.shield))
		if player_hidden():
			lines.append("HIDDEN IN BUSH")
	if freeze_t > 0.0:
		lines.append("FREEZE %d" % ceili(freeze_t))
	if not temp_walls.is_empty():
		lines.append("WALLS %d" % ceili(temp_walls[0].t))
	hud_label.text = "\n".join(lines)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and state == "title":
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < LEVELS.size():
			pending_pick = n
	if event is InputEventScreenTouch:
		var vp := get_viewport().get_visible_rect().size
		if event.pressed:
			if state != "playing":
				touch_confirm = true
				return
			if event.position.x < vp.x * 0.5:
				touch_id = event.index
				touch_origin = event.position
				touch_vec = Vector2.ZERO
			else:
				fire_id = event.index
				touch_fire = true
		else:
			if event.index == touch_id:
				touch_id = -1
				touch_vec = Vector2.ZERO
			if event.index == fire_id:
				fire_id = -1
				touch_fire = false
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_vec = ((event.position - touch_origin) / 60.0).limit_length(1.0)
