# =============================================================================
# Retardo.gd  (Decorador — Delay)
#
# Espera N segundos ANTES de ejecutar al hijo por primera vez.
# Durante la espera retorna EN_EJECUCION.
# Una vez pasado el tiempo, ejecuta al hijo y retorna su resultado.
# Si el hijo retorna EN_EJECUCION, continúa llamándolo normalmente cada tick.
#
# Diferencia clave con Enfriamiento:
#   • Retardo  → espera ANTES de ejecutar al hijo (prepara la acción).
#   • Enfriamiento → espera DESPUÉS de que el hijo termina (limita repetición).
#
# Casos de uso:
#   • Hacer que un enemigo dude un momento antes de atacar.
#   • Retrasar una animación de aviso antes de ejecutar la acción real.
#   • Simular tiempo de reacción del NPC.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Retardo.
# =============================================================================
class_name Retardo
extends NodoDecorador

@export_group("Configuración Retardo")
## Tiempo en segundos a esperar antes de ejecutar al hijo.
@export var tiempo_espera: float = 1.0
## Si es true, el retardo se repite cada vez que el nodo es re-entrado.
## Si es false, solo espera la primera vez; en re-entradas ejecuta al hijo directo.
@export var reiniciar_al_entrar: bool = true

# Marca de tiempo en que empezó la espera actual.
var _tiempo_inicio: float = -1.0
# Si ya terminó la espera en este ciclo.
var _espera_completada: bool = false


func _on_entrar() -> void:
	super._on_entrar()
	if reiniciar_al_entrar or _tiempo_inicio < 0.0:
		_tiempo_inicio = Time.get_ticks_msec() / 1000.0
		_espera_completada = false
		if debug_activo:
			print_rich(
				"[color=yellow][BT ⏳][/color] Retardo [b]%s[/b]: esperando %.1fs..."
				% [nombre_nodo, tiempo_espera]
			)


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tiempo_inicio = -1.0
	_espera_completada = false


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Retardo '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Si la espera ya terminó en un tick anterior, ejecutar el hijo directo.
	if _espera_completada:
		return _hijo.ejecutar()

	var ahora: float = Time.get_ticks_msec() / 1000.0
	var transcurrido: float = ahora - _tiempo_inicio

	if transcurrido < tiempo_espera:
		if debug_activo:
			print_rich(
				"[color=yellow][BT ⏳][/color] Retardo [b]%s[/b]: %.1f / %.1fs"
				% [nombre_nodo, transcurrido, tiempo_espera]
			)
		return Estado.EN_EJECUCION

	# Espera terminada: ejecutar el hijo por primera vez.
	_espera_completada = true
	if debug_activo:
		print_rich(
			"[color=green][BT ⏳][/color] Retardo [b]%s[/b]: listo, ejecutando hijo."
			% nombre_nodo
		)
	return _hijo.ejecutar()
