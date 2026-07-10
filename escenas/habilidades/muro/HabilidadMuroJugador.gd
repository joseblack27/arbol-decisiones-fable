class_name HabilidadMuroJugador
extends HabilidadBase
## Invoca un Muro: una fila de pilares perpendicular a la dirección de
## lanzamiento que aparece a "poder * alcance_maximo" de distancia (igual
## que HabilidadAreaEfecto), y que bloquea (opcional, por parámetro) y
## daña a los enemigos que la toquen mientras dura.
##
## Es destructible: su vida es Defensa + Tenacidad del jugador — los
## ataques enemigos que la golpeen se la restan igual que a cualquier otro
## objetivo de combate.

@export var escena_muro: PackedScene  = preload("res://escenas/habilidades/muro/muro.tscn")
@export var escena_pilar: PackedScene = preload("res://escenas/habilidades/muro/pilar.tscn")

@export_group("Forma del muro")
@export var cantidad_pilares: int             = 3
@export var distancia_entre_pilares: float    = 16.0
@export var radio_pilar: float                = 8.0

@export_group("Alcance")
## Distancia máxima a la que aparece el centro del muro; poder (0..1) la escala.
@export var alcance_maximo: float = 150.0

@export_group("Combate")
@export var duracion_muro: float = 5.0
## Daño por segundo, siempre el mismo mientras dure el muro. Sobreescrito
## por DatosHabilidad.aplicar_datos() al equipar (igual que las demás
## habilidades) vía dano_calculado_min/max — ver HabilidadBase._calcular_dano().
@export var dano: float = 10.0
## Si el muro bloquea físicamente a los enemigos además de dañarlos.
@export var bloquea_enemigos: bool = false


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Muro"
	tipo_habilidad   = "muro"
	# Se apunta arrastrando el joystick (como HabilidadAreaEfecto), no con un
	# tap instantáneo: sin esto, UIHabilidad la dispara con dirección cero
	# de inmediato (activar() igual inicia la recarga aunque _ejecutar() no
	# haga nada por falta de dirección).
	requiere_direccion = true


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		alcance_maximo = float(d.alcance_metros) * ESCALA_METROS_PIXEL


func _ejecutar(direccion: Vector2, poder: float) -> void:
	if direccion.length() < 0.1:
		return
	var dir := direccion.normalized()
	var distancia := alcance_maximo * clampf(poder, 0.2, 1.0)
	var centro: Vector2 = (entidad_dueña as Node2D).global_position + dir * distancia

	# Reutiliza un muro ya creado en vez de instanciar uno nuevo cada vez
	# (object pooling: ver GestorPiscinas).
	var muro := GestorPiscinas.obtener(escena_muro) as Muro
	muro.global_position = centro
	# Un solo valor de daño, fijo mientras dure el muro: se calcula UNA vez
	# aquí (puede variar por el rango de DatosHabilidad) y se repite igual
	# en cada tick — no se vuelve a tirar el dado por segundo.
	muro.configurar(
		entidad_dueña,
		dir,
		_calcular_vida_muro(),
		_obtener_defensa_jugador(),
		_calcular_dano(int(dano)),
		duracion_muro,
		bloquea_enemigos,
		cantidad_pilares,
		distancia_entre_pilares,
		radio_pilar,
		escena_pilar,
		tipo_dano,
	)


## La vida del muro no es un valor fijo: depende de las defensas actuales
## del jugador (Defensa + Tenacidad), para que suba con su equipo.
func _calcular_vida_muro() -> float:
	var atributos := entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return 50.0
	return atributos.base.defensa + atributos.base.tenacidad


## Umbral de penetración de armadura del muro: un ataque con más "impacto"
## que esto lo revienta de un golpe en vez de solo restarle vida — ver
## Muro.recibir_impacto(). La mitad de la Defensa del jugador más su
## Tenacidad completa (distinto de la vida, que usa ambas enteras).
func _obtener_defensa_jugador() -> float:
	var atributos := entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return 20.0
	return atributos.base.defensa * 0.5 + atributos.base.tenacidad
