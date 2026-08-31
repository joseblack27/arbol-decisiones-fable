# =============================================================================
# PanelMapa (pestaña "Mapa" del OS) — mapa VISUAL real del nivel actual (no
# un radar esquemático): un SubViewport propio con su PROPIO World2D
# AISLADO (no comparte el del viewport principal — ver el comentario grande
# en PanelMapa.gd sobre por qué se abandonó esa versión anterior: dejó el
# mapa en blanco en el juego real). Al cambiar de nivel, _actualizar_fondo()
# DUPLICA los TileMapLayer de terreno/decoración del nivel real y los pone
# en ese World2D aislado — así es IMPOSIBLE que aparezca algo que no sea
# terreno/decoración (jugadores, mobs, barras de vida, VFX de habilidades)
# sin depender de ningún filtro de capas de renderizado. Usa
# NivelBase.limites_camara() (el mismo rectángulo que ya usa la cámara del
# jugador) tanto para encuadrar la cámara del mapa como para proyectar los
# marcadores (dibujados encima de la textura, en el World2D REAL).
#
# --headless no renderiza pixels de verdad (renderer nulo), así que esta
# prueba NO puede verificar el contenido visual en sí — solo la
# CONFIGURACIÓN que determina qué se vería (terreno duplicado con la data
# de celdas y posición correctas, tamaño del SubViewport, encuadre de la
# cámara). La confirmación visual final queda para el editor/juego real.
#
# Con la Pradera real (4 portales reales, con su etiqueta de destino):
#   1. Muestra el nombre del nivel actual.
#   2. Fondo tiene una copia de Terreno con la MISMA data de celdas
#      (get_used_rect) y en la posición global real (si no, CamaraMapa
#      apuntaría a donde debería estar el terreno pero no encontraría nada).
#   3. El SubViewport queda del mismo tamaño que AreaMapa, y CamaraMapa
#      encuadrada con la MISMA escala/centro que _limites — la fórmula
#      exacta que usaría Camera2D.zoom/global_position para que el nivel
#      entero entre centrado.
#   4. Crea un marcador por cada portal, con el texto de su etiqueta real.
#   5. El marcador del jugador cae en el punto proyectado correcto —
#      verificado con la fórmula de escala UNIFORME (no estirada) a mano,
#      la MISMA que usa la cámara — así el marcador queda alineado con lo
#      que se ve en la textura de abajo.
#   6. Un jugador en una ESQUINA de los límites del nivel se recorta al
#      borde del área dibujada, no se sale del panel.
#   godot --headless --path . --script res://pruebas/prueba_panel_mapa.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gn
var _contenedor
var _nivel
var _jugador
var _otro_jugador
var _mob
var _jefe
var _aliado
var _panel

var _muestra_nombre_nivel_ok := false
var _fondo_terreno_duplicado_ok := false
var _mundo_aislado_ok := false
var _camara_encuadrada_ok := false
var _crea_marcador_por_portal_ok := false
var _etiqueta_portal_correcta_ok := false
var _jugador_proyectado_correcto_ok := false
var _recorta_en_el_borde_ok := false
var _otro_jugador_verde_ok := false
var _mob_rojo_ok := false
var _jefe_amarillo_ok := false
var _aliado_verde_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		_probar_nombre_y_portales()
		_probar_camara_del_mapa()
		_probar_proyeccion_jugador()
		_probar_recorte_en_el_borde()
		_probar_marcadores_de_entidades()
		return _informar()
	return false


