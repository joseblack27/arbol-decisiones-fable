class_name HabilidadPuestaHuevos
extends HabilidadBase
## Puesta de Huevos: dos o tres huevos alrededor de la Reina, que se queda
## en reposo (+20% de daño recibido, ver VulnerabilidadComponente) un
## tiempo fijo. Si algún huevo sigue vivo al terminar, eclosiona en una
## Hormiga Soldado "guardiana" que le da a la Reina -20% de daño recibido
## MIENTRAS esa hormiga siga viva (hasta 3 guardianas = -60% total, ver
## EscudoComponente) — matando a las guardianas se le quita esa resistencia
## de a una. Tanto cada guardiana como la propia Reina muestran un ícono de
## escudo mientras dure, para no confundirlas con hormigas normales.
##
## Autoridad exclusiva del servidor de punta a punta (huevos, reposo,
## eclosión, resistencia real) — mismo criterio que _invocar_refuerzos() en
## los jefes de la Mina: un mob (o un huevo) vive una sola vez, con una
## sola fuente de verdad. Lo único que viaja a los demás peers es el AVISO
## de "estos son los guardianes vivos ahora" (ver _actualizar_guardianes_
## red), para que el ícono de escudo se vea igual en toda pantalla: los
## mobs de este proyecto no usan MultiplayerSynchronizer (ver Enemigo.gd),
## así que cualquier nodo agregado DESPUÉS del spawn (el BuffsComponente)
## necesita su propio aviso explícito — mismo criterio que
## HabilidadMarcaColonia._marcar_objetivo_red.

const _TEXTURA_ICONOS := "res://assets/iconos/iconos habilidades.png"
## Duración "permanente" del escudo/ícono mientras haya guardianes vivos —
## se recalcula (o se apaga del todo) cada vez que cambia la cantidad, así
## que nunca hace falta que este número realista importe de verdad.
const _DURACION_EFECTO_PERMANENTE := 999999.0
## Tope de resistencia real (60%, ver comentario de clase) — reportado en
## juego real (19 sep 2026): si por solapar dos puestas seguidas quedaban
## más de 3 guardianas vivas a la vez, el clamp usaba 1.0 (100%) en vez de
## este valor y la Reina llegaba a recibir 0 de daño.
const _REDUCCION_MAXIMA := 0.6

@export_group("Puesta de Huevos")
@export var cantidad_huevos: int = 3
@export var radio_dispersion: float = 60.0
@export var duracion_descanso: float = 10.0
@export var porcentaje_vulnerabilidad: float = 0.2
@export var reduccion_por_guardian: float = 0.2
@export var escena_huevo: PackedScene = preload("res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn")
@export var escena_guardian: PackedScene = preload("res://escenas/enemigos/EnemigoHormigaSoldado.tscn")
@export var icono_escudo: Texture2D = preload(_TEXTURA_ICONOS)

var _huevos_activos: Array = []
var _guardianes_vivos: Array = []


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Puesta de Huevos"
	tipo_habilidad   = "puesta_huevos"
	requiere_direccion = false
	# Ícono de escudo (Rect2(32,160,32,32) del mismo atlas que ya usa
	# HabilidadEscudo — mismo lenguaje visual: "esto da resistencia").
	var atlas := AtlasTexture.new()
	atlas.atlas = icono_escudo
	atlas.region = Rect2(32, 160, 32, 32)
	icono_escudo = atlas


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	_reproducir_sonido()
	if not is_instance_valid(entidad_dueña):
		return
	if Utils.en_red() and not multiplayer.is_server():
		return

	var origen := entidad_dueña as Node2D
	var contenedor := entidad_dueña.get_parent()
	if origen == null or contenedor == null:
		return

	_activar_vulnerabilidad()

	_huevos_activos.clear()
	for i in cantidad_huevos:
		var huevo := escena_huevo.instantiate()
		contenedor.add_child(huevo, true)
		huevo.global_position = origen.global_position \
			+ Vector2(randf_range(-radio_dispersion, radio_dispersion),
				randf_range(-radio_dispersion, radio_dispersion))
		_huevos_activos.append(huevo)

	# Mismo "respiro" telegrafiado que las transiciones de fase (ver
	# Enemigo._telegrafiar_pausa_de_fase): congela BT+movimiento+animación,
	# espera duracion_descanso, y si sigue viva reactiva todo antes de
	# llamar al callback — evita duplicar esa lógica acá.
	if entidad_dueña.has_method("_telegrafiar_pausa_de_fase"):
		entidad_dueña.call("_telegrafiar_pausa_de_fase", duracion_descanso, _al_terminar_descanso)


