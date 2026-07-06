extends Area2D
class_name VisionComponente
## Detecta entidades con VidaComponente dentro de su radio.
## Opcionalmente verifica línea de visión directa con raycast.

# --- Señales ---
signal objetivo_detectado(area: Area2D)
signal objetivo_perdido(area: Area2D)

# --- Línea de visión ---
@export_group("Línea de Visión")
## Si está activo, solo emite objetivo_detectado cuando hay visión directa sin obstáculos.
## Si está inactivo, funciona igual que antes (solo por proximidad).
@export var requiere_linea_vision: bool = false
## Capas de física que bloquean la visión (paredes, obstáculos, etc.).
## Configurar en el Inspector según las capas del proyecto.
@export_flags_2d_physics var capa_obstaculos: int = 0
## Cada cuántos segundos se re-verifica la LoS de objetivos ya detectados.
## Valor bajo = más reactivo, más costoso. 0.1 es un buen balance.
@export var intervalo_verificacion: float = 0.1

@export_group("Filtro de Objetivo")
## Grupos que pueden ser detectados. Vacío = detecta todo.
## Ejemplo: ["jugadores"] para que el enemigo solo vea al jugador.
@export var grupos_objetivo: Array[String] = []

@export_group("Debug")
## Muestra los rayos de visión en pantalla durante el juego.
@export var debug_rayos: bool = false

# --- Estado interno ---
## Todas las áreas físicamente dentro del radio de visión.
var _areas_en_rango: Dictionary[String, Area2D] = {}
## Subconjunto de _areas_en_rango con línea de visión confirmada.
var _areas_con_los: Dictionary[String, Area2D] = {}
## Alias público para compatibilidad con código existente.
var areas_detectadas: Dictionary[String, Area2D]:
	get: return _areas_con_los

var _timer_los: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	if not requiere_linea_vision or _areas_en_rango.is_empty():
		return
	_timer_los += delta
	if _timer_los < intervalo_verificacion:
		return
	_timer_los = 0.0
	_verificar_los_todos()
	if debug_rayos:
		queue_redraw()


func _draw() -> void:
	if not debug_rayos or not requiere_linea_vision:
		return
	var origen_local := Vector2.ZERO  # _draw usa coordenadas locales del nodo
	for key in _areas_en_rango:
		var area := _areas_en_rango[key] as Area2D
		if not is_instance_valid(area) or not area.get_parent() is Node2D:
			continue
		var destino_global := (area.get_parent() as Node2D).global_position
		var destino_local  := to_local(destino_global)
		var tiene_los      := _areas_con_los.has(key)
		# Verde = visión libre, rojo = bloqueado
		var color := Color(0.0, 1.0, 0.2, 0.7) if tiene_los else Color(1.0, 0.2, 0.0, 0.5)
		draw_line(origen_local, destino_local, color, 1.5)


# =============================================================================
# SEÑALES DE ÁREA
# =============================================================================

func _on_area_entered(area: Area2D) -> void:
	if not area is VidaComponente or area.get_parent() == get_parent():
		return
	if not grupos_objetivo.is_empty():
		var propietario := area.get_parent()
		var en_grupo := grupos_objetivo.any(func(g): return propietario.is_in_group(g))
		if not en_grupo:
			return

	var key := _clave(area)
	if _areas_en_rango.has(key):
		return

	_areas_en_rango[key] = area

	if not requiere_linea_vision:
		# Modo clásico: detectar solo por proximidad.
		_registrar_con_los(area)
	else:
		# Modo LoS: solo detectar si hay visión directa.
		if _tiene_linea_vision(area):
			_registrar_con_los(area)


func _on_area_exited(area: Area2D) -> void:
	if not area is VidaComponente:
		return
	var key := _clave(area)
	_areas_en_rango.erase(key)
	_desregistrar_con_los(area)


# =============================================================================
# LÓGICA DE LÍNEA DE VISIÓN
# =============================================================================

## Revisa todos los objetivos en rango y actualiza su estado de LoS.
func _verificar_los_todos() -> void:
	for key in _areas_en_rango.keys():
		var area := _areas_en_rango.get(key) as Area2D
		if not is_instance_valid(area):
			_areas_en_rango.erase(key)
			_areas_con_los.erase(key)
			continue

		var tenia_los := _areas_con_los.has(key)
		var tiene_los := _tiene_linea_vision(area)

		if tiene_los and not tenia_los:
			# Recuperó visión — ahora sí lo ve.
			_registrar_con_los(area)
		elif not tiene_los and tenia_los:
			# Perdió visión — se metió detrás de algo.
			_desregistrar_con_los(area)


## Lanza un rayo desde el enemigo hacia el objetivo.
## Retorna true si no hay obstáculos en la capa configurada.
func _tiene_linea_vision(area: Area2D) -> bool:
	if capa_obstaculos == 0:
		return true  # Sin capa configurada = siempre hay visión.

	var origen  := (get_parent() as Node2D).global_position if get_parent() is Node2D else global_position
	var destino := (area.get_parent() as Node2D).global_position if area.get_parent() is Node2D else area.global_position

	var espacio := get_world_2d().direct_space_state
	var query   := PhysicsRayQueryParameters2D.create(origen, destino, capa_obstaculos)
	# Excluir al propio enemigo y su VidaComponente para que el rayo no choque consigo mismo.
	query.exclude = [self, get_parent()]

	var resultado := espacio.intersect_ray(query)
	if resultado.is_empty():
		return true  # El rayo llegó al destino sin chocar con nada.

	# Si lo que chocó ES el objetivo (o su VidaComponente), hay visión directa.
	var collider = resultado.get("collider")
	return collider == area or collider == area.get_parent()


# =============================================================================
# HELPERS INTERNOS
# =============================================================================

func _registrar_con_los(area: Area2D) -> void:
	var key := _clave(area)
	if _areas_con_los.has(key):
		return
	_areas_con_los[key] = area
	if _areas_con_los.size() == 1:
		objetivo_detectado.emit(area)


func _desregistrar_con_los(area: Area2D) -> void:
	var key := _clave(area)
	if not _areas_con_los.has(key):
		return
	_areas_con_los.erase(key)
	if _areas_con_los.is_empty():
		objetivo_perdido.emit(area)


func _clave(area: Area2D) -> String:
	return str(area.get_instance_id())


# =============================================================================
# API PÚBLICA (compatibilidad con código existente)
# =============================================================================

func registrar_area_detectada(area: Area2D) -> void:
	_registrar_con_los(area)


func desregistrar_area_detectada(area: Area2D) -> void:
	_desregistrar_con_los(area)


func buscar_area_por_nombre(nombre: String) -> Array[Area2D]:
	var resultados: Array[Area2D] = []
	nombre = nombre.to_lower()
	for key in _areas_con_los:
		var area := _areas_con_los[key] as Area2D
		if is_instance_valid(area) and area.owner and area.owner.name.to_lower().contains(nombre):
			resultados.append(area)
	return resultados
