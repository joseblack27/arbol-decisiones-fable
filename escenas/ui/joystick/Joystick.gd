extends Area2D

var signal_id: String = "default"
var distancia: float
var direccion: Vector2
var angulo: float
var index: int = -1

@onready var palanca = $Palanca
@onready var rango = $Rango
@onready var radio = $CollisionShape2D.shape.radius

@export var habilitado: bool = true

func _ready():
	signal_id = str(get_parent().get_instance_id())
	SeñalManager.registrar(str("joystick_movimiento"), signal_id, {"direccion": TYPE_VECTOR2})
	SeñalManager.conectar(str("touch_iniciado_",get_instance_id()), self, "_on_touch_iniciado")
	SeñalManager.conectar(str("touch_finalizado_",get_instance_id()), self, "_on_touch_finalizado")
	SeñalManager.conectar(str("touch_movido_",get_instance_id()), self, "_on_touch_movido")
	radio = radio * scale.x


## Red de seguridad: si la app pierde el foco (p. ej. el SO intercepta el
## gesto — arrastrar el joystick "hasta arriba" puede entrar en la franja
## donde Android interpreta un gesto propio, como bajar la barra de
## notificaciones) el touch en curso puede quedar sin su evento normal de
## "soltado", y el jugador seguía moviéndose solo para siempre con la
## última dirección (reportado por el usuario). Sin esto, nada volvía a
## soltar el joystick hasta el próximo toque.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if index != -1:
			_on_touch_finalizado(index, palanca.global_position)

func _on_touch_iniciado(indice, posicion):
	if index == -1 and habilitado == true:
		distancia = global_position.distance_to(posicion)
		if distancia <= radio:
			index = indice
			palanca.global_position = posicion
			direccion = global_position.direction_to(palanca.global_position) * distancia / radio
		SeñalManager.emitir(str("joystick_movimiento"), signal_id, [direccion])

func _on_touch_movido(indice, posicion):
	if indice == index and habilitado == true:
		distancia = global_position.distance_to(posicion)
		direccion = global_position.direction_to(posicion)
		if distancia <= radio:
			palanca.global_position = posicion
		else:
			palanca.position = direccion * (radio / scale.x)
		SeñalManager.emitir(str("joystick_movimiento"), signal_id, [direccion])

func _on_touch_finalizado(indice, _posicion):
	if indice == index and habilitado == true:
		index = -1
		palanca.position = Vector2.ZERO
		direccion = Vector2.ZERO
		distancia = 0
		SeñalManager.emitir(str("joystick_movimiento"), signal_id, [direccion])
