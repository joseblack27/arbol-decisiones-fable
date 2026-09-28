# =============================================================================
# AccionIrAPunto.gd  (Acción)
#
# Viaja hacia un PUNTO FIJO guardado en la memoria (no un Node2D como
# AccionPerseguir) — no le importa ningún objetivo ni jugador detectado.
# Nace para "Llamada de Auxilio" de la Reina de las Hormigas (ver
# HabilidadLlamadaAuxilio.gd / Enemigo.responder_llamada_auxilio()): un mob
# alertado abandona lo que esté haciendo y camina directo al punto, sin
# trabarse a pelear con nadie que se cruce en el camino.
#
# RETORNA:
#   EXITOSO → di un paso hacia el punto, O ya llegué, O me rendí por estar
#             atascado (por paso: el Selector raíz re-evalúa prioridades cada
#             tick, mismo criterio que AccionPerseguir — al terminar, apaga la
#             variable activa y el próximo tick el árbol cae solo a las ramas
#             normales de combate).
#   FALLIDO → sin agente/movimiento, o la variable de destino no es un Vector2.
#
# MEMORIA:
#   lee "agente", "componente_movimiento", nombre_variable_destino
#   escribe nombre_variable_activa = false al llegar o al rendirse
# =============================================================================
class_name AccionIrAPunto
extends Accion

@export_group("Memoria")
## Variable con el Vector2 destino (posición GLOBAL) al que viajar.
@export var nombre_variable_destino: String = "destino_llamada"
## Variable booleana que esta acción apaga al llegar — es la misma que la
## Condición de la Secuencia que envuelve a esta Acción chequea, así que
## apagarla acá hace que el próximo tick esa rama deje de ganar prioridad.
@export var nombre_variable_activa: String = "en_llamada_auxilio"

@export_group("Configuración")
@export var margen_llegada: float = 100.0
## Multiplicador sobre componente_movimiento.velocidad_base — >1 para que
## la respuesta se sienta urgente, no un paseo.
@export var multiplicador_velocidad: float = 1.3
## Se rinde si pasa este tiempo sin acercarse por la RUTA, nunca por tiempo
## total: en el Hormiguero las rutas por los túneles miden 1.600-12.000 px
## (14-100 s de caminata). Con MovimientoComponente.llego_al_destino(), que se
## da por llegado a los 6 s, las hormigas de la llamada de la Reina
## abandonaban a mitad de un pasillo o en la entrada de la cámara.
@export var segundos_sin_progreso_para_rendirse: float = 3.0

## Cuánto tiene que bajar lo que falta de ruta para contar como avance.
const _AVANCE_MINIMO := 10.0

var _destino_en_curso := Vector2.INF
var _menor_restante := INF
var _segundo_ultimo_avance := 0.0


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	if not agente or not movimiento:
		return Estado.FALLIDO
	var destino_raw = _memoria.obtener(nombre_variable_destino)
	if not (destino_raw is Vector2):
		_memoria.establecer(nombre_variable_activa, false)
		return Estado.FALLIDO
	var destino: Vector2 = destino_raw

	movimiento.comandar_destino(destino, movimiento.velocidad_base * multiplicador_velocidad)

	var ahora := _segundos_de_juego()
	if destino != _destino_en_curso:
		# Llamada nueva (o repetida desde otro lugar): se mide desde cero.
		_destino_en_curso = destino
		_menor_restante = INF
		_segundo_ultimo_avance = ahora

	var agente_nav := movimiento.agente_navegacion
	var llego := agente.global_position.distance_to(destino) <= margen_llegada
	# Fin de ruta: si el punto exacto cae en un tramo que la malla no alcanza,
	# la ruta termina en el punto navegable más cercano — eso también es llegar.
	if agente_nav != null and agente_nav.is_navigation_finished():
		llego = true
	if llego:
		return _terminar(movimiento)

	var restante := _ruta_restante(agente, agente_nav, destino)
	if restante < _menor_restante - _AVANCE_MINIMO:
		_menor_restante = restante
		_segundo_ultimo_avance = ahora
	elif ahora - _segundo_ultimo_avance > segundos_sin_progreso_para_rendirse:
		# Atascada de verdad (bloqueada, o dando vueltas sin acercarse): sin
		# esto quedaría respondiendo para siempre — es la rama de MÁS prioridad
		# del árbol y le taparía atacar/perseguir/deambular.
		return _terminar(movimiento)
	return Estado.EXITOSO


func _terminar(movimiento: MovimientoComponente) -> Estado:
	movimiento.detener()
	_memoria.establecer(nombre_variable_activa, false)
	_destino_en_curso = Vector2.INF
	return Estado.EXITOSO


## Lo que falta recorrer SIGUIENDO la ruta (no en línea recta: por los túneles
## la distancia recta puede crecer mientras se avanza bien). Sin agente de
## navegación, la recta.
func _ruta_restante(agente: Node2D, agente_nav: NavigationAgent2D, destino: Vector2) -> float:
	if agente_nav == null:
		return agente.global_position.distance_to(destino)
	var ruta := agente_nav.get_current_navigation_path()
	var indice := agente_nav.get_current_navigation_path_index()
	if ruta.is_empty() or indice >= ruta.size():
		return agente.global_position.distance_to(destino)
	var total := agente.global_position.distance_to(ruta[indice])
	for i in range(indice + 1, ruta.size()):
		total += ruta[i - 1].distance_to(ruta[i])
	return total


## Tiempo de JUEGO (no de reloj): igual de preciso en el servidor y en las
## pruebas que corren con --fixed-fps.
func _segundos_de_juego() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
