extends Control
class_name PanelMisiones
## Antes leía de "lista_misiones" (@export nunca asignado en ningún lado —
## el panel de detalle jamás llegaba a mostrarse en juego real). Ahora lee
## el catálogo real (GestorMisiones.catalogo, las DEFINICIONES) cruzado con
## el progreso real del jugador (MisionesComponente.progreso, por partida)
## — mismo patrón "Gestor autoload + BusEventos + refrescar()" que
## PanelInventario.

@onready var group_button := ButtonGroup.new()
@onready var mission_scene: PackedScene = preload("res://escenas/ui/panel_os/comunes/opcion_lista_boton/OpcionListaBoton.tscn")
@onready var reward_item_view_scene: PackedScene = preload("res://escenas/ui/panel_os/paneles/misiones/VistaItemRecompensa.tscn")

@onready var btn_missions_active:    Button = $MarginContainer/HBox/PanelListaMisiones/MarginContainer/VBoxListaMisiones/TabsFiltro/BotonMisionesActivas
@onready var btn_missions_completed: Button = $MarginContainer/HBox/PanelListaMisiones/MarginContainer/VBoxListaMisiones/TabsFiltro/BotonMisionesCompletadas
@onready var btn_missions_pending:   Button = $MarginContainer/HBox/PanelListaMisiones/MarginContainer/VBoxListaMisiones/TabsFiltro/BotonMisionesPendientes
@onready var mission_detail_panel = $MarginContainer/HBox/PanelDetalleMision/MarginContainer

@onready var missions_list: VBoxContainer = $MarginContainer/HBox/PanelListaMisiones/MarginContainer/VBoxListaMisiones/HBoxContainer/ScrollContainer/MarginContainer/ListaMisiones

@onready var title_label:        Label       = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/TituloMision
@onready var type_value:         Label       = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/GridContainer/ValorTipo
@onready var level_value:        Label       = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/GridContainer/ValorNivel
@onready var region_value:       Label       = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/GridContainer/ValorRegion
@onready var description_label:  RichTextLabel = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/TextoDescripcion
@onready var objectives_vbox:    VBoxContainer = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/ListaObjetivos
@onready var rewards_vbox:       VBoxContainer = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ScrollContainer/VBoxContainer/ListaRecompensas
@onready var track_button:       Button = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ButtonBar/TrackButton
@onready var abandon_button:     Button = $MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ButtonBar/AbandonButton

## Con nodos propios (no ConfirmationDialog) para que respete el tema del
## juego en vez del estilo nativo de ventana del sistema — pedido explícito
## del usuario, quedaba desentonado con el resto de la interfaz.
@onready var confirmar_abandonar: Control = $ConfirmarAbandonar
@onready var confirmar_abandonar_mensaje: Label = $ConfirmarAbandonar/PanelCentro/Margin/VBox/Mensaje
@onready var confirmar_abandonar_boton_si: Button = $ConfirmarAbandonar/PanelCentro/Margin/VBox/Botones/BotonConfirmar
@onready var confirmar_abandonar_boton_no: Button = $ConfirmarAbandonar/PanelCentro/Margin/VBox/Botones/BotonCancelar

var _mision_actual: DatosMision = null
var _filtro_actual: Enums.Mision.Estado = Enums.Mision.Estado.EN_PROGRESO


func _ready():
	btn_missions_active.pressed.connect(set_missions_button.bind(btn_missions_active, Enums.Mision.Estado.EN_PROGRESO))
	btn_missions_completed.pressed.connect(set_missions_button.bind(btn_missions_completed, Enums.Mision.Estado.COMPLETADA))
	btn_missions_pending.pressed.connect(set_missions_button.bind(btn_missions_pending, Enums.Mision.Estado.DISPONIBLE))
	abandon_button.pressed.connect(_on_abandon_pressed)
	confirmar_abandonar_boton_si.pressed.connect(_on_abandonar_confirmado)
	confirmar_abandonar_boton_no.pressed.connect(_on_abandonar_cancelado)

	BusEventos.mision_aceptada.connect(_on_mision_cambiada)
	BusEventos.mision_completada.connect(_on_mision_cambiada)
	BusEventos.mision_abandonada.connect(_on_mision_cambiada)
	BusEventos.mision_progreso_actualizado.connect(_on_progreso_actualizado)
	GestorGuardado.partida_cargada.connect(refrescar)

	clear()
	refrescar()
	set_missions_button(btn_missions_active, Enums.Mision.Estado.EN_PROGRESO)


