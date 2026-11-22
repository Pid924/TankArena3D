extends Node3D
## Bullet: moves each physics frame and ray-casts the swept segment so it never tunnels.

var main = null
var shooter_rid: RID
var from_player := false
var dir := Vector3(0, 0, -1)
var speed := 12.0
var power := 1
var life := 2.5
var dead := false


func _ready() -> void:
	add_to_group("bullets")


func _physics_process(delta: float) -> void:
	if dead or main == null or main.state != "playing":
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + dir * speed * delta
	# follow the terrain height (plateaus, ramps): bullets fired from high ground arc down
	var gh: float = main.ground_height(to.x, to.z) + 0.4
	to.y = move_toward(from.y, gh, speed * delta * 1.2)
	# bullets from opposite sides that meet cancel each other out
	for o in get_tree().get_nodes_in_group("bullets"):
		if o == self or o.dead or o.from_player == from_player:
			continue
		var op: Vector3 = o.global_position
		if absf(op.y - from.y) > 0.6:
			continue
		var seg := Vector2(to.x - from.x, to.z - from.z)
		var rel := Vector2(op.x - from.x, op.z - from.z)
		var t := clampf(rel.dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (rel - seg * t).length() < 0.4:
			main.bullets_clash(self, o)
			return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	if shooter_rid.is_valid():
		q.exclude = [shooter_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		main.bullet_hit(self, hit.collider, hit.position)
		queue_free()
		return
	global_position = to
