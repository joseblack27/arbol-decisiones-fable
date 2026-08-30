class_name HabilidadMuroGuardian
extends HabilidadBase
## Invoca un Muro (mismo Muro.gd que ya usa el jugador, sin tocarlo) entre
## el Guardián Quebrado y su objetivo, para "cortar la sala" — fase
## "Corrupción". Copia casi literal de HabilidadMuroJugador.gd (misma vida/
## umbral de impacto, misma sincronización de destrucción por red); la
## única diferencia real es bloquea_enemigos=false, fijo (ver la decisión
## confirmada con el usuario: el muro del jefe es zona de peligro, no
## bloqueo físico — así no hace falta tocar el collision_mask del jugador).
##
## Sin .tscn propio — habilidad de MOB, se agrega como script node directo
## dentro de EnemigoGuardianQuebrado.tscn.

@export var escena_muro: PackedScene  = preload("res://escenas/habilidades/muro/muro.tscn")
@export var escena_pilar: PackedScene = preload("res://escenas/habilidades/muro/pilar.tscn")

@export_group("Forma del muro")
@export var cantidad_pilares: int          = 4
@export var distancia_entre_pilares: float = 20.0
@export var radio_pilar: float             = 10.0

@export_group("Alcance")
## TOPE de distancia del muro, no un valor fijo: _ejecutar() usa la menor
## entre esto y la distancia real al objetivo, así el muro converge sobre
## el jugador cuando está más cerca en vez de quedar corto (bug real
## reportado: "lo sigue lanzando en otra posición en lugar de encima del
## jugador"). HabilidadBT.rango_maximo en MuroGuardian.tres tiene que
## quedar <= este valor (mismo criterio que las demás habilidades, ver
## HabilidadBarridoGuardian.largo) para que la IA no lo invoque desde tan
## lejos que el muro quede varios píxeles corto igual.
@export var distancia_muro: float = 130.0

@export_group("Combate")
@export var duracion_muro: float = 6.0
@export var dano: float = 12.0
## Fijo en false: el muro del jefe es zona de peligro (daña, es
## destructible con Corte), no una pared física — decisión confirmada con
## el usuario, ver el plan.
const bloquea_enemigos := false

var _contador_muros := 0
var _muros_activos: Dictionary = {}  # id (int) -> Muro


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Muro Corrupto"
	tipo_habilidad   = "muro_guardian"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var dir := direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	# distancia_muro es un TOPE, no una distancia fija: si el objetivo real
	# está más cerca que eso, el muro se queda corto y aparece "en otra
	# posición" en vez de sobre el jugador (bug real reportado) — se calcula
	# la distancia real al objetivo (memoria) y se usa la menor de las dos,
	# así el muro nunca se pasa de largo del objetivo.
	var distancia := distancia_muro
	if "memoria" in entidad_dueña:
		var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
		if is_instance_valid(objetivo_raw) and objetivo_raw is Node2D:
			distancia = minf(distancia_muro,
				(entidad_dueña as Node2D).global_position.distance_to((objetivo_raw as Node2D).global_position))
	var centro: Vector2 = (entidad_dueña as Node2D).global_position + dir * distancia

	_contador_muros += 1
	var id_muro := _contador_muros

	var muro := GestorPiscinas.obtener(escena_muro) as Muro
	muro.global_position = centro
	muro.configurar(
		entidad_dueña,
		dir,
		_calcular_vida_muro(),
		_obtener_umbral_impacto(),
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
	muro.muerte.connect(_on_muro_muerte.bind(id_muro), CONNECT_ONE_SHOT)


## Mismo criterio de sincronización que HabilidadMuroJugador._on_muro_muerte
## — ver ese archivo para el porqué completo (el Muro es un objeto efímero
## de piscina LOCAL, sin ruta estable entre peers).
func _on_muro_muerte(_valor: float, id_muro: int) -> void:
	var posicion := Vector2.ZERO
	if _muros_activos.has(id_muro) and is_instance_valid(_muros_activos[id_muro]):
		posicion = (_muros_activos[id_muro] as Muro).global_position
	_muros_activos.erase(id_muro)
	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(posicion):
			rpc_id(peer_id, "_recibir_destruccion_muro_red", id_muro)


@rpc("authority", "reliable")
func _recibir_destruccion_muro_red(id_muro: int) -> void:
	var muro: Muro = _muros_activos.get(id_muro)
	_muros_activos.erase(id_muro)
	if is_instance_valid(muro):
		muro._romper()


func _calcular_vida_muro() -> float:
	var atributos := entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return 200.0
	return atributos.base.defensa + atributos.base.tenacidad + 150.0


func _obtener_umbral_impacto() -> float:
	var atributos := entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return 60.0
	return atributos.base.defensa * 0.5 + atributos.base.tenacidad + 60.0
