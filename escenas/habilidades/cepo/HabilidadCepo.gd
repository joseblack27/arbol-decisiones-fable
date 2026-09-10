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

## El cepo vigente de ESTE peer — la copia REAL (con detección) en el
## servidor, o la copia solo-visual en cualquier cliente (ver
## _mostrar_cepo_red). Se usa para aplicarle activar_visual() cuando llega
## el aviso de activación (_activar_cepo_visual_red).
var _cepo_actual: Cepo = null


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
	_cepo_actual = cepo

	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_mostrar_cepo_red", posicion)


## Llamado por la copia REAL del cepo (Cepo._on_body_entrada) cuando se
## activa de verdad — le avisa a los peers cercanos para que sus copias
## solo-visuales reproduzcan el mismo cambio, en vez de decidirlo cada una
## por su cuenta.
func avisar_cepo_activado(posicion: Vector2) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	for peer_id in InteresEspacial.peers_cercanos(posicion):
		rpc_id(peer_id, "_activar_cepo_visual_red")


## El servidor decidió la posición real — acá se crea la copia SOLO visual
## de este cliente (ver Cepo.mostrar_solo_visual).
@rpc("authority", "reliable")
func _mostrar_cepo_red(posicion: Vector2) -> void:
	var cepo := GestorPiscinas.obtener(escena_cepo) as Cepo
	cepo.global_position = posicion
	cepo.mostrar_solo_visual(duracion_maxima, entidad_dueña)
	_cepo_actual = cepo


## El servidor avisa que el cepo real ya se activó — refleja el mismo
## cambio en la copia visual de este cliente.
@rpc("authority", "reliable")
func _activar_cepo_visual_red() -> void:
	if is_instance_valid(_cepo_actual):
		_cepo_actual.activar_visual()
