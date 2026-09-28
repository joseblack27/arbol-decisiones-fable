extends Enemigo
class_name EnemigoJefe
## Base de los jefes con fases (Araña Reina, Guardián Quebrado, Corazón de
## Cristal, Núcleo de la Forja, Heraldo de la Corrupción, Reina de las
## Hormigas). Al cruzar cada umbral de vida el jefe pasa a la fase siguiente:
## golpe de transición (si tiene el nodo), queda quieto e invulnerable durante
## pausa_cambio_fase (Enemigo._telegrafiar_pausa_de_fase) y al reanudar suma lo
## que la subclase declare en _reanudar_fase(fase).
##
## Corre en TODOS los peers: cambio_valor_vida se emite igual en el servidor y
## en la réplica del cliente (ver VidaComponente._recibir_vida_red), así el
## respiro se ve igual en todas las pantallas. Sumar habilidades en un cliente
## no tiene efecto (la IA solo corre en el servidor); lo que crea nodos
## (_invocar_refuerzos) corta en el cliente.
##
## Las subclases heredan por ruta (extends "res://.../EnemigoJefe.gd") y no por
## class_name, para no depender del caché de clases que actualiza el editor
## (las pruebas headless corren sin él).

const RUTA_SELECTOR_ATAQUE := "ArbolComportamiento/Selector/Atacar/SelectorHabilidades"
const _RUTA_GOLPE_TRANSICION := "Habilidades/HabilidadGolpeVerdaderoTransicion"
const _DURACION_ETIQUETA_HABILIDAD := 3.0

@export_group("Fases")
## Segundos que el jefe queda quieto al cruzar de fase: el "respiro"
## telegrafiado para reaccionar.
@export var pausa_cambio_fase: float = 1.3
## Daño del golpe de transición (Habilidades/HabilidadGolpeVerdaderoTransicion:
## no de área, ignora defensa) que marca cada cruce de fase. Sin ese nodo, no
## hay golpe.
@export var dano_golpe_transicion: float = 40.0
## Cuántas veces más rápido recarga TODAS sus habilidades con la furia final
## (ver _activar_furia_final), por el resto del combate.
@export var multiplicador_furia_final: float = 1.4

## Fracción de la vida máxima que dispara cada cambio de fase, de mayor a
## menor: el primero pasa a la fase 2, el segundo a la 3... Las subclases con
## otros umbrales los fijan en _init().
var umbrales_fase: Array[float] = [0.75, 0.50, 0.25]
## Si el cruce de fase lo deja invulnerable durante la pausa.
var invulnerable_en_cambio_de_fase := true

var _fase: int = 1
var _furia_activada := false

## Ayuda visual de balanceo: muestra sobre el jefe qué habilidad acaba de
## lanzar (EtiquetaHabilidad en el .tscn; sin ese nodo no se usa).
@onready var _etiqueta_habilidad: Label = get_node_or_null("EtiquetaHabilidad")
var _tiempo_restante_etiqueta: float = 0.0
## Label REAL puesto en la escena (NombreJefe en el .tscn), no dibujado por
## código como el de los mobs, para poder acomodarlo en el editor.
## mostrar_nombre=false en el .tscn apaga el de la base; el texto se llena acá
## desde "datos" para que no se desincronice con el .tres.
@onready var _nombre_jefe: Label = get_node_or_null("NombreJefe")


func _ready() -> void:
	super._ready()
	# Enemigo._ready() ya conectó cambio_valor_vida a _on_vida_cambiada, que
	# acá se reemplaza por el cambio de fase (sin super): la memoria "vida"
	# del árbol no se actualiza en los jefes, así nunca entran en vida_baja.
	if componente_vida and not componente_vida.cambio_valor_vida.is_connected(_on_vida_cambiada):
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
	_conectar_embestida()
	_conectar_etiqueta_habilidad()
	if _nombre_jefe and datos:
		_nombre_jefe.text = ("Nv.%d %s" % [datos.nivel, datos.nombre_tipo]) if datos.nivel > 0 else datos.nombre_tipo
	# HabilidadGolpeVerdaderoTransicion no tiene override de "daño" en el
	# .tscn: sin esto pegaría el default del script (20) y no
	# dano_golpe_transicion.
	var golpe_transicion := get_node_or_null(_RUTA_GOLPE_TRANSICION)
	if golpe_transicion:
		golpe_transicion.daño = dano_golpe_transicion


func _process(delta: float) -> void:
	super._process(delta)
	if _tiempo_restante_etiqueta <= 0.0:
		return
	_tiempo_restante_etiqueta -= delta
	if _tiempo_restante_etiqueta <= 0.0 and _etiqueta_habilidad:
		_etiqueta_habilidad.visible = false


# ── Fases ─────────────────────────────────────────────────────────────────────

func _on_vida_cambiada(valor: float) -> void:
	if _muerto or not componente_vida:
		return
	var maxima := componente_vida.obtener_vida_maxima()
	if maxima <= 0.0 or _fase > umbrales_fase.size():
		return
	if valor / maxima <= umbrales_fase[_fase - 1]:
		_entrar_fase(_fase + 1)


func _entrar_fase(nueva: int) -> void:
	_fase = nueva
	_golpear_transicion()
	if invulnerable_en_cambio_de_fase and componente_vida:
		componente_vida.activar_invulnerabilidad(pausa_cambio_fase)
	_telegrafiar_pausa_de_fase(pausa_cambio_fase, _reanudar_fase.bind(nueva))


