extends Enemigo
class_name EnemigoGuardianQuebrado
## Jefe de 4 fases pensado para poner a prueba la habilidad "Corte" del
## jugador (parry direccional de área, corta ataques, daño verdadero, se lanza
## aturdido) sin que sea un botón de "gano automático". Máquina de fases
## calcada de EnemigoArañaReina.gd (mismo _telegrafiar_pausa_de_fase de
## Enemigo, habilidades que se suman al SelectorHabilidades por fase),
## extendida a un tercer umbral:
##   Fase 1 "Guardia": combo, barrido, amague.
##   Fase 2 "Cazador": lluvia de lanzas, francotirador, charco en golpes de área.
##   Fase 3 "Corrupción": golpe corrupto, muro, escudo reflectante, castigo por
##     cooldown de Corte.
##   Fase 4 "Quiebre": arremetida de daño verdadero, miedo/empujón, refuerzos.
## Cada fase tiene su prueba (pruebas/prueba_guardian_*.gd), y
## prueba_guardian_4_fases_completas.gd las recorre de punta a punta.

## Umbrales de vida (fracción de la máxima) que disparan cada transición.
const _UMBRAL_FASE_2 := 0.75
const _UMBRAL_FASE_3 := 0.50
const _UMBRAL_FASE_4 := 0.25

@export_group("Fases")
## Segundos que el jefe queda quieto/indefenso al cruzar de fase — mismo
## criterio que EnemigoArañaReina/EnemigoJefeEsqueleto.
@export var pausa_cambio_fase: float = 1.3
## Daño del golpe de transición (no-área, ignora_defensa=true) que marca
## cada cruce de fase — ver _entrar_fase().
@export var dano_golpe_transicion: float = 40.0

@export_group("Fase 2 - Cazador")
## Los NODOS (Habilidades/HabilidadLluviaLanzasGuardian, .../
## HabilidadFrancotiradorGuardian) ya están en la escena desde el inicio —
## esto es el recurso HabilidadBT que hay que sumar al SelectorHabilidades
## al entrar la fase, mismo criterio que EnemigoArañaReina.
@export var habilidad_lluvia_lanzas_bt: HabilidadBT
@export var habilidad_francotirador_bt: HabilidadBT

@export_group("Fase 3 - Corrupción")
@export var habilidad_golpe_corrupto_bt: HabilidadBT
@export var habilidad_muro_bt: HabilidadBT
@export var habilidad_escudo_reflectante_bt: HabilidadBT
## La rama "CastigoCorte" (ArbolComportamiento/Selector/CastigoCorte) está
## presente en el árbol DESDE EL INICIO, igual que CastigoIndefenso en
## EnemigoArañaReina — pero su SelectorHabilidades empieza vacío, así que
## _on_ejecutar() siempre da FALLIDO y cae a "Atacar" como si no existiera,
## hasta que esto se agrega recién en fase 3. Mismo patrón que las demás
## habilidades por fase: la estructura del árbol no cambia, solo lo que
## SelectorHabilidades tiene para elegir.
@export var habilidad_castigo_bt: HabilidadBT

@export_group("Fase 4 - Quiebre")
@export var habilidad_arremetida_bt: HabilidadBT
@export var habilidad_miedo_bt: HabilidadBT
## Recarga sus habilidades esto veces más rápido al entrar en Quiebre (mismo
## mecanismo que EnemigoArañaReina._activar_furia_final: multiplicador_recarga
## de HabilidadBase), por el resto del combate. Sin esto, el ritmo de ataque
## no cambiaba entre la fase 1 y la 4, más allá de las habilidades nuevas.
@export var multiplicador_furia_final: float = 1.4

var _fase: int = 1
## Mismo criterio que EnemigoArañaReina._refuerzos_fase3: PackedScene
## precargadas, instanciadas SOLO en servidor al entrar la fase.
var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]

## Ayuda visual de balanceo: muestra sobre el jefe qué habilidad acaba de
## lanzar (ver EtiquetaHabilidad en el .tscn). Se engancha a
## habilidad_activada, que solo se emite en quien decide el lanzamiento (el
## servidor); a los clientes llega por _mostrar_etiqueta_habilidad_red.
const _DURACION_ETIQUETA_HABILIDAD := 3.0
@onready var _etiqueta_habilidad: Label = get_node_or_null("EtiquetaHabilidad")
var _tiempo_restante_etiqueta: float = 0.0

## Label REAL puesto en la escena (NombreJefe en el .tscn), no dibujado por
## código como el de los mobs (Enemigo._dibujar_nombre_mob), para poder
## acomodarlo en el editor. mostrar_nombre=false en el .tscn apaga el de la
## base; el texto se llena acá desde "datos" para que no se desincronice si
## cambia GuardianQuebrado.tres.
@onready var _nombre_jefe: Label = get_node_or_null("NombreJefe")


func _ready() -> void:
	super._ready()
	if componente_vida and not componente_vida.cambio_valor_vida.is_connected(_on_vida_cambiada):
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
	_conectar_arremetida()
	_conectar_etiqueta_habilidad()
	if _nombre_jefe and datos:
		_nombre_jefe.text = ("Nv.%d %s" % [datos.nivel, datos.nombre_tipo]) if datos.nivel > 0 else datos.nombre_tipo
	# HabilidadLluviaLanzasGuardian.tscn es una instancia PELADA de
	# HabilidadProyectilAbanico.gd (sin script propio, ver ese .tscn) — su
	# propio _ready() pisa nombre_habilidad con el genérico "Proyectil en
	# abanico" DESPUÉS de cualquier valor que se le ponga como override en
	# el .tscn, así que la única forma de que la etiqueta muestre un nombre
	# propio es fijarlo ACÁ, en el _ready() del jefe — que corre DESPUÉS del
	# de todos sus hijos (Godot llama _ready() de abajo hacia arriba).
	var lluvia_lanzas := get_node_or_null("Habilidades/HabilidadLluviaLanzasGuardian")
	if lluvia_lanzas:
		lluvia_lanzas.nombre_habilidad = "Lluvia de Lanzas"
	# HabilidadGolpeVerdaderoTransicion no tiene override de "daño" en el
	# .tscn: sin esto pegaría el default del script (20) y no
	# dano_golpe_transicion.
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


