# =============================================================================
# SelectorHabilidades.gd  (Nodo Hoja)
#
# Elige automáticamente la mejor habilidad disponible según:
#   1. Rango    → la habilidad debe estar dentro del rango al objetivo.
#   2. Cooldown → la habilidad no debe estar en enfriamiento.
#   3. Prioridad → entre las disponibles, se elige la de mayor prioridad.
#
# Al elegir, llama al método configurado en el agente (vía HabilidadBT.metodo_en_agente).
# No sabe nada de qué hace cada habilidad; solo selecciona y delega.
#
# RETORNA:
#   EXITOSO    → encontró y ejecutó una habilidad disponible.
#   FALLIDO    → ninguna habilidad está disponible (rango, cooldown, sin habilidades).
#   (nunca retorna EN_EJECUCION — la ejecución real la maneja el agente/animaciones)
#
# ÁRBOL DE EJEMPLO:
#
#   Selector
#   └─ Secuencia  [Atacar]
#       ├─ CondicionMemoria  "jugador_detectado"
#       └─ SelectorHabilidades
#           habilidades: [ataque_melee.tres, proyectil.tres]
# =============================================================================
class_name SelectorHabilidades
extends NodoHoja

@export_group("Habilidades")
## Lista de habilidades disponibles. Añade aquí tus recursos HabilidadBT.
@export var habilidades: Array[HabilidadBT] = []

@export_group("Claves Memoria")
## Clave en memoria que contiene el Node2D objetivo (para calcular distancia).
@export var clave_objetivo: String = "objetivo"
## Clave donde se escribe el nombre de la habilidad elegida (útil para DepuradorBT y UI).
@export var clave_habilidad_activa: String = "habilidad_activa"

# ─── Estado interno ────────────────────────────────────────────────────────────
# Timestamps de fin de cooldown: nombre_habilidad → tiempo_fin (segundos).
var _cooldowns: Dictionary = {}
## Los avisos de configuración se emiten UNA vez: _on_ejecutar corre en cada
## tick del árbol (~10/s por mob) — sin este corte, un mob mal configurado
## llenaba el log del servidor.
var _aviso_config_emitido := false

## Emitida cuando se elige una habilidad. Útil para conectar UI, audio, etc.
signal habilidad_seleccionada(habilidad: HabilidadBT)
## Emitida cuando ninguna habilidad está disponible.
signal sin_habilidades_disponibles()


# =============================================================================
# EJECUCIÓN
# =============================================================================

