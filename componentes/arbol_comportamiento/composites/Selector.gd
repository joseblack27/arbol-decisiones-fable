# =============================================================================
# Selector.gd  (Composite — OR lógico)
# Ejecuta sus hijos en orden. Equivale a un "O" lógico:
#   • Retorna EXITOSO    → en cuanto cualquier hijo retorna EXITOSO.
#   • Retorna FALLIDO    → solo si TODOS los hijos retornan FALLIDO.
#   • Retorna EN_EJECUCION → mientras el hijo actual aún está procesando.
#
# USO EN ESCENA: Añade hijos NodoBT directamente como nodos hijo de Selector.
# =============================================================================
class_name Selector
extends NodoComposite


func _on_ejecutar() -> Estado:
	if _hijos.is_empty():
		push_warning("Selector '%s': No tiene hijos NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Continúa desde donde se quedó (soporte para EN_EJECUCION entre ticks).
	while _indice_actual < _hijos.size():
		var resultado: Estado = _hijos[_indice_actual].ejecutar()

		match resultado:
			Estado.EXITOSO:
				# Cualquier éxito termina el selector con éxito.
				_indice_actual = 0
				return Estado.EXITOSO

			Estado.FALLIDO:
				# Prueba el siguiente hijo.
				_indice_actual += 1

			Estado.EN_EJECUCION:
				# Espera; el mismo hijo se ejecutará en el próximo tick.
				return Estado.EN_EJECUCION

	# Ningún hijo tuvo éxito.
	_indice_actual = 0
	return Estado.FALLIDO


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_indice_actual = 0
