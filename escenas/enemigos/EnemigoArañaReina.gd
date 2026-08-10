extends Enemigo
class_name EnemigoArañaReina
## Segundo boss del juego, pensado para ser más difícil que el Jefe Esqueleto:
## mantiene distancia y dispara (reusa el kiting de EnemigoAraña) en vez de
## caminar derecho, tiene 3 fases con invocación de refuerzos + escudo de
## daño mientras vivan (ver EscudoComponente), y una rama de "Castigo" que
## penaliza quedarse pegado sin ninguna habilidad disponible (ver
## CondicionObjetivoSinHabilidades, cableada en la escena).
##
## Fase 1 (100%-70% vida): Arañazo + Bola de Telaraña, igual que una Araña
## normal — la mecánica de fases/adds/escudo se agrega en los pasos
## siguientes del plan.

## Mismo ícono que ya usa la Habilidad Escudo del jugador — reduce trabajo
## de arte y es reconocible para quien ya la vio ahí.
const _TEXTURA_ICONOS := preload("res://assets/iconos/iconos habilidades.png")
const _REDUCCION_ESCUDO_ADDS := 0.7

## Umbral de vida (fracción de la máxima) que dispara cada transición.
const _UMBRAL_FASE_2 := 0.70
const _UMBRAL_FASE_3 := 0.35

@export_group("Fases")
## Segundos que la reina queda quieta/indefensa al cruzar de fase — el
## "respiro" telegrafiado, mismo criterio que EnemigoJefeEsqueleto.
@export var pausa_cambio_fase: float = 1.3
## Habilidad que se suma al repertorio de melee al entrar en fase 2 — el
## NODO (Habilidades/HabilidadVenenoParalizante) ya está en la escena; esto
## es el recurso HabilidadBT que hay que agregar al SelectorHabilidades.
@export var habilidad_veneno_paralizante_bt: HabilidadBT
## Las tres habilidades que se suman al repertorio a distancia al entrar en
## fase 3 — mismo criterio que arriba, los NODOS ya están en la escena.
@export var habilidad_marca_bt: HabilidadBT
@export var habilidad_charco_bt: HabilidadBT
@export var habilidad_disparo_linea_bt: HabilidadBT
## "Furia final": cuánto más rápido recarga TODA su habilidades tras limpiar
## los refuerzos de fase 3 (permanente el resto del combate) — mismo
## mecanismo que ya usa HabilidadFervor (multiplicador_recarga en
## HabilidadBase), aplicado acá por código en vez de por una habilidad.
@export var multiplicador_furia_final: float = 1.4

var _fase: int = 1
var _furia_activada := false
var _refuerzos_fase2: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
]
var _refuerzos_fase3: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
	preload("res://escenas/enemigos/EnemigoLoboFeroz.tscn"),
	preload("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn"),
]

var _adds: Array[Node] = []
var _escudo: EscudoComponente = null
## Deliberadamente NO se llama "_buffs": Enemigo.gd ya declara ese campo
## (lo usa para dibujar los íconos de estado encima del nombre) y lo conecta
## solo con su propio mecanismo de reintento — este es un handle propio,
## solo para poder llamar agregar() sin duplicar esa lógica.
var _buffs_propio: BuffsComponente = null


func _ready() -> void:
	super._ready()
	if componente_vida and not componente_vida.cambio_valor_vida.is_connected(_on_vida_cambiada):
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
	await _esperar_malla_antes_de_actuar()


## Único enemigo del juego "colocado a mano" en su nivel (ver
## NivelNidoArañaReina.gd) en vez de generado por SpawnerMobs — arranca viva
## desde el primer fotograma del nivel, sin la espera a que la malla de
## navegación termine de sincronizar que SpawnerMobs sí les da a todos los
## demás mobs (ver Utils.esperar_malla_de_nivel_lista). Si detecta al
## jugador y decide moverse/atacar en esa ventana (recién cargado el nivel,
## la malla puede tardar unos physics_frame), queda "no se mueve, no ataca"
## (reportado en juego real). Se pausa su propio árbol mientras se espera —
## a propósito NO en Enemigo.gd (afectaría a TODOS los enemigos): varias
## pruebas apagan el árbol de un mob a mano para conducirlo manualmente
## (ver prueba_navegacion.gd), y esta reactivación tardía les pisaba ese
## apagado si corría para cualquier enemigo.
func _esperar_malla_antes_de_actuar() -> void:
	var arbol := get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if arbol:
		arbol.activo = false
	await Utils.esperar_malla_de_nivel_lista(self)
	if arbol and not _muerto:
		arbol.activo = true


## Corre en TODOS los peers (cambio_valor_vida se emite igual en el servidor
## real y en la réplica del cliente) — a propósito, mismo criterio que
## EnemigoJefeEsqueleto._on_vida_cambiada_jefe: así todos ven el mismo
## respiro/cambio de fase al mismo tiempo. SelectorHabilidades nunca corre
## en un cliente puro (Enemigo._physics_process solo ejecuta IA del lado del
## servidor), así que el único efecto real ahí es la pausa visual.
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