func _activar_vulnerabilidad() -> void:
	var vulnerabilidad := entidad_dueña.get_node_or_null("VulnerabilidadComponente") as VulnerabilidadComponente
	if vulnerabilidad == null:
		vulnerabilidad = VulnerabilidadComponente.new()
		vulnerabilidad.name = "VulnerabilidadComponente"
		entidad_dueña.add_child(vulnerabilidad)
	vulnerabilidad.activar(duracion_descanso, porcentaje_vulnerabilidad)


func _al_terminar_descanso() -> void:
	var contenedor := entidad_dueña.get_parent() if is_instance_valid(entidad_dueña) else null
	for huevo in _huevos_activos:
		if is_instance_valid(huevo) and not huevo.esta_muerto():
			_eclosionar(huevo, contenedor)
	_huevos_activos.clear()


func _eclosionar(huevo: Node2D, contenedor: Node) -> void:
	var pos := huevo.global_position
	huevo.queue_free()
	if contenedor == null:
		return
	var guardian := escena_guardian.instantiate()
	contenedor.add_child(guardian, true)
	guardian.global_position = pos
	_guardianes_vivos.append(guardian)
	var vida := guardian.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.muerte.connect(_al_morir_guardian.bind(guardian), CONNECT_ONE_SHOT)
	_recalcular_resistencia()
	_difundir_guardianes()


func _al_morir_guardian(_valor: float, guardian: Node) -> void:
	_guardianes_vivos.erase(guardian)
	_recalcular_resistencia()
	_difundir_guardianes()


## SERVIDOR: la resistencia REAL de la Reina — EscudoComponente es lo único
## que consulta VidaComponente.quitar_vida() de verdad. También deja el
## ícono puesto localmente (para un solo jugador, o para quien mire la
## pantalla del propio servidor) — los DEMÁS peers lo reciben por
## _actualizar_guardianes_red, ver _difundir_guardianes().
func _recalcular_resistencia() -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_guardianes_vivos = _guardianes_vivos.filter(func(g): return is_instance_valid(g))
	var escudo := entidad_dueña.get_node_or_null("EscudoComponente") as EscudoComponente
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if _guardianes_vivos.is_empty():
		if escudo:
			escudo.activar(0.0, 0.0)
		if buffs:
			buffs.quitar("resistencia_colonia")
		return
	if escudo == null:
		escudo = EscudoComponente.new()
		escudo.name = "EscudoComponente"
		entidad_dueña.add_child(escudo)
	var reduccion := clampf(reduccion_por_guardian * _guardianes_vivos.size(), 0.0, _REDUCCION_MAXIMA)
	escudo.activar(_DURACION_EFECTO_PERMANENTE, reduccion)
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		entidad_dueña.add_child(buffs)
	buffs.agregar("resistencia_colonia", icono_escudo, _DURACION_EFECTO_PERMANENTE, false,
		"Resistencia de la Colonia", "Reduce el daño recibido en %d%%" % int(reduccion * 100))


func _anotar_icono_guardian(guardian: Node) -> void:
	if not is_instance_valid(guardian):
		return
	var buffs := guardian.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		guardian.add_child(buffs)
	buffs.agregar("guardian_reina", icono_escudo, _DURACION_EFECTO_PERMANENTE, false,
		"Guardiana de la Reina", "Le da resistencia a la Reina mientras siga viva")


func _difundir_guardianes() -> void:
	for g in _guardianes_vivos:
		_anotar_icono_guardian(g)
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var origen := entidad_dueña as Node2D
	if origen == null:
		return
	var rutas: Array[NodePath] = []
	for g in _guardianes_vivos:
		if is_instance_valid(g):
			rutas.append(g.get_path())
	for peer_id in InteresEspacial.peers_cercanos(origen.global_position):
		rpc_id(peer_id, "_actualizar_guardianes_red", rutas)


## CLIENTE: mismo resultado ya decidido por el servidor (ver arriba), solo
## ícono — la resistencia REAL vive en el EscudoComponente del servidor.
@rpc("authority", "reliable")
func _actualizar_guardianes_red(rutas: Array[NodePath]) -> void:
	for ruta in rutas:
		_anotar_icono_guardian(get_node_or_null(ruta))
	if not is_instance_valid(entidad_dueña):
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if rutas.is_empty():
		if buffs:
			buffs.quitar("resistencia_colonia")
		return
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		entidad_dueña.add_child(buffs)
	var reduccion := clampf(reduccion_por_guardian * rutas.size(), 0.0, _REDUCCION_MAXIMA)
	buffs.agregar("resistencia_colonia", icono_escudo, _DURACION_EFECTO_PERMANENTE, false,
		"Resistencia de la Colonia", "Reduce el daño recibido en %d%%" % int(reduccion * 100))
