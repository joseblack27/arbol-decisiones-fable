class_name HabilidadCepo
extends HabilidadBase
## Coloca un Cepo oculto a cierta distancia (dirección + poder, igual que
## HabilidadTrampa) que espera a que un enemigo pise su radio de detección
## — recién ahí lo inmoviliza y le hace daño por tick durante
## duracion_aturdimiento segundos (ver Cepo.gd/EfectoCepo.gd). Congela
## brevemente al colocarlo (ver congela_movimiento_en_red más abajo) para
## que la posición no se corra si el jugador sigue moviéndose después de
## soltar el touch.

@export var escena_cepo: PackedScene = preload("res://escenas/habilidades/cepo/Cepo.tscn")

@export_group("Colocación")
## Distancia máxima a la que se coloca; poder (0..1) la escala, igual que
## AreaEfecto.desplazamiento_maximo/HabilidadTrampa.alcance_maximo.
var alcance_maximo: float = 150.0

@export_group("Cepo")
@export var radio_deteccion: float         = 15.0
@export var dano_por_tick: float           = 10.0
@export var intervalo_tick: float          = 0.5
## Nombre elegido a propósito igual al de HabilidadSacudida: PanelDetalle
## Habilidad.gd busca esta propiedad por NOMBRE (duck typing) para llenar
## el {duracion} de la descripción — ver ese script, sección "duracion_X".
@export var duracion_aturdimiento: float   = 3.0
@export var duracion_maxima: float         = 20.0

## Mismo ícono que la habilidad, para que BuffsComponente lo muestre igual
## que en el botón — mismo criterio que HabilidadSacudida._icono_debuff.
var _icono_debuff: Texture2D = null

## TODOS los cepos vigentes de ESTE peer que todavía no se activaron — la
## copia REAL (con detección) en el servidor, o la copia solo-visual en
## cualquier cliente (ver _mostrar_cepo_red). Antes era una sola referencia
## (_cepo_actual): con DOS cepos vivos a la vez, colocar el segundo la
## pisaba, así que _activar_cepo_visual_red() (sin ninguna forma de saber
## CUÁL de los dos activó el servidor) siempre terminaba actuando sobre el
## último colocado — el otro se quedaba mostrando "puesto" para siempre en
## los clientes hasta que se le acababa el tiempo solo, aunque su copia
## real ya se hubiera activado. Reportado por el usuario: "coloco 2 cepos,
## uno encima del otro, el enemigo los pisa y solo se cierra el primero".
var _cepos_activos: Array[Cepo] = []


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Cepo"
	tipo_habilidad   = "cepo"
	requiere_direccion = true
	# Congela brevemente al colocarlo — sin esto, si el jugador seguía
	# moviéndose después de soltar el touch, el servidor calculaba la
	# posición desde SU posición más nueva (la ida y vuelta de red de por
	# medio), y el cepo terminaba corrido de donde se apuntó ("se sigue
	# moviendo la posición de lanzamiento", reportado). Un margen de 0.2s
	# no alcanzó en juego real (seguía corriéndose) — mismo margen que el
	# resto (0.5s, default de HabilidadBase), sin override propio.
	congela_movimiento_en_red = true
	# Pedido explícito del usuario: reducir la velocidad al apuntar (no solo
	# congelar al soltar) para forzar a pensar mejor dónde colocarlo, Y de
	# paso reducir el margen real de drift — a un quinto de la velocidad,
	# cualquier resto de movimiento que se cuele durante la ida y vuelta de
	# red pesa mucho menos (ver factor_velocidad_apuntando en HabilidadBase).
	factor_velocidad_apuntando = 0.2


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		alcance_maximo = float(d.alcance_metros) * ESCALA_METROS_PIXEL
	if d.icono:
		_icono_debuff = d.icono


