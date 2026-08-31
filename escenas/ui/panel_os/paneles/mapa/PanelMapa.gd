extends Control
## Pestaña "Mapa" del OS — mapa VISUAL de verdad del nivel ACTUAL (terreno,
## decoración, otros jugadores/mobs — lo que sea que haya ahí), no un radar
## esquemático de puntos. No es un mapa del mundo entero: los niveles son
## mapas discretos conectados por portales (ver GestorNiveles), no un
## mundo continuo, así que no hay "un" mapa único que mostrar — este panel
## siempre muestra el nivel donde estás parado ahora.
##
## Cómo se renderiza de verdad: un SubViewport propio (Viewport, hijo de
## AreaMapa) con su PROPIO World2D aislado — NO comparte el del viewport
## principal (versión anterior; se abandonó tras romper el mapa en la
## primera prueba real, ver abajo). Al cambiar de nivel, _actualizar_fondo()
## DUPLICA los TileMapLayer de terreno/decoración del nivel real (Terreno,
## Decoracion) y los reubica en el mismo World2D aislado, dentro de Fondo —
## eso es lo único que CamaraMapa puede llegar a ver. Los jugadores, mobs,
## barras de vida, VFX de habilidades, etc. viven en el World2D REAL, nunca
## en el aislado, así que es IMPOSIBLE que aparezcan en el mapa sin
## necesidad de ningún filtro de capas de renderizado.
##
## Versión anterior (compartir world_2d + visibility_layer/canvas_cull_mask
## para filtrar qué se ve): pedido explícito del usuario "no quiero que se
## vea nada que no sea el cuadrado que marca la posición del jugador y los
## mobs" (31 ago 2026) — se implementó así primero, pero en el juego real
## dejó el mapa completamente en blanco ("lo dañaste, ahora no veo el
## mapa"), sin poder confirmarlo antes en --headless (no renderiza pixels).
## Se revirtió esa versión y se reemplazó por esta (World2D aislado +
## duplicado), que no depende de ningún mecanismo de filtrado de Godot que
## no se pueda verificar sin abrir el juego real.
##
## Ese Viewport se muestra en un TextureRect (Textura). Los marcadores de
## jugador/portales/mobs se dibujan ENCIMA de esa textura, en vez de
## reemplazarla — a la escala de zoom del mapa, la ronda/etiqueta real de un
## portal queda demasiado chica para leerse, así que el marcador sigue
## haciendo falta para saber "hacia dónde queda cada uno" de un vistazo.
##
## Reusa NivelBase.limites_camara() (el mismo rectángulo que ya usa la
## cámara del jugador para no mostrar el vacío fuera del mapa) tanto para
## encuadrar CamaraMapa como para proyectar los marcadores — la MISMA
## fórmula de escala para las dos cosas, así el marcador de un portal cae
## exactamente sobre el portal real que se ve en la textura de abajo.
##
## Pedido explícito del usuario (30 ago 2026): panel dedicado dentro del
## menú OS, no una tira siempre visible en el HUD. Marcadores por color
## (31 ago 2026): jugador propio celeste, otros jugadores verde, mobs
## comunes rojo, jefes amarillo — ver _actualizar_entidades().

const _COLOR_BORDE := Color(0.45, 0.45, 0.45, 0.9)
const _COLOR_PORTAL := Color(1.0, 0.85, 0.2, 1.0)
## Pedido explícito del usuario (31 ago 2026): otros jugadores en verde,
## mobs comunes en rojo, jefes en amarillo — el jugador PROPIO sigue con su
## color celeste de siempre (_marcador_jugador), para distinguirse del
## resto de un vistazo.
const _COLOR_JUGADOR_OTRO := Color(0.3, 1.0, 0.3, 1.0)
const _COLOR_MOB := Color(1.0, 0.25, 0.25, 1.0)
const _COLOR_JEFE := Color(1.0, 0.9, 0.1, 1.0)
const _DIAMETRO_MARCADOR_JUGADOR := 8.0
const _DIAMETRO_MARCADOR_PORTAL := 6.0
const _DIAMETRO_MARCADOR_ENTIDAD := 6.0

