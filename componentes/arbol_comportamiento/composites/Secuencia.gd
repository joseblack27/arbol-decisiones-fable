# =============================================================================
# Secuencia.gd  (Composite — AND lógico)
# Ejecuta sus hijos en orden. Equivale a un "Y" lógico:
#   • Retorna EXITOSO  → solo si TODOS los hijos retornan EXITOSO.
#   • Retorna FALLIDO  → en cuanto cualquier hijo retorna FALLIDO.
#   • Retorna EN_EJECUCION → mientras el hijo actual aún está procesando.
#
# USO EN ESCENA: Añade hijos NodoBT directamente como nodos hijo de Secuencia.
# =============================================================================
class_name Secuencia
extends NodoComposite


func _on_ejecutar() -> Estado:
	if _hijos.is_empty():
		push_warning("Secuencia '%s': No tiene hijos NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Continúa desde donde se quedó (soporte para EN_EJECUCION entre ticks).
	while _indice_actual < _hijos.size():
		var resultado: Estado = _hijos[_indice_actual].ejecutar()

		match resultado:
			Estado.EXITOSO:
				# Avanza al siguiente hijo.
				_indice_actual += 1

			Estado.FALLIDO:
				# Falla toda la secuencia y reinicia el cursor.
				_indice_actual = 0
				return Estado.FALLIDO

			Estado.EN_EJECUCION:
				# Espera; el mismo hijo se ejecutará en el próximo tick.
				return Estado.EN_EJECUCION

	# Todos los hijos terminaron con EXITOSO.
	_indice_actual = 0
	return Estado.EXITOSO


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_indice_actual = 0