func _montar() -> void:
	_gn = root.get_node("/root/GestorNiveles")

	_contenedor = Node2D.new()
	root.add_child(_contenedor)
	_gn.registrar(_contenedor, null)

	_nivel = (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	var spawner = _nivel.get_node_or_null("Enemigos/SpawnerMobs")
	if spawner != null:
		spawner.set("cantidad_inicial", 0)
		spawner.set("activo", false)
	_contenedor.add_child(_nivel)
	current_scene = _nivel

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	_nivel.add_child(_jugador)
	var limites: Rect2 = _nivel.limites_camara()
	# Un poco adentro del centro, para no depender de si el punto exacto
	# cae sobre un tile transitable — acá lo único que importa es la
	# proyección de coordenadas, no la navegación.
	_jugador.global_position = limites.position + limites.size * 0.5

	_otro_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_otro_jugador.name = "2"
	_nivel.add_child(_otro_jugador)
	_otro_jugador.global_position = _jugador.global_position + Vector2(50, 0)

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	_nivel.add_child(_mob)
	_mob.global_position = _jugador.global_position + Vector2(100, 0)

	_jefe = (load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn") as PackedScene).instantiate()
	_nivel.add_child(_jefe)
	_jefe.global_position = _jugador.global_position + Vector2(150, 0)

	# AliadoInvocado.gd se saca del grupo "enemigos" y se mete en
	# "jugadores" en su propio _ready() (así Combate.mismo_equipo() lo
	# trata como un jugador más) — tiene que salir marcado VERDE como
	# cualquier aliado, nunca rojo/amarillo.
	_aliado = (load("res://escenas/enemigos/AliadoInvocado.tscn") as PackedScene).instantiate()
	_nivel.add_child(_aliado)
	_aliado.global_position = _jugador.global_position + Vector2(200, 0)

	_panel = (load("res://escenas/ui/panel_os/paneles/mapa/PanelMapa.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_panel.get_node("VBox/AreaMapa").size = Vector2(260, 260)  # tamaño estable, sin esperar layout real.


func _probar_nombre_y_portales() -> void:
	var etiqueta_nivel: Label = _panel.get_node("VBox/EtiquetaNivel")
	_muestra_nombre_nivel_ok = etiqueta_nivel.text == _nivel.nombre_nivel
	print("Muestra el nombre del nivel actual (esperado '%s'): %s" % [_nivel.nombre_nivel, etiqueta_nivel.text])

	var portales_reales := get_nodes_in_group(&"portales_nivel")
	_crea_marcador_por_portal_ok = _panel._marcadores_portal.size() == portales_reales.size() \
		and portales_reales.size() > 0
	print("Crea un marcador por cada portal real (esperado true, %d portales): %s" % [
		portales_reales.size(), _crea_marcador_por_portal_ok])

	# Al menos uno de los marcadores tiene que mostrar la etiqueta real de
	# ALGÚN portal (no un texto genérico fijo) — Pradera tiene "→ Cueva",
	# "→ Camino", "→ Ciudad", "→ Santuario del Guardián Quebrado".
	var alguna_etiqueta_real := false
	for marcador in _panel._marcadores_portal:
		var etiqueta: Label = marcador.get_child(1)
		if etiqueta.text.begins_with("→"):
			alguna_etiqueta_real = true
			break
	_etiqueta_portal_correcta_ok = alguna_etiqueta_real
	print("Los marcadores muestran la etiqueta real del portal (esperado true): %s" % _etiqueta_portal_correcta_ok)


## No se puede verificar el PIXEL renderizado en --headless (renderer
## nulo) — lo que sí se puede verificar es la CONFIGURACIÓN que determina
## qué se vería: el World2D del SubViewport es uno AISLADO (no el real —
## si lo fuera, cualquier sprite/mob/VFX del mundo real volvería a
## aparecer, exactamente el bug reportado por el usuario con la versión
## anterior), con una copia de Terreno adentro que tiene la MISMA data de
## celdas que el Terreno real y quedó en la posición global correcta.
func _probar_camara_del_mapa() -> void:
	var subviewport: SubViewport = _panel.get_node("VBox/AreaMapa/Viewport")
	var camara: Camera2D = _panel.get_node("VBox/AreaMapa/Viewport/CamaraMapa")
	var area: Control = _panel.get_node("VBox/AreaMapa")

	_mundo_aislado_ok = subviewport.world_2d != root.get_viewport().world_2d
	print("El World2D del mapa es uno aislado, no el real (esperado true): %s" % _mundo_aislado_ok)

	var terreno_real: TileMapLayer = _nivel.get_node("Terreno")
	var fondo: Node2D = _panel.get_node("VBox/AreaMapa/Viewport/Fondo")
	var terreno_copia: TileMapLayer = fondo.get_node_or_null("Terreno")
	var copia_existe_ok: bool = terreno_copia != null
	var misma_data_ok: bool = copia_existe_ok and terreno_copia.get_used_rect() == terreno_real.get_used_rect()
	var misma_posicion_ok: bool = copia_existe_ok \
		and terreno_copia.global_position.distance_to(terreno_real.global_position) < 0.01
	_fondo_terreno_duplicado_ok = copia_existe_ok and misma_data_ok and misma_posicion_ok
	print("Fondo tiene una copia de Terreno con la misma data y posición (esperado true — existe=%s, data=%s, posición=%s): %s" \
		% [copia_existe_ok, misma_data_ok, misma_posicion_ok, _fondo_terreno_duplicado_ok])

	var limites: Rect2 = _nivel.limites_camara()
	var escala_esperada: float = minf(area.size.x / limites.size.x, area.size.y / limites.size.y)
	var centro_esperado: Vector2 = limites.position + limites.size / 2.0
	var tamano_subviewport_ok: bool = Vector2(subviewport.size) == area.size
	var zoom_ok: bool = camara.zoom.distance_to(Vector2.ONE * escala_esperada) < 0.001
	var posicion_ok: bool = camara.global_position.distance_to(centro_esperado) < 1.0
	_camara_encuadrada_ok = tamano_subviewport_ok and zoom_ok and posicion_ok
	print("CamaraMapa encuadra el nivel entero centrado (esperado true — subviewport=%s, zoom=%s esperado %.4f, posición=%s esperado %s): %s" % [
		tamano_subviewport_ok, camara.zoom, escala_esperada, camara.global_position, centro_esperado, _camara_encuadrada_ok])


func _probar_proyeccion_jugador() -> void:
	var area: Control = _panel.get_node("VBox/AreaMapa")
	var limites: Rect2 = _nivel.limites_camara()
	var escala: float = minf(area.size.x / limites.size.x, area.size.y / limites.size.y)
	var offset: Vector2 = (area.size - limites.size * escala) / 2.0
	var esperado: Vector2 = (_jugador.global_position - limites.position) * escala + offset

	var marcador: ColorRect = _panel.get_node("VBox/AreaMapa/MarcadorJugador")
	var real: Vector2 = marcador.position + marcador.size / 2.0
	_jugador_proyectado_correcto_ok = marcador.visible and real.distance_to(esperado) < 1.0
	print("El jugador se proyecta en la posición esperada (esperado ~%s, obtenido %s): %s" % [
		esperado, real, _jugador_proyectado_correcto_ok])


## Un jugador bien afuera de los límites del nivel (ej. un bug de posición,
## o durante una transición) no debe mandar el marcador fuera del área
## dibujada — se recorta al borde en vez de desbordar el panel.
func _probar_recorte_en_el_borde() -> void:
	var area: Control = _panel.get_node("VBox/AreaMapa")
	var limites: Rect2 = _nivel.limites_camara()
	_jugador.global_position = limites.position - Vector2(5000, 5000)  # bien afuera, arriba-izquierda.
	_panel._actualizar_posiciones()

	var marcador: ColorRect = _panel.get_node("VBox/AreaMapa/MarcadorJugador")
	var real: Vector2 = marcador.position + marcador.size / 2.0
	var offset: Vector2 = (area.size - limites.size \
		* minf(area.size.x / limites.size.x, area.size.y / limites.size.y)) / 2.0
	_recorta_en_el_borde_ok = real.distance_to(offset) < 1.0
	print("Un jugador afuera de los límites se recorta a la esquina del área dibujada (esperado true): %s" \
		% _recorta_en_el_borde_ok)


## Otro jugador -> verde, mob común -> rojo, jefe -> amarillo, y el aliado
## invocado (que técnicamente vive en el grupo "enemigos") queda AFUERA de
## los dos últimos — pedido explícito del usuario (31 ago 2026).
func _probar_marcadores_de_entidades() -> void:
	_panel._actualizar_entidades()  # por si el throttle todavía no disparó en este fotograma.

	var color_otro = _color_de_marcador_de(_otro_jugador)
	_otro_jugador_verde_ok = color_otro == Color(0.3, 1.0, 0.3, 1.0)
	print("Otro jugador tiene marcador verde (esperado true, color=%s): %s" % [color_otro, _otro_jugador_verde_ok])

	var color_mob = _color_de_marcador_de(_mob)
	_mob_rojo_ok = color_mob == Color(1.0, 0.25, 0.25, 1.0)
	print("Mob común tiene marcador rojo (esperado true, color=%s): %s" % [color_mob, _mob_rojo_ok])

	var color_jefe = _color_de_marcador_de(_jefe)
	_jefe_amarillo_ok = color_jefe == Color(1.0, 0.9, 0.1, 1.0)
	print("Jefe tiene marcador amarillo (esperado true, color=%s): %s" % [color_jefe, _jefe_amarillo_ok])

	var color_aliado = _color_de_marcador_de(_aliado)
	_aliado_verde_ok = color_aliado == Color(0.3, 1.0, 0.3, 1.0)
	print("El aliado invocado sale marcado verde, como cualquier aliado (esperado true, color=%s): %s" \
		% [color_aliado, _aliado_verde_ok])


func _color_de_marcador_de(entidad: Node) -> Variant:
	for marcador in _panel._marcadores_entidad:
		if marcador.get_meta("entidad") == entidad:
			return marcador.color
	return null


func _informar() -> bool:
	var exito := _muestra_nombre_nivel_ok and _fondo_terreno_duplicado_ok and _mundo_aislado_ok and _camara_encuadrada_ok \
		and _crea_marcador_por_portal_ok and _etiqueta_portal_correcta_ok \
		and _jugador_proyectado_correcto_ok and _recorta_en_el_borde_ok \
		and _otro_jugador_verde_ok and _mob_rojo_ok and _jefe_amarillo_ok and _aliado_verde_ok
	print("PRUEBA PANEL MAPA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
