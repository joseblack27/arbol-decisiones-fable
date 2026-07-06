extends Control
class_name MainOs

signal main_button_close

@onready var color_rect: ColorRect = $ColorRect
@onready var tabs: TabContainer = $ColorRect/Margin/VBox/TabContainer
@onready var boton_cerrar: Button = $ColorRect/Margin/VBox/PanelTitulo/HBoxContainer/BotonCerrar
@onready var btn_dashboard: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnDashboard
@onready var btn_messages: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnMessages
@onready var btn_missions: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnMissions
@onready var btn_inventory: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnInventory
@onready var btn_skills: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnSkills
@onready var btn_encyclopedia: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnEncyclopedia
@onready var btn_world_log: Button = $ColorRect/Margin/VBox/Panel/TopBar/BtnWorldLog
@onready var btn_shortcut_os: Button = $ColorRect2/OsButton
@onready var btn_shortcut_message: Button = $ColorRect2/MessageButton
@onready var btn_shortcut_missions : Button= $ColorRect2/MissionsButton
@onready var btn_shortcut_inventory: Button = $ColorRect2/InventoryButton
@onready var btn_shortcut_skills: Button = $ColorRect2/SkillsButton

@onready var inventory_panel: InventoryPanel = $ColorRect/Margin/VBox/TabContainer/InventoryTab/InventoryPanel

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
	
	
	_on_btn_dashboard()

func _on_shortcut_os():
	color_rect.show()
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
