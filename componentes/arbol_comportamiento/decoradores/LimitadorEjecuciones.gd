# =============================================================================
# LimitadorEjecuciones.gd  (Decorador)
# Permite que su hijo se ejecute como máximo N veces por ciclo del árbol.
# Una vez alcanzado el límite, retorna FALLIDO sin ejecutar al hijo.
# Útil para evitar que una acción se repita más veces de las deseadas.
#
# El contador se reinicia al llamar reiniciar() en el nodo o en el árbol.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de LimitadorEjecuciones.
# =============================================================================
class_name LimitadorEjecuciones
extends NodoDecorador

@export_group("Configuración Limitador")
## Número máximo de ejecuciones permitidas antes de retornar FALLIDO.
@export var max_ejecuciones: int = 1

var _ejecuciones_actuales: int = 0


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_ejecuciones_actuales = 0


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("LimitadorEjecuciones '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	if _ejecuciones_actuales >= max_ejecuciones:
		if debug_activo:
			print_rich(
				"[color=orange][BT ⛔][/color] Límite alcanzado en [b]%s[/b] (%d/%d)"
				% [nombre_nodo, _ejecuciones_actuales, max_ejecuciones]
			)
		return Estado.FALLIDO

	var resultado: Estado = _hijo.ejecutar()

	# Solo cuenta cuando el hijo termina (no mientras está EN_EJECUCION).
	if resultado != Estado.EN_EJECUCION:
		_ejecuciones_actuales += 1
		if debug_activo:
			print_rich(
				"[color=yellow][BT ⚙][/color] Ejecución %d/%d en [b]%s[/b]"
				% [_ejecuciones_actuales, max_ejecuciones, nombre_nodo]
			)

	return resultado
