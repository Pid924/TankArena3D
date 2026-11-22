extends Node3D
## Tank Arena 3D: game manager. Builds levels procedurally from text maps,
## spawns enemies, handles items, menus, HUD, camera and local 2-player input.

const TankScript = preload("res://scripts/tank.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const ShellScript = preload("res://scripts/shell.gd")
const OverlayScript = preload("res://scripts/overlay.gd")
const Icons = preload("res://scripts/icons.gd")
const I18n = preload("res://scripts/i18n.gd")
const THAI_FONT = preload("res://fonts/NotoSansThai.ttf")
const SfxScript = preload("res://scripts/sfx.gd")

# Map legend:
#  .  floor        B  brick (breakable)     S  steel (needs max weapon)
#  W  water        G  bush (hides player)   I  ice (slippery)
#  H  high ground  > < ^ v  ramp rising toward that direction (^ = up/north)
#  P  player start (player 2 starts on the nearest free cell)   E  enemy spawn
# Enemy list (20 letters): b scout, f racer, h bulwark, a mortar, s ghost,
#  o hovercraft, m mine layer, t thief
const LEVELS := [
	{
		"enemies": "bhbfbhbbfhbbhfbbhbfh",
		"map": [
			"E.........E.........E",
			"..BB..BB.....BB..BB..",
			"..BB..BB..S..BB..BB..",
			".....................",
			"WWWWWW..WWWWW..WWWWWW",
			"WWWWWW..WWWWW..WWWWWW",
			"....B...........B....",
			"GG..B..SS...SS..B..GG",
			"GG.......WWW.......GG",
			"....BB..WWGWW..BB....",
			".........WWW.........",
			"..B...............B..",
			"..B..BBB.....BBB..B..",
			"WWW...............WWW",
			"WGW..BB..BBB..BB..WGW",
			"WWW.......P.......WWW",
			".....................",
		],
	},
	{
		"enemies": "bfahbbfahbfbahbfhbab",
		"map": [
			"E.........E.........E",
			"....BB.........BB....",
			"..S....WWWWWWW....S..",
			"..S..WWW.....WWW..S..",
			"....WW..BB.BB..WW....",
			"GG.WW...B...B...WW.GG",
			"GG.W.....GGG.....W.GG",
			"...W..SS.GGG.SS..W...",
			"...W.....GGG.....W...",
			"...WW...........WW...",
			"....WWW..B.B..WWW....",
			"..B...WWW...WWW...B..",
			"..B......B.B......B..",
			".....BB.......BB.....",
			"IIIII...........IIIII",
			"IIIII.B..BPB..B.IIIII",
			".....................",
		],
	},
	{
		"enemies": "bmfahbmfbahmbfmhabfb",
		"map": [
			"E.........E.........E",
			"..BBB...........BBB..",
			"..B.....GGGGG.....B..",
			"..B..SS.......SS..B..",
			"IIIIIIIIIIIIIIIIIIIII",
			"IIWWWWIIIIBIIIIWWWWII",
			"IIWWWWIIIBBBIIIWWWWII",
			"IIWWWWIIIIBIIIIWWWWII",
			"..BB....HHHHH....BB..",
			"..BB...>HHHHH<...BB..",
			"WWW.....HHHHH.....WWW",
			"WGW.....^...^.....WGW",
			"WWW..BB.......BB..WWW",
			".....B..BBBBB..B.....",
			"..SS.....B.B.....SS..",
			"WWWW......P......WWWW",
			"WWWW.............WWWW",
		],
	},
	{
		"enemies": "bsfmahsbfmhsabfsmhbs",
		"map": [
			"E.........E.........E",
			"...GG...........GG...",
			".WWWWW..BB.BB..WWWWW.",
			".WGGGW.........WGGGW.",
			".WGGGW..S...S..WGGGW.",
			".WW.WW.........WW.WW.",
			".......WW...WW.......",
			"..BB...WG...GW...BB..",
			"..BB...WW...WW...BB..",
			".........SSS.........",
			"GG..WWW.......WWW..GG",
			"GG..WGW..B.B..WGW..GG",
			"....WWW..B.B..WWW....",
			"..S.......G.......S..",
			"..S..BB..BBB..BB..S..",
			"..........P..........",
			"GGG...............GGG",
		],
	},
	{
		"enemies": "obsfoamhbofsmoahbfso",
		"map": [
			"E.........E.........E",
			"..BB.....BBB.....BB..",
			".....................",
			".WWWWW.WWWWWWW.WWWWW.",
			".WGGGW.W.....W.WGGGW.",
			".WGGGW.W.BSB.W.WGGGW.",
			".WWWWW.W.....W.WWWWW.",
			".......WWW.WWW.......",
			"..SS.............SS..",
			".WWWWW..BB.BB..WWWWW.",
			".W.B.W.........W.B.W.",
			".WWWWW..GGGGG..WWWWW.",
			".......WW...WW.......",
			"..BB...WG...GW...BB..",
			"..BB...WW...WW...BB..",
			"..........P..........",
			".....BB.......BB.....",
		],
	},
	{
		"enemies": "wbfowsahwmbofwshawbo",
		"map": [
			"E.........E.........E",
			".BB.BB.BB...BB.BB.BB.",
			".BB.BB.BB...BB.BB.BB.",
			"WWWWWWW..WWW..WWWWWWW",
			".....................",
			".SS.BB.BB...BB.BB.SS.",
			".SS.BB.BB.G.BB.BB.SS.",
			"WWWWW..WWWWWWW..WWWWW",
			".....................",
			".BB.BB.BB...BB.BB.BB.",
			".BB.BB.BB.S.BB.BB.BB.",
			"WWWW...WWWWWWW...WWWW",
			"GG.................GG",
			"GG..BBB.......BBB..GG",
			"....B...........B....",
			"..........P..........",
			"WWW...............WWW",
		],
	},
	{
		"enemies": "rwbofrsamhrwofbsrahw",
		"map": [
			"E.........E.........E",
			"...S.....BBB.....S...",
			".GGS..HHHHHHHHH..SGG.",
			".GG...H.......H...GG.",
			"WWW...H.BB.BB.H...WWW",
			"WWW..>H.B...B.H<..WWW",
			"......H...v...H......",
			"......HHHHHHHHH......",
			"WWWWW.....^.....WWWWW",
			"..BBSS..IIIII..SSBB..",
			"WW......IIIII......WW",
			"GW..BB..IIIII..BB..WG",
			"WW..B...........B..WW",
			"....B..BB.WWW.BB.B...",
			"..SS...B..WGW..B.SS..",
			"..........P..........",
			"GGG...............GGG",
		],
	},
	{
		"enemies": "tbrowtfsamhrtowbfstr",
		"map": [
			"E.........E.........E",
			"...BB.....W.....BB...",
			"..........W..........",
			"WWWW..BB..W..BB..WWWW",
			"...W......W......W...",
			"...W..SS.....SS..W...",
			"GG.W......W......W.GG",
			"GG.WWWW...W...WWWW.GG",
			"..........W..........",
			"..BB..BB..W..BB..BB..",
			"..........W..........",
			"WWWWW.....W.....WWWWW",
			"...G..BB.....BB..G...",
			"...G.............G...",
			"..SS..B..BBB..B..SS..",
			"..........P..........",
			"GGG.......W.......GGG",
		],
	},
	{
		"enemies": "frwtohsamtrwofhsatmr",
		"map": [
			"E.........E.........E",
			"IIIIIIIIIIIIIIIIIIIII",
			"IBBIIWWWWIIIWWWWIIBBI",
			"IIIIIWGGWIIIWGGWIIIII",
			"IISSIWWWWIBIWWWWISSII",
			"IIIIIIIIIBBBIIIIIIIII",
			"WWWWWII.......IIWWWWW",
			"WWWWWI..BB.BB..IWWWWW",
			"......I.......I......",
			"..BB..IIIIIIIII..BB..",
			".....................",
			"GG..WWWW.....WWWW..GG",
			"GG..WGGW..S..WGGW..GG",
			"....WWWW.....WWWW....",
			"..SS....BB.BB....SS..",
			"..........P..........",
			"WWWW.............WWWW",
		],
	},
	{
		"enemies": "hrwtosamfhrwtosamfrh",
		"map": [
			"E.........E.........E",
			"..SS.....SSS.....SS..",
			".....................",
			"WWWW.HHHHHHHHHHH.WWWW",
			"W..W.H....B....H.W..W",
			"W.GW.H.SS...SS.H.WG.W",
			"W..W>H....v....H<W..W",
			"WWWW.HHHHHHHHHHH.WWWW",
			"..........^..........",
			"..BB.WWW.....WWW.BB..",
			"..BB.WGW.BBB.WGW.BB..",
			".....WWW.....WWW.....",
			"IIII.............IIII",
			"IIII..BB..S..BB..IIII",
			"..S...B.......B...S..",
			"..........P..........",
			"GGG....WWW.WWW....GGG",
		],
	},
]

const ITEM_TYPES := ["star", "shield", "heart", "freeze", "bomb", "amphibious", "flame", "speed", "slow"]
const ITEM_WEIGHTS := {"star": 3, "shield": 2, "heart": 2, "freeze": 2, "bomb": 1, "amphibious": 3, "flame": 2, "speed": 2, "slow": 2}
const ITEM_COLORS := {
	"star": Color(1.0, 0.85, 0.2),
	"shield": Color(0.3, 0.8, 1.0),
	"heart": Color(1.0, 0.3, 0.4),
	"freeze": Color(0.7, 0.95, 1.0),
	"bomb": Color(1.0, 0.45, 0.1),
	"amphibious": Color(0.3, 0.7, 1.0),
	"flame": Color(1.0, 0.4, 0.1),
	"speed": Color(1.0, 0.6, 0.1),
	"slow": Color(0.75, 0.55, 1.0),
}
const ENEMY_KINDS := {"b": "basic", "f": "fast", "h": "heavy", "a": "artillery", "s": "stealth", "o": "hover", "m": "miner", "t": "thief", "r": "flamer", "w": "twin"}
const KIND_ORDER := ["basic", "fast", "heavy", "artillery", "stealth", "hover", "miner", "twin", "flamer", "thief"]
const CARRIER_SLOTS := [2, 6, 10, 14, 18]
const MAX_ON_FIELD := 4
const MAX_HP := 5
const SETTINGS_PATH := "user://settings.cfg"

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
var players: Array = []
var enemies: Array = []
var items: Array = []
var mines: Array = []
var spawn_list := ""
var spawn_index := 0
var spawn_timer := 1.0
var spawn_rr := 0
var kills := 0
var total := 20
var score := 0
var level_idx := 0
var start_level := 0
var num_players := 1
var demo := false  # no human players: the computer drives every tank, any key exits
var p_mode := ["human", "off"]  # per player: "human", "cpu" or "off" (P2 only)
var carry_hp := [3, 3]
var carry_weapon := 0
var state := "title"
var state_t := 0.0
var lang := "th"
var sfx: Node
var sound_on := true

# timed effects (players' items)
var freeze_t := 0.0
var flame_t := 0.0
var amphibious_t := 0.0
var speed_t := 0.0
var slow_t := 0.0
# timed effects (items stolen by thieves)
var enemy_shield_t := 0.0
var enemy_fast_t := 0.0
var enemy_amph_t := 0.0
var player_slow_t := 0.0
var player_freeze_t := 0.0
var enemy_flame_t := 0.0

var msg_t := 0.0
var touch_vec := Vector2.ZERO
var touch_fire := false
var touch_id := -1
var fire_id := -1
var touch_origin := Vector2.ZERO

var hud_label: Label
var msg_label: Label
var overlay: Control
var menu_root: CenterContainer
var menu_box: VBoxContainer
var ui_font: Font
var mats := {}
var mesh_cache := {}
var item_tex := {}
var flag_tex := {}


func _ready() -> void:
	randomize()
	load_settings()
	setup_input()
	setup_font()
	make_materials()
	setup_world()
	setup_hud()
	sfx = SfxScript.new()
	add_child(sfx)
	sfx.set_muted(not sound_on)
	load_level(0)
	show_title()


func tr_(key: String) -> String:
	return I18n.t(key, lang)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		lang = cfg.get_value("game", "lang", "th")
		sound_on = cfg.get_value("game", "sound", true)
		p_mode = [cfg.get_value("game", "p1", "human"), cfg.get_value("game", "p2", "off")]
	if not ["human", "cpu"].has(p_mode[0]):
		p_mode[0] = "human"
	if not ["human", "cpu", "off"].has(p_mode[1]):
		p_mode[1] = "off"
	if not I18n.LANGS.has(lang):
		lang = "th"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "lang", lang)
	cfg.set_value("game", "sound", sound_on)
	cfg.set_value("game", "p1", p_mode[0])
	cfg.set_value("game", "p2", p_mode[1])
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------- setup