@onready var _etiqueta_nivel: Label = $VBox/EtiquetaNivel
@onready var _area_mapa: Control = $VBox/AreaMapa
@onready var _subviewport: SubViewport = $VBox/AreaMapa/Viewport
@onready var _fondo: Node2D = $VBox/AreaMapa/Viewport/Fondo
@onready var _camara_mapa: Camera2D = $VBox/AreaMapa/Viewport/CamaraMapa
@onready var _textura: TextureRect = $VBox/AreaMapa/Textura
@onready var _marcador_jugador: ColorRect = $VBox/AreaMapa/MarcadorJugador

## Nombres de los TileMapLayer de terreno/decoración que sí queremos ver en
## el mapa — duplicados a Fondo en _actualizar_fondo(). No todos los niveles
## tienen los dos (Decoracion es solo de Pradera); get_node_or_null() cubre
## los que faltan. A propósito NO incluye "Decoraciones" (el contenedor de
## objetos con colisión — árboles, rocas): esos son entidades del mundo, no
## terreno de fondo, y duplicarlos arrastraría Area2D/CollisionShape2D sin
## necesidad para un mapa que solo se mira.
const _CAPAS_TERRENO_A_DUPLICAR := ["Terreno", "Decoracion"]

## Mientras la pestaña está abierta, la cámara secundaria vuelve a dibujar
## TODO el nivel una segunda vez, cada fotograma que se le permita — a
## 60fps eso es el doble de trabajo de render del nivel actual, solo para
## el minimapa. Un minimapa no necesita esa frecuencia: 5 refrescos por
## segundo (los marcadores de jugador/portales SÍ se siguen moviendo cada
## fotograma, ver _process — es solo la "foto" de fondo la que se
## refresca menos) recorta ese costo más del 90% sin que se note a simple
## vista. Pedido del usuario: "ese subviewport no consume demasiado
## computo?" — esto es puramente del lado del CLIENTE (cada jugador en su
## propia PC/celular); el servidor dedicado no tiene HUD ni corre esto.
const _INTERVALO_ACTUALIZACION_MAPA := 0.2

var _limites := Rect2()
var _marcadores_portal: Array[Control] = []
## Jugadores/mobs/jefes van y vienen (spawnean, mueren, se desconectan) —
## a diferencia de los portales (fijos por nivel), esta lista se rearma
## entera cada _INTERVALO_ACTUALIZACION_MAPA en vez de una sola vez.
var _marcadores_entidad: Array[Control] = []
var _tiempo_hasta_actualizar_mapa := 0.0


func _ready() -> void:
	# A propósito NO se comparte world_2d con el viewport principal — ver el
	# comentario grande arriba del todo. El SubViewport se queda con su
	# propio World2D aislado (el que trae por defecto), y _actualizar_fondo()
	# es lo único que mete contenido ahí adentro.
	_textura.texture = _subviewport.get_texture()
	_area_mapa.draw.connect(_dibujar_fondo)
	# El tamaño real de AreaMapa (para _escala_y_offset) recién queda firme
	# tras el primer layout del contenedor — reencuadrar cuando eso pase
	# evita un primer fotograma con la cámara/el borde mal calculados.
	_area_mapa.resized.connect(_al_redimensionar)
	GestorNiveles.nivel_cargado.connect(_al_cambiar_nivel)
	_actualizar_nivel()


func _process(delta: float) -> void:
	var visible_ahora := is_visible_in_tree()
	# No vale la pena seguir renderizando la cámara secundaria (ni recalcular
	# posiciones de marcadores) mientras la pestaña Mapa ni siquiera está a
	# la vista — el resto del panel OS puede estar abierto en otra pestaña.
	if not visible_ahora:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _limites.size == Vector2.ZERO:
		return
	_tiempo_hasta_actualizar_mapa -= delta
	if _tiempo_hasta_actualizar_mapa <= 0.0:
		_tiempo_hasta_actualizar_mapa = _INTERVALO_ACTUALIZACION_MAPA
		_subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_actualizar_entidades()
	_actualizar_posiciones()


func _al_cambiar_nivel(_nivel) -> void:
	_actualizar_nivel()


func _al_redimensionar() -> void:
	_actualizar_camara()
	_area_mapa.queue_redraw()


