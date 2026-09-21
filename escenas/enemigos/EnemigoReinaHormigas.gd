extends Enemigo
class_name EnemigoReinaHormigas
## Reina de las Hormigas — jefa final del Hormiguero (ver el plan
## "Hormiguero" en C:\Users\USER\.claude\plans\cheeky-mixing-melody.md).
## Mirror del esqueleto de fases de EnemigoHeraldoCorrupcion.gd/
## EnemigoNucleoForja.gd/EnemigoCorazonCristal.gd (umbrales 0.75/0.50/0.25,
## golpe de transición telegrafiado, SelectorHabilidades que crece por fase
## en vez de reconstruirse, furia final) — solo cambian los nombres de
## campos/habilidades por el tema de la colonia. Kit propio, en vez de
## reusar el de un jefe existente (a diferencia de Corrupción, que sí reusa
## tal cual el kit de EnemigoGuardianQuebrado): Mordida (golpe básico) +
## Pisotón Sísmico (área telegrafiada centrada en ella, castiga quedarse en
## melee) desde el arranque; Escupitajo Ácido (área) + Marca de la Colonia
## (marca a un jugador al azar cercano, detona sobre él y quien esté al
## lado, ver HabilidadMarcaColonia.gd) en fase 2; Llamada de Auxilio (firma
## propia, ver HabilidadLlamadaAuxilio.gd) + Puesta de Huevos (huevos que,
## si sobreviven, eclosionan en hormigas guardianas que le dan resistencia
## mientras vivan, ver HabilidadPuestaHuevos.gd) en fase 3; Embestida
## (carga, hereda la animación MORDIDA_PREPARACION/MORDIDA_DASH ya armada
## en el esqueleto de Lobo Feroz del que se reskineó esta escena — el
## nombre de esos estados es herencia del lobo, no tiene relación con la
## habilidad "Mordida") + refuerzos + furia en fase 4.

const _UMBRAL_FASE_2 := 0.75
const _UMBRAL_FASE_3 := 0.50
const _UMBRAL_FASE_4 := 0.25

@export_group("Fases")
@export var pausa_cambio_fase: float = 1.3
@export var dano_golpe_transicion: float = 45.0

@export_group("Fase 2 - Ácido de la Colonia")
@export var habilidad_escupitajo_bt: HabilidadBT
@export var habilidad_marca_colonia_bt: HabilidadBT

@export_group("Fase 3 - Instinto de Enjambre")
@export var habilidad_llamada_auxilio_bt: HabilidadBT
@export var habilidad_puesta_huevos_bt: HabilidadBT

@export_group("Fase 4 - Furia de la Reina")
@export var habilidad_embestida_bt: HabilidadBT
@export var multiplicador_furia_final: float = 1.4

## Pedido explícito del usuario (20 sep 2026): "quiero que cuando la
## reina detecte un jugador, el area de detección se doble, para que sea
## un poco mas dificil perder al jugador" -- probando el Hormiguero de
## punta a punta, la Reina perdía el agro seguido (alejarse un poco del
## radio de VisionComponente, ver ese script, ya alcanza para que
## objetivo_perdido se dispare). Mientras tenga a alguien detectado, su
## radio de visión se duplica; en cuanto se queda sin nadie detectado,
## vuelve al radio original -- ver _ajustar_radio_deteccion().
const MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO := 2.0
var _radio_deteccion_base: float = 0.0

var _fase: int = 1
var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoHormigaObrera.tscn"),
	preload("res://escenas/enemigos/EnemigoHormigaObrera.tscn"),
	preload("res://escenas/enemigos/EnemigoHormigaSoldado.tscn"),
]

const _DURACION_ETIQUETA_HABILIDAD := 3.0
@onready var _etiqueta_habilidad: Label = get_node_or_null("EtiquetaHabilidad")
var _tiempo_restante_etiqueta: float = 0.0
@onready var _nombre_jefe: Label = get_node_or_null("NombreJefe")


func _ready() -> void:
	super._ready()
	if componente_vida and not componente_vida.cambio_valor_vida.is_connected(_on_vida_cambiada):
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
	_conectar_embestida()
	_conectar_etiqueta_habilidad()
	if _nombre_jefe and datos:
		_nombre_jefe.text = ("Nv.%d %s" % [datos.nivel, datos.nombre_tipo]) if datos.nivel > 0 else datos.nombre_tipo
	var golpe_transicion := get_node_or_null("Habilidades/HabilidadGolpeVerdaderoTransicion")
	if golpe_transicion:
		golpe_transicion.daño = dano_golpe_transicion
	_preparar_radio_deteccion()
	# TEMPORAL (21 sep 2026) -- pedido explícito para poder probar Puesta de
	# Huevos sin tener que bajarle la vida a la Reina hasta fase 3 primero.
	# Normalmente esta habilidad recién se agrega en _reanudar_fase(3). NO
	# hace falta tocar ese caso 3: _agregar_habilidad_bt() ya es un no-op si
	# el BT ya la tiene (evita duplicados cuando la fase 3 llegue de verdad).
	# RECORDAR SACAR ESTA LÍNEA cuando termine el diagnóstico -- el usuario
	# pidió que se lo recuerde.
	_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_puesta_huevos_bt)


