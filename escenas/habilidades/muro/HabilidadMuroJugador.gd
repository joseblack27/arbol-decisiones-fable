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


## Identidad de red de cada muro invocado por ESTA habilidad — hace falta
## porque el propio Muro es un objeto efímero de una piscina LOCAL (sin
## nombre/ruta estable entre peers, a diferencia de Jugador/Enemigo): no
## se le puede avisar "este nodo murió" por RPC apuntándole directo. Se
## identifica por un contador propio de la habilidad — como las
## activaciones viajan por el mismo canal reliable y en el mismo orden en
## todos los peers (ver HabilidadBase._disparar/_activar_red/_reproducir_
## visual_red), el número de muro coincide en todos lados para la MISMA
## invocación real. Puede haber más de un muro vivo a la vez (confirmado
## por el usuario), por eso un Dictionary y no una sola referencia.
var _contador_muros := 0
var _muros_activos: Dictionary = {}  # id (int) -> Muro


func _ejecutar(direccion: Vector2, poder: float) -> void:
	if direccion.length() < 0.1:
		return
	var dir := direccion.normalized()
	var distancia := alcance_maximo * clampf(poder, 0.2, 1.0)
	var centro: Vector2 = (entidad_dueña as Node2D).global_position + dir * distancia

	_contador_muros += 1
	var id_muro := _contador_muros

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
	_muros_activos[id_muro] = muro
	# CONNECT_ONE_SHOT: esta misma instancia vuelve a la piscina y se
	# reutiliza en una invocación FUTURA con otro id — sin esto, la
	# conexión vieja seguiría viva y dispararía con el id equivocado la
	# próxima vez que ese muro reciclado muera.
	muro.muerte.connect(_on_muro_muerte.bind(id_muro), CONNECT_ONE_SHOT)


## El muro murió DE VERDAD (Muro.quitar_vida()/recibir_impacto() ya están
## gateados a solo servidor/un jugador solo — ver esos comentarios): esta
## señal nunca dispara ya por la predicción de un cliente puro. Acá es
## donde el servidor avisa a los demás peers cercanos para que destruyan
## su propia copia local — antes cada uno decidía esto por su cuenta con
## su propia simulación, y terminaban en desacuerdo (bug reportado: el
## muro vivía para un jugador y no para otro).
func _on_muro_muerte(_valor: float, id_muro: int) -> void:
	var posicion := Vector2.ZERO
	if _muros_activos.has(id_muro) and is_instance_valid(_muros_activos[id_muro]):
		posicion = (_muros_activos[id_muro] as Muro).global_position
	_muros_activos.erase(id_muro)
	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_recibir_destruccion_muro_red", id_muro)


## CLIENTE: el servidor confirma que este muro (identificado por su
## número, ver _contador_muros de arriba) se rompió de verdad — destruye
## la copia LOCAL correspondiente. Puede volver a disparar _on_muro_muerte
## en este mismo cliente (la conexión de arriba sigue viva acá, nunca se
## gastó por predicción local) pero es inofensivo: ese chequeo de
## multiplayer.is_server() corta antes de volver a mandar nada.
@rpc("authority", "reliable")
func _recibir_destruccion_muro_red(id_muro: int) -> void:
	var muro: Muro = _muros_activos.get(id_muro)
	_muros_activos.erase(id_muro)
	if is_instance_valid(muro):
		muro._romper()


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
