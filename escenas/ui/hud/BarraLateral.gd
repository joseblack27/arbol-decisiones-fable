extends Control
class_name BarraLateral
## Tira de HUD con pestañas laterales — combina Grupo (vida de compañeros,
## antes en BarraGrupo.gd, fusionado acá) y Misiones (progreso de las
## misiones activas) en un único panel colapsable, en la MISMA posición que
## ocupaba BarraGrupo (ver Mundo.tscn). Pedido explícito del usuario
## (1 sep 2026): "si esta oculto y presionas cualquiera de los dos botones
## del tab, se muestra el tab con la opcion seleccionada; si se presiona un
## tab distinto con el tab abierto, debe cambiar al tab seleccionado; pero
## si se presiona el boton del mismo tab que esta abierto, debe ocultarse
## el panel" — ver _alternar_tab(), que unifica los 3 casos en una regla.
##
## A diferencia de BarraGrupo (que se ocultaba ENTERO sin grupo), este
## widget queda SIEMPRE visible — las pestañas tienen sentido incluso sin
## grupo (para mirar misiones) o sin misiones activas (para mirar el
## grupo), así que cada pestaña muestra su propio estado vacío en vez de
## esconder todo el widget.

enum Tab { GRUPO, MISIONES }

@onready var _boton_grupo: Button = $TirasTabs/BotonGrupo
@onready var _boton_misiones: Button = $TirasTabs/BotonMisiones
@onready var _panel: PanelContainer = $Panel
@onready var _scroll_grupo: Control = $Panel/ScrollGrupo
@onready var _scroll_misiones: Control = $Panel/ScrollMisiones
@onready var _lista_grupo: VBoxContainer = $Panel/ScrollGrupo/ListaGrupo
@onready var _lista_misiones: VBoxContainer = $Panel/ScrollMisiones/ListaMisiones

var _abierto := false
var _tab_activo: Tab = Tab.GRUPO


func _ready() -> void:
	_boton_grupo.pressed.connect(_alternar_tab.bind(Tab.GRUPO))
	_boton_misiones.pressed.connect(_alternar_tab.bind(Tab.MISIONES))
	GestorGrupos.grupo_actualizado.connect(_actualizar_grupo)
	BusEventos.mision_aceptada.connect(_al_cambiar_mision)
	BusEventos.mision_completada.connect(_al_cambiar_mision)
	BusEventos.mision_abandonada.connect(_al_cambiar_mision)
	BusEventos.mision_progreso_actualizado.connect(_al_progreso_mision)
	# Bug real reportado: "la barra lateral no muestra las misiones que
	# tengo" — misiones ya EN_PROGRESO de una partida guardada no pasan por
	# aceptar_mision() al restaurarse (GestorGuardado las carga directo en
	# MisionesComponente.progreso), así que ninguna de las señales de
	# arriba se dispara para avisar. PanelMisiones.gd ya se conecta a esto
	# mismo (GestorGuardado.partida_cargada) — a este widget se le había
	# olvidado.
	GestorGuardado.partida_cargada.connect(_actualizar_misiones)
	_actualizar_grupo()
	_actualizar_misiones()
	_actualizar_visual()


## Pedido explícito del usuario (ver comentario de arriba): cerrado -> abre
## en el tab que tocaste; abierto en OTRO tab -> cambia a ese tab; abierto
## en el MISMO tab que tocaste -> cierra. Una sola regla para los 3 casos,
## sin duplicar la lógica entre los dos botones.
func _alternar_tab(tab: Tab) -> void:
	if _abierto and _tab_activo == tab:
		_abierto = false
	else:
		_abierto = true
		_tab_activo = tab
	_actualizar_visual()


func _actualizar_visual() -> void:
	_panel.visible = _abierto
	_scroll_grupo.visible = _tab_activo == Tab.GRUPO
	_scroll_misiones.visible = _tab_activo == Tab.MISIONES
	_boton_grupo.button_pressed = _abierto and _tab_activo == Tab.GRUPO
	_boton_misiones.button_pressed = _abierto and _tab_activo == Tab.MISIONES


func _al_cambiar_mision(_jugador, _id_mision: String) -> void:
	_actualizar_misiones()


func _al_progreso_mision(_jugador, _id_mision: String, _id_objetivo: String, _actual: int, _requerido: int) -> void:
	_actualizar_misiones()


