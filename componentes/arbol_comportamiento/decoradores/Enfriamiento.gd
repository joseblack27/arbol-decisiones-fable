# =============================================================================
# Enfriamiento.gd  (Decorador — Cooldown)
#
# Bloquea la re-ejecución del hijo durante N segundos después de que termine.
# Durante el enfriamiento retorna FALLIDO sin llamar al hijo.
# Una vez pasado el tiempo, vuelve a ejecutar el hijo con normalidad.
#
# Casos de uso:
#   • Limitar con qué frecuencia un enemigo puede atacar.
#   • Evitar que una alerta suene más de una vez cada X segundos.
#   • Espaciar chequeos costosos (pathfinding, raycasts, etc.)
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Enfriamiento.
# =============================================================================
class_name Enfriamiento
extends NodoDecorador

@export_group("Configuración Enfriamiento")
## Tiempo en segundos que debe esperar antes de poder ejecutar al hijo de nuevo.
@export var tiempo_enfriamiento: float = 2.0
## Si es true, el cooldown solo inicia cuando el hijo retorna EXITOSO.
## Si es false, inicia cuando el hijo termina con cualquier resultado.
@export var solo_al_exitoso: bool = false

# Marca de tiempo (en segundos) de la última vez que el hijo terminó.
var _tiempo_ultima_ejecucion: float = -INF


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tiempo_ultima_ejecucion = -INF


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Enfriamiento '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	var ahora: float = Time.get_ticks_msec() / 1000.0
	var tiempo_restante: float = (_tiempo_ultima_ejecucion + tiempo_enfriamiento) - ahora

	# Si aún está en enfriamiento, bloquear.
	if tiempo_restante > 0.0:
		if debug_activo:
			print_rich(
				"[color=orange][BT ❄][/color] Enfriamiento [b]%s[/b]: %.1fs restantes"
				% [nombre_nodo, tiempo_restante]
			)
		return Estado.FALLIDO

	# Ejecutar el hijo normalmente.
	var resultado: Estado = _hijo.ejecutar()

	# Registrar el tiempo al terminar (no mientras está EN_EJECUCION).
	if resultado != Estado.EN_EJECUCION:
		if not solo_al_exitoso or resultado == Estado.EXITOSO:
			_tiempo_ultima_ejecucion = Time.get_ticks_msec() / 1000.0
			if debug_activo:
				print_rich(
					"[color=orange][BT ❄][/color] Enfriamiento [b]%s[/b]: iniciado (%.1fs)"
					% [nombre_nodo, tiempo_enfriamiento]
				)

	return resultado