func setup_input() -> void:
	var keymap := {
		"p1_up": [KEY_W], "p1_down": [KEY_S], "p1_left": [KEY_A], "p1_right": [KEY_D],
		"p1_fire": [KEY_SPACE, KEY_J],
		"p2_up": [KEY_UP], "p2_down": [KEY_DOWN], "p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT],
		"p2_fire": [KEY_ENTER, KEY_KP_ENTER, KEY_CTRL, KEY_KP_0],
	}
	for a in keymap:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keymap[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	# gamepads: first pad drives player 1, second pad player 2
	for pi in 2:
		var pre := "p%d_" % (pi + 1)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_A
		jb.device = pi
		InputMap.action_add_event(pre + "fire", jb)
		var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
		for a in axes:
			var ja := InputEventJoypadMotion.new()
			ja.axis = axes[a][0]
			ja.axis_value = axes[a][1]
			ja.device = pi
			InputMap.action_add_event(pre + a, ja)


func setup_font() -> void:
	# Default font for Latin text, Noto Sans Thai as fallback for Thai glyphs.
	var fv: FontFile = THAI_FONT.duplicate()
	fv.fallbacks = [ThemeDB.fallback_font]
	ui_font = fv
	var theme := Theme.new()
	theme.default_font = fv
	theme.default_font_size = 20
	get_tree().root.theme = theme


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
	for t in ITEM_TYPES:
		item_tex[t] = Icons.make(t, ITEM_COLORS[t])
	for code in I18n.LANGS:
		flag_tex[code] = Icons.flag(code)
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
	mats.mine = std_mat(Color(0.25, 0.25, 0.25))
	mats.mine_light = std_mat(Color(1.0, 0.15, 0.1))
	mats.mine_light.emission_enabled = true
	mats.mine_light.emission = Color(1.0, 0.1, 0.05)


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
	hud_label = make_label(17, HORIZONTAL_ALIGNMENT_LEFT)
	hud_label.position = Vector2(16, 40)
	layer.add_child(hud_label)
	msg_label = make_label(32, HORIZONTAL_ALIGNMENT_CENTER)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-450, 110)
	msg_label.size = Vector2(900, 120)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(msg_label)
	menu_root = CenterContainer.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu_root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.88)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	sb.border_color = Color(0.3, 0.8, 0.6, 0.8)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	menu_root.add_child(panel)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	panel.add_child(menu_box)


