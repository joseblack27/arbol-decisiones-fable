extends Control

@onready var tabs: TabContainer = $MarginContainer/VBoxContainer/TabContainer
@onready var btn_activas: Button = $MarginContainer/VBoxContainer/BarraTabs/BtnActivas
@onready var btn_pasivas: Button = $MarginContainer/VBoxContainer/BarraTabs/BtnPasivas
@onready var _etiqueta_puntos: Label = $MarginContainer/VBoxContainer/BarraTabs/MarginContainer/EtiquetaPuntos
@onready var _boton_reiniciar_puntos: Button = $MarginContainer/VBoxContainer/BarraTabs/BotonReiniciarPuntos

@onready var skill_list_panel := $MarginContainer/VBoxContainer/TabContainer/TabActivas/HBoxContainer/PanelListaHabilidades/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var detail_panel := $MarginContainer/VBoxContainer/TabContainer/TabActivas/HBoxContainer/PanelDetalle
@onready var group_button := ButtonGroup.new()

@onready var pasivas_list_panel := $MarginContainer/VBoxContainer/TabContainer/TabPasivas/HBoxContainer/PanelListaPasivas/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var pasivas_detail_panel := $MarginContainer/VBoxContainer/TabContainer/TabPasivas/HBoxContainer/PanelDetallePasiva
@onready var group_button_pasivas := ButtonGroup.new()

@export var skill_item_scene: PackedScene = preload("res://escenas/ui/panel_os/paneles/habilidades/ItemHabilidad.tscn")
@export var pasiva_item_scene: PackedScene = preload("res://escenas/ui/panel_os/paneles/habilidades/ItemPasiva.tscn")

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	btn_activas.pressed.connect(_on_btn_activas)
	btn_pasivas.pressed.connect(_on_btn_pasivas)
	_boton_reiniciar_puntos.pressed.connect(_on_reiniciar_puntos_pressed)
	# Cualquier gasto (pasiva o habilidad) cambia los puntos disponibles —
	# refrescar el indicador sin esperar a la próxima vez que se abra el panel.
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): _actualizar_puntos())
	_on_btn_activas()

## Pedido del usuario: "un botón al lado de los puntos de habilidad
## disponibles para reiniciarlos" — respec completo (ver MejorasComponente.
## reiniciar_puntos). El propio reinicio ya emite mejora_comprada, así que
## _actualizar_puntos() y el resto de los paneles/filas se refrescan solos.
func _on_reiniciar_puntos_pressed() -> void:
	var mejoras := Utils.mejoras_componente_local()
	if mejoras:
		mejoras.reiniciar_puntos()

func _on_visibility_changed() -> void:
	if visible:
		populate()

func _get_slot_habilidades() -> SlotHabilidades:
	return Utils.slot_habilidades_local()

## Pestaña "Activas" / "Pasivas" — mismo patrón que la barra superior de
## OsPrincipal (botones toggle en vez de los tabs nativos del
## TabContainer, que quedan ocultos con tabs_visible=false): pedido del
## usuario, "dividir las habilidades de pasivas y activas con un tab...
## siguiendo la forma en como se han hecho los demás que también usan tabs".
func _on_btn_activas() -> void:
	tabs.current_tab = 0
	btn_activas.button_pressed = true
	btn_activas.disabled = true
	btn_pasivas.button_pressed = false
	btn_pasivas.disabled = false

func _on_btn_pasivas() -> void:
	tabs.current_tab = 1
	btn_pasivas.button_pressed = true
	btn_pasivas.disabled = true
	btn_activas.button_pressed = false
	btn_activas.disabled = false

func populate():
	_actualizar_puntos()

	for child in skill_list_panel.get_children():
		child.queue_free()

	var slot_habs := _get_slot_habilidades()
	var skills: Array[DatosHabilidad] = slot_habs.catalogo if slot_habs else []

	for skill in skills:
		var item: ItemHabilidad = skill_item_scene.instantiate()
		item.button_group = group_button
		item.skill_data = skill
		item.skill_selected.connect(_on_skill_selected)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_list_panel.add_child(item)

	if skill_list_panel.get_child_count() > 0:
		_on_skill_selected(skill_list_panel.get_child(0).skill_data)

	_poblar_pasivas()

func _on_skill_selected(skill: DatosHabilidad):
	detail_panel.show_skill(skill)

## Indicador de puntos de mejora disponibles (ver MejorasComponente) —
## refrescado cada vez que se puebla el panel, y también tras cada gasto
## (ver _on_pasiva_selected/_on_skill_selected, que corren de nuevo al
## volver de mejorar algo).
func _actualizar_puntos() -> void:
	var mejoras := Utils.mejoras_componente_local()
	_etiqueta_puntos.text = "Puntos: %d" % (mejoras.puntos_disponibles() if mejoras else 0)
	# Sin nada gastado, no hay nada que reiniciar — deshabilitado en vez de
	# dejarlo tocable sin ningún efecto (mismo criterio que el resto de los
	# botones de este sistema, ver PanelDetalleHabilidad._uplevel_btn).
	_boton_reiniciar_puntos.disabled = mejoras == null or mejoras.puntos_gastados <= 0

## Pestaña de PASIVAS, de solo lectura — pedido del usuario: nada de
## equipar, solo ver cuáles ya se tienen. Antes de tener su propia pestaña
## vivían pegadas al final de la lista de habilidades activas con la
## descripción en un tooltip; en mobile eso no sirve (no hay hover), así
## que ahora tocar una fila muestra su descripción en pasivas_detail_panel
## (ver ItemPasiva.pasiva_selected / PanelDetallePasiva).
func _poblar_pasivas() -> void:
	for child in pasivas_list_panel.get_children():
		child.queue_free()

	var jugador := Utils.jugador_local()
	if jugador == null:
		pasivas_detail_panel.mostrar_sin_pasivas()
		return

	var filas: Array[Dictionary] = []

	var experiencia := jugador.get_node_or_null("ExperienciaComponente")
	if experiencia:
		for pasiva in experiencia.pasivas_stat:
			if pasiva and pasiva.nivel_requerido <= experiencia.nivel:
				filas.append({
					"nombre": pasiva.nombre, "descripcion": pasiva.descripcion,
					"icono": pasiva.icono, "pasiva_stat": pasiva,
				})

	var pasivas_comp := Utils.pasivas_componente_local()
	if pasivas_comp:
		for hijo in pasivas_comp.get_children():
			if hijo is PasivaBase:
				filas.append({
					"nombre": hijo.nombre_pasiva, "descripcion": hijo.descripcion,
					"icono": hijo.icono, "pasiva_stat": null,
				})

	if filas.is_empty():
		pasivas_detail_panel.mostrar_sin_pasivas()
		return

	for fila in filas:
		var item: ItemPasiva = pasiva_item_scene.instantiate()
		item.button_group = group_button_pasivas
		pasivas_list_panel.add_child(item)
		item.set_datos(fila["nombre"], fila["descripcion"], fila["icono"], fila["pasiva_stat"])
		item.pasiva_selected.connect(_on_pasiva_selected)

	var primera: Dictionary = filas[0]
	_on_pasiva_selected(primera["nombre"], primera["descripcion"], primera["icono"], primera["pasiva_stat"])

func _on_pasiva_selected(nombre: String, descripcion: String, icono: Texture2D, pasiva_stat: PasivaStatDesbloqueo) -> void:
	pasivas_detail_panel.show_pasiva(nombre, descripcion, icono, pasiva_stat)
