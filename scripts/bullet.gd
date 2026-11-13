extends Node3D
## Bullet: moves each physics frame and ray-casts the swept segment so it never tunnels.

var main = null
var shooter_rid: RID
var from_player := false
var dir := Vector3(0, 0, -1)
var speed := 12.0
var power := 1
var life := 2.5


func _physics_process(delta: float) -> void:
	if main == null or main.state != "playing":
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
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	if shooter_rid.is_valid():
		q.exclude = [shooter_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		main.bullet_hit(self, hit.collider, hit.position)
		queue_free()
		return
	global_position = to
