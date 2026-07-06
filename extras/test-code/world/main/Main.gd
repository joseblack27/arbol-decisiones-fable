extends Node2D
## Entry point scene.
## Owns the game world and the HUD CanvasLayer.

const TILE  := 80
const COLS  := 50
const ROWS  := 38

func _draw() -> void:
	# Large checkerboard floor
	for row in ROWS:
		for col in COLS:
			var rect := Rect2(
				(col - COLS / 2) * TILE,
				(row - ROWS / 2) * TILE,
				TILE, TILE
			)
			var dark := (row + col) % 2 == 0
			draw_rect(rect, Color(0.13, 0.13, 0.13) if dark else Color(0.17, 0.17, 0.17))

	# Map border
	var half_w := COLS / 2.0 * TILE
	var half_h := ROWS / 2.0 * TILE
	draw_rect(Rect2(-half_w, -half_h, COLS * TILE, ROWS * TILE),
		Color(0.5, 0.5, 0.5, 0.8), false, 3.0)
