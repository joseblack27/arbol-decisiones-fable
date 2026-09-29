extends RefCounted
## Hornea la malla de navegación de un nivel (la usa NivelBase):
##   1. Transitable: lo pintado en la capa Navegacion, celda por celda, o el
##      polígono de la NavigationRegion2D "Navegacion" (el Camino).
##   2. Obstáculos: la colisión física de capa "mundo" que cae sobre esa
##      superficie. Tiles con colisión de las OTRAS capas del nivel (la Colision
##      invisible de la Pradera, el Terreno sólido de las cuevas) y los
##      StaticBody2D de "Decoraciones" (árboles, rocas, vetas, almacenes). Los
##      que abren y cierran (grupo "obstaculos_moviles", las compuertas) no
##      cuentan.
##   3. Margen: todo se achica MovimientoComponente.MARGEN_MALLA.
##   4. Islas: se descarta lo que no está conectado con la aparición ni con
##      ningún portal del nivel.
##
## Sin 2 y 4 la malla y la física no coincidían: la Navegacion de la Pradera
## estaba pintada en todo el rectángulo del mapa, también del otro lado de la
## cerca, así que los spawners hacían aparecer mobs afuera, adonde nadie llega,
## y las rutas cruzaban cercas y troncos (el cazador se arrastraba contra la
## cerca hacia presas del otro lado).

const _CAPA_MUNDO := 1
const _LADOS_CIRCULO := 12


## La malla lista, en coordenadas locales de "destino" (la región que la va a
## usar). Metadatos para pruebas y diagnóstico: "obstaculos" (contornos
## restados) y "poligonos_descartados" (islas).
static func hornear(nivel: Node2D, origen: Node, destino: Node2D) -> NavigationPolygon:
	var fuente := NavigationMeshSourceGeometryData2D.new()
	var celdas := {}
	if origen is TileMapLayer:
		_agregar_celdas(origen as TileMapLayer, destino, fuente, celdas)
	elif origen is NavigationRegion2D:
		_agregar_region(origen as NavigationRegion2D, destino, fuente)
	var obstaculos := _agregar_obstaculos(nivel, origen, destino, fuente, celdas)
	var malla := NavigationPolygon.new()
	malla.agent_radius = MovimientoComponente.MARGEN_MALLA
	NavigationServer2D.bake_from_source_geometry_data(malla, fuente)
	var descartados := _quitar_islas(malla, _entradas(nivel, destino))
	malla.set_meta("obstaculos", obstaculos)
	malla.set_meta("poligonos_descartados", descartados)
	return malla


# =============================================================================
# SUPERFICIE TRANSITABLE
# =============================================================================

## Cada celda aporta el polígono de navegación de su ficha (en general el
## cuadrado entero). "celdas" queda con las celdas caminables, para saber qué
## obstáculos pisan la malla.
static func _agregar_celdas(capa: TileMapLayer, destino: Node2D,
		fuente: NavigationMeshSourceGeometryData2D, celdas: Dictionary) -> void:
	for celda in capa.get_used_cells():
		var datos := capa.get_cell_tile_data(celda)
		if datos == null:
			continue
		var alternativa := capa.get_cell_alternative_tile(celda)
		var poligono := datos.get_navigation_polygon(0,
			alternativa & TileSetAtlasSource.TRANSFORM_FLIP_H != 0,
			alternativa & TileSetAtlasSource.TRANSFORM_FLIP_V != 0,
			alternativa & TileSetAtlasSource.TRANSFORM_TRANSPOSE != 0)
		if poligono == null:
			continue
		celdas[celda] = true
		var centro := capa.map_to_local(celda)
		for contorno in _contornos_de(poligono):
			var puntos := PackedVector2Array()
			for p in contorno:
				puntos.append(destino.to_local(capa.to_global(centro + p)))
			fuente.add_traversable_outline(puntos)