# ---------------------------------------------------------------- menus

func clear_menu() -> void:
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()


func hide_menu() -> void:
	clear_menu()
	menu_root.visible = false


func menu_text(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 860
	menu_box.add_child(l)
	return l


func menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(380, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): sfx.play("click", -4.0))
	b.pressed.connect(cb)
	menu_box.add_child(b)
	return b


func focus_first_button() -> void:
	for c in menu_box.get_children():
		if c is Button:
			c.grab_focus()
			return


func human_count() -> int:
	var n := 0
	for i in num_players:
		if p_mode[i] == "human":
			n += 1
	return n


func show_title(focus_idx := 0) -> void:
	state = "title"
	clear_menu()
	menu_root.visible = true
	menu_text("TANK ARENA 3D", 44, Color(0.5, 1.0, 0.75))
	menu_text(tr_("title_tag"), 20)
	menu_button(tr_("btn_play"), func(): start_game())
	menu_button(tr_("p_slot") % [1, tr_("mode_" + p_mode[0])], func():
		p_mode[0] = "cpu" if p_mode[0] == "human" else "human"
		save_settings()
		show_title(1))
	menu_button(tr_("p_slot") % [2, tr_("mode_" + p_mode[1])], func():
		p_mode[1] = {"off": "human", "human": "cpu", "cpu": "off"}[p_mode[1]]
		save_settings()
		show_title(2))
	menu_button(tr_("btn_level") % (start_level + 1), func():
		start_level = (start_level + 1) % LEVELS.size()
		show_title(3))
	# language picker: one flag button per language
	var flags := HBoxContainer.new()
	flags.alignment = BoxContainer.ALIGNMENT_CENTER
	flags.add_theme_constant_override("separation", 14)
	for code in I18n.LANGS:
		var fb := TextureButton.new()
		fb.texture_normal = flag_tex[code]
		fb.ignore_texture_size = true
		fb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		fb.custom_minimum_size = Vector2(72, 48)
		fb.tooltip_text = I18n.LANG_NAMES[code]
		fb.modulate = Color.WHITE if code == lang else Color(0.55, 0.55, 0.55)
		if code == lang:
			fb.scale = Vector2(1.12, 1.12)
			fb.pivot_offset = Vector2(36, 24)
		fb.pressed.connect(func():
			lang = code
			save_settings()
			show_title())
		flags.add_child(fb)
	# sound on/off
	var snd := TextureButton.new()
	snd.texture_normal = Icons.speaker(sound_on)
	snd.ignore_texture_size = true
	snd.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	snd.custom_minimum_size = Vector2(48, 48)
	snd.pressed.connect(func():
		toggle_sound()
		show_title())
	flags.add_child(snd)
	menu_box.add_child(flags)
	menu_text(tr_("controls_1p") + "\n" + tr_("controls_2p") + "\n" + tr_("controls_mute"), 15, Color(0.8, 0.85, 0.9))
	focus_button.call_deferred(focus_idx)


