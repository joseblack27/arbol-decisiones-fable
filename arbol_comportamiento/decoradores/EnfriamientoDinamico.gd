# =============================================================================
# EnfriamientoDinamico.gd  (Decorador)
#
# Cooldown activado y configurado desde la MemoriaBT en tiempo de ejecución.
# A diferencia de Enfriamiento, NO empieza a contar cuando el hijo termina.
# Empieza cuando ALGUIEN escribe un valor > 0 en la clave configurada.
#
# Flujo:
#   1. En reposo → ejecuta al hijo con normalidad.
#   2. Cualquier nodo del árbol (o el Enemigo) escribe:
#        _memoria.establecer("mi_clave", 3.0)   ← duración en segundos
#   3. El decorador detecta el cambio, bloquea el hijo durante 3s.
#   4. Durante el bloqueo → retorna FALLIDO sin llamar al hijo.
#   5. Al expirar → borra la clave de la memoria y vuelve al paso 1.
#
# POSICIÓN RECOMENDADA EN EL ÁRBOL:
#   Envuelve el nodo padre de la rama que quieres bloquear:
#
#   Selector
#   └─ EnfriamientoDinamico          ← aquí
#       └─ Secuencia
#           ├─ Inversor
#           │   └─ CondicionMemoriaEstado
#           ├─ CondicionMemoriaJugadorDetectado
#           └─ AccionCambiarEstado
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de EnfriamientoDinamico.
# =============================================================================
class_name EnfriamientoDinamico
extends NodoDecorador

@export_group("Configuración")
## Clave en la MemoriaBT que activa y define la duración del bloqueo.
## Escribe un float > 0 en esta clave para iniciar el cooldown.
## El decorador la limpia automáticamente al expirar.
@export var clave_duracion: String = "cooldown_estado"

## Si es true, interrumpe al hijo si está EN_EJECUCION cuando se activa el cooldown.
@export var interrumpir_si_activo: bool = true

# ─── Estado interno ────────────────────────────────────────────────────────────
var _bloqueado: bool = false
var _tiempo_fin: float = 0.0


func _on_inicializar() -> void:
	super._on_inicializar()
	if _memoria:
		# Escucha cambios en la memoria para detectar cuando se activa el cooldown.
		_memoria.variable_cambiada.connect(_on_variable_memoria_cambiada)


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_bloqueado = false
	_tiempo_fin = 0.0


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("EnfriamientoDinamico '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Si el bloqueo expiró, limpiarlo.
	if _bloqueado:
		var ahora := Time.get_ticks_msec() / 1000.0
		if ahora >= _tiempo_fin:
			_desactivar_bloqueo()
		else:
			# Sigue bloqueado: muestra tiempo restante en debug y retorna FALLIDO.
			if debug_activo:
				var restante := _tiempo_fin - ahora
				print_rich(
					"[color=orange][BT ❄+][/color] EnfriamientoDinamico [b]%s[/b]"
					% nombre_nodo +
					": bloqueado %.1fs restantes" % restante
				)
			return Estado.FALLIDO

	return _hijo.ejecutar()


# ─── Lógica de activación ──────────────────────────────────────────────────────

func _on_variable_memoria_cambiada(nombre: String, _anterior: Variant, nuevo: Variant) -> void:
	if nombre != clave_duracion:
		return

	# Si se escribe null o 0 o negativo, desactivar si estaba activo.
	if nuevo == null or (nuevo is float and nuevo <= 0.0) or (nuevo is int and nuevo <= 0):
		if _bloqueado:
			_desactivar_bloqueo()
		return

	# Valor positivo recibido → activar cooldown.
	var duracion := float(nuevo)
	_activar_bloqueo(duracion)


func _activar_bloqueo(duracion: float) -> void:
	# Si hay un hijo ejecutándose y está configurado para interrumpir, reiniciarlo.
	if interrumpir_si_activo and _hijo:
		_hijo.reiniciar()

	_bloqueado = true
	_tiempo_fin = (Time.get_ticks_msec() / 1000.0) + duracion

	if debug_activo:
		print_rich(
			"[color=orange][BT ❄+][/color] EnfriamientoDinamico [b]%s[/b]"
			% nombre_nodo +
			": activado por [i]%s[/i] durante %.1fs" % [clave_duracion, duracion]
		)


func _desactivar_bloqueo() -> void:
	_bloqueado = false
	_tiempo_fin = 0.0
	# Limpia la clave de la memoria para que no quede "sucia".
	if _memoria and _memoria.existe(clave_duracion):
		_memoria.eliminar(clave_duracion)

	if debug_activo:
		print_rich(
			"[color=green][BT ❄+][/color] EnfriamientoDinamico [b]%s[/b]"
			% nombre_nodo +
			": cooldown expirado, reanudando."
		)
