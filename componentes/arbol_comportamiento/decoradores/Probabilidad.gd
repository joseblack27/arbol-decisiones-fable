# =============================================================================
# Probabilidad.gd  (Decorador — Chance)
#
# Ejecuta al hijo solo si un número aleatorio supera el umbral configurado.
# Si no supera el umbral, retorna FALLIDO sin ejecutar al hijo.
# La tirada se hace UNA sola vez al entrar al nodo; se mantiene para todos
# los ticks mientras el hijo devuelva EN_EJECUCION.
#
# Casos de uso:
#   • Un enemigo que solo lanza un proyectil especial el 30% de las veces.
#   • Variar el comportamiento de patrulla aleatoriamente.
#   • Añadir impredictibilidad a la IA sin lógica adicional.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Probabilidad.
# =============================================================================
class_name Probabilidad
extends NodoDecorador

@export_group("Configuración Probabilidad")
## Probabilidad de ejecutar al hijo (0.0 = nunca, 1.0 = siempre).
@export_range(0.0, 1.0, 0.01) var probabilidad: float = 0.5
## Semilla para el generador aleatorio. -1 = aleatoria cada vez.
@export var semilla: int = -1

# Resultado de la tirada actual (se mantiene mientras el hijo esté EN_EJECUCION).
var _tirada_superada: bool = false
# Si la tirada ya fue realizada para este ciclo de ejecución.
var _tirada_realizada: bool = false

var _rng: RandomNumberGenerator


func _on_inicializar(_mem = null) -> void:
	_rng = RandomNumberGenerator.new()
	if semilla >= 0:
		_rng.seed = semilla


func _on_entrar() -> void:
	super._on_entrar()
	# Realizar la tirada al entrar, una sola vez por ciclo.
	var valor: float = _rng.randf()
	_tirada_superada = valor <= probabilidad
	_tirada_realizada = true

	if debug_activo:
		var icono := "✅" if _tirada_superada else "❌"
		print_rich(
			"[color=magenta][BT 🎲][/color] Probabilidad [b]%s[/b]: %.0f%% → tirada=%.2f → %s"
			% [nombre_nodo, probabilidad * 100.0, valor, icono]
		)


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tirada_superada = false
	_tirada_realizada = false


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Probabilidad '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	if not _tirada_superada:
		return Estado.FALLIDO

	return _hijo.ejecutar()