static func _agregar_region(region: NavigationRegion2D, destino: Node2D,
		fuente: NavigationMeshSourceGeometryData2D) -> void:
	if region.navigation_polygon == null:
		return
	for contorno in _contornos_de(region.navigation_polygon):
		var puntos := PackedVector2Array()
		for p in contorno:
			puntos.append(destino.to_local(region.to_global(p)))
		fuente.add_traversable_outline(puntos)


## Los polígonos pueden traer contornos o solo los polígonos ya horneados
## (vértices + índices); cualquiera de los dos sirve de contorno.
static func _contornos_de(poligono: NavigationPolygon) -> Array[PackedVector2Array]:
	var contornos: Array[PackedVector2Array] = []
	for i in poligono.get_outline_count():
		contornos.append(poligono.get_outline(i))
	if not contornos.is_empty():
		return contornos
	var vertices := poligono.get_vertices()
	for i in poligono.get_polygon_count():
		var contorno := PackedVector2Array()
		for indice in poligono.get_polygon(i):
			contorno.append(vertices[indice])
		contornos.append(contorno)
	return contornos


# =============================================================================
# OBSTÁCULOS
# =============================================================================

static func _agregar_obstaculos(nivel: Node2D, origen: Node, destino: Node2D,
		fuente: NavigationMeshSourceGeometryData2D, celdas: Dictionary) -> int:
	var total := 0
	for nodo in _descendientes(nivel):
		if nodo != origen and nodo is TileMapLayer:
			total += _obstaculos_de_capa(nodo as TileMapLayer, origen, destino, fuente, celdas)
	var decoraciones := nivel.get_node_or_null("Decoraciones")
	if decoraciones != null:
		for nodo in _descendientes(decoraciones):
			# Los que abren y cierran (compuertas) se anotan en este grupo: si
			# se hornearan cerrados, lo de atrás quedaría como isla.
			if nodo.is_in_group(&"obstaculos_moviles"):
				continue
			if nodo is StaticBody2D and ((nodo as StaticBody2D).collision_layer & _CAPA_MUNDO):
				total += _obstaculos_de_cuerpo(nodo as StaticBody2D, destino, fuente)
	return total


static func _obstaculos_de_capa(capa: TileMapLayer, origen: Node, destino: Node2D,
		fuente: NavigationMeshSourceGeometryData2D, celdas: Dictionary) -> int:
	if not capa.enabled or not capa.collision_enabled or capa.tile_set == null:
		return 0
	var fisicas: Array[int] = []
	for i in capa.tile_set.get_physics_layers_count():
		if capa.tile_set.get_physics_layer_collision_layer(i) & _CAPA_MUNDO:
			fisicas.append(i)
	if fisicas.is_empty():
		return 0
	var total := 0
	for celda in _celdas_candidatas(capa, origen, celdas):
		var datos := capa.get_cell_tile_data(celda)
		if datos == null:
			continue
		var alternativa := capa.get_cell_alternative_tile(celda)
		var centro := capa.map_to_local(celda)
		for i in fisicas:
			for j in datos.get_collision_polygons_count(i):
				var puntos := PackedVector2Array()
				for p in datos.get_collision_polygon_points(i, j):
					puntos.append(capa.to_global(centro + _transformar(p, alternativa)))
				if not _pisa_la_superficie(puntos, origen, celdas):
					continue
				fuente.add_obstruction_outline(_a_local(destino, puntos))
				total += 1
	return total


static func _obstaculos_de_cuerpo(cuerpo: StaticBody2D, destino: Node2D,
		fuente: NavigationMeshSourceGeometryData2D) -> int:
	var total := 0
	for hijo in cuerpo.get_children():
		var contorno := PackedVector2Array()
		if hijo is CollisionShape2D and not (hijo as CollisionShape2D).disabled:
			contorno = _contorno_de_forma((hijo as CollisionShape2D).shape)
		elif hijo is CollisionPolygon2D and not (hijo as CollisionPolygon2D).disabled:
			contorno = (hijo as CollisionPolygon2D).polygon
		if contorno.size() < 3:
			continue
		var puntos := PackedVector2Array()
		for p in contorno:
			puntos.append(destino.to_local((hijo as Node2D).global_transform * p))
		fuente.add_obstruction_outline(puntos)
		total += 1
	return total


