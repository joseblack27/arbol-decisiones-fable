# =============================================================================
# Temporizador.gd  (Decorador — Timeout)
#
# Da al hijo un tiempo máximo para completarse.
# Si el hijo devuelve EN_EJECUCION durante más de N segundos → FALLIDO.
# Si el hijo termina dentro del tiempo → retorna su resultado sin cambios.
#
# Casos de uso:
#   • Cancelar una persecución si el enemigo no alcanza al jugador en X segundos.
#   • Abandonar una acción que se quedó trabada.
#   • Forzar que la IA tome otra decisión si la actual no resuelve pronto.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Temporizador.
# =============================================================================
class_name Temporizador
extends NodoDecorador

@export_group("Configuración Temporizador")
## Tiempo máximo en segundos que el hijo puede estar EN_EJECUCION.
@export var tiempo_limite: float = 3.0
## Estado que retorna al agotar el tiempo (normalmente FALLIDO).
@export var estado_al_agotar: NodoBT.Estado = NodoBT.Estado.FALLIDO

# Marca de tiempo en que empezó la ejecución del hijo.
var _tiempo_inicio: float = -1.0


func _on_entrar() -> void:
	super._on_entrar()
	_tiempo_inicio = Time.get_ticks_msec() / 1000.0
	if debug_activo:
		print_rich(
			"[color=cyan][BT ⏱][/color] Temporizador [b]%s[/b]: límite de %.1fs iniciado."
			% [nombre_nodo, tiempo_limite]
		)


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tiempo_inicio = -1.0


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Temporizador '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	var resultado: Estado = _hijo.ejecutar()

	# Si el hijo terminó, retornar su resultado sin interferir.
	if resultado != Estado.EN_EJECUCION:
		return resultado

	# El hijo sigue en ejecución: verificar si se agotó el tiempo.
	var ahora: float = Time.get_ticks_msec() / 1000.0
	var transcurrido: float = ahora - _tiempo_inicio

	if transcurrido >= tiempo_limite:
		_hijo.reiniciar()
		if debug_activo:
			print_rich(
				"[color=red][BT ⏱][/color] Temporizador [b]%s[/b]: tiempo agotado (%.1fs). Retornando %s."
				% [nombre_nodo, tiempo_limite, _nombre_estado(estado_al_agotar)]
			)
		return estado_al_agotar

	if debug_activo:
		print_rich(
			"[color=cyan][BT ⏱][/color] Temporizador [b]%s[/b]: %.1f / %.1fs"
			% [nombre_nodo, transcurrido, tiempo_limite]
		)
	return Estado.EN_EJECUCION


func _nombre_estado(e: Estado) -> String:
	match e:
		Estado.EXITOSO:      return "EXITOSO"
		Estado.FALLIDO:      return "FALLIDO"
		Estado.EN_EJECUCION: return "EN_EJECUCION"
	return "?"
