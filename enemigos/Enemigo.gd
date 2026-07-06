extends CharacterBody2D
class_name Enemigo

# =============================================================================
# 🧠 ENEMIGO — CLASE BASE
# Contiene solo la lógica común a todos los tipos de enemigo:
# componentes, memoria, visión, vida y física.
# Las habilidades van en cada subclase (EnemigoLobo, EnemigoRapido…).
# =============================================================================

## Capa física de obstáculos creados por habilidades del jugador (ver
## Muro.CAPA_BLOQUEO): todos los mobs la incluyen en su collision_mask para
## chocar contra ellos cuando bloquean; el jugador no la incluye en la suya,
## así que nunca queda atrapado por sus propias habilidades.
const CAPA_OBSTACULOS_HABILIDAD := 4

# --- Componentes ---
@export var componente_vida: VidaComponente
@export var componente_maquina_de_estados: MaquinaDeEstadosComponente
@export var componente_movimiento: MovimientoComponente
@export var componente_vision: VisionComponente
@export var componente_animacion: AnimacionComponente
@export var memoria: MemoriaBT

@export var datos: EnemigoDatos
@export var velocidad_base: float = 150.0
@export_range(0.0, 1.0, 0.05) var umbral_vida_baja: float = 0.3

var direccion: Vector2 = Vector2.ZERO
var esta_atacando: bool = false

@onready var habilidades: Marker2D = $Habilidades


func _ready() -> void:
	add_to_group("enemigos")
	collision_mask |= CAPA_OBSTACULOS_HABILIDAD
	_aplicar_datos()
	# ── Memoria inicial ───────────────────────────────────────────────────────
	memoria.establecer("agente",                        self)
	memoria.establecer("componente_movimiento",         componente_movimiento)
	memoria.establecer("componente_vision",             componente_vision)
	memoria.establecer("componente_maquina_estados",    componente_maquina_de_estados)
	memoria.establecer("objetivo",                      null)
	memoria.establecer("jugador_detectado",             false)
	memoria.establecer("en_combate",                    false)
	memoria.establecer("en_recuperacion",               false)
	memoria.establecer("esta_huyendo",                  false)
	memoria.establecer("huida_en_cooldown",             false)
	memoria.establecer("tiempo_cooldown_huida",         0.0)

	if componente_vida:
		memoria.establecer("vida",      componente_vida.obtener_vida())
		memoria.establecer("vida_baja", false)
		memoria.establecer("vida_cero", false)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
		componente_vida.muerte.connect(_on_muerte)

	if componente_vision:
		componente_vision.objetivo_detectado.connect(_on_objetivo_detectado)
		componente_vision.objetivo_perdido.connect(_on_objetivo_perdido)

	memoria.variable_cambiada.connect(_on_memoria_variable_cambiada)

	if componente_maquina_de_estados:
		componente_maquina_de_estados.cambiar_estado("EstadoIdle")


func _physics_process(delta: float) -> void:
	if direccion != Vector2.ZERO and not memoria.obtener("congelar_rotacion", false):
		habilidades.rotation = direccion.angle()

	var tiempo_cd: float = memoria.obtener("tiempo_cooldown_huida", 0.0)
	if tiempo_cd > 0.0:
		var nuevo_cd := maxf(tiempo_cd - delta, 0.0)
		memoria.establecer("tiempo_cooldown_huida", nuevo_cd)
		if nuevo_cd <= 0.0:
			memoria.establecer("huida_en_cooldown", false)

	if componente_maquina_de_estados:
		componente_maquina_de_estados.procesar_estado(delta)

	if componente_animacion:
		var caminando := velocity != Vector2.ZERO
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    not caminando)
		componente_animacion.actualizar_blend(direccion)


# =============================================================================
# API PÚBLICA
# =============================================================================

func quitar_vida(cantidad: float) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad)


# =============================================================================
# SEÑALES DE COMPONENTES
# =============================================================================