## Solo cuentan los obstáculos que caen sobre alguna celda caminable: el
## Terreno sólido de las cuevas ya está fuera de la Navegacion, y restarlo
## igual triplicaba el costo del horneado en el Hormiguero sin cambiar nada.
## Por eso con una capa Navegacion se recorren solo las celdas de "capa" que
## quedan debajo de alguna caminable (en el Hormiguero, 5 mil en vez de los 12
## mil tiles de Terreno sólido), y _pisa_la_superficie afina por polígono.
static func _celdas_candidatas(capa: TileMapLayer, origen: Node, celdas: Dictionary) -> Array[Vector2i]:
	if not (origen is TileMapLayer):
		return capa.get_used_cells()
	var navegacion := origen as TileMapLayer
	var medio := Vector2(navegacion.tile_set.tile_size) / 2.0 - Vector2(0.5, 0.5)
	var vistas := {}
	for celda_nav: Vector2i in celdas:
		var centro := navegacion.map_to_local(celda_nav)
		var a := capa.local_to_map(capa.to_local(navegacion.to_global(centro - medio)))
		var b := capa.local_to_map(capa.to_local(navegacion.to_global(centro + medio)))
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				vistas[Vector2i(x, y)] = true
	var candidatas: Array[Vector2i] = []
	for celda: Vector2i in vistas:
		if capa.get_cell_source_id(celda) != -1:
			candidatas.append(celda)
	return candidatas


static func _pisa_la_superficie(puntos: PackedVector2Array, origen: Node, celdas: Dictionary) -> bool:
	if not (origen is TileMapLayer):
		return true
	var capa := origen as TileMapLayer
	var caja := Rect2(puntos[0], Vector2.ZERO)
	for p in puntos:
		caja = caja.expand(p)
	# Achicada medio px: un obstáculo que solo toca el borde de una celda
	# caminable vecina no la pisa.
	caja = caja.grow(-0.5)
	var desde := capa.local_to_map(capa.to_local(caja.position))
	var hasta := capa.local_to_map(capa.to_local(caja.end))
	for y in range(mini(desde.y, hasta.y), maxi(desde.y, hasta.y) + 1):
		for x in range(mini(desde.x, hasta.x), maxi(desde.x, hasta.x) + 1):
			if celdas.has(Vector2i(x, y)):
				return true
	return false


## Mismas transformaciones que aplica TileMapLayer a una celda espejada o
## traspuesta (bits de la alternativa).
static func _transformar(p: Vector2, alternativa: int) -> Vector2:
	if alternativa & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		p = Vector2(p.y, p.x)
	if alternativa & TileSetAtlasSource.TRANSFORM_FLIP_H:
		p.x = -p.x
	if alternativa & TileSetAtlasSource.TRANSFORM_FLIP_V:
		p.y = -p.y
	return p


static func _contorno_de_forma(forma: Shape2D) -> PackedVector2Array:
	var r := PackedVector2Array()
	if forma is RectangleShape2D:
		var m := (forma as RectangleShape2D).size / 2.0
		r = PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	elif forma is CircleShape2D:
		for i in _LADOS_CIRCULO:
			r.append(Vector2.RIGHT.rotated(TAU * i / _LADOS_CIRCULO) * (forma as CircleShape2D).radius)
	elif forma is CapsuleShape2D:
		var capsula := forma as CapsuleShape2D
		var medio := capsula.height / 2.0 - capsula.radius
		for i in _LADOS_CIRCULO / 2 + 1:
			r.append(Vector2(0, -medio) + Vector2.RIGHT.rotated(PI + PI * i / (_LADOS_CIRCULO / 2)) * capsula.radius)
		for i in _LADOS_CIRCULO / 2 + 1:
			r.append(Vector2(0, medio) + Vector2.RIGHT.rotated(PI * i / (_LADOS_CIRCULO / 2)) * capsula.radius)
	elif forma is ConvexPolygonShape2D:
		r = (forma as ConvexPolygonShape2D).points
	return r