func _on_ejecutar() -> Estado:
	if habilidades.is_empty():
		if not _aviso_config_emitido:
			_aviso_config_emitido = true
			push_warning("SelectorHabilidades '%s': No hay habilidades configuradas." % nombre_nodo)
		return Estado.FALLIDO

	var agente: Node    = _memoria.obtener("agente")
	# Validar ANTES de asignar a la variable tipada (Node2D): un objetivo
	# liberado (jugador desconectado en red) revienta la asignación con
	# "Trying to assign invalid previously freed instance".
	var objetivo_raw = _memoria.obtener(clave_objetivo)
	var objetivo: Node2D = objetivo_raw if is_instance_valid(objetivo_raw) else null

	if not agente:
		if not _aviso_config_emitido:
			_aviso_config_emitido = true
			push_warning("SelectorHabilidades '%s': 'agente' no está en la memoria." % nombre_nodo)
		return Estado.FALLIDO

	var distancia: float = _calcular_distancia(agente, objetivo)
	var disponibles := _filtrar_disponibles(distancia, agente)

	if disponibles.is_empty():
		_memoria.establecer(clave_habilidad_activa, null)
		sin_habilidades_disponibles.emit()
		if debug_activo:
			_imprimir_estado_habilidades(distancia)
		return Estado.FALLIDO

	# Ordenar por prioridad (mayor primero) y elegir la primera.
	disponibles.sort_custom(
		func(a: HabilidadBT, b: HabilidadBT) -> bool: return a.prioridad > b.prioridad
	)
	var elegida: HabilidadBT = disponibles[0]

	# Registrar cooldown de la habilidad elegida.
	_iniciar_cooldown(elegida)

	# Guardar en memoria (para debug y para que otros nodos puedan reaccionar).
	_memoria.establecer(clave_habilidad_activa, elegida.nombre)

	# Ejecutar la habilidad: ruta_nodo tiene prioridad sobre metodo_en_agente.
	if not elegida.ruta_nodo.is_empty():
		var nodo := agente.get_node_or_null(elegida.ruta_nodo)
		if nodo == null:
			push_error(
				"SelectorHabilidades '%s': no encontró nodo en ruta '%s' del agente '%s'."
				% [nombre_nodo, elegida.ruta_nodo, agente.name]
			)
			return Estado.FALLIDO
		if not nodo.has_method("activar"):
			push_error(
				"SelectorHabilidades '%s': el nodo '%s' no tiene método activar()."
				% [nombre_nodo, elegida.ruta_nodo]
			)
			return Estado.FALLIDO
		# Apuntar con direccion_mirada (AccionAtacar la mantiene hacia el
		# objetivo durante el combate), no con "direccion" (la de MOVIMIENTO):
		# un kiter dispara quieto o retrocediendo, así que su dirección de
		# movimiento apunta a cualquier lado menos al jugador. Esta dir viaja
		# también al efecto visual replicado en los clientes (ver
		# HabilidadBase._reproducir_visual_red), así que arreglarla acá
		# corrige el apuntado en TODOS lados.
		var dir: Vector2 = Vector2.ZERO
		if "direccion_mirada" in agente and agente.get("direccion_mirada") != Vector2.ZERO:
			dir = agente.get("direccion_mirada")
		elif "direccion" in agente:
			dir = agente.get("direccion")
		nodo.activar(dir, 1.0)
	elif not elegida.metodo_en_agente.is_empty():
		if agente.has_method(elegida.metodo_en_agente):
			agente.call(elegida.metodo_en_agente)
		else:
			push_error(
				"SelectorHabilidades '%s': El agente '%s' no tiene el método '%s'."
				% [nombre_nodo, agente.name, elegida.metodo_en_agente]
			)
			return Estado.FALLIDO

	if debug_activo:
		print_rich(
			"[color=green][BT ⚔][/color] SelectorHabilidades [b]%s[/b]: eligió [i]%s[/i]"
			% [nombre_nodo, elegida.nombre] +
			"  prioridad=%d  dist=%.1f" % [elegida.prioridad, distancia]
		)

	habilidad_seleccionada.emit(elegida)
	return Estado.EXITOSO


func _on_reiniciar() -> void:
	# Los cooldowns NO se limpian al reiniciar — son estado de juego que debe
	# persistir entre transiciones de estado (ej: salir y volver a EstadoAtacar).
	# Para limpiar cooldowns explícitamente usa cancelar_todos_los_cooldowns().
	if _memoria:
		_memoria.establecer(clave_habilidad_activa, null)


# =============================================================================
# LÓGICA DE SELECCIÓN
# =============================================================================

func _filtrar_disponibles(distancia: float, agente: Node = null) -> Array[HabilidadBT]:
	var resultado: Array[HabilidadBT] = []
	for h in habilidades:
		if _esta_disponible(h, distancia, agente):
			resultado.append(h)
	return resultado


func _esta_disponible(h: HabilidadBT, distancia: float, agente: Node = null) -> bool:
	# Verificar cooldown.
	if _en_cooldown(h):
		return false
	# Verificar rango mínimo.
	if distancia < h.rango_minimo:
		return false
	# Verificar rango máximo (-1 = sin límite).
	if h.rango_maximo >= 0.0 and distancia > h.rango_maximo:
		return false
	# Fuente de verdad real: el NODO de la habilidad. Su recarga interna
	# (duracion_recarga de HabilidadBase) puede ser más larga que el cooldown
	# del .tres; si no se consulta, activar() rechaza en silencio y el árbol
	# cree que atacó cuando no salió nada.
	if agente != null and not h.ruta_nodo.is_empty():
		var nodo := agente.get_node_or_null(h.ruta_nodo)
		if nodo != null and nodo.has_method("puede_usarse") and not nodo.puede_usarse():
			return false
	return true


