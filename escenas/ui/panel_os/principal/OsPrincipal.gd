extends Control
class_name OsPrincipal

signal main_button_close

@onready var color_rect: ColorRect = $ColorRect
@onready var tabs: TabContainer = $ColorRect/Margin/VBox/TabContainer
@onready var boton_cerrar: Button = $ColorRect/Margin/VBox/PanelTitulo/HBoxContainer/BotonCerrar
@onready var boton_guardar: Button = $ColorRect/Margin/VBox/PanelTitulo/HBoxContainer/BotonGuardar
@onready var boton_cargar: Button = $ColorRect/Margin/VBox/PanelTitulo/HBoxContainer/BotonCargar
@onready var btn_dashboard: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnTablero
@onready var btn_messages: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnMensajes
@onready var btn_missions: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnMisiones
@onready var btn_inventory: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnInventario
@onready var btn_skills: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnHabilidades
@onready var btn_encyclopedia: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnEnciclopedia
@onready var btn_world_log: Button = $ColorRect/Margin/VBox/Panel/BarraSuperior/BtnRegistroMundo
@onready var btn_shortcut_os: Button = $ColorRect2/BotonOs
@onready var btn_shortcut_message: Button = $ColorRect2/BotonMensaje
@onready var btn_shortcut_missions : Button= $ColorRect2/BotonMisiones
@onready var btn_shortcut_inventory: Button = $ColorRect2/BotonInventario
@onready var btn_shortcut_skills: Button = $ColorRect2/BotonHabilidades

@onready var inventory_panel: PanelInventario = $ColorRect/Margin/VBox/TabContainer/TabInventario/PanelInventario

func _ready():
	btn_shortcut_os.pressed.connect(_on_shortcut_os)
	btn_shortcut_message.pressed.connect(_on_shortcut_message)
	btn_shortcut_missions.pressed.connect(_on_shortcut_missions)
	btn_shortcut_inventory.pressed.connect(_on_shortcut_inventory)
	btn_shortcut_skills.pressed.connect(_on_shortcut_skills)
	
	
	btn_dashboard.pressed.connect(_on_btn_dashboard)
	btn_messages.pressed.connect(_on_btn_messages)
	btn_missions.pressed.connect(_on_btn_missions)
	btn_inventory.pressed.connect(_on_btn_inventory)
	btn_skills.pressed.connect(_on_btn_skills)
	btn_encyclopedia.pressed.connect(_on_btn_encyclopedia)
	btn_world_log.pressed.connect(_on_btn_world_log)
	boton_cerrar.pressed.connect(_on_close_button)
	boton_guardar.pressed.connect(GestorGuardado.guardar_partida)
	boton_cargar.pressed.connect(GestorGuardado.cargar_partida)

	color_rect.hide()
	_on_btn_dashboard()

func _on_shortcut_os():
	if color_rect.visible:
		color_rect.hide()
		GestorUI.cerrar_os()
	else:
		color_rect.show()
		GestorUI.abrir_os()
		_on_btn_dashboard()

func _on_shortcut_message():
	color_rect.show()
	_on_btn_messages()

func _on_shortcut_missions():
	color_rect.show()
	_on_btn_missions()

func _on_shortcut_inventory():
	color_rect.show()
	_on_btn_inventory()

func _on_shortcut_skills():
	color_rect.show()
	_on_btn_skills()

func _on_tab_button_pressed(index: int) -> void:
	tabs.current_tab = index

func _on_close_button():
	color_rect.hide()
	GestorUI.cerrar_os()
	main_button_close.emit()

func _on_btn_dashboard():
	_on_tab_button_pressed(0)
	set_active_topbar_button(btn_dashboard)

func _on_btn_messages():
	_on_tab_button_pressed(1)
	set_active_topbar_button(btn_messages)

func _on_btn_missions():
	_on_tab_button_pressed(2)
	set_active_topbar_button(btn_missions)

func _on_btn_inventory():
	_on_tab_button_pressed(3)
	set_active_topbar_button(btn_inventory)

func _on_btn_skills():
	_on_tab_button_pressed(4)
	set_active_topbar_button(btn_skills)

func _on_btn_encyclopedia():
	_on_tab_button_pressed(5)
	set_active_topbar_button(btn_encyclopedia)

func _on_btn_world_log():
	_on_tab_button_pressed(6)
	set_active_topbar_button(btn_world_log)

func set_active_topbar_button(button: Button):
	# Primero desactivo todos
	btn_dashboard.button_pressed = false
	btn_dashboard.disabled = false
	btn_messages.button_pressed = false
	btn_messages.disabled = false
	btn_missions.button_pressed = false
	btn_missions.disabled = false
	btn_inventory.button_pressed = false
	btn_inventory.disabled = false
	btn_skills.button_pressed = false
	btn_skills.disabled = false
	btn_encyclopedia.button_pressed = false
	btn_encyclopedia.disabled = false
	btn_world_log.button_pressed = false
	btn_world_log.disabled = false

	# Activo solo el correcto
	button.button_pressed = true
	button.disabled = true
