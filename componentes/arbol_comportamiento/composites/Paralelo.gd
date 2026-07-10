# =============================================================================
# Paralelo.gd  (Composite — ejecución simultánea)
# Ejecuta TODOS sus hijos en cada tick (no se detiene al fallar/éxito uno).
# El resultado global depende de las políticas configuradas:
#
#   PoliticaExito:
#     TODOS → EXITOSO cuando TODOS los hijos terminen en EXITOSO.
#     UNO   → EXITOSO cuando AL MENOS UNO termine en EXITOSO.
#
#   PoliticaFallo:
#     UNO   → FALLIDO en cuanto CUALQUIER hijo retorne FALLIDO.
#     TODOS → FALLIDO solo si TODOS los hijos retornan FALLIDO.
#
# USO EN ESCENA: Añade hijos NodoBT directamente como nodos hijo de Paralelo.
# =============================================================================
class_name Paralelo
extends NodoComposite


enum PoliticaExito {
	TODOS, ## EXITOSO cuando todos los hijos terminan con éxito.
	UNO    ## EXITOSO cuando al menos un hijo tiene éxito.
}

enum PoliticaFallo {
	UNO,   ## FALLIDO en cuanto un hijo falla.
	TODOS  ## FALLIDO solo si todos los hijos fallan.
}

@export_group("Configuración Paralelo")
@export var politica_exito: PoliticaExito = PoliticaExito.TODOS
@export var politica_fallo: PoliticaFallo = PoliticaFallo.UNO

# Caché de los estados de cada hijo para no re-ejecutar los que ya terminaron.
var _estados_hijos: Array[Estado] = []


func _on_entrar() -> void:
	super._on_entrar()
	# Inicializa todos los hijos como EN_EJECUCION al empezar.
	_estados_hijos.clear()
	for _hijo in _hijos:
		_estados_hijos.append(Estado.EN_EJECUCION)


func _on_ejecutar() -> Estado:
	if _hijos.is_empty():
		push_warning("Paralelo '%s': No tiene hijos NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	# Asegura que el array de estados esté inicializado.
	if _estados_hijos.size() != _hijos.size():
		_estados_hijos.resize(_hijos.size())
		_estados_hijos.fill(Estado.EN_EJECUCION)

	# Ejecuta solo los hijos que todavía están en curso.
	for i in _hijos.size():
		if _estados_hijos[i] == Estado.EN_EJECUCION:
			_estados_hijos[i] = _hijos[i].ejecutar()

	var exitosos: int = _estados_hijos.count(Estado.EXITOSO)
	var fallidos: int  = _estados_hijos.count(Estado.FALLIDO)

	# Evalúa política de fallo primero (tiene prioridad).
	match politica_fallo:
		PoliticaFallo.UNO:
			if fallidos > 0:
				_estados_hijos.clear()
				return Estado.FALLIDO
		PoliticaFallo.TODOS:
			if fallidos == _hijos.size():
				_estados_hijos.clear()
				return Estado.FALLIDO

	# Evalúa política de éxito.
	match politica_exito:
		PoliticaExito.TODOS:
			if exitosos == _hijos.size():
				_estados_hijos.clear()
				return Estado.EXITOSO
		PoliticaExito.UNO:
			if exitosos > 0:
				_estados_hijos.clear()
				return Estado.EXITOSO

	return Estado.EN_EJECUCION


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_estados_hijos.clear()