func focus_button(idx: int) -> void:
	var n := 0
	for c in menu_box.get_children():
		if c is Button:
			if n == idx:
				c.grab_focus()
				return
			n += 1


## n/watch are shortcuts used by tests; the menu uses the P1/P2 settings.
func start_game(n := 0, watch := false) -> void:
	if n == 1:
		p_mode = ["human", "off"]
	elif n == 2:
		p_mode = ["cpu", "cpu"] if watch else ["human", "human"]
	num_players = 1 if p_mode[1] == "off" else 2
	demo = human_count() == 0
	score = 0
	carry_hp = [3, 3]
	carry_weapon = 0
	show_briefing(start_level)


func show_briefing(idx: int) -> void:
	load_level(idx)
	state = "brief"
	clear_menu()
	menu_root.visible = true
	menu_text(tr_("brief_title") % [idx + 1, tr_("lv_%d" % idx)], 34, Color(0.5, 1.0, 0.75))
	menu_text(tr_("brief_enemies"), 20, Color(1.0, 0.85, 0.4))
	var counts := {}
	var max_hp := {}
	for i in spawn_list.length():
		var k: String = ENEMY_KINDS.get(spawn_list[i], "basic")
		counts[k] = counts.get(k, 0) + 1
		max_hp[k] = maxi(max_hp.get(k, 0), TankScript.KIND_HP[k] + hp_bonus(i))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	for k in KIND_ORDER:
		if not counts.has(k):
			continue
		var sw := ColorRect.new()
		sw.color = TankScript.KIND_COLORS[k]
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(sw)
		var base_hp: int = TankScript.KIND_HP[k]
		var hp_txt := str(base_hp) if base_hp == max_hp[k] else "%d-%d" % [base_hp, max_hp[k]]
		var l := Label.new()
		l.text = "%s  %s  %s\n%s" % [tr_("name_" + k), tr_("brief_count") % counts[k], tr_("brief_hp") % hp_txt, tr_("desc_" + k)]
		l.add_theme_font_size_override("font_size", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		grid.add_child(l)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	menu_box.add_child(gc)
	var notes := tr_("brief_carrier") + "\n" + tr_("brief_tough")
	if num_players == 2:
		notes += "\n" + tr_("brief_shared")
	menu_text(notes, 15, Color(1.0, 0.75, 0.75))
	if demo:
		menu_text(tr_("demo_exit"), 16, Color(0.6, 0.9, 1.0))
		state_t = 4.0
	else:
		menu_button(tr_("btn_start"), func(): begin_level())
	focus_first_button.call_deferred()


func toggle_sound() -> void:
	sound_on = not sound_on
	sfx.set_muted(not sound_on)
	save_settings()
	sfx.play("click")


func begin_level() -> void:
	sfx.play("level_start")
	hide_menu()
	spawn_players()
	state = "playing"
	show_msg(tr_("brief_title") % [level_idx + 1, tr_("lv_%d" % level_idx)], 2.0)


func show_game_over() -> void:
	sfx.play("game_over")
	state = "gameover"
	clear_menu()
	menu_root.visible = true
	menu_text(tr_("gameover"), 44, Color(1.0, 0.4, 0.4))
	menu_text(tr_("score") % score, 22)
	if demo:
		state_t = 5.0
		menu_button(tr_("btn_menu"), func(): end_demo())
		focus_first_button.call_deferred()
		return
	menu_button(tr_("btn_retry"), func():
		carry_hp = [3, 3]
		carry_weapon = 0
		show_briefing(level_idx))
	menu_button(tr_("btn_menu"), func():
		load_level(0)
		show_title())
	focus_first_button.call_deferred()


func end_demo() -> void:
	demo = false
	load_level(0)
	show_title()


func show_victory() -> void:
	sfx.play("victory")
	state = "victory"
	clear_menu()
	menu_root.visible = true
	menu_text(tr_("victory"), 44, Color(1.0, 0.85, 0.3))
	menu_text(tr_("victory_body") % score, 22)
	state_t = 5.0
	menu_button(tr_("btn_menu"), func():
		load_level(0)
		show_title())
	focus_first_button.call_deferred()


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


func alive_players() -> Array:
	return players.filter(func(p): return p != null and is_instance_valid(p) and not p.dead)


func is_hidden(p) -> bool:
	return cells.get(cell_of(p.global_position), ".") == "G"


func nearest_visible_player(pos: Vector3):
	var best = null
	var bd := INF
	for p in alive_players():
		if is_hidden(p):
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best


func nearest_player_dist(pos: Vector3) -> float:
	var bd := INF
	for p in alive_players():
		bd = minf(bd, p.global_position.distance_to(pos))
	return bd


func nearest_item(pos: Vector3):
	var best = null
	var bd := INF
	for it in items:
		var d: float = it.node.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = it.node
	return best


func can_pass_water(t) -> bool:
	if t.is_player:
		return amphibious_t > 0.0
	return t.kind == "hover" or enemy_amph_t > 0.0


func enemy_speed_mult() -> float:
	var m := 1.0
	if slow_t > 0.0:
		m *= 0.45
	if enemy_fast_t > 0.0:
		m *= 1.5
	return m


func player_speed_mult() -> float:
	var m := 1.0
	if speed_t > 0.0:
		m *= 1.6
	if player_slow_t > 0.0:
		m *= 0.6
	return m


func hp_bonus(spawn_i: int) -> int:
	# later tanks in a wave are tougher; the last levels add a bit more
	return int(spawn_i / 7) + int(level_idx / 4)


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

func load_level(idx: int) -> void:
	if level_root:
		level_root.free()
	level_root = Node3D.new()
	add_child(level_root)
	cells.clear()
	blocks.clear()
	enemies.clear()
	items.clear()
	mines.clear()
	enemy_spawns.clear()
	players.clear()
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
	flame_t = 0.0
	amphibious_t = 0.0
	speed_t = 0.0
	slow_t = 0.0
	enemy_shield_t = 0.0
	enemy_fast_t = 0.0
	enemy_amph_t = 0.0
	player_slow_t = 0.0
	player_freeze_t = 0.0
	enemy_flame_t = 0.0
	cam_focus = cell_center(player_spawn)


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
			add_static(Vector3(1, 1.2, 1), p + Vector3(0, 0.6, 0), TankScript.WATER_LAYER)
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
	mi.material_override = mats.brick if type == "B" else mats.steel
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

func free_cell_near(c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, -r), Vector2i(r, -1), Vector2i(-r, -1)]:
			var n: Vector2i = c + d
			if cells.get(n, "#") == "." and not enemy_spawns.has(n):
				return n
	return c


