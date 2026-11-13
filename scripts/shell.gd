extends Node3D
## Artillery shell: flies in an arc over walls and explodes at the target.

var main = null
var start := Vector3.ZERO
var target := Vector3.ZERO
var t := 0.0
var dur := 1.4
var marker: Node3D


func _physics_process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	t += delta
	var k := minf(t / dur, 1.0)
	var p := start.lerp(target, k)
	p.y += sin(PI * k) * 4.0
	global_position = p
	if is_instance_valid(marker):
		marker.scale = Vector3.ONE * (1.4 - 0.5 * k)
	if k >= 1.0:
		main.artillery_impact(target)
		if is_instance_valid(marker):
			marker.queue_free()
		queue_free()
