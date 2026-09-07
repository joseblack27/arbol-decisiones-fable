extends Enemigo
class_name EnemigoCorazonCristal
## Jefe de 4 fases al fondo de la Mina de Cristal — ver el plan
## "C:\Users\USER\.claude\plans\cheeky-mixing-melody.md". Misma máquina de
## fases que EnemigoGuardianQuebrado.gd/EnemigoArañaReina.gd (mismo
## _telegrafiar_pausa_de_fase heredado de Enemigo, mismo patrón de agregar
## habilidades al SelectorHabilidades en runtime), pero el KIT DE ATAQUES
## reusa habilidades genéricas YA EXISTENTES (Golpe Básico, Arañazo,
## Proyectil, Área de Efecto, Muro, Sacudida, Carga) con nombre/tema de
## cristal en vez de escribir una habilidad bespoke por fase — mismo
## criterio que EnemigoArañaReina ya usa para su propio Arañazo/Sacudida
## (ver Habilidades/HabilidadArañazo, Habilidades/HabilidadVenenoParalizante
## en EnemigoArañaReina.tscn). Nada de esto es nuevo ni improvisado: cada
## pieza ya está probada por los mobs/jefes que la usan hoy.
##
## Fase 1 "Cristalización" (Golpe + Zarpazo, cuerpo a cuerpo).
## Fase 2 "Fractura" (<75%): suma Lluvia de Esquirlas (proyectil a
## distancia) y Erupción de Cristal (área).
## Fase 3 "Resonancia" (<50%): suma Muro de Cristal (bloquea la sala) y
## Pulso de Cristal (aturde en área corta — mismo Sacudida.gd que ya usa
## Araña Reina).
## Fase 4 "Quiebre Final" (<25%): suma Embestida de Cristal (carga de daño
## verdadero, misma HabilidadCarga.gd base que ArremetidaGuardian), invoca
## refuerzos y aplica furia final (recarga más rápida, permanente).

const _UMBRAL_FASE_2 := 0.75
const _UMBRAL_FASE_3 := 0.50
const _UMBRAL_FASE_4 := 0.25

@export_group("Fases")
@export var pausa_cambio_fase: float = 1.3
@export var dano_golpe_transicion: float = 40.0

@export_group("Fase 2 - Fractura")
@export var habilidad_esquirlas_bt: HabilidadBT
@export var habilidad_erupcion_bt: HabilidadBT

@export_group("Fase 3 - Resonancia")
@export var habilidad_muro_bt: HabilidadBT
@export var habilidad_pulso_bt: HabilidadBT

@export_group("Fase 4 - Quiebre Final")
@export var habilidad_embestida_bt: HabilidadBT
@export var multiplicador_furia_final: float = 1.4

var _fase: int = 1
var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]

## Mismo helper de balanceo temporal que EnemigoGuardianQuebrado.gd — ver
## ese archivo para el porqué completo.
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
	# Mismo motivo que EnemigoGuardianQuebrado._ready(): dano_golpe_transicion
	# es un @export de ESTE script, pero el nodo real (HabilidadGolpeVerdaderoTransicion,
	# instancia pelada de HabilidadGolpeVerdaderoGuardian.gd reusada tal
	# cual) tiene su propio "daño" con el default de fábrica — hay que
	# conectarlos a mano acá.
	var golpe_transicion := get_node_or_null("Habilidades/HabilidadGolpeVerdaderoTransicion")
	if golpe_transicion:
		golpe_transicion.daño = dano_golpe_transicion


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
		for peer_id in InteresEspacial.peers_cercanos(global_position):
			rpc_id(peer_id, "_mostrar_etiqueta_habilidad_red", habilidad.nombre_habilidad)


@rpc("authority", "reliable")
func _mostrar_etiqueta_habilidad_red(nombre: String) -> void:
	if _etiqueta_habilidad == null:
		return
	_etiqueta_habilidad.text = nombre
	_etiqueta_habilidad.visible = true
	_tiempo_restante_etiqueta = _DURACION_ETIQUETA_HABILIDAD


## Misma conexión que EnemigoGuardianQuebrado._conectar_arremetida() — ver
## ese archivo para el porqué completo: HabilidadCarga.gd no toca el
## AnimationTree por su cuenta, eso lo hace SIEMPRE el mob dueño.
func _conectar_embestida() -> void:
	var embestida := get_node_or_null("Habilidades/HabilidadEmbestidaCristal")
	if embestida == null:
		return
	embestida.preparacion_iniciada.connect(_on_embestida_preparacion)
	embestida.carga_iniciada.connect(_on_embestida_iniciada)
	embestida.carga_terminada.connect(_on_embestida_terminada)


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
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_esquirlas_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_erupcion_bt)
		3:
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_muro_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_pulso_bt)
		4:
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_embestida_bt)
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