## Misma fila nombre+barra de vida que tenía BarraGrupo.gd — portada tal
## cual. A diferencia de esa versión, no oculta la lista entera sin grupo:
## muestra un estado vacío, porque ahora el widget entero queda siempre
## visible (ver comentario de arriba).
func _actualizar_grupo() -> void:
	# remove_child() + queue_free() (nunca queue_free() solo): si dos
	# actualizaciones caen en el mismo fotograma (ej. en una prueba, o dos
	# señales seguidas en la vida real), el hijo "borrado" sigue en
	# get_children() hasta el próximo fotograma y se contaba de más.
	for hijo in _lista_grupo.get_children():
		_lista_grupo.remove_child(hijo)
		hijo.queue_free()
	var grupo: Dictionary = GestorGrupos.mi_grupo
	var miembros: Array = grupo.get("miembros", []) as Array
	if miembros.is_empty():
		_lista_grupo.add_child(_etiqueta_vacio("Sin grupo"))
		return
	for miembro: Dictionary in miembros:
		_lista_grupo.add_child(_fila_miembro(miembro))


func _fila_miembro(miembro: Dictionary) -> Control:
	var fila := HBoxContainer.new()

	var nombre := Label.new()
	nombre.text = str(miembro.get("nombre", ""))
	nombre.custom_minimum_size = Vector2(64, 0)
	nombre.add_theme_font_size_override("font_size", 10)
	fila.add_child(nombre)

	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = maxf(1.0, float(miembro.get("vida_maxima", 1.0)))
	barra.value = float(miembro.get("vida", 0.0))
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(70, 10)
	fila.add_child(barra)

	return fila


## Misiones EN_PROGRESO del jugador local, con el progreso de cada
## objetivo HABILITADO (ver MisionesComponente.objetivo_habilitado, oculta
## fases futuras de una misión secuencial) — mismo formato "✔/•
## descripción (actual/meta)" que ya usa PanelMisiones._update_objectives,
## a escala de HUD.
func _actualizar_misiones() -> void:
	for hijo in _lista_misiones.get_children():
		_lista_misiones.remove_child(hijo)
		hijo.queue_free()
	var misiones := Utils.misiones_componente_local()
	var alguna := false
	if misiones:
		for id_mision in misiones.progreso.keys():
			var entrada: Dictionary = misiones.progreso[id_mision]
			if entrada.get("estado") != Enums.Mision.Estado.EN_PROGRESO:
				continue
			var datos: DatosMision = GestorMisiones.obtener_por_id(id_mision)
			if datos == null:
				continue
			alguna = true
			_lista_misiones.add_child(_fila_mision(datos, misiones))
	if not alguna:
		_lista_misiones.add_child(_etiqueta_vacio("Sin misiones activas"))


func _fila_mision(datos: DatosMision, misiones: MisionesComponente) -> Control:
	var contenedor := VBoxContainer.new()
	contenedor.add_theme_constant_override("separation", 0)

	var titulo := Label.new()
	titulo.text = datos.titulo
	titulo.add_theme_font_size_override("font_size", 10)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenedor.add_child(titulo)

	for objetivo in datos.objetivos:
		if objetivo == null:
			continue
		if not misiones.objetivo_habilitado(datos, objetivo.id):
			continue
		var actual := misiones.progreso_objetivo(datos.id, objetivo.id)
		var completo := actual >= objetivo.cantidad_meta
		var texto := objetivo.descripcion
		if objetivo.cantidad_meta > 1:
			texto += " (%d/%d)" % [actual, objetivo.cantidad_meta]
		# Pedido explícito del usuario: "los objetivos de la misión se
		# muestren pegados a la izquierda" — sin espacios sueltos al
		# principio del texto (mismo criterio que ya se corrigió en las
		# filas de conjunto del inventario, ver Utils._agregar_fila_
		# indentada).
		var linea := Label.new()
		linea.text = ("✔ " if completo else "• ") + texto
		linea.add_theme_font_size_override("font_size", 9)
		linea.modulate = Color(0.6, 1.0, 0.6) if completo else Color(0.85, 0.85, 0.85)
		linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contenedor.add_child(linea)

	return contenedor


func _etiqueta_vacio(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.modulate = Color(0.7, 0.7, 0.7)
	return etiqueta
