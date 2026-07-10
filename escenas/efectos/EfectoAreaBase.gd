extends Area2D
class_name EfectoAreaBase
## Base genérica para efectos de área que se spawnean en el mundo.
## Crea subclases que sobreescriban _aplicar_efecto() y _quitar_efecto().

@export var duracion: float        = 3.0
@export var grupo_objetivo: String = "jugadores"

var _objetivos_actuales: Array[Node] = []
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = duracion
	_timer.one_shot  = true
	_timer.timeout.connect(_terminar)
	add_child(_timer)
	_timer.start()

	body_entered.connect(_on_cuerpo_entro)
	body_exited.connect(_on_cuerpo_salio)


func _on_cuerpo_entro(cuerpo: Node) -> void:
	if not cuerpo.is_in_group(grupo_objetivo):
		return
	_objetivos_actuales.append(cuerpo)
	_aplicar_efecto(cuerpo)


func _on_cuerpo_salio(cuerpo: Node) -> void:
	if not cuerpo.is_in_group(grupo_objetivo):
		return
	_objetivos_actuales.erase(cuerpo)
	_quitar_efecto(cuerpo)


func _terminar() -> void:
	for objetivo in _objetivos_actuales:
		if is_instance_valid(objetivo):
			_quitar_efecto(objetivo)
	_objetivos_actuales.clear()
	_al_terminar()


## Sobreescribir en subclases.
func _aplicar_efecto(_objetivo: Node) -> void:
	pass


## Sobreescribir en subclases.
func _quitar_efecto(_objetivo: Node) -> void:
	pass


## Qué hacer cuando el efecto termina (por duración o porque una subclase lo
## llama antes de tiempo, p. ej. Muro._romper()). Por defecto se libera de
## verdad; una subclase pooled (ver GestorPiscinas) puede devolverse a su
## piscina en cambio.
func _al_terminar() -> void:
	queue_free()


## Reinicia el temporizador de duración con un valor nuevo — para reutilizar
## esta instancia desde una piscina en vez de crear una desde cero (el Timer
## solo se crea una vez, en _ready(), que un nodo pooled nunca vuelve a
## ejecutar). Ver Muro.configurar().
func reiniciar_temporizador(duracion_nueva: float) -> void:
	duracion = duracion_nueva
	_objetivos_actuales.clear()
	_timer.wait_time = duracion
	_timer.start()
