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


func _al_aplicar_daño(objetivo: Node, cantidad: float, _fuente: Node,
		tipo: int = Enums.Habilidad.TipoDano.FISICO, critico: bool = false) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or not (objetivo is Node2D):
		return
	# Reutiliza un número ya creado en vez de instanciar uno nuevo cada golpe
	# (object pooling: ver GestorPiscinas).
	var numero := GestorPiscinas.obtener(ESCENA_NUMERO) as NumeroDaño
	numero.configurar(cantidad, (objetivo as Node2D).global_position, tipo,
		_es_golpe_a_debilidad(objetivo, tipo), critico)


## true si el objetivo tiene resistencia NEGATIVA (= debilidad) al elemento
## del golpe. Se consulta acá, del lado que muestra el número (funciona igual
## en el celular: la réplica del mob carga el mismo .tscn con los mismos
## atributos base) — el daño real ya viene amplificado desde el servidor,
## esto solo decide si el número se marca visualmente como "golpe débil".
func _es_golpe_a_debilidad(objetivo: Node, tipo: int) -> bool:
	var atributos := objetivo.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return false
	match tipo:
		Enums.Habilidad.TipoDano.FISICO: return atributos.base.resistencia_fisica < 0.0
		Enums.Habilidad.TipoDano.AIRE:   return atributos.base.resistencia_aire < 0.0
		Enums.Habilidad.TipoDano.AGUA:   return atributos.base.resistencia_agua < 0.0
		Enums.Habilidad.TipoDano.FUEGO:  return atributos.base.resistencia_fuego < 0.0
		Enums.Habilidad.TipoDano.TIERRA: return atributos.base.resistencia_tierra < 0.0
	return false
