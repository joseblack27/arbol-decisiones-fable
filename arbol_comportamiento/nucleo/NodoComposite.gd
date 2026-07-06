# =============================================================================
# NodoComposite.gd
# Clase BASE ABSTRACTA para nodos compuestos (Secuencia, Selector, Paralelo).
# Gestiona automáticamente la lista de hijos NodoBT.
# NO usar directamente — extender para crear composites concretos.
# =============================================================================
class_name NodoComposite
extends NodoBT

# Lista de hijos NodoBT recopilada automáticamente al inicializar.
var _hijos: Array[NodoBT] = []
# Índice del hijo que se está ejecutando actualmente.
var _indice_actual: int = 0


func _ready() -> void:
	_recopilar_hijos()


# Recorre los hijos del nodo y almacena los que son NodoBT.
func _recopilar_hijos() -> void:
	_hijos.clear()
	for hijo in get_children():
		if hijo is NodoBT:
			_hijos.append(hijo)
	if debug_activo:
		print_rich(
			"[color=yellow][BT][/color] Composite [b]%s[/b]: %d hijos encontrados." % [nombre_nodo, _hijos.size()]
		)


func _on_inicializar() -> void:
	_recopilar_hijos()


func _on_reiniciar() -> void:
	_indice_actual = 0
	for hijo in _hijos:
		hijo.reiniciar()