## Conecta habilidad_activada de CADA hijo de "Habilidades" — cubre las 10+
## habilidades del jefe sin tener que tocar cada una a mano si se agrega
## una nueva más adelante.
func _conectar_etiqueta_habilidad() -> void:
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo.has_signal("habilidad_activada"):
			hijo.habilidad_activada.connect(_on_habilidad_activada_para_etiqueta)


## Si ya había una etiqueta a la vista, el texto se reemplaza y el contador de
## 3 s arranca de nuevo.
##
## habilidad_activada solo se emite DENTRO de activar() (ver HabilidadBase),
## que en red corre SOLO en el servidor: los clientes solo ven la réplica
## visual (_reproducir_visual_red, que llama _ejecutar() sin pasar por
## activar()). Sin el rpc_id de abajo, la etiqueta nunca cambiaría en la
## pantalla de un jugador.
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


## HabilidadArremetidaGuardian hereda las 3 señales de HabilidadCarga
## (preparacion_iniciada/carga_iniciada/carga_terminada), y HabilidadCarga no
## toca el AnimationTree: eso lo hace SIEMPRE el mob dueño conectado a esas
## señales (como EnemigoLobo._on_carga_terminada). Sin esta conexión,
## memoria["ataque_en_curso"] (lo pone en true HabilidadCarga._ejecutar())
## quedaba en true para siempre tras la primera embestida, y AccionAtacar
## dejaba al jefe congelado esperando que termine.
func _conectar_arremetida() -> void:
	var arremetida := get_node_or_null("Habilidades/HabilidadArremetidaGuardian")
	if arremetida == null:
		return
	arremetida.preparacion_iniciada.connect(_on_arremetida_preparacion)
	arremetida.carga_iniciada.connect(_on_arremetida_iniciada)
	arremetida.carga_terminada.connect(_on_arremetida_terminada)


func _on_arremetida_preparacion() -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCargando", true)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		componente_animacion.viajar_a_estado("CARGANDO")


func _on_arremetida_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	pass  # Sigue en el mismo estado CARGANDO durante el dash — sin pose propia todavía.


func _on_arremetida_terminada() -> void:
	if memoria:
		memoria.establecer("ataque_en_curso", false)
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCargando", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)


## Corre en TODOS los peers (cambio_valor_vida se emite igual en el servidor
## real y en la réplica del cliente) — a propósito, mismo criterio que
## EnemigoArañaReina._on_vida_cambiada: así todos ven el mismo respiro al
## mismo tiempo. SelectorHabilidades nunca corre en un cliente puro
## (Enemigo._physics_process es server-only), así que ahí el único efecto
## real es la pausa visual.
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


## Golpe grande NO de área (GolpeVerdaderoGuardian) que marca el cruce de
## fase. Usa el mismo nodo que castiga el cooldown de Corte en fase 3
## (HabilidadGolpeVerdaderoTransicion), con ignora_defensa=true para que se
## sienta aun contra un jugador bien defendido.
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
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_lluvia_lanzas_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_francotirador_bt)
			# Los golpes de área ya no se van sin dejar rastro — el piso se
			# va llenando de charcos, empuja a moverse en vez de plantarse.
			var combo := get_node_or_null("Habilidades/HabilidadComboGuardian")
			if combo:
				combo.deja_charco = true
			var barrido := get_node_or_null("Habilidades/HabilidadBarridoGuardian")
			if barrido:
				barrido.deja_charco = true
		3:
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_golpe_corrupto_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_muro_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_escudo_reflectante_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/CastigoCorte/AtacarCastigo/SelectorCastigo", habilidad_castigo_bt)
		4:
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_arremetida_bt)
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/Atacar/SelectorHabilidades", habilidad_miedo_bt)
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()


func _agregar_habilidad_bt(ruta_selector: String, bt: HabilidadBT) -> void:
	if bt == null:
		return
	var selector := get_node_or_null(ruta_selector)
	if selector and not selector.habilidades.has(bt):
		selector.habilidades.append(bt)


## Mismo mecanismo que EnemigoArañaReina._activar_furia_final: recarga
## TODAS las habilidades multiplicador_furia_final veces más rápido,
## permanente por el resto del combate — corre en todos los peers (mismo
## criterio que _on_vida_cambiada, para que el ritmo se vea igual en
## cualquier pantalla), sin efecto real en un cliente puro porque
## SelectorHabilidades/AccionAtacar ya son server-only.
func _activar_furia_final() -> void:
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo is HabilidadBase:
			hijo.multiplicador_recarga = multiplicador_furia_final


## SERVIDOR: instancia mobs reales como refuerzos — copia literal de
## EnemigoArañaReina._invocar_refuerzos() (ver ese archivo para el porqué
## completo: correr esto en TODOS los peers duplicaría refuerzos fantasma
## sin IA real en cada cliente, ya que _on_vida_cambiada dispara la
## transición de fase en todos lados a propósito para que el respiro
## visual se vea igual en todos lados).
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
