class_name HabilidadTrampa
extends HabilidadBase
## Coloca una trampa oculta a cierta distancia (dirección + poder, igual
## que AreaEfecto/Muro) que espera a que un enemigo pise su radio de
## detección — recién ahí explota con daño en área. Congela brevemente al
## colocarla (ver congela_movimiento_en_red más abajo) para que la
## posición no se corra si el jugador sigue moviéndose después de soltar
## el touch.

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

## TODAS las trampas vigentes de ESTE peer que todavía no explotaron — la
## copia REAL (con detección) en el servidor, o la copia solo-visual en
## cualquier cliente (ver _mostrar_trampa_red). Mismo bug real ya
## encontrado y arreglado en HabilidadCepo.gd (ver ese comentario): con una
## sola referencia, colocar una segunda trampa mientras la primera seguía
## viva pisaba la referencia, y _activar_trampa_visual_red() (sin forma de
## saber CUÁL activó el servidor) siempre actuaba sobre la última colocada.
var _trampas_activas: Array[Trampa] = []


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Trampa"
	tipo_habilidad   = "trampa"
	requiere_direccion = true
	congela_movimiento_en_red = true
	# Pedido explícito del usuario: reducir la velocidad al apuntar (no solo
	# congelar al soltar) para forzar a pensar mejor dónde colocarla, Y de
	# paso reducir el margen real de drift — ver factor_velocidad_apuntando
	# en HabilidadBase, mismo criterio que HabilidadCepo.
	factor_velocidad_apuntando = 0.2


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
	_limpiar_trampas_vencidas()
	_trampas_activas.append(trampa)

	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_mostrar_trampa_red", posicion)


## Llamado por la copia REAL de la trampa (Trampa._activar) cuando explota
## de verdad — le avisa a los peers cercanos para que sus copias
## solo-visuales reproduzcan el mismo cambio. Manda la posición para que
## _activar_trampa_visual_red() pueda identificar CUÁL trampa es (ver
## _trampas_activas).
func avisar_trampa_activada(posicion: Vector2) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	for peer_id in InteresEspacial.peers_cercanos(posicion):
		rpc_id(peer_id, "_activar_trampa_visual_red", posicion)


## El servidor decidió la posición real — acá se crea la copia SOLO visual
## de este cliente (ver Trampa.mostrar_solo_visual).
@rpc("authority", "reliable")
func _mostrar_trampa_red(posicion: Vector2) -> void:
	var trampa := GestorPiscinas.obtener(escena_trampa) as Trampa
	trampa.global_position = posicion
	trampa.mostrar_solo_visual(duracion_maxima, entidad_dueña)
	_limpiar_trampas_vencidas()
	_trampas_activas.append(trampa)


## El servidor avisa que LA TRAMPA EN "posicion" ya explotó de verdad —
## refleja el mismo cambio en la copia visual de este cliente que está en
## esa posición (nunca "la última colocada": con 2+ trampas vivas a la vez
## eso activaba la equivocada, ver el comentario de _trampas_activas).
@rpc("authority", "reliable")
func _activar_trampa_visual_red(posicion: Vector2) -> void:
	for trampa in _trampas_activas:
		if is_instance_valid(trampa) and trampa.global_position.is_equal_approx(posicion):
			trampa.activar_visual()
			_trampas_activas.erase(trampa)
			return


## GestorPiscinas recicla instancias (ver ese archivo): una trampa que se
## apagó sola (nadie la pisó) vuelve a la piscina y puede reaparecer más
## tarde reasignada a una colocación NUEVA — sin sacarla de acá, esta lista
## crecería para siempre con referencias obsoletas.
func _limpiar_trampas_vencidas() -> void:
	_trampas_activas = _trampas_activas.filter(
		func(t): return is_instance_valid(t) and t._configurada)
