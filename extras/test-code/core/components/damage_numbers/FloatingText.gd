class_name FloatingText
extends Node2D
## Self-contained floating damage number.
## Spawn via FloatingText.spawn(scene_root, world_position, text).
## Adds itself to scene_root, animates upward + fade, then frees itself.

const FLOAT_DISTANCE := 45.0
const DURATION       := 0.85
const FONT_SIZE      := 20

static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var ft := FloatingText.new()
	parent.add_child(ft)
	ft.global_position = world_pos
	ft._start(text, color)

var _label: Label
var _tween: Tween

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.pivot_offset = _label.size / 2.0
	add_child(_label)
	z_index = 10

func _start(text: String, color: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	# Center the label over the spawn point
	await get_tree().process_frame
	_label.pivot_offset = _label.size / 2.0
	_label.position     = -_label.size / 2.0

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	_tween.chain().tween_callback(queue_free)
