# =============================================================================
# Regresión: pedido del usuario — "me gustaria que fuera tambien por
# probabilidad si irse a otro mapa o seguir combatiendo, pero esta decisión
# debe seleccionarse o lanzarse cuando se termine de combatir con un mob, ya
# que muchas veces se queda dando vueltas esperando encontrar un mob en
# lugar de cambiar de mapa".
#
# Sin red (single player), con probabilidad_cambiar_mapa forzada a 1.0 para
# que la corrida sea determinística, verifica:
#   1. Al abandonar un objetivo (acá: se aleja más allá de radio_abandono,
#      mismo camino que "se murió" — ambos pasan por _abandonar_objetivo),
#      el bot entra en estado VIAJAR con un PortalNivel real como destino
#      en vez de quedarse deambulando en el mismo mapa.
#   2. Viajando, el bot CAMINA de verdad hacia el portal (la distancia baja
#      con el tiempo) y NO se distrae con otro mob nuevo mucho más cerca
#      (_escanear_enemigos no debe interrumpir el viaje).
#   3. Al terminar de cargar un nivel (GestorNiveles.nivel_cargado, lo que
#      pasaría de verdad al cruzar el portal) el bot suelta el viaje, vuelve
#      a DEAMBULAR y reancla su radio de deambulación a la posición actual
#      en vez de seguir usando coordenadas del mapa anterior.
#   godot --headless --path . --script res://pruebas/prueba_bot_ia_cambio_de_mapa.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raiz: Node2D
var _jugador
var _bot
var _muneco
var _muneco_cebo
var _portal
var _gestor_niveles

var _distancia_al_abandonar := 0.0

var _entro_en_viajar_ok := false
var _se_acerco_al_portal_ok := false
var _ignoro_mob_cebo_durante_viaje_ok := false
var _reset_tras_cambio_nivel_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		# Tiempo de sobra para que el bot enganche al muñeco y se estabilice
		# en combate (holding a distancia_combate).
		120:
			_forzar_abandono()
		121:
			_entro_en_viajar_ok = _bot._estado == 2 and _bot._portal_destino == _portal  # 2 == _Estado.VIAJAR
			_distancia_al_abandonar = _jugador.global_position.distance_to(_portal.global_position)
			_agregar_mob_cebo_cerca()
		240:
			# ~2s viajando: tuvo que acercarse al portal y jamás enganchar
			# al cebo, aunque esté pegado.
			var distancia_actual: float = _jugador.global_position.distance_to(_portal.global_position)
			_se_acerco_al_portal_ok = distancia_actual < _distancia_al_abandonar - 20.0
			_ignoro_mob_cebo_durante_viaje_ok = _bot._estado == 2
			_simular_cambio_de_nivel()
		242:
			# Un par de fotogramas después del emit (uno para el signal, otro
			# para el call_deferred que reancla el origen).
			return _informar()
	return false


func _montar() -> void:
	root.get_node("/root/Utils").modo_bot = true
	_gestor_niveles = root.get_node("/root/GestorNiveles")

	_raiz = Node2D.new()
	root.add_child(_raiz)
	current_scene = _raiz

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	_raiz.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO
	var datos_golpe_basico := load("res://recursos/habilidades/golpe_basico.tres")
	_jugador.slot_habilidades.equipar(0, datos_golpe_basico)

	_bot = _jugador.get_node("BotIA")
	_bot.probabilidad_cambiar_mapa = 1.0

	# Muñeco QUIETO, cerca, para que el bot lo enganche y se estabilice en
	# combate antes de forzar el abandono (mismo criterio que
	# prueba_bot_ia_distancia_y_habilidades.gd).
	_muneco = (load("res://escenas/enemigos/MunecoEntrenamiento.tscn") as PackedScene).instantiate()
	_raiz.add_child(_muneco)
	_muneco.global_position = Vector2(150, 0)

	# Portal real, bien lejos: alcanza con confirmar que el bot camina HACIA
	# él, no que llegue a cruzarlo (eso ya lo cubre
	# prueba_gestor_niveles_aparicion_junto_a_portal.gd / prueba_niveles.gd).
	_portal = (load("res://escenas/niveles/PortalNivel.tscn") as PackedScene).instantiate()
	_portal.ruta_nivel_destino = "res://escenas/niveles/NivelPradera.tscn"
	_portal.global_position = Vector2(3000, 0)
	_raiz.add_child(_portal)


func _forzar_abandono() -> void:
	# Mismo resultado que "el mob murió" en cuanto a lo que le importa a
	# BotIA (_objetivo deja de tener sentido) — pero instantáneo y
	# determinístico, sin depender del timing de una animación de muerte.
	_muneco.global_position = Vector2(50000, 0)


func _agregar_mob_cebo_cerca() -> void:
	# Pegado al jugador, bien dentro de radio_deteccion: si _escanear_enemigos
	# no respetara el estado VIAJAR, iba a enganchar a este apenas apareciera.
	_muneco_cebo = (load("res://escenas/enemigos/MunecoEntrenamiento.tscn") as PackedScene).instantiate()
	_raiz.add_child(_muneco_cebo)
	_muneco_cebo.global_position = _jugador.global_position + Vector2(20, 0)


func _simular_cambio_de_nivel() -> void:
	var nivel_falso := NivelBase.new()
	_raiz.add_child(nivel_falso)
	_gestor_niveles.nivel_cargado.emit(nivel_falso)


func _informar() -> bool:
	# Margen generoso a propósito: entre el frame del emit y esta revisión el
	# bot ya volvió a moverse un par de veces hacia el nuevo destino de
	# deambular — lo que importa es que _origen quedó ANCLADO A LA POSICIÓN
	# NUEVA (cerca del portal, lejísimos del (0,0) original), no que sea
	# bit-a-bit exacto a un instante congelado.
	var origen_reanclado_ok: bool = _bot._origen.distance_to(_jugador.global_position) < 30.0 \
		and _bot._origen.distance_to(Vector2.ZERO) > 200.0
	_reset_tras_cambio_nivel_ok = _bot._estado == 0 and _bot._portal_destino == null \
		and _bot._objetivo == null and origen_reanclado_ok  # 0 == _Estado.DEAMBULAR

	print("Al abandonar el objetivo, entra en VIAJAR con el portal como destino (esperado true): %s" % _entro_en_viajar_ok)
	print("Viajando, se acerca de verdad al portal (esperado true): %s" % _se_acerco_al_portal_ok)
	print("Viajando, ignora un mob cebo pegado en vez de engancharlo (esperado true): %s" % _ignoro_mob_cebo_durante_viaje_ok)
	print("Tras cambiar de nivel, vuelve a DEAMBULAR y reancla origen (esperado true): %s" % _reset_tras_cambio_nivel_ok)

	var exito := _entro_en_viajar_ok and _se_acerco_al_portal_ok \
		and _ignoro_mob_cebo_durante_viaje_ok and _reset_tras_cambio_nivel_ok
	print("PRUEBA BOT IA CAMBIO DE MAPA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