func refrescar() -> void:
	# remove_child() + queue_free(), no .free() solo: si el hijo que se
	# libera es el mismo botón que disparó (por su señal pressed) el camino
	# que terminó llamando a refrescar(), Godot lo tiene "locked" mientras
	# esa señal sigue en emisión y rechaza liberarlo (mismo bug encontrado
	# en PanelDialogo). remove_child() saca al hijo del árbol de inmediato
	# (evita que se acumule si refrescar() se llama más de una vez en el
	# mismo fotograma) sin necesitar destruirlo ahí mismo.
	for child in missions_list.get_children():
		missions_list.remove_child(child)
		child.queue_free()
	for data: DatosMision in GestorMisiones.catalogo:
		if data == null:
			continue
		var mission: OpcionListaBoton = mission_scene.instantiate()
		mission.button_group = group_button
		mission.resource = data
		mission.button_clicked.connect(_on_button_clicked)
		missions_list.add_child(mission)
		mission.title_label.text    = data.titulo
		mission.subtitle_label.text = data.region
		mission.date_label.text     = ""
	filter_items(_filtro_actual)
	if _mision_actual:
		show_mission(_mision_actual)


func _on_mision_cambiada(_jugador: Node, _id_mision: String) -> void:
	refrescar()


func _on_progreso_actualizado(_jugador: Node, id_mision: String, _id_objetivo: String, _actual: int, _requerido: int) -> void:
	if _mision_actual and _mision_actual.id == id_mision:
		show_mission(_mision_actual)


func _on_button_clicked(mission_data: DatosMision):
	if mission_data:
		show_mission(mission_data)


## Solo pregunta — el abandono de verdad ocurre en _on_abandonar_confirmado,
## si el jugador confirma. Pedido explícito: no abandonar de un solo toque.
func _on_abandon_pressed() -> void:
	if _mision_actual == null:
		return
	confirmar_abandonar_mensaje.text = "¿Seguro que querés abandonar \"%s\"? Vas a perder el progreso de sus objetivos." % _mision_actual.titulo
	confirmar_abandonar.visible = true


func _on_abandonar_cancelado() -> void:
	confirmar_abandonar.visible = false


func _on_abandonar_confirmado() -> void:
	confirmar_abandonar.visible = false
	if _mision_actual == null:
		return
	var misiones := Utils.misiones_componente_local()
	if misiones:
		# Borra el progreso — MisionesComponente.estado_de() ya no encuentra
		# entrada y vuelve a BLOQUEADA; _estado_efectivo() de acá abajo la
		# reclasifica a DISPONIBLE, que es la misma pestaña "Pendientes":
		# abandonar una misión EN_PROGRESO la devuelve a pendiente, no la
		# borra de la lista.
		misiones.abandonar_mision(_mision_actual.id)
	clear()
	_mision_actual = null
	refrescar()


func set_missions_button(button: Button, estado: Enums.Mision.Estado):
	btn_missions_active.button_pressed    = false
	btn_missions_active.disabled          = false
	btn_missions_completed.button_pressed = false
	btn_missions_completed.disabled       = false
	btn_missions_pending.button_pressed   = false
	btn_missions_pending.disabled         = false
	button.button_pressed = true
	button.disabled = true
	_filtro_actual = estado
	filter_items(estado)