func spawn_players() -> void:
	players.clear()
	var spots := [player_spawn]
	if num_players == 2:
		var left := player_spawn + Vector2i(-2, 0)
		var right := player_spawn + Vector2i(2, 0)
		spots = [left if cells.get(left, "#") == "." else player_spawn, right if cells.get(right, "#") == "." else free_cell_near(player_spawn)]
	for i in num_players:
		var p = TankScript.new()
		level_root.add_child(p)
		p.setup(self, true, "player", i)
		p.is_bot = p_mode[i] == "cpu"
		p.global_position = cell_center(spots[i]) + Vector3(0, 0.05, 0)
		p.hp = carry_hp[i]
		p.max_hp = MAX_HP
		p.weapon = carry_weapon
		p.shield = 3.0
		players.append(p)


func update_spawning(delta: float) -> void:
	if spawn_index >= spawn_list.length() or enemy_spawns.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0.0 or enemies.size() >= MAX_ON_FIELD:
		return
	var sp: Vector2i = enemy_spawns[spawn_rr % enemy_spawns.size()]
	spawn_rr += 1
	var pos := cell_center(sp)
	for t in enemies + alive_players():
		if is_instance_valid(t) and t.global_position.distance_to(pos) < 1.1:
			spawn_timer = 0.3
			return
	var e = TankScript.new()
	level_root.add_child(e)
	e.setup(self, false, ENEMY_KINDS.get(spawn_list[spawn_index], "basic"))
	e.set_bonus_hp(hp_bonus(spawn_index))
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
	sfx.play("spawn", -10.0)


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
	sfx.play("whistle", -6.0)