func _entrar_fase(nueva: int) -> void:
	_fase = nueva
	_telegrafiar_pausa_de_fase(pausa_cambio_fase, _reanudar_fase.bind(nueva))


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidad_bt(
				"ArbolComportamiento/Selector/AtacarMelee/SelectorArañazo", habilidad_veneno_paralizante_bt)
			_invocar_refuerzos(_refuerzos_fase2)
		3:
			var ruta_telaraña := "ArbolComportamiento/Selector/AtaqueADistancia/AtacarLejos/SelectorTelaraña"
			_agregar_habilidad_bt(ruta_telaraña, habilidad_marca_bt)
			_agregar_habilidad_bt(ruta_telaraña, habilidad_charco_bt)
			_agregar_habilidad_bt(ruta_telaraña, habilidad_disparo_linea_bt)
			_invocar_refuerzos(_refuerzos_fase3)


func _agregar_habilidad_bt(ruta_selector: String, bt: HabilidadBT) -> void:
	if bt == null:
		return
	var selector := get_node_or_null(ruta_selector)
	if selector and not selector.habilidades.has(bt):
		selector.habilidades.append(bt)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _muerto:
		return
	if not _adds.is_empty():
		_asegurar_escudo().activar(1.0, _REDUCCION_ESCUDO_ADDS)
		_asegurar_buffs().agregar("resistencia_adds", _icono_escudo(), 1.0, false,
			"Protegida", "Reduce el daño recibido en 70%% — mata a los refuerzos")


## SERVIDOR: instancia mobs reales como refuerzos — mismo patrón que
## SpawnerMobs._generar_uno() (force_readable_name=true, si no el
## MultiplayerSpawner rechaza el nombre autogenerado y el add nunca replica
## al cliente). El contenedor es el mismo "Enemigos" del nivel del que esta
## reina ya es hija (get_parent()), así el MultiplayerSpawner de NivelBase ya
## configurado ahí los replica igual que a cualquier otro mob.
func _invocar_refuerzos(escenas: Array[PackedScene]) -> void:
	# _on_vida_cambiada (quien dispara esto, vía _entrar_fase/_reanudar_fase)
	# corre A PROPÓSITO en TODOS los peers para que el respiro visual de
	# cambio de fase se vea igual en todos lados — sin este corte, la
	# RÉPLICA de la reina en cada cliente invocaba SU PROPIA copia local de
	# los refuerzos (nunca replicada, sin IA real porque Enemigo._physics_
	# process solo corre del lado del servidor) además de la real que sí
	# manda el servidor — reportado: "salieron 6 mobs y solo 3 se movían"
	# (los 3 reales, replicados; los otros 3, fantasmas locales del cliente).
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
		_adds.append(mob)
		var vida := mob.get_node_or_null("VidaComponente") as VidaComponente
		if vida:
			# Señal "muerte" (no tree_exiting): dispara al instante en que la
			# vida llega a 0, sin esperar el fundido visual de
			# _desvanecer_y_eliminar() (~0.4s) — el escudo cae apenas mueren
			# de verdad, sin darle al jugador un colchón extra gratis.
			vida.muerte.connect(_al_morir_add.bind(mob), CONNECT_ONE_SHOT)
		else:
			# Sin VidaComponente no hay forma de saber cuándo "murió" — mejor
			# no contarlo como add real que nunca se va a quitar solo.
			_adds.erase(mob)


func _al_morir_add(_valor: float, mob: Node) -> void:
	_adds.erase(mob)
	if _fase == 3 and _adds.is_empty() and not _furia_activada:
		_activar_furia_final()


## "Se enoja" al perder a sus últimos refuerzos: recarga sus habilidades
## multiplicador_furia_final veces más rápido, permanente por el resto del
## combate — mismo mecanismo que HabilidadFervor (multiplicador_recarga en
## HabilidadBase), pero acá las habilidades cuelgan del Marker2D
## "Habilidades" del enemigo, no directo de la raíz como en un jugador.
func _activar_furia_final() -> void:
	_furia_activada = true
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return
	for hijo in habilidades.get_children():
		if hijo is HabilidadBase:
			hijo.multiplicador_recarga = multiplicador_furia_final


func _asegurar_escudo() -> EscudoComponente:
	if _escudo == null or not is_instance_valid(_escudo):
		_escudo = get_node_or_null("EscudoComponente") as EscudoComponente
		if _escudo == null:
			_escudo = EscudoComponente.new()
			_escudo.name = "EscudoComponente"
			add_child(_escudo)
	return _escudo


func _asegurar_buffs() -> BuffsComponente:
	if _buffs_propio == null or not is_instance_valid(_buffs_propio):
		_buffs_propio = get_node_or_null("BuffsComponente") as BuffsComponente
		if _buffs_propio == null:
			_buffs_propio = BuffsComponente.new()
			_buffs_propio.name = "BuffsComponente"
			add_child(_buffs_propio)
	return _buffs_propio


func _icono_escudo() -> Texture2D:
	var icono := AtlasTexture.new()
	icono.atlas = _TEXTURA_ICONOS
	icono.region = Rect2(32, 160, 32, 32)
	return icono
