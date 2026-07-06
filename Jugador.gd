## Jugador.gd
## Controlador principal del jugador. Su única responsabilidad es orquestar el flujo de datos y eventos entre los componentes.
## Toda la lógica de física y el estado de los componentes deben estar referenciados y configurados desde el Inspector de Godot.

extends CharacterBody2D

# --- Referencias de Componentes ---
# Estos componentes deben estar adjuntos como nodos hijos de este jugador y deben existir
# en la escena de Godot. El usuario debe arrastrar las referencias aquí en el Inspector.
@export var componente_vida: VidaComponente # Componente de vida.
@export var componente_movimiento: MovimientoComponente # Componente de movimiento.
#@export var arbol_comportamiento: ArbolComportamiento # Referencia principal del sistema de IA.

# --- Variables de estado ---
var componentes_de_acciones: Dictionary = {}
var _vida_anterior: float = 0.0
var direccion: Vector2

@onready var btn_agregar: Button = $Panel/VBoxContainer/HBoxContainer/BtnAgregar
@onready var btn_quitar: Button = $Panel/VBoxContainer/HBoxContainer/BtnQuitar
@onready var sprite: Sprite2D = $Sprite2D
@onready var slot_habilidades: SlotHabilidades = $SlotHabilidades
@onready var camara: Camera2D = $Camara

var _ultima_direccion: Vector2 = Vector2.RIGHT


func _ready():
	add_to_group("jugadores")
	# 1. Conectar señales de los componentes.
	if componente_vida:
		# Conectar la muerte del componente de vida.
		componente_vida.muerte.connect(self.manejar_muerte)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
		_vida_anterior = componente_vida.obtener_vida_maxima()
	
	# 2. Registrar componentes.
	componentes_de_acciones["Movimiento"] = componente_movimiento
	componentes_de_acciones["Vida"] = componente_vida
	
	btn_agregar.pressed.connect(_on_btn_agregar)
	btn_quitar.pressed.connect(_on_btn_quitar)

	SeñalManager.conectar("joystick_movimiento", self, "_joystick_movimiento")
	# Slots 0-3 (UIHabilidad por índice de slot)
	SeñalManager.conectar("slot_0_activar", self, "_on_slot_0_activar")
	SeñalManager.conectar("slot_0_lanzar",  self, "_on_slot_0_lanzar")
	SeñalManager.conectar("slot_1_activar", self, "_on_slot_1_activar")
	SeñalManager.conectar("slot_1_lanzar",  self, "_on_slot_1_lanzar")
	SeñalManager.conectar("slot_2_activar", self, "_on_slot_2_activar")
	SeñalManager.conectar("slot_2_lanzar",  self, "_on_slot_2_lanzar")
	SeñalManager.conectar("slot_3_activar", self, "_on_slot_3_activar")
	SeñalManager.conectar("slot_3_lanzar",  self, "_on_slot_3_lanzar")


func _joystick_movimiento(_direccion: Vector2):
	direccion = _direccion


func _physics_process(_delta: float) -> void:
	# *** ORQUESTACIÓN FÍSICA ***

	# Delegamos la aplicación de física al componente de movimiento.
	if componente_movimiento:
		componente_movimiento.physics_process(_delta, direccion)
	if componente_vida:
		$Panel/VBoxContainer/Label.text = "Vida:" + str(componente_vida.obtener_vida())

	if direccion != Vector2.ZERO:
		_ultima_direccion = direccion


func manejar_muerte(_vida_actual: float) -> void:
	#print("EVENTO DE VIDA: El jugador ha sido notificado de su propia muerte.")
	# Cuando la vida llega a cero, el controlador debe forzar el paro de la física.
	velocity = Vector2.ZERO
	componente_vida.agregar_vida(100)


## Activa la habilidad del slot indicado.
func _activar_slot(index: int, dir: Vector2 = Vector2.ZERO, poder: float = 1.0) -> void:
	var h := slot_habilidades.obtener(index)
	if h:
		var d := dir if dir.length() > 0.1 else _ultima_direccion
		h.activar(d, poder)

func _on_slot_0_activar()                    -> void: _activar_slot(0)
func _on_slot_0_lanzar(d: Vector2, p: float) -> void: _activar_slot(0, d, p)
func _on_slot_1_activar()                    -> void: _activar_slot(1)
func _on_slot_1_lanzar(d: Vector2, p: float) -> void: _activar_slot(1, d, p)
func _on_slot_2_activar()                    -> void: _activar_slot(2)
func _on_slot_2_lanzar(d: Vector2, p: float) -> void: _activar_slot(2, d, p)
func _on_slot_3_activar()                    -> void: _activar_slot(3)
func _on_slot_3_lanzar(d: Vector2, p: float) -> void: _activar_slot(3, d, p)


## Recibe daño externo (carga, habilidades enemigas). Delega al componente.
func quitar_vida(cantidad: float) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad)


## GestorNiveles llama esto tras cada cambio de nivel para que la cámara no
## muestre el vacío fuera del mapa. rect vacío (nivel sin Terreno) = sin límite.
func aplicar_limites_camara(rect: Rect2) -> void:
	if camara == null:
		return
	if rect.size == Vector2.ZERO:
		camara.limit_left = -10000000
		camara.limit_top = -10000000
		camara.limit_right = 10000000
		camara.limit_bottom = 10000000
		return
	camara.limit_left = int(rect.position.x)
	camara.limit_top = int(rect.position.y)
	camara.limit_right = int(rect.position.x + rect.size.x)
	camara.limit_bottom = int(rect.position.y + rect.size.y)


func _on_btn_agregar():
	componente_vida.agregar_vida(5)


func _on_btn_quitar():
	componente_vida.quitar_vida(5)
	BusEventos.daño_aplicado.emit(self, 5, self)


func parpadear(veces: int = 10, duracion: float = 0.1) -> void:
	var tween := create_tween()
	for i in veces:
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
		tween.tween_property(sprite, "modulate", Color.WHITE,        duracion)


func _on_vida_cambiada(nueva_vida: float) -> void:
	if nueva_vida < _vida_anterior:
		parpadear()
	_vida_anterior = nueva_vida
