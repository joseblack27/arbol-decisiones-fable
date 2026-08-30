# =============================================================================
# Regresión: pedido del usuario — "me gustaria que los bots fueran
# conscientes del espacio del mapa, porque de tres que puse 2 se quedaron
# cerca del portal y tratando de caminar hacia la izquierda y siempre
# estaban pegados a la pared... que supieran donde estan los portales y
# deambularan por zonas navegables del mismo y si no cambian de posicion en
# 3 segundos mientras caminan, significan que estan atascados y hagan un
# mapeo del mapa y se dirijan a un punto bueno del mismo".
#
# Con la Pradera REAL (malla de navegación real, no una prueba aislada sin
# nivel) verifica:
#   1. El destino de deambulación elegido cae de verdad SOBRE la malla de
#      navegación (antes: cualquier punto del círculo, sin mirar el mapa).
#   2. Si el bot no avanza (simulando quedar atascado contra algo, sin
#      necesitar reproducir una pared física exacta) durante
#      umbral_atascado_segundos mientras deambula, se dispara la
#      recuperación: un destino NUEVO, también validado contra la malla,
#      anclado a la posición actual.
#   3. Lo mismo mientras viaja a un portal (VIAJAR): al atascarse, suelta el
#      portal y vuelve a DEAMBULAR en vez de quedar pegado ahí para siempre.
#
# Espera a que la malla de navegación esté sincronizada antes de tocar nada
# (mismo criterio que prueba_navegacion.gd — recién instanciado el nivel, la
# malla puede tardar algún physics_frame en responder consultas de verdad).
#   godot --headless --path . --script res://pruebas/prueba_bot_ia_navegacion.gd
# =============================================================================
extends SceneTree

const _DISTANCIA_SONDA := 1_000_000.0
const _FISICAS_ESPERA_MALLA := 180
## umbral_atascado_segundos=3.0 en BotIA: de sobra a ~60 físicas/seg.
const _FISICAS_ESPERA_ATASCO := 250
## Techo duro: pase lo que pase, esta prueba TERMINA (mismo criterio que
## prueba_navegacion.gd — sin esto, un error a mitad de _process() que
## nunca llegue a quit() deja el proceso de Godot vivo para siempre).
const _FOTOGRAMAS_TOPE_DURO := 3000

enum _Fase { ESPERAR_MALLA, VERIFICAR_DESTINO_INICIAL, ATASCADO_DEAMBULANDO, ATASCADO_VIAJANDO, FIN }

var _fotogramas := 0
var _fisicas := 0
var _fase := _Fase.ESPERAR_MALLA
var _fisicas_al_entrar_fase := 0
var _nivel
var _jugador
var _bot
var _mapa: RID

var _destino_forzado_deambular := Vector2.ZERO

var _destino_deambular_sobre_malla_ok := false
var _atascado_deambulando_se_recupera_ok := false
var _atascado_viajando_suelta_portal_ok := false


func _init() -> void:
	physics_frame.connect(func() -> void: _fisicas += 1)


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas > _FOTOGRAMAS_TOPE_DURO:
		print("FALLO: la prueba no llegó a ningún veredicto en %d fotogramas "
			% _FOTOGRAMAS_TOPE_DURO + "(revisá los errores de script de arriba).")
		print("PRUEBA BOT IA NAVEGACION FALLIDA")
		quit(1)
		return true
	_congelar_posicion_si_corresponde()
	if _nivel == null:
		_montar()
		return false

	match _fase:
		_Fase.ESPERAR_MALLA:
			if _malla_responde():
				_cambiar_fase(_Fase.VERIFICAR_DESTINO_INICIAL)
		_Fase.VERIFICAR_DESTINO_INICIAL:
			_verificar_destino_inicial_sobre_malla()
			_forzar_atasco_deambulando()
			_cambiar_fase(_Fase.ATASCADO_DEAMBULANDO)
		_Fase.ATASCADO_DEAMBULANDO:
			if _fisicas - _fisicas_al_entrar_fase >= _FISICAS_ESPERA_ATASCO:
				_verificar_recuperacion_deambulando()
				_forzar_atasco_viajando()
				_cambiar_fase(_Fase.ATASCADO_VIAJANDO)
		_Fase.ATASCADO_VIAJANDO:
			if _fisicas - _fisicas_al_entrar_fase >= _FISICAS_ESPERA_ATASCO:
				return _informar()
	return false


func _cambiar_fase(nueva: _Fase) -> void:
	_fase = nueva
	_fisicas_al_entrar_fase = _fisicas


