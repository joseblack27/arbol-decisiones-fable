# =============================================================================
# NodoBT.gd
# Clase BASE ABSTRACTA para todos los nodos del Árbol de Comportamiento.
# NO usar directamente en escena — extender para crear nodos concretos.
# =============================================================================
class_name NodoBT
extends Node

## Estados posibles que puede retornar un nodo al ejecutarse.
enum Estado {
	EXITOSO,      ## El nodo completó su tarea con éxito.
	FALLIDO,      ## El nodo no pudo completar su tarea.
	EN_EJECUCION  ## El nodo sigue procesando (requiere múltiples ticks).
}

@export_group("Identificación")
## Nombre descriptivo del nodo para logs y debug.
@export var nombre_nodo: String = "NodoBT"

@export_group("Debug")
## Activa mensajes de debug para este nodo específico.
@export var debug_activo: bool = false

# ─── Estado interno ────────────────────────────────────────────────────────────
var _estado_actual: Estado = Estado.FALLIDO
var _en_ejecucion: bool = false
var _memoria: MemoriaBT
## Tick del BT en el que este nodo fue evaluado por última vez.
## Usado por DepuradorBT para distinguir nodos activos de nodos no evaluados.
var _ultimo_tick: int = -1


# =============================================================================
# API PÚBLICA
# =============================================================================

## Inicializa el nodo y todos sus hijos NodoBT con la memoria compartida.
## Llamado automáticamente por ArbolComportamiento al inicio.
func inicializar(memoria: MemoriaBT) -> void:
	_memoria = memoria
	_on_inicializar()
	for hijo in get_children():
		if hijo is NodoBT:
			hijo.inicializar(memoria)


## Ejecuta el nodo y retorna su Estado.
## Gestiona automáticamente los callbacks _on_entrar / _on_salir.
func ejecutar() -> Estado:
	# Registrar en qué tick fue evaluado este nodo (usado por DepuradorBT).
	if _memoria:
		_ultimo_tick = _memoria.obtener("__bt_tick", 0)

	if not _en_ejecucion:
		_en_ejecucion = true
		_on_entrar()

	_estado_actual = _on_ejecutar()

	if _estado_actual != Estado.EN_EJECUCION:
		_en_ejecucion = false
		_on_salir(_estado_actual)

	return _estado_actual


## Reinicia el nodo a su estado inicial.
## Llamado automáticamente al reiniciar el árbol.
func reiniciar() -> void:
	_estado_actual = Estado.FALLIDO
	_en_ejecucion = false
	_on_reiniciar()


## Retorna el último estado registrado del nodo.
func obtener_estado() -> Estado:
	return _estado_actual


# =============================================================================
# MÉTODOS SOBREESCRIBIBLES (callbacks internos)
# =============================================================================

## [OVERRIDE OPCIONAL] Llamado una vez al inicializar el árbol.
## Úsalo para cachear referencias o pre-calcular valores.
func _on_inicializar() -> void:
	pass


## [OVERRIDE OBLIGATORIO en subclases concretas]
## Lógica principal del nodo. Debe retornar EXITOSO, FALLIDO o EN_EJECUCION.
func _on_ejecutar() -> Estado:
	push_error(
		"NodoBT: '_on_ejecutar()' no fue sobreescrito en el nodo '%s' (%s)."
		% [nombre_nodo, get_script().resource_path]
	)
	return Estado.FALLIDO


## [OVERRIDE OPCIONAL] Llamado la primera vez que el nodo entra en ejecución.
func _on_entrar() -> void:
	if debug_activo:
		print_rich("[color=cyan][BT →][/color] Entrando: [b]%s[/b]" % nombre_nodo)


## [OVERRIDE OPCIONAL] Llamado cuando el nodo termina (EXITOSO o FALLIDO).
func _on_salir(estado: Estado) -> void:
	if debug_activo:
		var color := "green" if estado == Estado.EXITOSO else "red"
		var texto := "EXITOSO" if estado == Estado.EXITOSO else "FALLIDO"
		print_rich(
			"[color=%s][BT ←][/color] Saliendo: [b]%s[/b] → %s" % [color, nombre_nodo, texto]
		)


## [OVERRIDE OPCIONAL] Llamado al reiniciar el nodo.
func _on_reiniciar() -> void:
	pass
