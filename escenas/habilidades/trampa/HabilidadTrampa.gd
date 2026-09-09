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

## La trampa vigente de ESTE peer — la copia REAL (con detección) en el
## servidor, o la copia solo-visual en cualquier cliente (ver
## _mostrar_trampa_red). Se usa para aplicarle activar_visual() cuando
## llega el aviso de activación (_activar_trampa_visual_red).
var _trampa_actual: Trampa = null


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
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + desplazamiento

	# Solo quien tiene autoridad real (el servidor, o un solo jugador sin
	# red) decide dónde va la trampa y detecta de verdad — mismo criterio
	# y mismo motivo que HabilidadCepo._ejecutar() (ver el comentario
	# grande ahí).
	if Utils.en_red() and not multiplayer.is_server():
		return

	# Reutiliza una trampa ya creada en vez de instanciar una nueva cada
	# vez (object pooling: ver GestorPiscinas).
	var trampa := GestorPiscinas.obtener(escena_trampa) as Trampa
	trampa.global_position = posicion
	trampa.configurar(
		_calcular_dano(int(dano_trampa)),
		radio_deteccion,
		radio_dano,
		entidad_dueña,
		duracion_maxima,
		tipo_dano,
		self if Utils.en_red() else null,
	)
	_trampa_actual = trampa

	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_mostrar_trampa_red", posicion)


## Llamado por la copia REAL de la trampa (Trampa._activar) cuando explota
## de verdad — le avisa a los peers cercanos para que sus copias
## solo-visuales reproduzcan el mismo cambio.
func avisar_trampa_activada(posicion: Vector2) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	for peer_id in InteresEspacial.peers_cercanos(posicion):
		rpc_id(peer_id, "_activar_trampa_visual_red")


## El servidor decidió la posición real — acá se crea la copia SOLO visual
## de este cliente (ver Trampa.mostrar_solo_visual).
@rpc("authority", "reliable")
func _mostrar_trampa_red(posicion: Vector2) -> void:
	var trampa := GestorPiscinas.obtener(escena_trampa) as Trampa
	trampa.global_position = posicion
	trampa.mostrar_solo_visual(duracion_maxima, entidad_dueña)
	_trampa_actual = trampa


## El servidor avisa que la trampa real ya explotó — refleja el mismo
## cambio en la copia visual de este cliente.
@rpc("authority", "reliable")
func _activar_trampa_visual_red() -> void:
	if is_instance_valid(_trampa_actual):
		_trampa_actual.activar_visual()