func _en_cooldown(h: HabilidadBT) -> bool:
	if h.duracion_cooldown <= 0.0:
		return false
	var ahora := Time.get_ticks_msec() / 1000.0
	return _cooldowns.get(h.nombre, 0.0) > ahora


func _iniciar_cooldown(h: HabilidadBT) -> void:
	if h.duracion_cooldown <= 0.0:
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	_cooldowns[h.nombre] = ahora + h.duracion_cooldown

	# Escribe el cooldown en memoria para que el DepuradorBT lo muestre.
	var clave_cd := "cd_" + h.nombre.to_lower().replace(" ", "_")
	_memoria.establecer(clave_cd, h.duracion_cooldown)

	if debug_activo:
		print_rich(
			"[color=orange][BT ⚔][/color] Cooldown iniciado: [i]%s[/i] → %.1fs"
			% [h.nombre, h.duracion_cooldown]
		)


# =============================================================================
# UTILIDADES PÚBLICAS
# =============================================================================

## Retorna true si existe al menos una habilidad SIN cooldown pero fuera del
## rango actual. Indica que el enemigo debe acercarse para poder usarla.
## Retorna false si todas las disponibles ya están en rango, o si todas
## están en cooldown (en ese caso moverse no sirve de nada, hay que esperar).
func hay_habilidades_fuera_de_rango(distancia_actual: float, agente: Node = null) -> bool:
	for h: HabilidadBT in habilidades:
		# Ignorar las que están en cooldown: acercarse no las activa antes.
		if _en_cooldown(h):
			continue
		# Ignorar las que su propio nodo aún está recargando.
		if agente != null and not h.ruta_nodo.is_empty():
			var nodo := agente.get_node_or_null(h.ruta_nodo)
			if nodo != null and nodo.has_method("puede_usarse") and not nodo.puede_usarse():
				continue
		# Ignorar habilidades reactivas que no requieren acercarse.
		if not h.requiere_acercarse:
			continue
		# Habilidad libre pero el enemigo está más lejos que su rango máximo.
		if h.rango_maximo >= 0.0 and distancia_actual > h.rango_maximo:
			return true
	return false


## Retorna los segundos restantes de cooldown de una habilidad (0 si disponible).
func obtener_cooldown_restante(nombre_habilidad: String) -> float:
	var ahora := Time.get_ticks_msec() / 1000.0
	return maxf(_cooldowns.get(nombre_habilidad, 0.0) - ahora, 0.0)


## Cancela el cooldown de una habilidad (útil si el estado cambia y quieres resetear).
func cancelar_cooldown(nombre_habilidad: String) -> void:
	_cooldowns.erase(nombre_habilidad)


## Cancela todos los cooldowns activos.
func cancelar_todos_los_cooldowns() -> void:
	_cooldowns.clear()


# =============================================================================
# HELPERS PRIVADOS
# =============================================================================

func _calcular_distancia(agente: Node, objetivo: Node2D) -> float:
	if not objetivo:
		return INF
	if agente is Node2D:
		return (agente as Node2D).global_position.distance_to(objetivo.global_position)
	return INF


func _imprimir_estado_habilidades(distancia: float) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	print_rich(
		"[color=red][BT ⚔][/color] SelectorHabilidades [b]%s[/b]: ninguna disponible  dist=%.1f"
		% [nombre_nodo, distancia]
	)
	for h: HabilidadBT in habilidades:
		var cd_restante := maxf(_cooldowns.get(h.nombre, 0.0) - ahora, 0.0)
		var en_rango := distancia >= h.rango_minimo and (h.rango_maximo < 0.0 or distancia <= h.rango_maximo)
		var razones := []
		if cd_restante > 0.0:   razones.append("cooldown %.1fs" % cd_restante)
		if not en_rango:        razones.append("fuera de rango [%.0f-%.0f]" % [h.rango_minimo, h.rango_maximo])
		print_rich(
			"  [color=gray]↳ %s (prioridad %d): %s[/color]"
			% [h.nombre, h.prioridad, ", ".join(razones) if razones else "OK"]
		)
