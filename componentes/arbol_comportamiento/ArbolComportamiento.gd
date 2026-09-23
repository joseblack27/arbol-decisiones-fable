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
## Radio (px) dentro del cual tiene que haber AL MENOS un jugador para que
## este árbol siga tickeando -- más allá, se "duerme" solo (deja de correr
## actualizar()) hasta que alguien vuelva a acercarse. Costo real medido en
## producción (ver "[CARGA]"/ServidorDedicado._reportar_capacidad): con
## varias decenas de mobs activos, "arboles=" (el tiempo evaluando árboles
## de TODOS los mobs) es la línea que más escala con la cantidad de mobs --
## y en un nivel grande (Camino, Hormiguero) la mayoría puede estar lejos de
## cualquier jugador en un momento dado, pensando en vano. Mismo radio que
## InteresEspacial.RADIO_INTERES a propósito: si nadie está lo bastante
## cerca como para que este mob se replique en red, tampoco hay razón para
## que piense -- nadie lo está mirando de ningún modo. 0 = nunca duerme
## (dejarlo así en una escena puntual que necesite pensar siempre, p. ej. un
## NPC errante cuya rutina dependa del reloj del mundo más que de si hay
## alguien cerca).
@export var radio_actividad: float = 1400.0

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

## Revisar "¿hay algún jugador cerca?" no necesita la frecuencia del propio
## tick del árbol (0.1s) -- un mob tarda un rato en volverse relevante o
## dejar de serlo, así que revisarlo cada _INTERVALO_REVISION_SUEÑO alcanza
## y evita sumar un chequeo de distancia por mob en CADA fotograma físico.
const _INTERVALO_REVISION_SUEÑO := 1.5
var _tiempo_para_revisar_sueño: float = 0.0
## Bandera PROPIA, separada de "activo" a propósito: "activo" ya lo usan
## los jefes para pausar el árbol durante transiciones de fase (ver
## Enemigo._telegrafiar_pausa_de_fase) -- mezclar ambas haría que este mob
## se "despertara" solo a mitad de una pausa de fase que todavía debía
## seguir, o que una pausa de fase real quedara pisada por un despertar por
## distancia. Se combinan en _process() (ver abajo), nunca se escriben una
## a la otra.
var _dormido_por_distancia: bool = false

## INSTRUMENTACIÓN TEMPORAL — microsegundos acumulados evaluando árboles de
## comportamiento (actualizar(), de TODOS los mobs) desde el último reporte
## de ServidorDedicado._reportar_capacidad(), que lo lee y lo resetea cada
## _INTERVALO_REPORTE. Objetivo: separar cuánto del costo idle sostenido
## medido en producción (Performance.TIME_PROCESS, "proceso=" en el log
## [CARGA]) es evaluar el árbol de cada mob en combate, contra el resto
## (el aviso RPC de cada habilidad usada, ver HabilidadBase._disparar).
## static: un contador ÚNICO compartido por todas las instancias (cada mob
## tiene la suya de ArbolComportamiento), no uno por mob — sumar todos a
## mano en cada reporte sería más caro que la propia medición.
static var us_acumulados_todos_los_arboles: int = 0

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
	if radio_actividad > 0.0:
		_tiempo_para_revisar_sueño -= delta
		if _tiempo_para_revisar_sueño <= 0.0:
			_tiempo_para_revisar_sueño = _INTERVALO_REVISION_SUEÑO
			_revisar_sueño_por_distancia()
		if _dormido_por_distancia:
			return
	_tiempo_acumulado += delta
	if _tiempo_acumulado >= intervalo_tick:
		_tiempo_acumulado = 0.0
		var _inicio_us := Time.get_ticks_usec()
		actualizar()
		us_acumulados_todos_los_arboles += Time.get_ticks_usec() - _inicio_us


## SERVIDOR (ver el gate de arriba, nunca corre en cliente): "duerme" el
## árbol si ningún jugador está a radio_actividad o menos del agente.
## Utils.en_red()==false (un solo jugador, sin red) nunca duerme --
## InteresEspacial.peers_cercanos() vive de la lista de peers conectados,
## que en ese modo siempre da vacía, y dormir SIEMPRE ahí apagaría la IA
## por completo en partidas de un jugador.
func _revisar_sueño_por_distancia() -> void:
	if not Utils.en_red():
		_dormido_por_distancia = false
		return
	if not is_instance_valid(_agente) or not (_agente is Node2D):
		return
	var posicion := (_agente as Node2D).global_position
	_dormido_por_distancia = not InteresEspacial.hay_jugador_cerca(posicion, radio_actividad)


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
