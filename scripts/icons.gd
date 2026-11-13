extends RefCounted
## Procedurally drawn item icons (no image files needed).
## Each icon is a round badge with a picture, rendered into an Image.

const SIZE := 64


static func make(type: String, col: Color) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			# u,v in [-1, 1], v points up
			var u := (x + 0.5) / SIZE * 2.0 - 1.0
			var v := 1.0 - (y + 0.5) / SIZE * 2.0
			img.set_pixel(x, y, shade(type, col, u, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func shade(type: String, col: Color, u: float, v: float) -> Color:
	var r := sqrt(u * u + v * v)
	if r > 0.98:
		return Color(0, 0, 0, 0)
	if r > 0.86:
		return Color(1, 1, 1)
	if r > 0.8:
		return col.darkened(0.5)
	var bg := col.darkened(0.55).lerp(col.darkened(0.25), (v + 1.0) * 0.5)
	var fg := symbol(type, u / 0.72, v / 0.72)
	if fg.a > 0.0:
		return fg
	return bg


static func in_star(u: float, v: float, r_out: float, r_in: float) -> bool:
	var poly := PackedVector2Array()
	for i in 10:
		var ang := TAU * i / 10.0
		var r := r_out if i % 2 == 0 else r_in
		poly.append(Vector2(sin(ang), cos(ang)) * r)
	return Geometry2D.is_point_in_polygon(Vector2(u, v), poly)


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (p - a - ab * h).length()


static func symbol(type: String, u: float, v: float) -> Color:
	var p := Vector2(u, v)
	var white := Color(1, 1, 1)
	var dark := Color(0.08, 0.08, 0.1)
	match type:
		"star":
			if in_star(u, v + 0.05, 1.0, 0.42):
				return Color(1.0, 0.92, 0.3) if in_star(u, v + 0.05, 0.8, 0.32) else Color(0.7, 0.45, 0.0)
		"shield":
			var w := 0.75 if v > -0.1 else 0.75 * (1.0 - (-0.1 - v) / 0.95)
			if v < 0.85 and v > -1.05 and absf(u) < w:
				var w2 := w - 0.14
				if v < 0.72 and absf(u) < w2:
					if absf(u) < 0.1 or absf(v - 0.25) < 0.1:
						return white
					return Color(0.25, 0.65, 1.0)
				return white
		"heart":
			var x := u * 1.15
			var y := v * 1.15 + 0.15
			var q := pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y
			if q <= 0.0:
				var x2 := x * 1.25
				var y2 := y * 1.25 + 0.05
				var q2 := pow(x2 * x2 + y2 * y2 - 1.0, 3.0) - x2 * x2 * y2 * y2 * y2
				if q2 <= 0.0:
					if Vector2(x + 0.35, y - 0.35).length() < 0.16:
						return white
					return Color(1.0, 0.25, 0.35)
				return white
		"freeze":
			var best := 9.0
			for i in 3:
				var a := PI / 3.0 * i
				var d := Vector2(sin(a), cos(a))
				best = minf(best, seg_dist(p, -d * 0.95, d * 0.95))
				for sgn in [-1.0, 1.0]:
					var base: Vector2 = d * 0.55 * sgn
					var bd: Vector2 = d * sgn
					var side := Vector2(-bd.y, bd.x)
					best = minf(best, seg_dist(p, base, base + (bd + side) * 0.3))
					best = minf(best, seg_dist(p, base, base + (bd - side) * 0.3))
			if best < 0.09:
				return Color(0.85, 0.97, 1.0)
		"bomb":
			if seg_dist(p, Vector2(0.3, 0.45), Vector2(0.55, 0.75)) < 0.07:
				return Color(0.75, 0.6, 0.4)
			if Vector2(u - 0.62, v - 0.85).length() < 0.17:
				return Color(1.0, 0.85, 0.2)
			if absf(u - 0.22) < 0.15 and v > 0.28 and v < 0.5 and absf(u - 0.22) + (v - 0.28) < 0.4:
				return Color(0.3, 0.3, 0.35)
			var bc := Vector2(u + 0.08, v + 0.12)
			if bc.length() < 0.68:
				if Vector2(u + 0.3, v - 0.12).length() < 0.15:
					return Color(0.6, 0.6, 0.65)
				return dark
		"radar":
			var rr := p.length()
			if rr < 0.95:
				var ang := fposmod(atan2(u, v), TAU)
				if ang < 0.9 and rr < 0.9:
					return Color(0.4, 1.0, 0.5).lerp(Color(0.1, 0.45, 0.2), ang / 0.9)
				if absf(rr - 0.9) < 0.05 or absf(rr - 0.6) < 0.04 or absf(rr - 0.3) < 0.04:
					return Color(0.5, 1.0, 0.6)
				if absf(u) < 0.03 or absf(v) < 0.03:
					return Color(0.35, 0.8, 0.45)
				if Vector2(u + 0.4, v + 0.35).length() < 0.1:
					return Color(1.0, 0.3, 0.3)
		"amphibious":
			# small tank riding on waves
			if v > -0.05 and v < 0.35 and absf(u) < 0.62:
				return Color(0.3, 0.85, 0.6) if v > 0.0 else Color(0.15, 0.4, 0.3)
			if v >= 0.35 and v < 0.6 and absf(u + 0.05) < 0.28:
				return Color(0.45, 0.95, 0.7)
			if absf(v - 0.47) < 0.06 and u > 0.2 and u < 0.8:
				return dark
			for k in 2:
				var wy := -0.3 - k * 0.38 + sin(u * 6.0 + k * 1.5) * 0.1
				if absf(v - wy) < 0.09 and absf(u) < 0.95:
					return Color(0.55, 0.85, 1.0)
	return Color(0, 0, 0, 0)