func _on_objetivo_detectado(area: Area2D) -> void:
	memoria.establecer("objetivo",          area.owner)
	memoria.establecer("jugador_detectado", true)


func _on_objetivo_perdido(_area: Area2D) -> void:
	memoria.establecer("jugador_detectado", false)


func _on_vida_cambiada(nuevo_valor: float) -> void:
	memoria.establecer("vida", nuevo_valor)


func _on_muerte(_valor: float) -> void:
	memoria.establecer("vida_cero", true)
	memoria.establecer("vida",      0.0)
	# Apagar el cerebro y frenar el cuerpo: un muerto no decide ni camina.
	var arbol := get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if arbol:
		arbol.activo = false
	if componente_movimiento:
		componente_movimiento.detener()
	_desvanecer_y_eliminar()


## Hace desaparecer el cuerpo (queda en idle, se pone negro y luego se
## desvanece) y lo libera de verdad.
## NO se recicla (sin object pooling): un mob arrastra demasiado estado
## propio (memoria del árbol de comportamiento, agente de navegación,
## áreas de visión, cooldowns de habilidades) para reutilizarlo con
## garantías, y muere pocas veces por partida — a diferencia de un
## proyectil o un número de daño (ver GestorPiscinas), el coste de crear
## uno nuevo la próxima vez es insignificante.
##
## Quien necesite saber "este mob ya no existe" (p. ej. SpawnerMobs, para
## liberar un hueco) puede escuchar la señal nativa `tree_exiting`, que
## dispara justo cuando queue_free() lo retira de verdad — no hace falta
## una señal propia.
func _desvanecer_y_eliminar() -> void:
	# Diferido: _on_muerte() puede llegar desde dentro de un callback de
	# física (un golpe cuerpo a cuerpo), donde cambiar capas de colisión
	# de golpe dispara "flushing queries".
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_physics_process(false)
	velocity = Vector2.ZERO
	var barra := get_node_or_null("BarraVidaEnergia") as CanvasItem
	if barra:
		barra.hide()
	if componente_animacion:
		# Si murió a mitad de una animación puntual (ataque, etc.), esa
		# override tiene el AnimationTree apagado: cancelarla primero o las
		# condiciones de abajo no tendrían ningún efecto.
		componente_animacion.cancelar_override()
		# Fijar el blend en la última dirección mirada ANTES de que
		# _physics_process (que la actualizaba cada frame) se apague, para
		# que el idle quede mirando hacia donde miraba, quieto.
		componente_animacion.actualizar_blend(direccion)
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    true)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _on_memoria_variable_cambiada(nombre: String, _anterior, _nuevo) -> void:
	if nombre != "vida":
		return
	var vida_actual: float = memoria.obtener("vida", 100.0)
	var vida_max: float    = componente_vida.obtener_vida_maxima() if componente_vida else 100.0
	var baja: bool = vida_actual > 0.0 and (vida_actual / vida_max) <= umbral_vida_baja
	memoria.establecer("vida_baja", baja)
	if baja and not memoria.obtener("jugador_detectado", false):
		var obj := memoria.obtener("objetivo") as Node2D
		if obj and is_instance_valid(obj):
			memoria.establecer("jugador_detectado", true)


# =============================================================================
# DATOS / PLANTILLA  (sobreescribir en subclases para stats propios)
# =============================================================================

func _aplicar_datos() -> void:
	if not datos:
		return
	if componente_vida:
		componente_vida.salud_maxima = datos.vida_maxima
	if componente_movimiento:
		componente_movimiento.velocidad_base = datos.velocidad_base
	velocidad_base = datos.velocidad_base
	var comp_energia := get_node_or_null("EnergiaComponente") as EnergiaComponente
	if comp_energia:
		comp_energia.energia_maxima          = datos.energia_maxima
		comp_energia.regeneracion_por_segundo = datos.regeneracion_energia
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = datos.color
