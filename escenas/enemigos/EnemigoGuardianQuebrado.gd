extends Enemigo
class_name EnemigoGuardianQuebrado
## Jefe de 4 fases pensado explícitamente para poner a prueba la habilidad
## "Corte" del jugador (parry direccional de área, corta ataques enemigos,
## daño verdadero, se lanza aunque esté aturdido) sin que sea un botón de
## "gano automático" — ver el plan de diseño para el detalle completo de
## cada fase. Máquina de fases calcada de EnemigoArañaReina.gd (mismo
## _telegrafiar_pausa_de_fase heredado de Enemigo, mismo patrón de agregar
## habilidades al SelectorHabilidades en runtime), extendida a un tercer
## umbral para las 4 fases.
##
## ESTADO DE ESTA VERSIÓN: las 4 fases tienen contenido real, implementado y
## probado por separado (pruebas/prueba_guardian_*.gd) — Fase 1 "Guardia"
## (combo/barrido/amague), Fase 2 "Cazador" (lluvia de lanzas,
## francotirador, charco en golpes de área), Fase 3 "Corrupción" (golpe
## corrupto, muro, escudo reflectante, castigo por cooldown de Corte) y
## Fase 4 "Quiebre" (arremetida de daño verdadero, miedo/empujón, refuerzos).
## Las 4 fases seguidas y las transiciones de punta a punta ya están
## probadas (prueba_guardian_4_fases_completas.gd) — esa misma prueba
## encontró y corrigió un bug real: dano_golpe_transicion nunca llegaba a
## aplicarse de verdad (el golpe de transición pegaba 20 fijo, la mitad de
## lo diseñado), ver el comentario en _ready() de más abajo.

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
## Recarga sus habilidades esto veces más rápido al entrar en Quiebre —
## mismo mecanismo que EnemigoArañaReina._activar_furia_final
## (multiplicador_recarga en HabilidadBase), permanente por el resto del
## combate. Pedido del usuario: "una IA un poco más inteligente" — sin
## esto, el ritmo de ataque no cambiaba nada entre la fase 1 y la 4 más
## allá de sumar habilidades nuevas al repertorio.
@export var multiplicador_furia_final: float = 1.4

var _fase: int = 1
## Mismo criterio que EnemigoArañaReina._refuerzos_fase3: PackedScene
## precargadas, instanciadas SOLO en servidor al entrar la fase.
var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]

## Ayuda visual TEMPORAL de balanceo — pedido del usuario para ver de un
## vistazo qué habilidad acaba de lanzar mientras se prueban los números;
## posiblemente se saque más adelante (ver EtiquetaHabilidad en el .tscn).
## Se engancha a habilidad_activada (HabilidadBase, emitida DENTRO de
## activar() en la entidad que de verdad decide el lanzamiento — el mismo
## SelectorHabilidades server-only que ya usa el resto del árbol, no la
## réplica visual pura _reproducir_visual_red de cada cliente), así que en
## una sesión sin red (edición/pruebas locales) queda perfecta; en un
## servidor dedicado real, la etiqueta se actualiza del lado del servidor
## pero no se replica sola a los clientes — aceptable para una ayuda de
## balanceo de corta vida.
const _DURACION_ETIQUETA_HABILIDAD := 3.0
@onready var _etiqueta_habilidad: Label = get_node_or_null("EtiquetaHabilidad")
var _tiempo_restante_etiqueta: float = 0.0

## Label REAL puesto a mano en la escena (ver NombreJefe en el .tscn), no
## dibujado por código como el resto de los mobs (Enemigo._crear_nombre_
## mob/_dibujar_nombre_mob) — pedido explícito del usuario: "coloca ese
## label como nodo, no lo crees por código", para poder acomodarlo a ojo
## en el editor. mostrar_nombre=false en el .tscn apaga el nameplate de
## la base (evita mostrar el nombre DOS veces); el texto se sigue
## llenando acá desde "datos" para que no se desincronice si algún día
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
	# Bug real encontrado por la prueba de integración de las 4 fases
	# (prueba_guardian_4_fases_completas.gd): dano_golpe_transicion nunca se
	# conectaba con el nodo real — HabilidadGolpeVerdaderoTransicion no
	# tiene override de "daño" en el .tscn, así que siempre pegaba el
	# default del script (20.0) sin importar lo que dijera este export. El
	# golpe de transición terminaba pegando la mitad de lo diseñado.
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


## Si ya había una etiqueta mostrándose, el texto se reemplaza y el
## contador de 3s arranca de nuevo desde cero — pedido explícito.
##
## habilidad_activada solo se emite DENTRO de activar() (ver HabilidadBase),
## que en un servidor dedicado real corre SOLO en el servidor — un cliente
## conectado nunca ve este método, solo la réplica visual pura
## (_reproducir_visual_red, que llama _ejecutar() directo sin pasar por
## activar()). Sin el rpc_id de abajo, la etiqueta se actualizaba en el
## servidor pero JAMÁS en la pantalla de ningún jugador real — bug real
## reportado: "el label no actualiza si lanza una habilidad nuevamente o
## una diferente" (en realidad nunca actualizaba del todo para un cliente).
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
## (preparacion_iniciada/carga_iniciada/carga_terminada) tal cual, pero
## HabilidadCarga.gd NO toca el AnimationTree por su cuenta — eso lo hace
## SIEMPRE el mob dueño, conectado a esas señales (mismo patrón que
## EnemigoLobo._on_carga_terminada). Sin esta conexión, "carga_terminada"
## nunca llegaba a nadie y memoria["ataque_en_curso"] (puesto en true por
## HabilidadCarga._ejecutar()) se quedaba en true PARA SIEMPRE tras la
## primera embestida — bug real reportado: "al hacer la embestida se queda
## pegado al final". AccionAtacar/el resto de la IA leen esa clave para
## saber si hay un ataque largo en curso; con ella atascada en true, el
## jefe queda congelado ahí de por vida.
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


## Golpe grande NO-área (GolpeVerdaderoGuardian, ver esa clase) que marca el
## cruce de fase — pedido del diseño: "un golpe grande telegrafiado no-área
## al cruzar cada umbral". Usa el mismo nodo que castiga el cooldown de
## Corte en fase 3 (HabilidadGolpeVerdaderoTransicion en Habilidades), con
## ignora_defensa=true para que se sienta como un golpe de verdad incluso
## contra un jugador bien defendido.
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