static func _a_local(destino: Node2D, puntos: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array()
	for p in puntos:
		r.append(destino.to_local(p))
	return r


# =============================================================================
# ISLAS
# =============================================================================

## Por dónde entra alguien al nivel: la aparición, cada portal y su punto de
## llegada.
static func _entradas(nivel: Node2D, destino: Node2D) -> PackedVector2Array:
	var r := PackedVector2Array()
	var aparicion := nivel.get_node_or_null("PuntoAparicion") as Node2D
	if aparicion != null:
		r.append(destino.to_local(aparicion.global_position))
	for nodo in _descendientes(nivel):
		if nodo is PortalNivel:
			r.append(destino.to_local((nodo as Node2D).global_position))
			var llegada: Marker2D = (nodo as PortalNivel).punto_llegada
			if llegada != null:
				r.append(destino.to_local(llegada.global_position))
	return r


## Quita los polígonos a los que no se llega desde ninguna entrada (dos
## polígonos están conectados si comparten un lado, igual que para
## NavigationServer). Devuelve cuántos quitó.
static func _quitar_islas(malla: NavigationPolygon, entradas: PackedVector2Array) -> int:
	var cantidad := malla.get_polygon_count()
	if cantidad == 0 or entradas.is_empty():
		return 0
	var vertices := malla.get_vertices()
	var poligonos: Array[PackedInt32Array] = []
	for i in cantidad:
		poligonos.append(malla.get_polygon(i))

	var por_lado := {}
	for i in cantidad:
		var p := poligonos[i]
		for k in p.size():
			var clave := _clave_lado(vertices[p[k]], vertices[p[(k + 1) % p.size()]])
			if por_lado.has(clave):
				(por_lado[clave] as Array).append(i)
			else:
				por_lado[clave] = [i]
	var vecinos: Array[Array] = []
	vecinos.resize(cantidad)
	for i in cantidad:
		vecinos[i] = []
	for compartido: Array in por_lado.values():
		for a in compartido:
			for b in compartido:
				if a != b:
					vecinos[a].append(b)

	var alcanzados := {}
	var pendientes: Array[int] = []
	for entrada in entradas:
		var inicio := _poligono_mas_cercano(entrada, vertices, poligonos)
		if inicio >= 0 and not alcanzados.has(inicio):
			alcanzados[inicio] = true
			pendientes.append(inicio)
	while not pendientes.is_empty():
		var i: int = pendientes.pop_back()
		for j in vecinos[i]:
			if not alcanzados.has(j):
				alcanzados[j] = true
				pendientes.append(j)
	if alcanzados.size() == cantidad:
		return 0
	malla.clear_polygons()
	for i in cantidad:
		if alcanzados.has(i):
			malla.add_polygon(poligonos[i])
	return cantidad - alcanzados.size()


static func _clave_lado(a: Vector2, b: Vector2) -> Vector4:
	a = a.snapped(Vector2(0.01, 0.01))
	b = b.snapped(Vector2(0.01, 0.01))
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		var t := a
		a = b
		b = t
	return Vector4(a.x, a.y, b.x, b.y)


## El que contiene al punto o, si queda en el margen (un portal pegado a la
## pared), el de lado más cercano.
static func _poligono_mas_cercano(punto: Vector2, vertices: PackedVector2Array,
		poligonos: Array[PackedInt32Array]) -> int:
	var mejor := -1
	var mejor_distancia := INF
	for i in poligonos.size():
		var contorno := PackedVector2Array()
		for indice in poligonos[i]:
			contorno.append(vertices[indice])
		if Geometry2D.is_point_in_polygon(punto, contorno):
			return i
		for k in contorno.size():
			var cercano := Geometry2D.get_closest_point_to_segment(punto, contorno[k], contorno[(k + 1) % contorno.size()])
			var distancia := punto.distance_squared_to(cercano)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = i
	return mejor


static func _descendientes(desde: Node) -> Array[Node]:
	var r: Array[Node] = []
	for hijo in desde.get_children():
		r.append(hijo)
		r.append_array(_descendientes(hijo))
	return r
