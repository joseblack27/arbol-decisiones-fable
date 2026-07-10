# =============================================================================
# ArbolComportamiento.gd  (Raíz / Controlador)
#
# Nodo raíz que gestiona y ejecuta el Árbol de Comportamiento.
# Debe ser el nodo padre de toda la jerarquía BT en la escena.
#
# ESTRUCTURA DE ESCENA ESPERADA:
# ─────────────────────────────────────────────────────────────────────────────
#   ┌─ ArbolComportamiento          ← Este nodo
#   │   ├─ MemoriaBT                ← Pizarrón compartido (requerido)
#   │   └─ Selector                 ← Primer hijo NodoBT = nodo raíz del árbol
#   │       ├─ Secuencia
#   │       │   ├─ Condicion...
#   │       │   └─ Accion...
#   │       └─ Accion...
#
# COEXISTENCIA CON MÁQUINA DE ESTADOS:
#   • Llama a establecer_activo(false) para pausar el árbol.
#   • Llama a reiniciar() al cambiar de estado para limpiar la ejecución.
#   • Expone obtener_memoria() para que la máquina de estados escriba datos.
# =============================================================================
class_name ArbolComportamiento
extends Node

@export_group("Identificación")
@export var nombre_nodo: String = "ArbolComportamiento"

@export_group("Configuración")
## Si es false, el árbol no se actualiza en _process.
@export var activo: bool = true
## Ruta al nodo que este árbol controla (personaje, enemigo, NPC, etc.).
## Se almacena automáticamente en la MemoriaBT bajo la clave "agente".
@export var agente: NodePath
@export var intervalo_tick: float = 0.1  # 10 veces/seg en vez de 60

@export_group("Memoria")
## Ruta al nodo MemoriaBT. Si se deja vacío, se busca automáticamente
## entre los hijos directos de ArbolComportamiento.
@export var ruta_memoria: NodePath

@export_group("Debug")
## Muestra en consola cada tick del árbol con el resultado final.
@export var debug_activo: bool = false
## Imprime el estado completo de la MemoriaBT después de cada tick.
@export var debug_imprimir_memoria: bool = false

# ─── Referencias internas ─────────────────────────────────────────────────────
var _nodo_raiz: NodoBT = null
var _memoria: MemoriaBT = null
var _agente: Node = null
var _tiempo_acumulado: float = 0.0
## Número de ticks ejecutados. DepuradorBT lo usa para detectar nodos no evaluados.
var tick_actual: int = 0

## Emitida al final de cada tick con el estado resultante del árbol.
signal arbol_actualizado(estado: NodoBT.Estado)


# =============================================================================
# CICLO DE VIDA
# =============================================================================

func _ready() -> void:
	_resolver_memoria()
	_resolver_agente()
	_resolver_nodo_raiz()
	_inicializar_arbol()


func _process(delta: float) -> void:
	if not activo:
		return
	# Fase 5 del plan de multijugador: en red, la IA solo decide en el
	# SERVIDOR — el cliente ve al mob moverse por la posición replicada
	# (ver Enemigo._enter_tree), nunca corriendo su propia copia del árbol
	# (que divergiría del resultado real). Sin multiplayer activo (un solo
	# jugador, de siempre) esto no cambia nada.
	if Utils.en_red() and not multiplayer.is_server():
		return
	_tiempo_acumulado += delta
	if _tiempo_acumulado >= intervalo_tick:
		_tiempo_acumulado = 0.0
		actualizar()


# =============================================================================
# API PÚBLICA
# =============================================================================

## Ejecuta un tick manual del árbol.
## Útil cuando activo = false y quieres controlar cuándo se actualiza.
func actualizar() -> NodoBT.Estado:
	if not _nodo_raiz:
		return NodoBT.Estado.FALLIDO

	if debug_activo:
		print_rich(
			"\n[color=cyan][ArbolBT][/color] ══ Tick: [b]%s[/b] ══" % nombre_nodo
		)

	# Incrementar contador de tick para que DepuradorBT detecte nodos no evaluados.
	tick_actual += 1
	if _memoria:
		_memoria.establecer("__bt_tick", tick_actual)

	var estado: NodoBT.Estado = _nodo_raiz.ejecutar()

	if debug_activo:
		var color := "green" if estado == NodoBT.Estado.EXITOSO \
			else ("orange" if estado == NodoBT.Estado.EN_EJECUCION else "red")
		var nombre_estado := _nombre_estado(estado)
		print_rich(
			"[color=cyan][ArbolBT][/color] ══ Resultado: [color=%s][b]%s[/b][/color] ══\n"
			% [color, nombre_estado]
		)

	if debug_imprimir_memoria and _memoria:
		_memoria.imprimir_estado()

	arbol_actualizado.emit(estado)
	return estado


