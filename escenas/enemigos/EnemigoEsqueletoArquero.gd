extends Enemigo
class_name EnemigoEsqueletoArquero

# =============================================================================
# 🏹 ESQUELETO ARQUERO
# Mob de presión a distancia: a diferencia de Lobo/Caballero (cuerpo a
# cuerpo + carga), su única habilidad es un disparo de flecha, sin arañazo
# ni dash de ataque. SelectorHabilidades/AccionAtacar ya resuelven solos
# "acercarse hasta rango y quedarse ahí" (ver FlechaArquero.tres +
# AccionAtacar.usar_rango_de_habilidades) — no hacía falta código para eso.
#
# Lo que SÍ es específico de este mob y vive acá: la reacción cuando el
# jugador invade su espacio (distancia_peligro). Mientras siga así de
# cerca, cada _INTERVALO_DECISION segundos tira una moneda 50/50:
#   - Cadencia rápida: dispara más seguido durante esa ventana — HabilidadBT
#     Cadencia Rápida propia (ver Habilidades/HabilidadCadenciaRapida),
#     activada directo acá (no por SelectorHabilidades: es una reacción del
#     propio mob, no una habilidad elegida por rango/prioridad entre
#     varias), con su propio ícono sobre el mob mientras dure.
#   - Retirada: dash en línea recta en dirección CONTRARIA al jugador
#     (hasta _DISTANCIA_RETIRADA), y vuelve a atacar normal apenas termina.
#     Esta sí es un reflejo aparte, no una habilidad — se implementa acá con
#     el mismo patrón de "tomar control directo del movimiento" que ya usa
#     HabilidadCarga durante su dash: se avisa "ataque_en_curso" a la
#     memoria (para que AccionAtacar suelte el comando de movimiento sin
#     pelear por él) y se mueve el cuerpo directo con componente_
#     movimiento.physics_process(), con el mismo chequeo de contener_
#     dentro_del_mapa() que ya usan los otros dashes rápidos del juego
#     contra el tuneleo en los bordes del mapa.
# =============================================================================

## Distancia por debajo de la cual el jugador se considera "demasiado
## cerca" — bien por debajo del rango de disparo (380, ver
## FlechaArquero.tres): solo entra en juego si el jugador de verdad invade
## su espacio, no mientras se acerca a la distancia normal de combate.
@export var distancia_peligro: float = 120.0

const _INTERVALO_DECISION := 5.0
## Cuánto retrocede en el dash. 200 px a pedido del usuario (antes 400): con
## el salto largo se despegaba demasiado y costaba volver a alcanzarlo.
const _DISTANCIA_RETIRADA := 200.0
const _VELOCIDAD_RETIRADA := 350.0

@onready var _habilidad_cadencia_rapida: HabilidadCadenciaRapidaArquero = $Habilidades/HabilidadCadenciaRapida

var _tiempo_restante_decision: float = 0.0
var _estaba_cerca := false

var _en_retirada := false
var _direccion_retirada := Vector2.ZERO
var _retirada_recorrida: float = 0.0


func _physics_process(delta: float) -> void:
	# Esta reacción es decisión de IA — igual que el árbol de comportamiento
	# (ver Enemigo._physics_process/ArbolComportamiento._process), solo
	# corre del lado de la autoridad real (servidor, o un solo jugador). El
	# cliente puro solo interpola la posición replicada; super() ya se
	# encarga de esa rama.
	if not Utils.en_red() or multiplayer.is_server():
		if _en_retirada:
			_procesar_retirada(delta)
		_actualizar_reaccion_cercania(delta)
	super._physics_process(delta)


# =============================================================================
# DECISIÓN CADA 5s MIENTRAS EL JUGADOR ESTÁ DEMASIADO CERCA
# =============================================================================