func spawn_mine(pos: Vector3) -> void:
	var c := cell_of(pos)
	var t: String = cells.get(c, "#")
	if t != "." and t != "I":
		return
	for m in mines:
		if m.cell == c:
			return
	var node := Node3D.new()
	level_root.add_child(node)
	node.position = Vector3(pos.x, 0.0, pos.z)
	var body := CylinderMesh.new()
	body.top_radius = 0.2
	body.bottom_radius = 0.26
	body.height = 0.08
	add_mesh(body, mats.mine, Vector3(0, 0.04, 0), node)
	var light := SphereMesh.new()
	light.radius = 0.07
	light.height = 0.1
	var lm := add_mesh(light, mats.mine_light, Vector3(0, 0.1, 0), node)
	mines.append({"node": node, "light": lm, "cell": c, "t": 8.0})
	sfx.play("mine", -8.0)


func update_mines(delta: float) -> void:
	for m in mines.duplicate():
		m.t -= delta
		var node: Node3D = m.node
		m.light.visible = fmod(m.t, 0.5) < 0.3 if m.t > 2.0 else fmod(m.t, 0.2) < 0.1
		var hit = null
		for p in alive_players():
			var d := Vector2(p.global_position.x - node.position.x, p.global_position.z - node.position.z).length()
			if d < 0.5 and absf(p.global_position.y - node.position.y) < 0.4:
				hit = p
		if hit != null:
			explode_fx(node.position + Vector3(0, 0.2, 0), 1.4, Color(1, 0.5, 0.15))
			shake = 0.3
			show_msg(tr_("msg_mine"), 1.0)
			sfx.play("boom", -2.0)
			hit.take_hit(1)
		if hit != null or m.t <= 0.0:
			node.queue_free()
			mines.erase(m)


# ---------------------------------------------------------------- combat

## A player bullet and an enemy bullet that meet cancel each other out.
func bullets_clash(a, b) -> void:
	a.dead = true
	b.dead = true
	explode_fx((a.global_position + b.global_position) * 0.5, 0.6, Color(1, 1, 0.8))
	sfx.play("hit", -6.0)
	a.queue_free()
	b.queue_free()


func bullet_hit(b, collider, pos: Vector3) -> void:
	explode_fx(pos, 0.45, Color(1, 0.9, 0.5))
	if collider == null:
		return
	if not collider.has_meta("tank") and not collider.has_meta("block"):
		sfx.play("hit", -10.0)
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
		sfx.play("brick", -6.0 if hp > 0 else -2.0)
		if hp <= 0:
			remove_block(c)
		else:
			body.set_meta("hp", hp)
			var mi: MeshInstance3D = body.get_meta("mesh")
			mi.material_override = mats.brick_dmg
			mi.scale.y = 0.75
			mi.position.y = 0.3
	elif t == "S" and power >= 2:
		sfx.play("brick", -2.0)
		remove_block(c)
	elif t == "S":
		sfx.play("steel", -8.0)


