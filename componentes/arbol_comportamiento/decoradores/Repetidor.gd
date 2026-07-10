# =============================================================================
# Repetidor.gd  (Decorador)
# Repite la ejecución de su hijo un número de veces configurable.
#   • repeticiones = -1  → bucle infinito (útil para comportamientos continuos).
#   • repetir_si_falla   → si es false, el Repetidor retorna FALLIDO al primer fallo.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Repetidor.
# =============================================================================
class_name Repetidor
extends NodoDecorador

@export_group("Configuración Repetidor")
## Número de veces a repetir. Usa -1 para repetición infinita.
@export var repeticiones: int = -1
## Si es false, el repetidor se detiene y retorna FALLIDO cuando el hijo falla.
@export var repetir_si_falla: bool = false

var _contador: int = 0


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_contador = 0


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Repetidor '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Bucle de repetición. Si el hijo retorna EN_EJECUCION,
	# se retorna inmediatamente para continuar en el próximo tick.
	while repeticiones == -1 or _contador < repeticiones:
		var resultado: Estado = _hijo.ejecutar()

		match resultado:
			Estado.EN_EJECUCION:
				return Estado.EN_EJECUCION

			Estado.FALLIDO:
				if not repetir_si_falla:
					_contador = 0
					return Estado.FALLIDO
				_hijo.reiniciar()
				_contador += 1

			Estado.EXITOSO:
				_hijo.reiniciar()
				_contador += 1

	# Se completaron todas las repeticiones.
	_contador = 0
	return Estado.EXITOSO
