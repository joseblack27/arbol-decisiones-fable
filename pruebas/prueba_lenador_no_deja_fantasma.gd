# =============================================================================
# Bug real reportado en juego: "el leñador nunca desaparece del mapa, es
# como si quedara la instancia allí en el círculo del tp y otro cuerpo se
# moviera desde el otro mapa". Causa: al ser una sola instancia que vive
# fuera de cualquier nivel (ver Lenador.gd), InteresEspacial.peers_cercanos()
# deja de mandarle posición a un cliente en cuanto el leñador cruza a un
# nivel lejano (100.000 px de offset) — ese cliente nunca se entera de que
# se fue, así que su sprite se queda dibujado para siempre en el último
# punto visto ("fantasma").
#
# Verifica que _cruzar_a_pradera()/_cruzar_a_ciudad() ocultan el nodo ANTES
# de saltar (evita el fantasma en cualquier cliente lejano), y que
# _recibir_estado_red() (lo que sí llega a un cliente CERCA de la posición
# nueva) lo vuelve a mostrar.
#   godot --headless --path . --script res://pruebas/prueba_lenador_no_deja_fantasma.gd
# =============================================================================
extends SceneTree

var _lenador

var _tscn_arranca_invisible_ok := false
var _cruzar_oculta_antes_de_saltar_ok := false
var _recibir_estado_vuelve_a_mostrar_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_arranca_invisible()
	_probar_cruzar_oculta()
	_probar_recibir_estado_muestra()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	var gn := root.get_node("/root/GestorNiveles")
	var contenedor_nivel := Node.new()
	root.add_child(contenedor_nivel)
	gn.registrar(contenedor_nivel, null)
	var contenedor_errantes := Node2D.new()
	root.add_child(contenedor_errantes)
	gn.registrar_errantes(contenedor_errantes)

	_lenador = (load("res://escenas/npc/leñador/Lenador.tscn") as PackedScene).instantiate()
	contenedor_errantes.add_child(_lenador)


## El .tscn arranca visible=false — evita un flash en la posición default
## (0,0) del editor en cualquier cliente recién spawneado, antes de que
## llegue la primera posición/visibilidad real.
func _probar_arranca_invisible() -> void:
	print("Arranca invisible (esperado false): %s" % _lenador.visible)
	_tscn_arranca_invisible_ok = not _lenador.visible


func _probar_cruzar_oculta() -> void:
	_lenador.visible = true  # simula que ya lo habían visto antes de cruzar.
	_lenador._cruzar_a_pradera()
	print("Cruzar oculta el nodo ANTES de reposicionarse (esperado false): %s" % _lenador.visible)
	_cruzar_oculta_antes_de_saltar_ok = not _lenador.visible


func _probar_recibir_estado_muestra() -> void:
	_lenador._recibir_estado_red(Vector2(999, 999), Vector2.RIGHT, Vector2.RIGHT)
	print("Recibir una posición real lo vuelve a mostrar (esperado true): %s" % _lenador.visible)
	_recibir_estado_vuelve_a_mostrar_ok = _lenador.visible


func _informar() -> bool:
	var exito := _tscn_arranca_invisible_ok and _cruzar_oculta_antes_de_saltar_ok \
		and _recibir_estado_vuelve_a_mostrar_ok
	print("PRUEBA LEÑADOR NO DEJA FANTASMA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
