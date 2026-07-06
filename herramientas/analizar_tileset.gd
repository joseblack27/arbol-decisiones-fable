# =============================================================================
# Herramienta de un solo uso: clasifica cada celda de 16x16 de tileset_01.png
# por color medio para localizar coordenadas de tiles útiles.
# Leyenda: . vacío | G hierba | g hierba clara | D tierra/marrón | Y arena
#          W agua | S piedra gris | K oscuro/negro | L lava/rojo | x mixto
#   godot --headless --path . --script res://herramientas/analizar_tileset.gd
# =============================================================================
extends SceneTree

const TAM := 16


func _initialize() -> void:
	var imagen := Image.load_from_file("res://assets/tilesets/tileset_01.png")
	var columnas := imagen.get_width() / TAM
	var filas := imagen.get_height() / TAM
	print("Atlas %dx%d celdas de %dpx" % [columnas, filas, TAM])
	var encabezado := "    "
	for x in columnas:
		encabezado += str(x % 10)
	print(encabezado)
	for y in filas:
		var linea := "%3d " % y
		for x in columnas:
			linea += _clasificar(imagen, x, y)
		print(linea)
	quit(0)


func _clasificar(imagen: Image, cx: int, cy: int) -> String:
	var suma := Vector3.ZERO
	var suma2 := Vector3.ZERO
	var opacos := 0
	for px in TAM:
		for py in TAM:
			var c := imagen.get_pixel(cx * TAM + px, cy * TAM + py)
			if c.a < 0.5:
				continue
			opacos += 1
			var v := Vector3(c.r, c.g, c.b)
			suma += v
			suma2 += v * v
	if opacos < 64:
		return "."
	var n := float(opacos)
	var media := suma / n
	var varianza := (suma2 / n) - media * media
	var dispersion := sqrt(maxf(varianza.x + varianza.y + varianza.z, 0.0))
	if opacos < TAM * TAM * 0.9 or dispersion > 0.22:
		return "x"
	var r := media.x
	var g := media.y
	var b := media.z
	if r + g + b < 0.45:
		return "K"
	if b > r and b > g and b > 0.35:
		return "W"
	if r > 0.55 and g < 0.35 and b < 0.25:
		return "L"
	if g > r * 1.25 and g > b * 1.3:
		return "G" if g < 0.55 else "g"
	if r > 0.75 and g > 0.65 and b < 0.45:
		return "Y"
	if r > g and g > b and r > 0.4:
		return "D"
	if absf(r - g) < 0.08 and absf(g - b) < 0.08:
		return "S"
	return "x"