func artillery_impact(pos: Vector3) -> void:
	explode_fx(pos + Vector3(0, 0.3, 0), 2.2, Color(1, 0.5, 0.15))
	sfx.play("boom", -4.0)
	shake = 0.25
	for p in alive_players():
		var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if d < 1.1 and absf(p.global_position.y - pos.y) < 1.0:
			p.take_hit(1)
	var pc := cell_of(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := pc + Vector2i(dx, dz)
			if cells.get(c, "") == "B" and cell_center(c).distance_to(Vector3(pos.x, 0, pos.z)) < 1.2:
				remove_block(c)


func on_player_hit(p) -> void:
	shake = 0.35
	sfx.play("player_hit")
	show_msg(tr_("msg_hit") % [p.player_idx + 1, p.hp], 1.0)


func on_tank_destroyed(t) -> void:
	explode_fx(t.global_position + Vector3(0, 0.4, 0), 1.8, Color(1, 0.6, 0.2))
	sfx.play("explode", 0.0 if t.is_player else -3.0)
	if t.is_player:
		shake = 0.6
		if num_players == 2:
			show_msg(tr_("msg_dead") % (t.player_idx + 1), 2.0)
		if alive_players().is_empty():
			state = "dying"
			state_t = 1.5
		return
	enemies.erase(t)
	kills += 1
	score += t.score_value
	if kills >= total and state == "playing":
		state = "clear"
		state_t = 3.5
		carry_hp = [3, 3]
		for p in alive_players():
			carry_hp[p.player_idx] = p.hp
			carry_weapon = p.weapon
		show_msg(tr_("msg_clear"), 3.5)
		sfx.play("level_clear")


# ---------------------------------------------------------------- items

func pick_item_type() -> String:
	var total_w := 0
	for t in ITEM_TYPES:
		total_w += ITEM_WEIGHTS[t]
	var r := randi() % total_w
	for t in ITEM_TYPES:
		r -= ITEM_WEIGHTS[t]
		if r < 0:
			return t
	return "star"


func spawn_item_random(force_type := "") -> void:
	var free_cells: Array = []
	for c in cells:
		var t: String = cells[c]
		if (t == "." or t == "I") and not enemy_spawns.has(c):
			free_cells.append(c)
	if free_cells.is_empty():
		return
	var c: Vector2i = free_cells[randi() % free_cells.size()]
	var type: String = force_type if force_type != "" else pick_item_type()
	var col: Color = ITEM_COLORS[type]
	var node := Node3D.new()
	level_root.add_child(node)
	node.position = cell_center(c) + Vector3(0, 0.45, 0)
	var spr := Sprite3D.new()
	spr.texture = item_tex[type]
	spr.pixel_size = 0.85 / Icons.SIZE
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.position = Vector3(0, 0.15, 0)
	node.add_child(spr)
	var glow := CylinderMesh.new()
	glow.top_radius = 0.42
	glow.bottom_radius = 0.42
	glow.height = 0.02
	var gm := std_mat(Color(col.r, col.g, col.b, 0.45))
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := add_mesh(glow, gm, cell_center(c) + Vector3(0, 0.02, 0))
	items.append({"node": node, "ring": ring, "type": type, "t": 0.0, "color": col})
	show_msg(tr_("msg_drop"), 1.2)
	sfx.play("item_drop", -3.0)


func remove_item(it: Dictionary) -> void:
	it.ring.queue_free()
	it.node.queue_free()
	items.erase(it)


func update_items(delta: float) -> void:
	for it in items.duplicate():
		var node: Node3D = it.node
		it.t += delta
		node.position.y = 0.45 + sin(it.t * 3.0) * 0.08
		node.visible = it.t < 11.0 or fmod(it.t, 0.3) < 0.18
		it.ring.visible = node.visible
		if it.t > 15.0:
			remove_item(it)
			continue
		var taken := false
		for p in alive_players():
			var d := Vector2(p.global_position.x - node.position.x, p.global_position.z - node.position.z).length()
			if d < 0.75:
				apply_item(it.type)
				explode_fx(node.global_position, 1.0, it.color)
				remove_item(it)
				taken = true
				break
		if taken:
			continue
		for e in enemies:
			if is_instance_valid(e) and e.kind == "thief":
				var d2 := Vector2(e.global_position.x - node.position.x, e.global_position.z - node.position.z).length()
				if d2 < 0.75:
					steal_item(it.type)
					explode_fx(node.global_position, 1.0, Color(0.9, 0.2, 0.6))
					remove_item(it)
					break


func apply_item(type: String) -> void:
	show_msg(tr_("item_" + type) if type != "star" else "", 1.8)
	score += 50
	sfx.play("pickup")
	if type == "freeze":
		sfx.play("freeze", -2.0)
	elif type == "bomb":
		sfx.play("boom")
	match type:
		"star":
			var lv := 0
			for p in alive_players():
				p.weapon = mini(3, p.weapon + 1)
				lv = p.weapon
			show_msg(tr_("item_star_max") if lv >= 3 else tr_("item_star") % lv, 1.8)
		"shield":
			for p in alive_players():
				p.shield = 10.0
		"heart":
			for p in alive_players():
				p.hp = mini(MAX_HP, p.hp + 1)
		"freeze":
			freeze_t = 8.0
		"bomb":
			shake = 0.5
			for e in enemies.duplicate():
				if is_instance_valid(e):
					e.die()
		"amphibious":
			amphibious_t = 15.0
		"flame":
			flame_t = 7.0
		"speed":
			speed_t = 10.0
			player_slow_t = 0.0
		"slow":
			slow_t = 10.0
			enemy_fast_t = 0.0


func steal_item(type: String) -> void:
	# A thief picked up the item: the effect turns against the players.
	show_msg(tr_("steal_" + type), 2.2)
	sfx.play("steal")
	shake = 0.2
	match type:
		"star":
			for p in alive_players():
				p.weapon = maxi(0, p.weapon - 1)
		"shield":
			enemy_shield_t = 8.0
		"heart":
			for e in enemies:
				if is_instance_valid(e):
					e.hp += 1
					e.max_hp = maxi(e.max_hp, e.hp)
		"freeze":
			player_freeze_t = 3.0
		"bomb":
			for p in alive_players():
				explode_fx(p.global_position + Vector3(0, 0.4, 0), 1.6, Color(1, 0.45, 0.1))
				p.take_hit(1)
		"amphibious":
			enemy_amph_t = 12.0
		"flame":
			enemy_flame_t = 7.0
		"speed":
			enemy_fast_t = 10.0
			slow_t = 0.0
		"slow":
			player_slow_t = 6.0
			speed_t = 0.0


func update_timers(delta: float) -> void:
	freeze_t = maxf(0.0, freeze_t - delta)
	flame_t = maxf(0.0, flame_t - delta)
	amphibious_t = maxf(0.0, amphibious_t - delta)
	speed_t = maxf(0.0, speed_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	enemy_shield_t = maxf(0.0, enemy_shield_t - delta)
	enemy_fast_t = maxf(0.0, enemy_fast_t - delta)
	enemy_amph_t = maxf(0.0, enemy_amph_t - delta)
	player_slow_t = maxf(0.0, player_slow_t - delta)
	player_freeze_t = maxf(0.0, player_freeze_t - delta)
	enemy_flame_t = maxf(0.0, enemy_flame_t - delta)


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
	match state:
		"playing":
			update_timers(delta)
			update_spawning(delta)
			update_items(delta)
			update_mines(delta)
		"dying":
			state_t -= delta
			if state_t <= 0.0:
				show_game_over()
		"brief":
			if demo:
				state_t -= delta
				if state_t <= 0.0:
					begin_level()
		"gameover", "victory":
			if demo:
				state_t -= delta
				if state_t <= 0.0:
					end_demo()
		"clear":
			state_t -= delta
			if state_t <= 0.0:
				if level_idx + 1 < LEVELS.size():
					show_briefing(level_idx + 1)
				else:
					show_victory()
	update_camera(delta)
	update_hud(delta)


func update_camera(delta: float) -> void:
	var target := Vector3(W / 2.0, 0, H / 2.0)
	var spread := 0.0
	var alive := alive_players()
	if (state == "playing" or state == "clear" or state == "dying") and not alive.is_empty():
		var sum := Vector3.ZERO
		for p in alive:
			sum += p.global_position
		target = sum / alive.size()
		if alive.size() == 2:
			spread = alive[0].global_position.distance_to(alive[1].global_position)
		target.x = clampf(target.x, 6.0, W - 6.0)
		target.z = clampf(target.z, 3.0, H - 4.5)
	target.y = 0.0
	cam_focus = cam_focus.lerp(target, minf(1.0, 4.0 * delta))
	var dist := 17.0
	if state != "title" and state != "brief":
		dist = 13.0 + clampf((spread - 6.0) * 0.6, 0.0, 6.0)
	camera.position = camera.position.lerp(cam_focus + Vector3(0, dist, dist * 0.62), minf(1.0, 6.0 * delta))
	camera.look_at(cam_focus)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		camera.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.5


func update_hud(delta: float) -> void:
	msg_t = maxf(0.0, msg_t - delta)
	msg_label.visible = msg_t > 0.0 and state != "title" and state != "brief"
	if state == "title" or state == "brief":
		hud_label.text = ""
		return
	var lines: Array = []
	lines.append(tr_("hud_level") % [level_idx + 1, tr_("lv_%d" % level_idx)])
	lines.append(tr_("hud_left") % (total - kills))
	lines.append(tr_("hud_score") % score)
	var alive := alive_players()
	if not alive.is_empty():
		lines.append(tr_("hud_weapon") % alive[0].weapon)
		if alive[0].shield > 0.0:
			lines.append(tr_("hud_shield") % ceili(alive[0].shield))
		for p in alive:
			if is_hidden(p):
				lines.append(("P%d " % (p.player_idx + 1) if num_players == 2 else "") + tr_("hud_hidden"))
	var timers := [
		[freeze_t, "hud_freeze"], [slow_t, "hud_slow"], [speed_t, "hud_speed"], [amphibious_t, "hud_amph"],
		[flame_t, "hud_flame"], [enemy_flame_t, "hud_eflame"], [enemy_shield_t, "hud_eshield"], [enemy_fast_t, "hud_efast"],
		[enemy_amph_t, "hud_eamph"], [player_slow_t, "hud_pslow"], [player_freeze_t, "hud_pfrozen"],
	]
	for t in timers:
		if t[0] > 0.0:
			lines.append(tr_(t[1]) % ceili(t[0]))
	if demo:
		lines.append(tr_("demo_exit"))
	hud_label.position.y = 40.0 if num_players == 1 else 66.0
	hud_label.text = "\n".join(lines)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_sound()
		if state == "title":
			show_title()
		elif state == "playing":
			show_msg(tr_("sound_on") if sound_on else tr_("sound_off"), 0.8)
	# in demo mode any key (except M), click or touch goes back to the title
	if demo and state != "title":
		var quit := false
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode != KEY_M:
			quit = true
		elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			quit = true
		elif event is InputEventJoypadButton and event.pressed:
			quit = true
		if quit:
			get_viewport().set_input_as_handled()
			end_demo.call_deferred()
			return
	if state != "playing":
		touch_id = -1
		fire_id = -1
		touch_vec = Vector2.ZERO
		touch_fire = false
		return
	if event is InputEventScreenTouch:
		var vp := get_viewport().get_visible_rect().size
		if event.pressed:
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
