# =============================================================================
# generar_nivel_ciudad.gd — construye escenas/niveles/NivelCiudad.tscn.
#
# Ciudad medieval amurallada, mismo tamaño de área jugable que NivelCueva
# (65x43 tiles). Edificios SIN TECHO a pedido del usuario: son solo el
# contorno de paredes visto desde arriba (piso de calle a la vista adentro,
# nada cubre el interior) — con puerta (hueco de 1 tile en la pared).
#
# Usa ÚNICAMENTE coordenadas de tileset_01.png YA VERIFICADAS como opacas
# por construir_niveles.gd (MURO_OSCURO/TIERRA/PIEDRA/HIERBA) — a propósito
# NINGUNA coordenada nueva sin verificar: el propio historial de este
# proyecto dejó agujeros negros por transparencia la primera vez que se
# usó una tile de borde como relleno (ver comentario de
# generar_nivel_camino.gd). El muro de piedra/ladrillo más "de ciudad" que
# se ve en el atlas queda para una pasada futura, cuando alguien pueda
# verificarlo a ojo en el editor.
#
# Decoración suelta (puesto de mercado + barril) recortada de
# assets/packs/pack items medievales reducido.png — pack sin usar en el
# resto del proyecto, con márgenes generosos porque el recorte es a ojo,
# no hay forma de verificar el pixel exacto sin abrir el editor.
#
#   godot --headless --path . --script res://herramientas/generar_nivel_ciudad.gd
# =============================================================================
extends SceneTree

const RUTA_SALIDA := "res://escenas/niveles/NivelCiudad.tscn"
const TILESET_JUEGO := "res://escenas/niveles/tileset_juego.tres"
const ESCENA_PORTAL := "res://escenas/niveles/PortalNivel.tscn"
const TEXTURA_ITEMS := "res://assets/packs/pack items medievales reducido.png"

# ── Forma del nivel (en tiles de 32 px) — igual área que NivelCueva ──────────
const MITAD_X := 32
const MITAD_Y := 21
const ANCHO := MITAD_X * 2 + 1  # 65
const ALTO := MITAD_Y * 2 + 1   # 43
const GROSOR_MURALLA := 2

# ── Paleta (coordenadas del atlas tileset_01.png, todas verificadas 100%
# opacas por construir_niveles.gd — ver ese archivo) ─────────────────────────
const TIERRA := Vector2i(15, 5)
const TIERRA_B := Vector2i(17, 5)
const PIEDRA := Vector2i(17, 30)
const MURO_OSCURO := Vector2i(27, 5)
const MURO_OSCURO_B := Vector2i(28, 5)
const HIERBA_A := Vector2i(21, 5)
const HIERBA_B := Vector2i(22, 5)

enum LadoPuerta { SUR, NORTE, ESTE, OESTE }


func _tile_a_px(tile: int) -> float:
	return tile * 32.0 + 16.0


func _tierra(x: int, y: int) -> Vector2i:
	return TIERRA if (x + y) % 2 == 0 else TIERRA_B


func _muro(x: int, y: int) -> Vector2i:
	return MURO_OSCURO if (x + y) % 2 == 0 else MURO_OSCURO_B


## Contorno de UN edificio sin techo: paredes en el perímetro con un hueco
## de 1 tile como puerta en el lado indicado; el interior (y la puerta)
## quedan con el mismo piso de tierra que la calle, a la vista.
func _pintar_edificio(terreno: TileMapLayer, x0: int, y0: int, ancho: int, alto: int,
		lado_puerta: LadoPuerta, offset_puerta: int) -> void:
	for dx in range(ancho):
		for dy in range(alto):
			var x := x0 + dx
			var y := y0 + dy
			var es_borde := dx == 0 or dx == ancho - 1 or dy == 0 or dy == alto - 1
			var es_puerta := false
			match lado_puerta:
				LadoPuerta.SUR: es_puerta = dy == alto - 1 and dx == offset_puerta
				LadoPuerta.NORTE: es_puerta = dy == 0 and dx == offset_puerta
				LadoPuerta.ESTE: es_puerta = dx == ancho - 1 and dy == offset_puerta
				LadoPuerta.OESTE: es_puerta = dx == 0 and dy == offset_puerta
			terreno.set_cell(Vector2i(x, y), 0,
				_tierra(x, y) if (not es_borde or es_puerta) else _muro(x, y))


func _pintar_rectangulo(terreno: TileMapLayer, x0: int, y0: int, ancho: int, alto: int,
		par: Vector2i, impar: Vector2i) -> void:
	for dx in range(ancho):
		for dy in range(alto):
			var x := x0 + dx
			var y := y0 + dy
			terreno.set_cell(Vector2i(x, y), 0, par if (x + y) % 2 == 0 else impar)