func _montar() -> void:
	root.get_node("/root/Utils").modo_bot = true

	_nivel = (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	var spawner = _nivel.get_node_or_null("Enemigos/SpawnerMobs")
	if spawner != null:
		spawner.set("cantidad_inicial", 0)
		spawner.set("activo", false)
	root.add_child(_nivel)
	current_scene = _nivel

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	_nivel.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_bot = _jugador.get_node("BotIA")
	_mapa = _nivel.mapa_navegacion()


## true cuando la malla ya contesta consultas de posición de verdad — mismo
## chequeo que prueba_navegacion.gd (sondear un punto absurdamente lejano la
## delata: sincronizada devuelve su vértice transitable más cercano, jamás el
## Vector2.ZERO de "no encontrado").
func _malla_responde() -> bool:
	if NavigationServer2D.map_get_regions(_mapa).is_empty():
		return false
	return NavigationServer2D.map_get_closest_point(
		_mapa, Vector2(_DISTANCIA_SONDA, _DISTANCIA_SONDA)
	) != Vector2.ZERO


func _verificar_destino_inicial_sobre_malla() -> void:
	# Con la malla YA lista, se le pide un destino fresco (el que se eligió en
	# _ready() pudo haber caído en la rama "sin malla" si el nivel todavía no
	# había sincronizado en ese primerísimo fotograma).
	_bot._elegir_destino_deambular()
	var destino: Vector2 = _bot._destino_deambular
	var punto_malla: Vector2 = NavigationServer2D.map_get_closest_point(_mapa, destino)
	var distancia: float = destino.distance_to(punto_malla)
	print("Destino de deambulación sobre la malla (distancia esperada ~0, obtenida %.2f)" % distancia)
	_destino_deambular_sobre_malla_ok = distancia < 1.0


func _forzar_atasco_deambulando() -> void:
	# En vez de reproducir una pared física exacta, se simula el síntoma que
	# le importa a _actualizar_deteccion_atascado: el bot INTENTA caminar
	# (sigue en DEAMBULAR, con un destino lejos) pero su posición no avanza —
	# clavada cada fotograma con la misma fuerza con la que una pared real lo
	# haría (ver _congelar_posicion_si_corresponde).
	_bot._estado = 0  # _Estado.DEAMBULAR
	_destino_forzado_deambular = _jugador.global_position + Vector2(1000, 0)  # bien lejos, nunca "llega" solo.
	_bot._destino_deambular = _destino_forzado_deambular
	var posicion_fija: Vector2 = _jugador.global_position
	_bot._posicion_control_atascado = posicion_fija
	_bot._tiempo_atascado = 0.0
	_jugador.set_meta("_posicion_congelada_prueba", posicion_fija)


func _verificar_recuperacion_deambulando() -> void:
	var destino_recuperado: Vector2 = _bot._destino_deambular
	var cambio_de_destino: bool = destino_recuperado.distance_to(_destino_forzado_deambular) > 1.0
	var sigue_deambulando: bool = _bot._estado == 0  # _Estado.DEAMBULAR
	var punto_malla: Vector2 = NavigationServer2D.map_get_closest_point(_mapa, destino_recuperado)
	var nuevo_destino_sobre_malla: bool = destino_recuperado.distance_to(punto_malla) < 1.0
	print("Tras atascarse deambulando: cambió de destino=%s, sigue en DEAMBULAR=%s, nuevo destino sobre la malla=%s" % [
		cambio_de_destino, sigue_deambulando, nuevo_destino_sobre_malla])
	_atascado_deambulando_se_recupera_ok = cambio_de_destino and sigue_deambulando and nuevo_destino_sobre_malla


func _forzar_atasco_viajando() -> void:
	var portal := (load("res://escenas/niveles/PortalNivel.tscn") as PackedScene).instantiate()
	portal.ruta_nivel_destino = "res://escenas/niveles/NivelCiudad.tscn"
	portal.global_position = _jugador.global_position + Vector2(2000, 0)
	_nivel.add_child(portal)

	_bot._portal_destino = portal
	_bot._objetivo = null
	_bot._estado = 2  # _Estado.VIAJAR
	var posicion_fija: Vector2 = _jugador.global_position
	_bot._posicion_control_atascado = posicion_fija
	_bot._tiempo_atascado = 0.0
	_jugador.set_meta("_posicion_congelada_prueba", posicion_fija)


func _congelar_posicion_si_corresponde() -> void:
	if _jugador != null and _jugador.has_meta("_posicion_congelada_prueba"):
		_jugador.global_position = _jugador.get_meta("_posicion_congelada_prueba")


func _informar() -> bool:
	var portal_soltado: bool = _bot._portal_destino == null
	var volvio_a_deambular: bool = _bot._estado == 0  # _Estado.DEAMBULAR
	print("Tras atascarse viajando: soltó el portal=%s, volvió a DEAMBULAR=%s" % [
		portal_soltado, volvio_a_deambular])
	_atascado_viajando_suelta_portal_ok = portal_soltado and volvio_a_deambular

	print("Destino inicial de deambulación cae sobre la malla (esperado true): %s" % _destino_deambular_sobre_malla_ok)
	print("Atascado deambulando se recupera con un destino nuevo y válido (esperado true): %s" % _atascado_deambulando_se_recupera_ok)
	print("Atascado viajando suelta el portal y vuelve a deambular (esperado true): %s" % _atascado_viajando_suelta_portal_ok)

	var exito := _destino_deambular_sobre_malla_ok and _atascado_deambulando_se_recupera_ok \
		and _atascado_viajando_suelta_portal_ok
	print("PRUEBA BOT IA NAVEGACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