func _actualizar_reaccion_cercania(delta: float) -> void:
	if _muerto or _en_retirada:
		return
	var objetivo_raw = memoria.obtener("objetivo")
	var jugador_cerca := false
	if is_instance_valid(objetivo_raw) and objetivo_raw is Node2D:
		var distancia := global_position.distance_to((objetivo_raw as Node2D).global_position)
		jugador_cerca = distancia <= distancia_peligro

	if not jugador_cerca:
		if _estaba_cerca:
			_estaba_cerca = false
			_habilidad_cadencia_rapida.desactivar()
		return

	# Primera vez que se detecta "demasiado cerca": reacciona YA, no espera
	# los 5s completos — a partir de acá sí vuelve a tirar la moneda cada
	# _INTERVALO_DECISION mientras el jugador se mantenga tan cerca.
	if not _estaba_cerca:
		_estaba_cerca = true
		_tiempo_restante_decision = 0.0

	_tiempo_restante_decision -= delta
	if _tiempo_restante_decision <= 0.0:
		_tiempo_restante_decision = _INTERVALO_DECISION
		_decidir_reaccion(objetivo_raw as Node2D)


## Moneda 50/50 entre cadencia rápida y retirada (ver comentario de clase).
const _PROBABILIDAD_CADENCIA_RAPIDA := 0.5

func _decidir_reaccion(objetivo: Node2D) -> void:
	if randf() < _PROBABILIDAD_CADENCIA_RAPIDA:
		_habilidad_cadencia_rapida.activar()
	else:
		# Cada ventana de 5s es independiente de la anterior — si la vez
		# pasada tocó cadencia rápida y esta vez toca retirada, no debe
		# quedar la cadencia rápida pegada (pedido explícito: tras la
		# retirada "sigue atacando normal hasta la próxima probabilidad").
		_habilidad_cadencia_rapida.desactivar()
		_iniciar_retirada(objetivo)


# =============================================================================
# RETIRADA (dash en dirección contraria al jugador)
# =============================================================================

func _iniciar_retirada(objetivo: Node2D) -> void:
	var direccion := (global_position - objetivo.global_position)
	direccion = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	_direccion_retirada = direccion
	_retirada_recorrida = 0.0
	_en_retirada = true
	# Sigue mirando (y por lo tanto, en el próximo disparo, apuntando) hacia
	# el jugador mientras retrocede — un arquero que se aleja de espaldas
	# sin verlo no encajaría con "sigue atacando normal" apenas termine.
	direccion_mirada = -direccion
	# Mismo aviso que HabilidadCarga: le dice a AccionAtacar que suelte el
	# comando de movimiento sin pelear por él mientras este dash lo maneja
	# directo (ver comentario de clase).
	memoria.establecer("ataque_en_curso", true)
	# Enemigo._aplicar_presentacion() deja de tocar debeCaminar/debeIdle
	# mientras ataque_en_curso sea true (ver ese comentario — lo agregó
	# HabilidadFlechaArquero para no pelear con su propia pose de ataque),
	# así que durante la retirada hay que ponerlos a mano acá: sigue siendo
	# un dash normal, tiene que verse caminando/corriendo, no quedarse
	# pegado en la pose que tuviera un fotograma antes de arrancar.
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", true)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", false)


func _procesar_retirada(delta: float) -> void:
	if _muerto:
		_terminar_retirada()
		return
	var posicion_antes := global_position
	componente_movimiento.physics_process(delta, _direccion_retirada, _VELOCIDAD_RETIRADA)
	# Red de seguridad contra el tuneleo en los bordes del mapa a velocidad
	# de dash — mismo criterio que HabilidadCarga/HabilidadCargaJugador.
	componente_movimiento.contener_dentro_del_mapa()
	_retirada_recorrida += global_position.distance_to(posicion_antes)
	if _retirada_recorrida >= _DISTANCIA_RETIRADA or is_on_wall():
		_terminar_retirada()


func _terminar_retirada() -> void:
	_en_retirada = false
	memoria.establecer("ataque_en_curso", false)
