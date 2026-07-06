# =============================================================================
# NodoDecorador.gd
# Clase BASE ABSTRACTA para nodos decoradores (Inversor, Repetidor, etc.).
# Wrappea UN único nodo hijo y modifica su comportamiento o resultado.
# NO usar directamente — extender para crear decoradores concretos.
# =============================================================================
class_name NodoDecorador
extends NodoBT

# Referencia al único hijo NodoBT que este decorador envuelve.
var _hijo: NodoBT = null


func _ready() -> void:
	_obtener_hijo()


# Busca el primer hijo NodoBT y lo almacena como _hijo.
func _obtener_hijo() -> void:
	_hijo = null
	for hijo in get_children():
		if hijo is NodoBT:
			_hijo = hijo
			return
	push_warning(
		"NodoDecorador '%s': No se encontró ningún hijo NodoBT. Coloca un nodo hijo bajo este decorador." % nombre_nodo
	)


func _on_inicializar() -> void:
	_obtener_hijo()


func _on_reiniciar() -> void:
	if _hijo:
		_hijo.reiniciar()
