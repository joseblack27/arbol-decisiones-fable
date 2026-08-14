extends Enemigo
class_name EnemigoJefeEsqueleto

# =============================================================================
# 👑 JEFE ESQUELETO — primer boss del juego, pensado para ser FÁCIL.
#
# FASE 1 (100%-50% vida): solo la embestida lenta (HabilidadCarga, ya
# telegrafiada por su duracion_preparacion — se ve venir el golpe) — nada de
# ataques a distancia todavía. Extiende Enemigo directo (no EnemigoCaballero
# Esqueleto): esa clase espera un HabilidadArañazo que este jefe no tiene a
# propósito (fase 1 = solo embestida), así que solo se copia el cableado de
# HabilidadCarga que sí comparte.
#
# FASE 2 (<=50% vida): al cruzar el umbral, se PARA en seco un momento (un
# respiro telegrafiado — ventana clara para que el jugador reaccione, se
# cure o se reposicione) y agrega el abanico de proyectiles a su
# repertorio. A partir de ahí, SelectorHabilidades alterna solo entre
# embestida y abanico según rango/cooldown — sin código de estado nuevo.
#
# Mucha vida, poco daño por golpe: la pelea dura, pero un error del jugador
# no lo mata de un tirón. Camina derecho hacia el jugador entre ataques —
# sin kiting ni huida — para que el patrón sea predecible.
# =============================================================================

## Habilidad de abanico que se agrega al repertorio al entrar en fase 2 — el
## NODO (Habilidades/HabilidadAbanico) ya está resuelto por su propio
## ruta_nodo interno; esto es el recurso HabilidadBT que hay que sumar al
## Array de SelectorHabilidades.
@export var habilidad_abanico_bt: HabilidadBT
## Segundos que el jefe queda quieto/indefenso al cruzar a fase 2 — el
## "respiro" telegrafiado antes de que empiece a disparar a distancia.
@export var pausa_cambio_fase: float = 1.3

var _en_fase_2 := false

@onready var _habilidad_carga: HabilidadCarga = $Habilidades/HabilidadCarga


func _ready() -> void:
	super._ready()
	# Mismo cableado que EnemigoCaballeroEsqueleto._ready() para su
	# HabilidadCarga — solo avisa al BT que la carga terminó, ver
	# HabilidadCarga.gd para la lógica real (daño, movimiento del dash).
	_habilidad_carga.preparacion_iniciada.connect(_on_carga_preparacion)
	_habilidad_carga.carga_iniciada.connect(_on_carga_iniciada)
	_habilidad_carga.carga_terminada.connect(_on_carga_terminada)
	if componente_vida:
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada_jefe)


## Este mob no tiene sprites propios de embestida (el AnimationTree solo
## tiene IDLE/CAMINAR, idéntico al del Caballero) — sin esto quedaba
## congelado durante toda la preparación + el dash. Mismo criterio que
## EnemigoCaballeroEsqueleto._on_carga_preparacion/_on_carga_iniciada.
func _on_carga_preparacion() -> void:
	componente_animacion.viajar_a_estado("CAMINAR")


func _on_carga_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	componente_animacion.viajar_a_estado("CAMINAR")


func _on_carga_terminada() -> void:
	memoria.establecer("ataque_en_curso", false)


## Corre en TODOS los peers (cambio_valor_vida se emite igual en el servidor
## real y en la réplica del cliente, ver VidaComponente._recibir_vida_red) —
## a propósito: así todos ven el mismo respiro/cambio de fase al mismo
## tiempo. Es inofensivo que un cliente puro también "decida" esto, porque
## SelectorHabilidades nunca corre ahí (Enemigo._physics_process solo
## ejecuta IA del lado del servidor) — el único efecto real en un cliente es
## la pausa visual (movimiento/animación), que sí debe verse igual en todos.
func _on_vida_cambiada_jefe(valor: float) -> void:
	if _en_fase_2 or _muerto:
		return
	var maxima := componente_vida.obtener_vida_maxima()
	if maxima <= 0.0 or valor / maxima > 0.5:
		return
	_entrar_fase_2()


func _entrar_fase_2() -> void:
	_en_fase_2 = true
	_telegrafiar_pausa_de_fase(pausa_cambio_fase, _agregar_abanico)


func _agregar_abanico() -> void:
	if habilidad_abanico_bt:
		var selector := get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
		if selector and not selector.habilidades.has(habilidad_abanico_bt):
			selector.habilidades.append(habilidad_abanico_bt)