## Duplica la forma ANTES de guardar el radio base -- es un sub_resource
## compartido en la escena empaquetada (CircleShape2D_itdr7), así que
## tocar .radius directo sin duplicar afectaría a CUALQUIER OTRA Reina
## que llegue a existir a la vez (ej. dos niveles de Hormiguero cargados
## juntos en una prueba) -- mismo criterio que otros duplicate() de forma
## en este proyecto (ver HabilidadParpadeo._forma_colision_de).
func _preparar_radio_deteccion() -> void:
	var forma := _forma_deteccion()
	if forma == null:
		return
	var col := componente_vision.get_node("CollisionShape2D") as CollisionShape2D
	col.shape = forma.duplicate()
	_radio_deteccion_base = (col.shape as CircleShape2D).radius


func _forma_deteccion() -> CircleShape2D:
	if componente_vision == null:
		return null
	var col := componente_vision.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is CircleShape2D):
		return null
	return col.shape as CircleShape2D


## Mientras siga habiendo AL MENOS un jugador detectado, radio doble; en
## cuanto se queda sin ninguno, vuelve al radio original -- ver el
## comentario grande de MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO.
func _ajustar_radio_deteccion(con_objetivo: bool) -> void:
	if _radio_deteccion_base <= 0.0:
		return
	var forma := _forma_deteccion()
	if forma == null:
		return
	forma.radius = _radio_deteccion_base * MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO if con_objetivo \
		else _radio_deteccion_base


func _on_objetivo_detectado(area: Area2D) -> void:
	var ya_tenia: bool = memoria.obtener("jugador_detectado", false) if memoria else false
	super._on_objetivo_detectado(area)
	if not ya_tenia:
		_ajustar_radio_deteccion(true)


func _on_objetivo_perdido(area: Area2D) -> void:
	super._on_objetivo_perdido(area)
	var sigue_detectando: bool = memoria.obtener("jugador_detectado", false) if memoria else false
	if not sigue_detectando:
		_ajustar_radio_deteccion(false)


func _process(delta: float) -> void:
	super._process(delta)
	if _tiempo_restante_etiqueta <= 0.0:
		return
	_tiempo_restante_etiqueta -= delta
	if _tiempo_restante_etiqueta <= 0.0 and _etiqueta_habilidad:
		_etiqueta_habilidad.visible = false


func _conectar_etiqueta_habilidad() -> void:
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo.has_signal("habilidad_activada"):
			hijo.habilidad_activada.connect(_on_habilidad_activada_para_etiqueta)


func _on_habilidad_activada_para_etiqueta(habilidad: HabilidadBase) -> void:
	_mostrar_etiqueta_habilidad_red(habilidad.nombre_habilidad)
	if Utils.en_red() and multiplayer.is_server():
		var peers := InteresEspacial.peers_cercanos(global_position)
		# DIAGNÓSTICO TEMPORAL (21 sep 2026) -- el usuario reporta que el
		# cartel de nombre de habilidad no aparece SOLO para Puesta de
		# Huevos (ver [DIAG huevos] en HabilidadPuestaHuevos.gd, mismo
		# día). Confirmar que el despacho del RPC ocurre igual para esta
		# habilidad que para las demás -- sacar cuando se resuelva.
		print("[DIAG etiqueta servidor] habilidad=%s peers=%s" % [habilidad.tipo_habilidad, peers])
		for peer_id in peers:
			rpc_id(peer_id, "_mostrar_etiqueta_habilidad_red", habilidad.nombre_habilidad)


@rpc("authority", "reliable")
func _mostrar_etiqueta_habilidad_red(nombre: String) -> void:
	# DIAGNÓSTICO TEMPORAL (21 sep 2026) -- confirmar si este RPC LLEGA al
	# cliente y si _etiqueta_habilidad está resuelta cuando llega -- ver
	# comentario en _on_habilidad_activada_para_etiqueta. Sacar cuando se
	# resuelva.
	if Utils.en_red() and not multiplayer.is_server():
		print("[DIAG etiqueta cliente] RPC recibido nombre=%s etiqueta_nula=%s" % [nombre, _etiqueta_habilidad == null])
	if _etiqueta_habilidad == null:
		return
	_etiqueta_habilidad.text = nombre
	_etiqueta_habilidad.visible = true
	_tiempo_restante_etiqueta = _DURACION_ETIQUETA_HABILIDAD


