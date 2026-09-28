extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoArañaReina
## Segundo jefe del juego, más difícil que el Jefe Esqueleto: mantiene
## distancia y dispara (reusa el kiting de EnemigoAraña), tiene 3 fases con
## invocación de refuerzos y escudo de daño mientras vivan (ver
## EscudoComponente), y una rama de "Castigo" que penaliza quedarse pegado sin
## ninguna habilidad disponible (ver CondicionObjetivoSinHabilidades, cableada
## en la escena). Mecánica de fases común en EnemigoJefe.gd, con sus propios
## umbrales (70% y 35%), sin golpe de transición ni invulnerabilidad al cruzar.
##
## Fase 1 (100%-70% de vida): Arañazo + Bola de Telaraña, como una Araña normal.
## Fase 2: suma Veneno Paralizante e invoca dos lobos.
## Fase 3: suma Marca, Charco y Disparo en Línea e invoca tres refuerzos. Al
## morir los últimos, se enfurece (_activar_furia_final).

## Mismo ícono que ya usa la Habilidad Escudo del jugador — reduce trabajo
## de arte y es reconocible para quien ya la vio ahí.
const _TEXTURA_ICONOS := preload("res://assets/iconos/iconos habilidades.png")
const _REDUCCION_ESCUDO_ADDS := 0.7
const _RUTA_SELECTOR_MELEE := "ArbolComportamiento/Selector/AtacarMelee/SelectorArañazo"
const _RUTA_SELECTOR_DISTANCIA := "ArbolComportamiento/Selector/AtaqueADistancia/AtacarLejos/SelectorTelaraña"

@export_group("Fases")
## El NODO (Habilidades/HabilidadVenenoParalizante) ya está en la escena; esto
## es el recurso HabilidadBT que se suma al selector de melee en fase 2.
@export var habilidad_veneno_paralizante_bt: HabilidadBT
## Las tres que se suman al repertorio a distancia en fase 3.
@export var habilidad_marca_bt: HabilidadBT
@export var habilidad_charco_bt: HabilidadBT
@export var habilidad_disparo_linea_bt: HabilidadBT

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


func _init() -> void:
	umbrales_fase = [0.70, 0.35]
	invulnerable_en_cambio_de_fase = false


func _ready() -> void:
	super._ready()
	await _esperar_malla_antes_de_actuar()


## Colocada a mano en su nivel (ver NivelNidoArañaReina.gd), no generada por
## SpawnerMobs: arranca viva desde el primer fotograma, sin la espera a que la
## malla de navegación sincronice que SpawnerMobs les da a los demás (ver
## Utils.esperar_malla_de_nivel_lista). Si decide moverse o atacar en esa
## ventana, no se mueve ni ataca. Por eso pausa su árbol mientras espera. No va
## en Enemigo.gd: varias pruebas apagan el árbol de un mob a mano (ver
## prueba_navegacion.gd), y esta reactivación tardía les pisaría ese apagado.
func _esperar_malla_antes_de_actuar() -> void:
	var arbol := get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if arbol:
		arbol.activo = false
	await Utils.esperar_malla_de_nivel_lista(self)
	if arbol and not _muerto:
		arbol.activo = true


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidad_bt(_RUTA_SELECTOR_MELEE, habilidad_veneno_paralizante_bt)
			_invocar_refuerzos(_refuerzos_fase2)
		3:
			_agregar_habilidad_bt(_RUTA_SELECTOR_DISTANCIA, habilidad_marca_bt)
			_agregar_habilidad_bt(_RUTA_SELECTOR_DISTANCIA, habilidad_charco_bt)
			_agregar_habilidad_bt(_RUTA_SELECTOR_DISTANCIA, habilidad_disparo_linea_bt)
			_invocar_refuerzos(_refuerzos_fase3)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _muerto:
		return
	if not _adds.is_empty():
		_asegurar_escudo().activar(1.0, _REDUCCION_ESCUDO_ADDS)
		_asegurar_buffs().agregar("resistencia_adds", _icono_escudo(), 1.0, false,
			"Protegida", "Reduce el daño recibido en 70%% — mata a los refuerzos")


## Además de invocarlos (ver EnemigoJefe), los anota como "adds": mientras
## viva alguno, la reina tiene escudo.
func _invocar_refuerzos(escenas: Array[PackedScene]) -> Array[Node]:
	var mobs := super._invocar_refuerzos(escenas)
	for mob in mobs:
		var vida := mob.get_node_or_null("VidaComponente") as VidaComponente
		if vida == null:
			# Sin VidaComponente no hay forma de saber cuándo "murió": mejor no
			# contarlo como add real que nunca se va a quitar solo.
			continue
		_adds.append(mob)
		# Señal "muerte" (no tree_exiting): dispara al instante en que la vida
		# llega a 0, sin esperar el fundido visual de _desvanecer_y_eliminar()
		# (~0.4 s): el escudo cae apenas mueren de verdad.
		vida.muerte.connect(_al_morir_add.bind(mob), CONNECT_ONE_SHOT)
	return mobs


## "Se enoja" al perder a sus últimos refuerzos de la fase 3.
func _al_morir_add(_valor: float, mob: Node) -> void:
	_adds.erase(mob)
	if _fase == 3 and _adds.is_empty() and not _furia_activada:
		_activar_furia_final()


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
