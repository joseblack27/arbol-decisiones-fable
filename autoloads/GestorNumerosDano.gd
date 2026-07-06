extends Node
## GestorNumerosDano (autoload): capa de PRESENTACIÓN pura. Escucha
## BusEventos.daño_aplicado (la única fuente de verdad de "se aplicó daño",
## que ya emiten Proyectil.gd, Arañazo.gd, HabilidadCarga.gd, etc.) y
## muestra el número flotante correspondiente.
##
## No sabe nada de salud, componentes ni combate — si este autoload se
## desactivara, el juego funcionaría exactamente igual, solo sin el número
## en pantalla. Por eso NO vive dentro de VidaComponente: mezclar "cuánta
## vida queda" con "cómo se ve" ahí dificultaría reutilizar una sin la otra.

const ESCENA_NUMERO := preload("res://escenas/ui/numero_daño/NumeroDaño.tscn")


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_aplicar_daño)


func _al_aplicar_daño(objetivo: Node, cantidad: float, _fuente: Node) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or not (objetivo is Node2D):
		return
	# Reutiliza un número ya creado en vez de instanciar uno nuevo cada golpe
	# (object pooling: ver GestorPiscinas).
	var numero := GestorPiscinas.obtener(ESCENA_NUMERO) as NumeroDaño
	numero.configurar(cantidad, (objetivo as Node2D).global_position)