func show_mission(mission: DatosMision) -> void:
	if mission == null:
		clear()
		return
	_mision_actual = mission
	title_label.text       = mission.titulo
	type_value.text        = Enums.Mision.get_type_text(mission.tipo)
	level_value.text       = str(mission.nivel_requerido)
	region_value.text      = mission.region
	description_label.text = mission.descripcion
	_update_objectives(mission)
	_update_rewards(mission.recompensas)
	_actualizar_botones(mission)
	mission_detail_panel.visible = true


## Abandonar solo tiene sentido con la misión ya aceptada — pendiente o
## completada no tienen nada que abandonar. Rastrear no tiene sentido con
## la misión ya completada. Pedido explícito del usuario: estos botones se
## OCULTAN (no solo se deshabilitan) cuando no aplican.
func _actualizar_botones(mission: DatosMision) -> void:
	var estado := _estado_efectivo(mission.id)
	abandon_button.visible = estado == Enums.Mision.Estado.EN_PROGRESO
	track_button.visible   = estado != Enums.Mision.Estado.COMPLETADA


## Sin entrada en progreso = nunca aceptada = cuenta como DISPONIBLE para
## la UI (no hay ninguna misión BLOQUEADA todavía en esta base — eso
## implicaría un sistema de requisitos previos, fuera de alcance por ahora).
func _estado_efectivo(id_mision: String) -> Enums.Mision.Estado:
	var misiones := Utils.misiones_componente_local()
	var estado: Enums.Mision.Estado = misiones.estado_de(id_mision) if misiones else Enums.Mision.Estado.DISPONIBLE
	if estado == Enums.Mision.Estado.BLOQUEADA:
		estado = Enums.Mision.Estado.DISPONIBLE
	return estado


func clear():
	title_label.text  = "Selecciona una misión"
	type_value.text   = "-"
	level_value.text  = "-"
	region_value.text = "-"
	description_label.text = ""
	_clear_container(objectives_vbox)
	_clear_container(rewards_vbox)
	abandon_button.visible = false
	track_button.visible   = false
	mission_detail_panel.visible = false


func _update_objectives(mission: DatosMision):
	_clear_container(objectives_vbox)
	var misiones := Utils.misiones_componente_local()
	for obj in mission.objetivos:
		if obj == null:
			continue
		# Misión secuencial (ver DatosMision.secuencial): no listar todavía
		# una fase futura — se revela sola cuando la anterior se completa
		# (mision_progreso_actualizado ya hace que este panel se refresque).
		if misiones and not misiones.objetivo_habilitado(mission, obj.id):
			continue
		var actual := misiones.progreso_objetivo(mission.id, obj.id) if misiones else 0
		var completo := actual >= obj.cantidad_meta
		var texto := obj.descripcion
		if obj.cantidad_meta > 1:
			texto += " (%d/%d)" % [actual, obj.cantidad_meta]
		var label := Label.new()
		label.text = ("✔ " if completo else " • ") + texto
		label.modulate = Color(0.6, 1, 0.6) if completo else Color.WHITE
		objectives_vbox.add_child(label)


func _update_rewards(rewards: DatosRecompensaMision):
	_clear_container(rewards_vbox)
	if rewards.xp > 0:
		_add_reward_label("XP", rewards.xp)
	if rewards.creditos > 0:
		_add_reward_label("Créditos", rewards.creditos)
	if rewards.items.size() > 0:
		var items_flow := FlowContainer.new()
		items_flow.add_theme_constant_override("h_separation", 8)
		items_flow.add_theme_constant_override("v_separation", 8)
		rewards_vbox.add_child(items_flow)
		for reward in rewards.items:
			if reward.item == null:
				continue
			var view := reward_item_view_scene.instantiate()
			items_flow.add_child(view)
			view.setup(reward.item, reward.cantidad)


func _add_reward_label(_name: String, _value: int):
	var label := Label.new()
	label.text = "%s: %d" % [_name, _value]
	rewards_vbox.add_child(label)


func _clear_container(container: Control):
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func filter_items(filtro_estado: Enums.Mision.Estado) -> void:
	for mission in missions_list.get_children():
		var datos: DatosMision = mission.resource
		mission.visible = _estado_efectivo(datos.id) == filtro_estado
