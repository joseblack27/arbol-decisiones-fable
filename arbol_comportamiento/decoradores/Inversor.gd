# =============================================================================
# Inversor.gd  (Decorador — NOT lógico)
# Invierte el resultado del único hijo NodoBT:
#   • EXITOSO    → FALLIDO
#   • FALLIDO    → EXITOSO
#   • EN_EJECUCION → EN_EJECUCION (sin cambios, espera el resultado final)
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Inversor.
# =============================================================================
class_name Inversor
extends NodoDecorador


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Inversor '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	match _hijo.ejecutar():
		Estado.EXITOSO:
			return Estado.FALLIDO
		Estado.FALLIDO:
			return Estado.EXITOSO
		_:
			return Estado.EN_EJECUCION
