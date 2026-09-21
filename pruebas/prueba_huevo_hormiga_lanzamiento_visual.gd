# =============================================================================
# Regresión (pedido explícito del usuario, 21 sep 2026): "que la hormiga los
# lance como proyectiles hasta la ubicación donde desea invocarlos, para
# tener por lo menos una visual como habilidad" -- antes los huevos
# aparecían de golpe en su posición final (invisibles en la práctica, sin
# ningún indicio de que la habilidad hizo algo). Ahora HuevoHormiga.
# lanzar_hacia() los anima desde donde nacieron hasta su destino con un
# Tween sobre global_position -- se replica solo, con el mismo mecanismo
# genérico de posición que cualquier mob en movimiento (ver Enemigo.
# _physics_process), sin RPC propio.
#
# Usa TIEMPO REAL (Time.get_ticks_msec), no conteo de fotogramas, para
# decidir cuándo verificar -- en este entorno headless la cantidad de
# fotogramas de SceneTree._process NO corresponde de forma confiable a
# tiempo real transcurrido (varía según carga del sistema, visto en la
# práctica: con un margen de fotogramas fijo, esta misma prueba pasaba
# aislada pero fallaba corriendo dentro de la suite completa). El Tween sí
# usa tiempo real, así que medir tiempo real es la única forma robusta de
# saber "ya debería haber llegado".
#
# Confirma:
#   1. Llamado directo a lanzar_hacia(): arranca en el origen, y termina en
#      el destino una vez pasado con margen su tiempo de vuelo real.
#   2. A través de la habilidad real (HabilidadPuestaHuevos.activar()): cada
#      huevo nace en la posición de la Reina (no en su destino disperso) y
#      termina dentro del radio de dispersión configurado -- no se queda
#      pegado en el origen. duracion_descanso se deja bien larga para no
#      toparse con la eclosión (que vacía _huevos_activos) mientras se
#      verifica esto.
#   godot --headless --path . --script res://pruebas/prueba_huevo_hormiga_lanzamiento_visual.gd
# =============================================================================
extends SceneTree

const DURACION_VUELO := 0.3
const MARGEN_VERIFICACION_MS := 1500  # 5x la duración del vuelo, de sobra.

var _huevo_directo
var _origen_directo := Vector2(100.0, 50.0)
var _destino_directo := Vector2(250.0, 50.0)

var _reina
var _habilidad
var _contenedor: Node2D

var _momento_inicio_ms := 0
var _verificado := false

var _arranca_en_origen_ok := false
var _llega_al_destino_ok := false
var _huevos_nacen_en_la_reina_ok := false
var _huevos_terminan_dispersos_ok := false


func _process(_delta: float) -> bool:
	if _momento_inicio_ms == 0:
		_montar()
		_momento_inicio_ms = Time.get_ticks_msec()
		return false
	if _verificado:
		return false
	if Time.get_ticks_msec() - _momento_inicio_ms >= MARGEN_VERIFICACION_MS:
		_verificado = true
		_verificar_llegada()
		return _informar()
	return false


func _montar() -> void:
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_huevo_directo = (load("res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn") as PackedScene).instantiate()
	_huevo_directo.global_position = _origen_directo
	_contenedor.add_child(_huevo_directo)
	_huevo_directo.lanzar_hacia(_destino_directo, DURACION_VUELO)

	# Chequeo SINCRÓNICO, ya mismo -- un Tween recién creado no avanza nada
	# hasta el próximo paso de proceso, así que esto confirma el punto de
	# partida sin depender de tiempos de fotograma.
	_arranca_en_origen_ok = _huevo_directo.global_position.distance_to(_origen_directo) < 1.0
	print("lanzar_hacia() arranca en el origen (esperado true): %s" % _arranca_en_origen_ok)

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = Vector2(1000.0, 1000.0)

	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")
	_habilidad.cantidad_huevos = 3
	# Bien larga a propósito: no queremos que la eclosión (que vacía
	# _huevos_activos) se dispare mientras todavía se está verificando el
	# aterrizaje -- ver comentario de cabecera.
	_habilidad.duracion_descanso = 60.0
	_habilidad.activar(Vector2.ZERO, 1.0)

	# Mismo criterio sincrónico: los huevos ya fueron creados y lanzados por
	# activar() (todo corre sincrónico dentro de _ejecutar()).
	var todos_en_reina = _habilidad._huevos_activos.all(func(h):
		return is_instance_valid(h) and h.global_position.distance_to(_reina.global_position) < 5.0)
	_huevos_nacen_en_la_reina_ok = _habilidad._huevos_activos.size() == 3 and todos_en_reina
	print("Los huevos de la habilidad nacen en la posición de la Reina (esperado true): %s" % \
		_huevos_nacen_en_la_reina_ok)


func _verificar_llegada() -> void:
	_llega_al_destino_ok = _huevo_directo.global_position.distance_to(_destino_directo) < 3.0
	print("lanzar_hacia() termina en el destino (esperado true, pos=%s): %s" % [
		_huevo_directo.global_position, _llega_al_destino_ok])

	# El offset de destino de _ejecutar() es randf_range independiente en X
	# e Y -- un CUADRADO de lado 2*radio, no un círculo -- así que la
	# distancia real a la Reina puede llegar a radio*sqrt(2) en una esquina
	# (encontrado en la práctica: con tolerancia "radio + 1.0" esta prueba
	# fallaba al azar, según dónde cayera randf_range esa corrida).
	var radio = _habilidad.radio_dispersion
	var radio_maximo = radio * sqrt(2.0) + 1.0
	var todos_dispersos = _habilidad._huevos_activos.all(func(h):
		return is_instance_valid(h) and h.global_position.distance_to(_reina.global_position) <= radio_maximo)
	var alguno_se_movio = _habilidad._huevos_activos.any(func(h):
		return is_instance_valid(h) and h.global_position.distance_to(_reina.global_position) > 5.0)
	_huevos_terminan_dispersos_ok = todos_dispersos and alguno_se_movio
	print("Los huevos de la habilidad terminan dispersos dentro del radio (esperado true): %s" % \
		_huevos_terminan_dispersos_ok)


func _informar() -> bool:
	var exito := _arranca_en_origen_ok and _llega_al_destino_ok \
		and _huevos_nacen_en_la_reina_ok and _huevos_terminan_dispersos_ok
	print("PRUEBA HUEVO HORMIGA LANZAMIENTO VISUAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