func _ejecutar(direccion: Vector2, poder: float) -> void:
	var desplazamiento := Vector2.ZERO
	if direccion.length() > 0.1:
		desplazamiento = direccion.normalized() * alcance_maximo * clampf(poder, 0.0, 1.0)
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + desplazamiento

	# Solo quien tiene autoridad real (el servidor, o un solo jugador sin
	# red) decide dónde va el cepo y detecta de verdad. Antes CADA peer
	# (el que lo lanza, el servidor, cualquier observador) instanciaba y
	# posicionaba su PROPIO cepo a partir de SU PROPIA vista de la posición
	# del dueño — con hasta el ping de diferencia entre esas vistas, cada
	# uno terminaba con el cepo en un punto distinto, tomando sus propias
	# decisiones de detección. Ver _mostrar_cepo_red/avisar_cepo_activado:
	# acá se le avisa a los demás peers la posición y el estado EXACTOS que
	# usó el servidor, en vez de que cada uno adivine los suyos.
	if Utils.en_red() and not multiplayer.is_server():
		return

	# Reutiliza un cepo ya creado en vez de instanciar uno nuevo cada vez
	# (object pooling: ver GestorPiscinas).
	var cepo := GestorPiscinas.obtener(escena_cepo) as Cepo
	cepo.global_position = posicion
	cepo.configurar(
		_calcular_dano(int(dano_por_tick)),
		intervalo_tick,
		duracion_aturdimiento,
		radio_deteccion,
		entidad_dueña,
		duracion_maxima,
		tipo_dano,
		_icono_debuff,
		self if Utils.en_red() else null,
	)
	_limpiar_cepos_vencidos()
	_cepos_activos.append(cepo)

	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_mostrar_cepo_red", posicion)


## Llamado por la copia REAL del cepo (Cepo._on_body_entrada) cuando se
## activa de verdad — le avisa a los peers cercanos para que sus copias
## solo-visuales reproduzcan el mismo cambio, en vez de decidirlo cada una
## por su cuenta. Manda la posición para que _activar_cepo_visual_red()
## pueda identificar CUÁL de los cepos vigentes es (ver _cepos_activos).
func avisar_cepo_activado(posicion: Vector2) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	for peer_id in InteresEspacial.peers_cercanos(posicion):
		rpc_id(peer_id, "_activar_cepo_visual_red", posicion)


## El servidor decidió la posición real — acá se crea la copia SOLO visual
## de este cliente (ver Cepo.mostrar_solo_visual).
@rpc("authority", "reliable")
func _mostrar_cepo_red(posicion: Vector2) -> void:
	var cepo := GestorPiscinas.obtener(escena_cepo) as Cepo
	cepo.global_position = posicion
	cepo.mostrar_solo_visual(duracion_maxima, entidad_dueña)
	_limpiar_cepos_vencidos()
	_cepos_activos.append(cepo)


## El servidor avisa que EL CEPO EN "posicion" ya se activó de verdad —
## refleja el mismo cambio en la copia visual de este cliente que está en
## esa posición (nunca "la última colocada": con 2+ cepos vivos a la vez
## eso activaba el equivocado, ver el comentario de _cepos_activos).
@rpc("authority", "reliable")
func _activar_cepo_visual_red(posicion: Vector2) -> void:
	for cepo in _cepos_activos:
		if is_instance_valid(cepo) and cepo.global_position.is_equal_approx(posicion):
			cepo.activar_visual()
			_cepos_activos.erase(cepo)
			return


## GestorPiscinas recicla instancias (ver ese archivo): un cepo que se
## apagó solo (nadie lo pisó, ver Cepo._process()) vuelve a la piscina y
## puede reaparecer más tarde reasignado a una colocación NUEVA — sin
## sacarlo de acá, esta lista crecería para siempre con referencias
## obsoletas, y un cepo reciclado podría terminar dos veces en la lista.
func _limpiar_cepos_vencidos() -> void:
	_cepos_activos = _cepos_activos.filter(
		func(c): return is_instance_valid(c) and c._configurada)
