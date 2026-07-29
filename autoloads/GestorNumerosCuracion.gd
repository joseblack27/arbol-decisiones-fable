extends Node
## GestorNumerosCuracion (autoload): capa de PRESENTACIÓN pura, contraparte
## de GestorNumerosDano para curación — NO toca ese autoload (sistema de
## daño ya probado y en uso); solo escucha BusEventos.curacion_aplicada y
## dibuja el número verde "+N" correspondiente. Si este autoload se
## desactivara, el juego funcionaría igual, solo sin el número en pantalla.
##
## Igual que con daño: el número es para MI jugador (la curación que recibo,
## sea de una habilidad, un ítem, robo de vida, etc.) — la señal llega
## replicada a todos los peers con el objetivo visible en pantalla, así que
## hace falta filtrar o se vería la curación de cualquier otro jugador.

const ESCENA_NUMERO := preload("res://escenas/ui/numero_curacion/NumeroCuracion.tscn")


func _ready() -> void:
	BusEventos.curacion_aplicada.connect(_al_curar)


func _al_curar(objetivo: Node, cantidad: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or not (objetivo is Node2D):
		return
	if objetivo != Utils.jugador_local():
		return
	var numero := GestorPiscinas.obtener(ESCENA_NUMERO) as NumeroCuracion
	numero.configurar(cantidad, (objetivo as Node2D).global_position)