## Lo que suma cada fase al reanudar (habilidades, refuerzos, furia). Lo
## implementa cada jefe.
func _reanudar_fase(_fase_nueva: int) -> void:
	pass


## Golpe grande NO de área que marca el cruce de fase, hacia el objetivo
## actual (o hacia donde mira, si no tiene).
func _golpear_transicion() -> void:
	var golpe := get_node_or_null(_RUTA_GOLPE_TRANSICION)
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


## Suma "bt" al SelectorHabilidades de "ruta_selector" si no lo tiene. Los
## NODOS de las habilidades ya están en la escena desde el inicio; lo que crece
## por fase es lo que el selector tiene para elegir.
func _agregar_habilidad_bt(ruta_selector: String, bt: HabilidadBT) -> void:
	if bt == null:
		return
	var selector := get_node_or_null(ruta_selector)
	if selector and not selector.habilidades.has(bt):
		selector.habilidades.append(bt)


## Atajo para el selector de ataque principal.
func _agregar_habilidades_ataque(bts: Array) -> void:
	for bt in bts:
		_agregar_habilidad_bt(RUTA_SELECTOR_ATAQUE, bt)


## Recarga TODAS sus habilidades multiplicador_furia_final veces más rápido,
## por el resto del combate (mismo mecanismo que HabilidadFervor:
## multiplicador_recarga de HabilidadBase). Corre en todos los peers, sin efecto
## real en un cliente, donde no piensa.
func _activar_furia_final() -> void:
	_furia_activada = true
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo is HabilidadBase:
			hijo.multiplicador_recarga = multiplicador_furia_final


## SERVIDOR: instancia mobs reales como refuerzos en el mismo contenedor
## "Enemigos" del jefe, así ReplicadorEnemigos los replica como a cualquier mob.
## En un cliente no hace nada: _reanudar_fase corre en todos los peers, y la
## réplica crearía refuerzos propios sin IA además de los reales. Devuelve los
## mobs creados.
func _invocar_refuerzos(escenas: Array[PackedScene]) -> Array[Node]:
	var creados: Array[Node] = []
	if Utils.en_red() and not multiplayer.is_server():
		return creados
	var contenedor := get_parent()
	if contenedor == null:
		return creados
	for escena in escenas:
		if escena == null:
			continue
		var mob := escena.instantiate()
		contenedor.add_child(mob, true)
		if mob is Node2D:
			(mob as Node2D).global_position = global_position \
				+ Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		creados.append(mob)
	return creados


# ── Embestida ─────────────────────────────────────────────────────────────────

## Ruta de su habilidad de embestida (derivada de HabilidadCarga), o "" si no
## tiene. HabilidadCarga no toca el AnimationTree: eso lo hace SIEMPRE el mob
## dueño conectado a sus señales (como EnemigoLobo). Sin esa conexión,
## memoria["ataque_en_curso"] quedaría en true tras la primera embestida y
## AccionAtacar dejaría al jefe congelado.
func _ruta_embestida() -> String:
	return ""


func _conectar_embestida() -> void:
	var ruta := _ruta_embestida()
	var embestida := get_node_or_null(ruta) if ruta != "" else null
	if embestida == null:
		return
	embestida.preparacion_iniciada.connect(_on_embestida_preparacion)
	embestida.carga_iniciada.connect(_on_embestida_iniciada)
	embestida.carga_terminada.connect(_on_embestida_terminada)


## Por defecto, la pose CARGANDO durante la preparación y el dash.
func _on_embestida_preparacion() -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCargando", true)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		componente_animacion.viajar_a_estado("CARGANDO")


func _on_embestida_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	pass


func _on_embestida_terminada() -> void:
	if memoria:
		memoria.establecer("ataque_en_curso", false)
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCargando", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)


# ── Cartel de habilidad ───────────────────────────────────────────────────────

## Conecta habilidad_activada de CADA hijo de "Habilidades", así una habilidad
## nueva queda cubierta sola. Solo si el jefe tiene EtiquetaHabilidad: si no, no
## vale la pena mandar un aviso de red por cada habilidad.
func _conectar_etiqueta_habilidad() -> void:
	if _etiqueta_habilidad == null:
		return
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo.has_signal("habilidad_activada"):
			hijo.habilidad_activada.connect(_on_habilidad_activada_para_etiqueta)


## habilidad_activada solo se emite DENTRO de activar() (ver HabilidadBase), que
## en red corre SOLO en el servidor: los clientes solo ven la réplica visual,
## que no pasa por activar(). Por eso el servidor les avisa a los peers
## cercanos.
func _on_habilidad_activada_para_etiqueta(habilidad: HabilidadBase) -> void:
	_mostrar_etiqueta_habilidad(habilidad.nombre_habilidad)
	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_cercanos(global_position):
			rpc_id(peer_id, "_mostrar_etiqueta_habilidad_red", habilidad.nombre_habilidad)


## Si ya había una etiqueta a la vista, el texto se reemplaza y el contador de
## 3 s arranca de nuevo.
func _mostrar_etiqueta_habilidad(nombre: String) -> void:
	if _etiqueta_habilidad == null:
		return
	_etiqueta_habilidad.text = nombre
	_etiqueta_habilidad.visible = true
	_tiempo_restante_etiqueta = _DURACION_ETIQUETA_HABILIDAD


@rpc("authority", "reliable")
func _mostrar_etiqueta_habilidad_red(nombre: String) -> void:
	_mostrar_etiqueta_habilidad(nombre)
