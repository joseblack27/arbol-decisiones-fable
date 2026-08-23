# =============================================================================
# Pedido del usuario: "arreglame el tp del jugador, quiero que este se haga
# tp alrededor del circulo del tp correspondiente" — y luego: "que el
# portal nivel pida un hijo de tipo Marker2D que es donde aparecerá el
# jugador, en lugar de aparecer en una ubicación aleatoria... con eso se
# establece bien una buena posición de respawn". Antes mover_peer_a_nivel()
# siempre usaba el PuntoAparicion fijo del nivel entero, sin importar por
# qué portal se cruzó; la primera vuelta de esto dispersaba a un ángulo al
# azar alrededor del portal. Ahora PortalNivel.punto_llegada (un Marker2D
# hijo, puesto a mano por instancia en el editor — la escena base
# PortalNivel.tscn NO trae uno por defecto, el usuario lo sacó a propósito
# para que cada portal real lo defina explícito) da la posición exacta.
#
# Cubre:
#   1. Cruzando un portal de verdad (con un portal de regreso real en el
#      nivel destino, con su propio punto_llegada configurado), el jugador
#      aparece EXACTAMENTE en PortalNivel.punto_llegada.global_position de
#      ESE portal — no en el PuntoAparicion fijo del nivel.
#   2. Sin portal de regreso identificable (llegada nueva, sin cruzar
#      nada), sigue cayendo al PuntoAparicion de siempre — sin regresión.
#   3. Portal de regreso identificado pero SIN punto_llegada configurado
#      (todavía no se editó a mano en el editor) — también cae al
#      PuntoAparicion fijo, en vez de reventar con un nulo.
#   godot --headless --path . --script res://pruebas/prueba_gestor_niveles_aparicion_junto_a_portal.gd
# =============================================================================
extends SceneTree

var _gn
var _nivel_a
var _nivel_b
var _nivel_c
var _portal_b_a_a
var _portal_c_a_a
var _jugador

var _aparece_en_punto_llegada_del_portal_ok := false
var _sin_origen_usa_punto_fijo_ok := false
var _portal_sin_marcador_usa_punto_fijo_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_con_portal_de_regreso()
	_probar_sin_origen()
	_probar_portal_sin_marcador_configurado()
	return _informar()


func _montar() -> void:
	_gn = root.get_node("/root/GestorNiveles")

	# Dos "niveles" mínimos: A (de donde viene el jugador) y B (a donde
	# cruza), con un portal en B que vuelve a A — igual que
	# PortalAPradera/PortalACiudad en el juego real.
	_nivel_a = NivelBase.new()
	_nivel_a.scene_file_path = "res://pruebas/_falso_nivel_a.tscn"
	root.add_child(_nivel_a)
	var punto_a := Marker2D.new()
	punto_a.name = "PuntoAparicion"
	punto_a.position = Vector2(1000, 1000)
	_nivel_a.add_child(punto_a)

	_nivel_b = NivelBase.new()
	_nivel_b.scene_file_path = "res://pruebas/_falso_nivel_b.tscn"
	root.add_child(_nivel_b)
	var punto_b := Marker2D.new()
	punto_b.name = "PuntoAparicion"
	punto_b.position = Vector2(-5000, -5000)  # bien lejos, para distinguirlo del portal.
	_nivel_b.add_child(punto_b)

	# Instancia REAL de PortalNivel.tscn. La escena base ya NO trae un
	# PuntoLlegada por defecto (el usuario lo sacó a propósito: cada
	# instancia real del juego pone el suyo propio, a mano, en el editor) —
	# se arma acá igual que se armaría en un nivel real.
	_portal_b_a_a = (load("res://escenas/niveles/PortalNivel.tscn") as PackedScene).instantiate()
	_portal_b_a_a.ruta_nivel_destino = _nivel_a.scene_file_path
	_portal_b_a_a.position = Vector2(200, 300)
	_nivel_b.add_child(_portal_b_a_a)
	var marcador_llegada := Marker2D.new()
	marcador_llegada.position = Vector2(0, 64)
	_portal_b_a_a.add_child(marcador_llegada)
	_portal_b_a_a.punto_llegada = marcador_llegada

	# Nivel C: mismo caso que B, pero su portal de regreso a A NO tiene
	# punto_llegada configurado — todavía no se editó a mano en el editor.
	_nivel_c = NivelBase.new()
	_nivel_c.scene_file_path = "res://pruebas/_falso_nivel_c.tscn"
	root.add_child(_nivel_c)
	var punto_c := Marker2D.new()
	punto_c.name = "PuntoAparicion"
	punto_c.position = Vector2(-7000, -7000)
	_nivel_c.add_child(punto_c)
	_portal_c_a_a = (load("res://escenas/niveles/PortalNivel.tscn") as PackedScene).instantiate()
	_portal_c_a_a.ruta_nivel_destino = _nivel_a.scene_file_path
	_portal_c_a_a.position = Vector2(500, 500)
	_nivel_c.add_child(_portal_c_a_a)

	_jugador = Node2D.new()
	root.add_child(_jugador)


func _probar_con_portal_de_regreso() -> void:
	var punto = _gn._punto_de_llegada(_nivel_b, _nivel_a.scene_file_path)
	var esperado: Vector2 = _portal_b_a_a.punto_llegada.global_position
	print("Aparece exactamente en punto_llegada del portal de regreso (esperado %s): %s" % [
		esperado, punto
	])
	_aparece_en_punto_llegada_del_portal_ok = punto == esperado

	# El punto_llegada por defecto debe quedar FUERA de "radio del portal +
	# radio del jugador" (30 + 10 px) — mismo bug real que encontró
	# prueba_limites_camara: a esa distancia justa, el portal se reactivaba
	# solo apenas vencía la gracia anti-rebote (ver el comentario en
	# PortalNivel.gd).
	var distancia: float = (punto as Vector2).distance_to(_portal_b_a_a.global_position)
	print("El punto_llegada por defecto queda fuera del radio de disparo + jugador (esperado >40, %s)" % distancia)
	_aparece_en_punto_llegada_del_portal_ok = _aparece_en_punto_llegada_del_portal_ok and distancia > 40.0


func _probar_sin_origen() -> void:
	var punto = _gn._punto_de_llegada(_nivel_b, "")
	print("Sin ruta de origen, usa el PuntoAparicion fijo (esperado true): %s" % \
		(punto == _nivel_b.punto_aparicion().global_position))
	_sin_origen_usa_punto_fijo_ok = punto == _nivel_b.punto_aparicion().global_position


func _probar_portal_sin_marcador_configurado() -> void:
	var punto = _gn._punto_de_llegada(_nivel_c, _nivel_a.scene_file_path)
	print("Portal de regreso sin punto_llegada configurado, cae al PuntoAparicion fijo (esperado true): %s" % \
		(punto == _nivel_c.punto_aparicion().global_position))
	_portal_sin_marcador_usa_punto_fijo_ok = punto == _nivel_c.punto_aparicion().global_position


func _informar() -> bool:
	var exito := _aparece_en_punto_llegada_del_portal_ok and _sin_origen_usa_punto_fijo_ok \
		and _portal_sin_marcador_usa_punto_fijo_ok
	print("PRUEBA GESTOR NIVELES APARICION JUNTO A PORTAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
