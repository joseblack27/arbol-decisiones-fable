# =============================================================================
# Herramienta: genera el atlas de tiles "programmer art" (assets/tiles_mundo.png).
# 11 tiles de 32x32 en una fila:
#   0 hierba A   1 hierba B   2 flores    3 tierra    4 agua      5 roca (muro)
#   6 cueva A    7 cueva B    8 grava     9 agua cueva 10 muro cueva
# Ejecutar y luego importar:
#   godot --headless --path . --script res://herramientas/generar_tiles_png.gd
#   godot --headless --path . --import
# =============================================================================
extends SceneTree

const TAM := 32

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260704
	var imagen := Image.create(TAM * 11, TAM, false, Image.FORMAT_RGBA8)

	_tile_moteado(imagen, 0, Color8(92, 132, 74), 7.0)          # hierba A
	_tile_moteado(imagen, 1, Color8(82, 121, 66), 7.0)          # hierba B
	_tile_moteado(imagen, 2, Color8(88, 128, 70), 6.0)          # base de flores
	_flores(imagen, 2)
	_tile_moteado(imagen, 3, Color8(133, 105, 74), 9.0)         # tierra
	_agua(imagen, 4, Color8(52, 100, 152))                      # agua
	_muro(imagen, 5, Color8(118, 114, 108))                     # roca
	_tile_moteado(imagen, 6, Color8(64, 59, 68), 5.0)           # cueva A
	_tile_moteado(imagen, 7, Color8(72, 66, 75), 5.0)           # cueva B
	_tile_moteado(imagen, 8, Color8(56, 52, 60), 10.0)          # grava
	_agua(imagen, 9, Color8(36, 70, 112))                       # agua cueva
	_muro(imagen, 10, Color8(44, 41, 49))                       # muro cueva

	var error := imagen.save_png("res://assets/tiles_mundo.png")
	if error != OK:
		push_error("No se pudo guardar el atlas (error %d)." % error)
		quit(1)
		return
	print("Atlas generado: res://assets/tiles_mundo.png (recuerda ejecutar --import)")
	quit(0)


## Rellena el tile con el color base más un moteado sutil por píxel.
func _tile_moteado(imagen: Image, indice: int, base: Color, variacion: float) -> void:
	var origen_x := indice * TAM
	for x in TAM:
		for y in TAM:
			var d := _rng.randf_range(-variacion, variacion) / 255.0
			imagen.set_pixel(origen_x + x, y, Color(base.r + d, base.g + d, base.b + d, 1.0))


func _flores(imagen: Image, indice: int) -> void:
	var colores := [Color8(235, 220, 90), Color8(240, 240, 240), Color8(220, 130, 170)]
	var origen_x := indice * TAM
	for _i in 5:
		var x: int = _rng.randi_range(2, TAM - 4)
		var y: int = _rng.randi_range(2, TAM - 4)
		var color: Color = colores[_rng.randi_range(0, colores.size() - 1)]
		for dx in 2:
			for dy in 2:
				imagen.set_pixel(origen_x + x + dx, y + dy, color)


func _agua(imagen: Image, indice: int, base: Color) -> void:
	_tile_moteado(imagen, indice, base, 5.0)
	var origen_x := indice * TAM
	var claro := Color(base.r + 0.10, base.g + 0.10, base.b + 0.12, 1.0)
	for _i in 3:
		var y: int = _rng.randi_range(4, TAM - 5)
		var x0: int = _rng.randi_range(2, 12)
		var largo: int = _rng.randi_range(8, 16)
		for x in range(x0, mini(x0 + largo, TAM - 2)):
			imagen.set_pixel(origen_x + x, y, claro)


## Roca con bisel: borde superior/izquierdo claro, inferior/derecho oscuro.
func _muro(imagen: Image, indice: int, base: Color) -> void:
	_tile_moteado(imagen, indice, base, 8.0)
	var origen_x := indice * TAM
	var claro := Color(base.r + 0.13, base.g + 0.13, base.b + 0.13, 1.0)
	var oscuro := Color(base.r - 0.15, base.g - 0.15, base.b - 0.15, 1.0)
	for i in TAM:
		for grosor in 3:
			imagen.set_pixel(origen_x + i, grosor, claro)
			imagen.set_pixel(origen_x + grosor, i, claro)
			imagen.set_pixel(origen_x + i, TAM - 1 - grosor, oscuro)
			imagen.set_pixel(origen_x + TAM - 1 - grosor, i, oscuro)
