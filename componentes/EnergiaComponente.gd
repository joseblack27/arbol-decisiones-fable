extends Node
class_name EnergiaComponente
## Componente de energía reutilizable para jugador y enemigos.
## Colócalo como hijo de la entidad. La energía se regenera por TICKS:
## +regeneracion_por_tick cada intervalo_regeneracion segundos (atributo de
## regeneración pedido de diseño: +10 cada 5 s por defecto).
##
## Réplica de red (mismo criterio que VidaComponente): el SERVIDOR es la
## autoridad del valor real — los ticks solo corren donde el cálculo es el
## real (servidor / un jugador) y le llegan al cliente por la réplica
## periódica. El gasto (consumir) sí se predice localmente en el cliente
## para que la barra reaccione al instante.

signal energia_cambiada(nueva: float, maxima: float)
signal energia_agotada()

@export_group("Energía")
@export var energia_maxima: float = 100.0
## RESPALDO cuando la entidad no tiene AtributosComponente (mobs simples,
## pruebas): energía recuperada por tick. Si SÍ hay atributos, manda
## AtributosBase.regeneracion_energia (base + bonos de equipo) y esto se
## ignora.
@export var regeneracion_por_tick: float = 10.0
## Segundos entre ticks de regeneración.
@export var intervalo_regeneracion: float = 5.0

var _energia_actual: float = 0.0
var _acumulador_regen: float = 0.0

## Réplica: cada cuánto (segundos) el servidor reenvía el valor real si
## cambió desde el último envío. Los gastos/cargas puntuales se replican al
## instante aparte de este ritmo.
const _INTERVALO_REPLICA := 0.5
var _acumulador_replica: float = 0.0
var _ultimo_valor_enviado: float = -1.0


func _ready() -> void:
	_energia_actual = energia_maxima


func _process(delta: float) -> void:
	# Regeneración por ticks — SOLO donde el cálculo es el real (servidor o
	# un jugador). El cliente puro no la simula: cada tick es un salto
	# discreto que le llega por la réplica de abajo (con ticks de varios
	# segundos no hay nada que suavizar, a diferencia de la regen continua
	# que había antes).
	if not (Utils.en_red() and not multiplayer.is_server()):
		_acumulador_regen += delta
		if _acumulador_regen >= intervalo_regeneracion:
			_acumulador_regen -= intervalo_regeneracion
			var cantidad := _cantidad_regen()
			if _energia_actual < energia_maxima and cantidad > 0.0:
				agregar_energia(cantidad)

	if Utils.en_red() and multiplayer.is_server():
		_acumulador_replica += delta
		if _acumulador_replica >= _INTERVALO_REPLICA:
			_acumulador_replica = 0.0
			if not is_equal_approx(_ultimo_valor_enviado, _energia_actual):
				_replicar_valor()


# =============================================================================
# API pública
# =============================================================================

## Intenta consumir cantidad. Devuelve true si había suficiente.
## En cliente puro esto es predicción: descuenta localmente para que la
## barra reaccione al instante, pero el valor real lo decide el servidor
## (que corre este mismo consumir() con autoridad al ejecutar la habilidad)
## y llega corregido por _recibir_energia_red.
func consumir(cantidad: float) -> bool:
	if cantidad <= 0.0:
		return true
	if _energia_actual < cantidad:
		energia_agotada.emit()
		return false
	_energia_actual -= cantidad
	energia_cambiada.emit(_energia_actual, energia_maxima)
	BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)
	if Utils.en_red() and multiplayer.is_server():
		_replicar_valor()
	return true


func tiene_energia(cantidad: float) -> bool:
	return _energia_actual >= cantidad


func agregar_energia(cantidad: float) -> void:
	_energia_actual = minf(_energia_actual + cantidad, energia_maxima)
	energia_cambiada.emit(_energia_actual, energia_maxima)
	BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)
	if Utils.en_red() and multiplayer.is_server():
		_replicar_valor()


func obtener_energia() -> float:
	return _energia_actual


func obtener_energia_maxima() -> float:
	return energia_maxima


func obtener_fraccion() -> float:
	return _energia_actual / energia_maxima if energia_maxima > 0.0 else 0.0


## Magnitud del tick: el ATRIBUTO regeneracion_energia (base + bonos de
## equipo) cuando la entidad tiene AtributosComponente — el equipamiento
## puede mejorarla y el bono aplica en vivo al equipar/quitar. Sin
## atributos, el export de respaldo.
func _cantidad_regen() -> float:
	var padre := get_parent()
	if padre:
		var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
		if atributos and atributos.base:
			return atributos.base.regeneracion_energia
	return regeneracion_por_tick


# =============================================================================
# Réplica de red
# =============================================================================

func _replicar_valor() -> void:
	rpc("_recibir_energia_red", _energia_actual)
	_ultimo_valor_enviado = _energia_actual


## unreliable_ordered: es un valor que se autocorrige solo — si un paquete
## se pierde, el siguiente reenvío periódico (o el próximo gasto) lo trae.
@rpc("authority", "unreliable_ordered")
func _recibir_energia_red(valor: float) -> void:
	_energia_actual = clampf(valor, 0.0, energia_maxima)
	energia_cambiada.emit(_energia_actual, energia_maxima)
	BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)
