extends Node2D
## V7 animated menu background: slowly drifting glowing orbs over a subtle
## starfield. Cheap: 14 circles redrawn per frame.

const ORB_COUNT := 16
const STAR_COUNT := 48
const EMBER_COUNT := 28

var _orbs: Array = []
var _stars: Array = []
var _embers: Array = []
var _time: float = 0.0
var _size: Vector2 = Vector2(1280, 720)

func _ready() -> void:
	set_process(true)
	for i in range(ORB_COUNT):
		_orbs.append({
			"base": Vector2(randf() * _size.x, randf() * _size.y),
			"radius": randf_range(70.0, 180.0),
			"drift": randf_range(12.0, 32.0),
			"phase": randf() * TAU,
			"color": [Color(0.25, 0.55, 1.0), Color(1.0, 0.78, 0.1), Color(0.2, 0.85, 0.7)][i % 3],
		})
	for i in range(STAR_COUNT):
		_stars.append({
			"pos": Vector2(randf() * _size.x, randf() * _size.y),
			"r": randf_range(0.9, 2.4),
			"twinkle": randf() * TAU,
		})
	for i in range(EMBER_COUNT):
		_embers.append({
			"x": randf() * _size.x,
			"y": randf() * _size.y,
			"speed": randf_range(25.0, 60.0),
			"size": randf_range(1.5, 3.5),
			"color": Color(1.0, 0.82, 0.2, 0.7) if (i % 2 == 0) else Color(0.3, 0.75, 1.0, 0.7),
			"wobble": randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	for e in _embers:
		e["y"] -= delta * e["speed"]
		e["wobble"] += delta * 2.0
		if e["y"] < -20.0:
			e["y"] = _size.y + 20.0
			e["x"] = randf() * _size.x
	queue_redraw()

func _draw() -> void:
	# Background deep space gradient / central soft vignette
	draw_circle(Vector2(_size.x * 0.5, _size.y * 0.45), 420.0, Color(0.12, 0.18, 0.32, 0.18))
	draw_circle(Vector2(_size.x * 0.5, _size.y * 0.45), 240.0, Color(0.18, 0.26, 0.45, 0.15))

	for s in _stars:
		var a := 0.4 + 0.35 * sin(_time * 2.2 + s["twinkle"])
		draw_circle(s["pos"], s["r"], Color(1.0, 1.0, 1.0, a))

	for o in _orbs:
		var pos: Vector2 = o["base"] + Vector2(
			cos(_time * 0.35 + o["phase"]) * o["drift"] * 2.0,
			sin(_time * 0.28 + o["phase"]) * o["drift"]
		)
		draw_circle(pos, o["radius"], Color(o["color"].r, o["color"].g, o["color"].b, 0.07))
		draw_circle(pos, o["radius"] * 0.45, Color(o["color"].r, o["color"].g, o["color"].b, 0.09))

	# Floating embers
	for e in _embers:
		var ex: float = e["x"] + sin(e["wobble"]) * 14.0
		var ea: float = 0.4 + 0.3 * sin(e["wobble"] * 1.5)
		var col: Color = e["color"]
		col.a = ea
		draw_circle(Vector2(ex, e["y"]), e["size"], col)
		draw_circle(Vector2(ex, e["y"]), e["size"] * 1.8, Color(col.r, col.g, col.b, ea * 0.3))
