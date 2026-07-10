# =============================================================================
# MemoriaBT.gd  (Pizarrón / Blackboard)
# Memoria compartida del Árbol de Comportamiento.
#
# Todos los nodos del árbol acceden a esta memoria para leer y escribir datos.
# También puede MONITORIZAR propiedades de otros nodos automáticamente,
# actualizando los valores cada frame para que el árbol reaccione a ellos.
#
# FORMAS DE POBLAR LA MEMORIA:
#   1. Desde el Inspector: añade entradas en "variables_iniciales".
#   2. Desde código externo: llama a memoria.establecer("clave", valor).
#   3. Monitoreo automático: añade MonitorVariable en "monitores_exportados".
#   4. Desde el árbol: cualquier Accion puede escribir en _memoria.
# =============================================================================
class_name MemoriaBT
extends Node

@export_group("Identificación")
@export var nombre_nodo: String = "MemoriaBT"

@export_group("Debug")
## Imprime en consola cada cambio de variable.
@export var debug_activo: bool = false

@export_group("Variables Iniciales")
## Variables que se cargan al inicio. Clave → Valor (cualquier tipo básico).
## Ejemplo: { "vida": 100, "en_alerta": false, "objetivo": null }
@export var variables_iniciales: Dictionary = {}

@export_group("Monitores")
## Array de MonitorVariable. Cada entrada sincroniza la propiedad de un nodo
## de la escena con un nombre en esta memoria, actualizándose cada frame.
@export var monitores_exportados: Array[MonitorVariable] = []

# ─── Estado interno ────────────────────────────────────────────────────────────
# Diccionario principal de datos.
var _datos: Dictionary = {}
# Monitores registrados en tiempo de ejecución: nombre → {nodo, propiedad}.
var _monitores_runtime: Dictionary = {}

## Emitida cada vez que una variable cambia de valor.
signal variable_cambiada(nombre: String, valor_anterior: Variant, valor_nuevo: Variant)


# =============================================================================
# CICLO DE VIDA
# =============================================================================

func _ready() -> void:
	# Carga variables iniciales definidas en el inspector.
	for clave in variables_iniciales:
		_datos[clave] = variables_iniciales[clave]

	# Registra los monitores exportados desde el inspector.
	for monitor in monitores_exportados:
		if monitor and not monitor.nombre_variable.is_empty() and not monitor.ruta_nodo.is_empty():
			var nodo = get_node_or_null(monitor.ruta_nodo)
			if nodo:
				monitorizar(monitor.nombre_variable, nodo, monitor.propiedad)
			else:
				push_warning(
					"MemoriaBT '%s': No se encontró el nodo en ruta '%s' para monitorizar '%s'."
					% [nombre_nodo, monitor.ruta_nodo, monitor.nombre_variable]
				)

	if debug_activo:
		print_rich(
			"[color=magenta][MemoriaBT][/color] [b]%s[/b] lista. Variables: %d | Monitores: %d"
			% [nombre_nodo, _datos.size(), _monitores_runtime.size()]
		)


func _process(_delta: float) -> void:
	# Sincroniza las propiedades monitoreadas con la memoria.
	for nombre_var: String in _monitores_runtime:
		var info: Dictionary = _monitores_runtime[nombre_var]
		if is_instance_valid(info["nodo"]):
			var nuevo_valor = info["nodo"].get(info["propiedad"])
			# Solo actualiza si el valor realmente cambió.
			if _datos.get(nombre_var) != nuevo_valor:
				establecer(nombre_var, nuevo_valor)


# =============================================================================
# API PÚBLICA
# =============================================================================

## Guarda un valor en la memoria bajo el nombre indicado.
## Si el valor cambia, emite la señal variable_cambiada.
func establecer(nombre: String, valor: Variant) -> void:
	var anterior: Variant = _datos.get(nombre, null)
	_datos[nombre] = valor
	if anterior != valor:
		if debug_activo:
			print_rich(
				"[color=magenta][MemoriaBT][/color] [b]%s[/b] → [i]%s[/i]: %s → %s"
				% [nombre_nodo, nombre, str(anterior), str(valor)]
			)
		variable_cambiada.emit(nombre, anterior, valor)


## Retorna el valor de la variable o `defecto` si no existe.
func obtener(nombre: String, defecto: Variant = null) -> Variant:
	return _datos.get(nombre, defecto)


## Retorna true si la variable existe en la memoria (incluso si su valor es null).
func existe(nombre: String) -> bool:
	return _datos.has(nombre)


## Elimina una variable de la memoria.
func eliminar(nombre: String) -> void:
	if _datos.has(nombre):
		var anterior = _datos[nombre]
		_datos.erase(nombre)
		if debug_activo:
			print_rich(
				"[color=magenta][MemoriaBT][/color] [b]%s[/b] → eliminada: [i]%s[/i] (era: %s)"
				% [nombre_nodo, nombre, str(anterior)]
			)


## Registra en tiempo de ejecución un nodo para monitorizar una de sus propiedades.
## Cada frame, el valor de nodo.propiedad se copiará automáticamente a nombre_variable.
func monitorizar(nombre_variable: String, nodo: Node, propiedad: String) -> void:
	if nombre_variable.is_empty() or propiedad.is_empty():
		push_warning("MemoriaBT '%s': monitorizar() recibió nombre o propiedad vacíos." % nombre_nodo)
		return
	_monitores_runtime[nombre_variable] = { "nodo": nodo, "propiedad": propiedad }
	if debug_activo:
		print_rich(
			"[color=magenta][MemoriaBT][/color] Monitorizando [b]%s.%s[/b] → [i]%s[/i]"
			% [nodo.name, propiedad, nombre_variable]
		)


## Detiene el monitoreo de una variable registrada en runtime.
func detener_monitoreo(nombre_variable: String) -> void:
	if _monitores_runtime.has(nombre_variable):
		_monitores_runtime.erase(nombre_variable)


## Retorna una copia de todos los datos actuales de la memoria (solo lectura).
func obtener_todos() -> Dictionary:
	return _datos.duplicate()


## Limpia toda la memoria (datos + monitores runtime). No afecta variables_iniciales.
func limpiar() -> void:
	_datos.clear()
	_monitores_runtime.clear()


## Imprime el estado completo de la memoria en consola. Útil para debug manual.
func imprimir_estado() -> void:
	print_rich("\n[color=magenta]╔══════════════════════════════════╗[/color]")
	print_rich("[color=magenta]║     MemoriaBT: [b]%-18s[/b] ║[/color]" % nombre_nodo)
	print_rich("[color=magenta]╠══════════════════════════════════╣[/color]")
	if _datos.is_empty():
		print_rich("[color=magenta]║[/color]  (sin variables)")
	else:
		for clave in _datos:
			print_rich("[color=magenta]║[/color]  [i]%-16s[/i] = %s" % [clave, str(_datos[clave])])
	if not _monitores_runtime.is_empty():
		print_rich("[color=magenta]╠══ Monitores activos ═════════════╣[/color]")
		for nombre_var in _monitores_runtime:
			var info = _monitores_runtime[nombre_var]
			print_rich(
				"[color=magenta]║[/color]  [i]%s[/i] ← %s.%s"
				% [nombre_var, info["nodo"].name, info["propiedad"]]
			)
	print_rich("[color=magenta]╚══════════════════════════════════╝[/color]\n")