## Misma animación MORDIDA_PREPARACION/MORDIDA_DASH que ya trae armada el
## esqueleto de Lobo Feroz del que se reskineó esta escena (ver
## EnemigoLobo._on_carga_preparacion/_on_carga_iniciada/_on_carga_terminada,
## copiado acá literal porque EnemigoReinaHormigas no hereda de EnemigoLobo).
func _conectar_embestida() -> void:
	var embestida := get_node_or_null("Habilidades/HabilidadEmbestidaReina")
	if embestida == null:
		return
	embestida.preparacion_iniciada.connect(_on_embestida_preparacion)
	embestida.carga_iniciada.connect(_on_embestida_iniciada)
	embestida.carga_terminada.connect(_on_embestida_terminada)


func _on_embestida_preparacion() -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", true)
		componente_animacion.viajar_a_estado("MORDIDA_PREPARACION")


func _on_embestida_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", true)
		componente_animacion.viajar_a_estado("MORDIDA_DASH")


func _on_embestida_terminada() -> void:
	if memoria:
		memoria.establecer("ataque_en_curso", false)
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeSalirMordida", true)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)


func _on_vida_cambiada(valor: float) -> void:
	if _muerto or not componente_vida:
		return
	var maxima := componente_vida.obtener_vida_maxima()
	if maxima <= 0.0:
		return
	var fraccion := valor / maxima
	if _fase == 1 and fraccion <= _UMBRAL_FASE_2:
		_entrar_fase(2)
	elif _fase == 2 and fraccion <= _UMBRAL_FASE_3:
		_entrar_fase(3)
	elif _fase == 3 and fraccion <= _UMBRAL_FASE_4:
		_entrar_fase(4)


func _entrar_fase(nueva: int) -> void:
	_fase = nueva
	_golpear_transicion()
	if componente_vida:
		componente_vida.activar_invulnerabilidad(pausa_cambio_fase)
	_telegrafiar_pausa_de_fase(pausa_cambio_fase, _reanudar_fase.bind(nueva))


func _golpear_transicion() -> void:
	var golpe := get_node_or_null("Habilidades/HabilidadGolpeVerdaderoTransicion")
	if golpe == null or not golpe.has_method("activar"):
		return
	var dir := direccion_mirada if direccion_mirada != Vector2.ZERO else Vector2.RIGHT
	if memoria:
		var objetivo_raw = memoria.obtener("objetivo")
		if is_instance_valid(objetivo_raw) and objetivo_raw is Node2D:
			var hacia := (objetivo_raw as Node2D).global_position - global_position
			if hacia.length() > 0.1:
				dir = hacia.normalized()
	golpe.activar(dir, 1.0)


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_escupitajo_bt)
			_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_marca_colonia_bt)
		3:
			_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_llamada_auxilio_bt)
			_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_puesta_huevos_bt)
		4:
			_agregar_habilidad_bt("ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_embestida_bt)
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()


func _agregar_habilidad_bt(ruta_selector: String, bt: HabilidadBT) -> void:
	if bt == null:
		return
	var selector := get_node_or_null(ruta_selector)
	if selector and not selector.habilidades.has(bt):
		selector.habilidades.append(bt)


func _activar_furia_final() -> void:
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo is HabilidadBase:
			hijo.multiplicador_recarga = multiplicador_furia_final


## Escenas que ESTA jefa puede llegar a crear en tiempo de ejecución, para
## que el nivel las registre en el spawner compartido (ver NivelBase.
## _crear_spawner_red) — mismo mecanismo que SpawnerMobs.escenas_
## replicables(). EnemigoHormigaSoldado.tscn ya suele quedar registrada
## sola (la usan los SpawnerMobs normales del Hormiguero para poblar
## salas), pero declararla acá también es gratis e inofensivo — sin esto,
## si algún día el Hormiguero deja de tener un SpawnerMobs de Soldado en
## alguna sala, tanto los refuerzos de fase 4 como las guardianas de
## HabilidadPuestaHuevos dejarían de verse en los clientes sin ningún
## error visible (el MultiplayerSpawner rechaza en silencio una escena no
## registrada). HuevoHormiga.tscn en cambio SÍ es nueva y no la crea
## ningún otro nodo del nivel.
func escenas_replicables() -> Array[String]:
	return [
		"res://escenas/enemigos/EnemigoHormigaObrera.tscn",
		"res://escenas/enemigos/EnemigoHormigaSoldado.tscn",
		"res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn",
	]


func _invocar_refuerzos(escenas: Array[PackedScene]) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		return
	var contenedor := get_parent()
	if contenedor == null:
		return
	for escena in escenas:
		if escena == null:
			continue
		var mob := escena.instantiate()
		contenedor.add_child(mob, true)
		if mob is Node2D:
			(mob as Node2D).global_position = global_position \
				+ Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