## Activa o desactiva el árbol.
## Al desactivar, el árbol deja de ejecutarse en _process.
func establecer_activo(valor: bool) -> void:
	activo = valor
	if debug_activo:
		print_rich(
			"[color=cyan][ArbolBT][/color] [b]%s[/b] → activo: %s"
			% [nombre_nodo, str(valor)]
		)


## Reinicia completamente el árbol (útil al cambiar de estado en la máquina de estados).
func reiniciar() -> void:
	if _nodo_raiz:
		_nodo_raiz.reiniciar()
	if debug_activo:
		print_rich("[color=cyan][ArbolBT][/color] [b]%s[/b] reiniciado." % nombre_nodo)


## Retorna la MemoriaBT asociada a este árbol.
func obtener_memoria() -> MemoriaBT:
	return _memoria


## Retorna el nodo agente asociado a este árbol.
func obtener_agente() -> Node:
	return _agente


## Escribe un valor en la memoria directamente desde fuera del árbol.
## Útil para que la máquina de estados comunique datos al árbol.
func escribir_en_memoria(nombre: String, valor: Variant) -> void:
	if _memoria:
		_memoria.establecer(nombre, valor)


## Lee un valor de la memoria desde fuera del árbol.
func leer_de_memoria(nombre: String, defecto: Variant = null) -> Variant:
	if _memoria:
		return _memoria.obtener(nombre, defecto)
	return defecto


# =============================================================================
# MÉTODOS PRIVADOS
# =============================================================================

func _resolver_memoria() -> void:
	if ruta_memoria and not ruta_memoria.is_empty():
		_memoria = get_node_or_null(ruta_memoria)
	if not _memoria:
		for hijo in get_children():
			if hijo is MemoriaBT:
				_memoria = hijo
				break
	if not _memoria:
		push_warning(
			"ArbolComportamiento '%s': No se encontró MemoriaBT. "
			% nombre_nodo +
			"Añade un nodo MemoriaBT como hijo o asigna 'ruta_memoria'."
		)
		# Crea una memoria vacía para evitar errores null.
		_memoria = MemoriaBT.new()
		_memoria.nombre_nodo = "MemoriaBT_Auto"
		add_child(_memoria)


func _resolver_agente() -> void:
	if agente and not agente.is_empty():
		_agente = get_node_or_null(agente)
		if _agente and _memoria:
			_memoria.establecer("agente", _agente)
		elif not _agente:
			push_warning(
				"ArbolComportamiento '%s': No se encontró el agente en la ruta '%s'."
				% [nombre_nodo, str(agente)]
			)


func _resolver_nodo_raiz() -> void:
	var hijos = get_children()
	for hijo in hijos:
		if hijo is NodoBT:
			_nodo_raiz = hijo
			return
	push_error(
		"ArbolComportamiento '%s': No se encontró ningún NodoBT hijo como raíz del árbol. "
		% nombre_nodo +
		"Añade un nodo Secuencia, Selector u otro NodoBT como hijo directo."
	)


func _inicializar_arbol() -> void:
	if not _nodo_raiz or not _memoria:
		return
	_nodo_raiz.inicializar(_memoria)
	if debug_activo:
		print_rich(
			"[color=cyan][ArbolBT][/color] [b]%s[/b] inicializado." % nombre_nodo
		)
		print_rich(
			"[color=cyan][ArbolBT][/color] Nodo raíz: [b]%s[/b]" % _nodo_raiz.nombre_nodo
		)
		if _agente:
			print_rich(
				"[color=cyan][ArbolBT][/color] Agente: [b]%s[/b]" % _agente.name
			)


func _nombre_estado(estado: NodoBT.Estado) -> String:
	match estado:
		NodoBT.Estado.EXITOSO:     return "EXITOSO"
		NodoBT.Estado.FALLIDO:     return "FALLIDO"
		NodoBT.Estado.EN_EJECUCION: return "EN_EJECUCION"
	return "DESCONOCIDO"
