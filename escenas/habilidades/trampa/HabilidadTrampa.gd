class_name HabilidadTrampa
extends HabilidadBase
## Coloca una trampa oculta a cierta distancia (dirección + poder, igual
## que AreaEfecto/Muro) que espera a que un enemigo pise su radio de
## detección — recién ahí explota con daño en área. A diferencia del
## resto de las habilidades ofensivas (que golpean al toque), esta es
## "preparar y esperar": el jugador la deja atrás y sigue de largo, por
## eso NO congela su movimiento al colocarla (ver congela_movimiento_en_
## red más abajo — a diferencia del default heredado de HabilidadBase).

@export var escena_trampa: PackedScene = preload("res://escenas/habilidades/trampa/Trampa.tscn")

@export_group("Colocación")
## Distancia máxima a la que se coloca; poder (0..1) la escala, igual que
## AreaEfecto.desplazamiento_maximo.
var alcance_maximo: float = 150.0

@export_group("Trampa")
@export var radio_deteccion: float = 15.0
@export var radio_dano: float      = 30.0
@export var dano_trampa: float     = 45.0
@export var duracion_maxima: float = 20.0


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Trampa"
	tipo_habilidad   = "trampa"
	requiere_direccion = true
	congela_movimiento_en_red = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		alcance_maximo = float(d.alcance_metros) * ESCALA_METROS_PIXEL


func _ejecutar(direccion: Vector2, poder: float) -> void:
	var desplazamiento := Vector2.ZERO
	if direccion.length() > 0.1:
		desplazamiento = direccion.normalized() * alcance_maximo * clampf(poder, 0.0, 1.0)

	# Reutiliza una trampa ya creada en vez de instanciar una nueva cada
	# vez (object pooling: ver GestorPiscinas).
	var trampa := GestorPiscinas.obtener(escena_trampa) as Trampa
	trampa.global_position = (entidad_dueña as Node2D).global_position + desplazamiento
	trampa.configurar(
		_calcular_dano(int(dano_trampa)),
		radio_deteccion,
		radio_dano,
		entidad_dueña,
		duracion_maxima,
		tipo_dano,
	)
