extends StaticBody2D
class_name CompuertaAtajoMina
## Compuerta del atajo secreto de la Mina de Cristal: bloquea el corredor
## corto entre la sala del jefe y la entrada hasta que el Corazón de Cristal
## muere. La abre/cierra NivelMina.gd (ver _al_morir_jefe/_respawnear_jefe),
## no esta misma escena — sin autoload ni persistencia nueva, mismo criterio
## que el resto del plan "Mina de Cristal".

@export var colision: CollisionShape2D
@export var visual: Node2D

var abierta: bool = false


func _ready() -> void:
	_aplicar_estado()


## SERVIDOR (o partida sin red): abre la compuerta y avisa a los clientes.
func abrir_servidor() -> void:
	if abierta:
		return
	abierta = true
	_aplicar_estado()
	if Utils.en_red() and multiplayer.is_server():
		rpc("_abrir_red")


## SERVIDOR: la cierra de nuevo tras reponer al jefe (mismo evento que su
## respawn, ver NivelMina.gd._respawnear_jefe).
func cerrar_servidor() -> void:
	if not abierta:
		return
	abierta = false
	_aplicar_estado()
	if Utils.en_red() and multiplayer.is_server():
		rpc("_cerrar_red")


@rpc("authority", "reliable")
func _abrir_red() -> void:
	abierta = true
	_aplicar_estado()


@rpc("authority", "reliable")
func _cerrar_red() -> void:
	abierta = false
	_aplicar_estado()


func _aplicar_estado() -> void:
	if colision:
		colision.set_deferred("disabled", abierta)
	if visual:
		visual.visible = not abierta