func _process(_d: float) -> bool:
	var raiz := Node2D.new()
	raiz.name = "NivelCiudad"
	raiz.set_script(load("res://escenas/niveles/NivelBase.gd"))
	raiz.set("nombre_nivel", "Ciudad")
	raiz.y_sort_enabled = true

	var terreno := TileMapLayer.new()
	terreno.name = "Terreno"
	terreno.tile_set = load(TILESET_JUEGO)
	terreno.z_index = -10
	terreno.y_sort_enabled = true
	terreno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(terreno)
	terreno.owner = raiz

	# 1. Piso de tierra en todo el mapa (calles de la ciudad).
	for ix in ANCHO:
		var x := ix - MITAD_X
		for iy in ALTO:
			var y := iy - MITAD_Y
			terreno.set_cell(Vector2i(x, y), 0, _tierra(x, y))

	# 2. Murallas: anillo sólido en el borde — a la vez límite del mapa
	# (mismo mecanismo que el anillo de maleza de Camino/muro de Cueva) y
	# tema visual de "ciudad amurallada". Puerta de entrada al oeste, del
	# lado de la Pradera.
	for ix in ANCHO:
		var x := ix - MITAD_X
		for iy in ALTO:
			var y := iy - MITAD_Y
			var en_muralla := absi(x) > MITAD_X - GROSOR_MURALLA or absi(y) > MITAD_Y - GROSOR_MURALLA
			var en_puerta := x <= -MITAD_X + GROSOR_MURALLA and absi(y) <= 2
			if en_muralla and not en_puerta:
				terreno.set_cell(Vector2i(x, y), 0, _muro(x, y))

	# 3. Plaza central de piedra.
	_pintar_rectangulo(terreno, -7, -5, 15, 11, PIEDRA, PIEDRA)

	# 4. Jardines (pasto) flanqueando el ayuntamiento.
	_pintar_rectangulo(terreno, -8, -9, 4, 3, HIERBA_A, HIERBA_B)
	_pintar_rectangulo(terreno, 4, -9, 4, 3, HIERBA_A, HIERBA_B)

	# 5. Edificios sin techo, puerta mirando hacia la plaza.
	_pintar_edificio(terreno, -24, -15, 10, 8, LadoPuerta.SUR, 5)   # noroeste
	_pintar_edificio(terreno, 14, -15, 10, 8, LadoPuerta.SUR, 5)    # noreste
	_pintar_edificio(terreno, -24, 7, 10, 8, LadoPuerta.NORTE, 5)   # suroeste
	_pintar_edificio(terreno, 14, 7, 10, 8, LadoPuerta.NORTE, 5)    # sureste
	_pintar_edificio(terreno, -8, -18, 17, 9, LadoPuerta.SUR, 8)    # ayuntamiento

	# 6. Decoración suelta (recortes del pack de items medievales) — margen
	# generoso a propósito, ver comentario de cabecera.
	var decoraciones := Node2D.new()
	decoraciones.name = "Decoraciones"
	decoraciones.y_sort_enabled = true
	raiz.add_child(decoraciones)
	decoraciones.owner = raiz

	var textura_items := load(TEXTURA_ITEMS) as Texture2D

	var puesto := Sprite2D.new()
	puesto.name = "PuestoMercado"
	puesto.texture = AtlasTexture.new()
	(puesto.texture as AtlasTexture).atlas = textura_items
	(puesto.texture as AtlasTexture).region = Rect2(0, 0, 96, 96)
	puesto.position = Vector2(_tile_a_px(-3), _tile_a_px(-3))
	puesto.centered = true
	decoraciones.add_child(puesto)
	puesto.owner = raiz

	var barril := Sprite2D.new()
	barril.name = "Barril"
	barril.texture = AtlasTexture.new()
	(barril.texture as AtlasTexture).atlas = textura_items
	(barril.texture as AtlasTexture).region = Rect2(0, 96, 90, 90)
	barril.position = Vector2(_tile_a_px(3), _tile_a_px(2))
	barril.centered = true
	decoraciones.add_child(barril)
	barril.owner = raiz

	# 7. Aparición + portal, del lado oeste (la puerta de la muralla).
	var aparicion := Marker2D.new()
	aparicion.name = "PuntoAparicion"
	aparicion.position = Vector2(_tile_a_px(-MITAD_X + GROSOR_MURALLA + 3), 0)
	raiz.add_child(aparicion)
	aparicion.owner = raiz

	var portal := (load(ESCENA_PORTAL) as PackedScene).instantiate()
	portal.name = "PortalAPradera"
	portal.position = Vector2(_tile_a_px(-MITAD_X + GROSOR_MURALLA + 1), 0)
	portal.set("ruta_nivel_destino", "res://escenas/niveles/NivelPradera.tscn")
	portal.set("etiqueta", "→ Pradera")
	raiz.add_child(portal)
	portal.owner = raiz

	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	enemigos.y_sort_enabled = true
	raiz.add_child(enemigos)
	enemigos.owner = raiz

	var escena := PackedScene.new()
	if escena.pack(raiz) != OK:
		push_error("No se pudo empaquetar el nivel.")
		quit(1)
		return true
	if ResourceSaver.save(escena, RUTA_SALIDA) != OK:
		push_error("No se pudo guardar %s" % RUTA_SALIDA)
		quit(1)
		return true

	print("Guardado %s" % RUTA_SALIDA)
	print("  %d x %d tiles (%d x %d px)" % [ANCHO, ALTO, ANCHO * 32, ALTO * 32])
	print("  celdas terreno: %d" % terreno.get_used_cells().size())
	print("  aparicion=%s portal=%s" % [aparicion.position, portal.position])
	quit(0)
	return true