func _actualizar_nivel() -> void:
	for marcador in _marcadores_portal:
		marcador.queue_free()
	_marcadores_portal.clear()

	var nivel := GestorNiveles.nivel_actual()
	_etiqueta_nivel.text = nivel.nombre_nivel if nivel else "Mapa"
	_limites = (nivel.limites_camara() if nivel else Rect2())
	_actualizar_fondo(nivel)
	_actualizar_camara()
	_area_mapa.queue_redraw()

	for portal in get_tree().get_nodes_in_group(&"portales_nivel"):
		if portal is Node2D:
			_marcadores_portal.append(_crear_marcador_portal(portal))

	# Sin esto, un cambio de nivel con la pestaña ya abierta podía dejar
	# marcadores de jugadores/mobs del nivel VIEJO en pantalla hasta el
	# próximo refresco por temporizador (hasta _INTERVALO_ACTUALIZACION_MAPA
	# de retraso) — acá se rearma ya mismo, sin esperar.
	_actualizar_entidades()


## Rearma Fondo con una copia del terreno/decoración del nivel actual —
## único contenido que llega al World2D aislado de este SubViewport (ver
## comentario grande arriba del todo). duplicate() copia la data de celdas
## pintadas Y el TileSet (mismo recurso, sin clonarlo) — verificado a mano
## que get_used_rect() de la copia coincide con el original. Hace falta
## copiar el TRANSFORM GLOBAL a mano después de reparentar: la copia queda
## colgando de Fondo (en el origen del World2D aislado), no del nivel real,
## así que su position LOCAL heredada del duplicate() ya no corresponde a
## la posición real en el mundo — sin esto, CamaraMapa (encuadrada con las
## coordenadas REALES de limites_camara()) apuntaría a donde debería estar
## el terreno, pero el terreno duplicado seguiría en otro lado.
func _actualizar_fondo(nivel) -> void:
	for hijo in _fondo.get_children():
		_fondo.remove_child(hijo)
		hijo.queue_free()
	if nivel == null:
		return
	for nombre_capa in _CAPAS_TERRENO_A_DUPLICAR:
		var original: Node2D = nivel.get_node_or_null(nombre_capa)
		if original == null:
			continue
		var copia: Node2D = original.duplicate()
		_fondo.add_child(copia)
		copia.global_transform = original.global_transform


## Encuadra CamaraMapa para que el rectángulo entero de _limites entre en
## el SubViewport, centrado — MISMA escala/offset que _proyectar() usa
## para los marcadores, así el mapa real y los marcadores quedan alineados.
func _actualizar_camara() -> void:
	if _area_mapa.size.x <= 0.0 or _area_mapa.size.y <= 0.0:
		return
	_subviewport.size = Vector2i(_area_mapa.size)
	if _limites.size == Vector2.ZERO:
		return
	var datos := _escala_y_offset()
	var escala: float = datos[0]
	if escala <= 0.0:
		return
	_camara_mapa.zoom = Vector2.ONE * escala
	_camara_mapa.global_position = _limites.position + _limites.size / 2.0


## Ver PortalNivel.etiqueta — mismo texto que ya se ve flotando sobre el
## portal en el mundo, para que el jugador reconozca a cuál se refiere.
func _crear_marcador_portal(portal: Node2D) -> Control:
	var marcador := Control.new()
	marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.set_meta("portal", portal)

	var punto := ColorRect.new()
	punto.color = _COLOR_PORTAL
	punto.size = Vector2.ONE * _DIAMETRO_MARCADOR_PORTAL
	punto.position = -punto.size / 2.0
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.add_child(punto)

	var etiqueta := Label.new()
	var texto: String = portal.get("etiqueta") if "etiqueta" in portal else ""
	etiqueta.text = texto if texto != "" else "Portal"
	etiqueta.add_theme_font_size_override("font_size", 9)
	etiqueta.add_theme_color_override("font_color", _COLOR_PORTAL)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 3)
	etiqueta.position = Vector2(5, -7)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.add_child(etiqueta)

	_area_mapa.add_child(marcador)
	return marcador


## Rearma la lista entera de marcadores de otros jugadores/mobs/jefes.
## AliadoInvocado hereda de Enemigo pero su propio _ready() se saca del
## grupo "enemigos" y se mete en "jugadores" (ver ese script — así
## Combate.mismo_equipo() lo trata como un jugador más: no le pega el
## dueño, sí le pegan los mobs de verdad) — así que ya cae solo en el
## bucle de jugadores de acá abajo y sale marcado VERDE como cualquier
## aliado, nunca en el bucle de "enemigos" (nada que excluir a mano).
func _actualizar_entidades() -> void:
	for marcador in _marcadores_entidad:
		marcador.queue_free()
	_marcadores_entidad.clear()

	var jugador_local := Utils.jugador_local()
	for jugador in get_tree().get_nodes_in_group(&"jugadores"):
		if jugador == jugador_local or not (jugador is Node2D):
			continue
		_marcadores_entidad.append(_crear_marcador_entidad(jugador, _COLOR_JUGADOR_OTRO))

	for enemigo in get_tree().get_nodes_in_group(&"enemigos"):
		if not (enemigo is Node2D):
			continue
		var es_jefe: bool = enemigo is EnemigoJefeEsqueleto or enemigo is EnemigoArañaReina \
			or enemigo is EnemigoGuardianQuebrado
		_marcadores_entidad.append(_crear_marcador_entidad(enemigo, _COLOR_JEFE if es_jefe else _COLOR_MOB))


func _crear_marcador_entidad(entidad: Node2D, color: Color) -> Control:
	var punto := ColorRect.new()
	punto.color = color
	punto.size = Vector2.ONE * _DIAMETRO_MARCADOR_ENTIDAD
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punto.set_meta("entidad", entidad)
	_area_mapa.add_child(punto)
	return punto


func _actualizar_posiciones() -> void:
	var jugador := Utils.jugador_local()
	if jugador is Node2D:
		_marcador_jugador.position = _proyectar((jugador as Node2D).global_position) \
			- _marcador_jugador.size / 2.0
		_marcador_jugador.visible = true
	else:
		_marcador_jugador.visible = false

	for marcador in _marcadores_portal:
		var portal: Node2D = marcador.get_meta("portal")
		if is_instance_valid(portal):
			marcador.position = _proyectar(portal.global_position)

	for marcador in _marcadores_entidad:
		var entidad: Node2D = marcador.get_meta("entidad")
		if is_instance_valid(entidad):
			marcador.position = _proyectar(entidad.global_position) - marcador.size / 2.0
			marcador.visible = true
		else:
			marcador.visible = false


## Escala UNIFORME (misma en X e Y, la menor de las dos que entra en
## _area_mapa) + offset para centrar — sin esto, un nivel que no sea
## cuadrado (como el Camino, mucho más ancho que alto) se veía estirado en
## vez de proporcionado de verdad. La MISMA escala encuadra CamaraMapa
## (ver _actualizar_camara) y proyecta los marcadores (ver _proyectar).
func _escala_y_offset() -> Array:
	if _limites.size.x <= 0.0 or _limites.size.y <= 0.0:
		return [0.0, Vector2.ZERO]
	var escala := minf(_area_mapa.size.x / _limites.size.x, _area_mapa.size.y / _limites.size.y)
	var offset := (_area_mapa.size - _limites.size * escala) / 2.0
	return [escala, offset]


## Posición del mundo -> coordenada dentro de _area_mapa, con el mismo
## rectángulo que limites_camara() reporta para el nivel actual.
func _proyectar(mundo: Vector2) -> Vector2:
	var datos := _escala_y_offset()
	var escala: float = datos[0]
	if escala <= 0.0:
		return Vector2.ZERO
	var relativo: Vector2 = mundo - _limites.position
	relativo.x = clampf(relativo.x, 0.0, _limites.size.x)
	relativo.y = clampf(relativo.y, 0.0, _limites.size.y)
	return relativo * escala + (datos[1] as Vector2)


## La textura del mapa real (Textura, hijo posterior a este Control) tapa
## todo el área — lo único que vale la pena dibujar acá encima es el marco
## alrededor del rectángulo real de _limites, para distinguir el nivel de
## verdad de cualquier margen "de sobra" cuando el nivel no es cuadrado
## (ej. el Camino, mucho más ancho que alto) y algún costado del
## SubViewport queda fuera de _limites.
func _dibujar_fondo() -> void:
	var datos := _escala_y_offset()
	var escala: float = datos[0]
	if escala <= 0.0:
		return
	var rect := Rect2((datos[1] as Vector2), _limites.size * escala)
	_area_mapa.draw_rect(rect, _COLOR_BORDE, false, 2.0)
