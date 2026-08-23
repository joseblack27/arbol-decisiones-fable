# =============================================================================
# Prueba de GestorNiveles.asegurar_nivel_cargado_servidor() — lo necesita el
# leñador (ver GestorLenador.gd) para forzar que Ciudad Y Pradera existan
# desde el arranque del servidor, sin depender de que un jugador visite
# cada una primero (hoy _asegurar_nivel_cargado es privado y solo se llama
# cuando un jugador real cruza a ese nivel).
#
# Cubre:
#   1. Fuera del servidor dedicado (_es_servidor=false) devuelve null, no
#      carga nada — evitar que un cliente/prueba suelta dispare esto por
#      error.
#   2. En el servidor, carga el nivel si todavía no estaba.
#   3. Llamarlo de nuevo con la misma ruta devuelve la MISMA instancia (no
#      duplica el nivel).
#   godot --headless --path . --script res://pruebas/prueba_gestor_niveles_asegurar_cargado_servidor.gd
# =============================================================================
extends SceneTree

const _RUTA_CAMINO := "res://escenas/niveles/NivelCamino.tscn"
const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"

var _gn
var _null_fuera_de_servidor_ok := false
var _carga_el_nivel_ok := false
var _no_duplica_al_repetir_ok := false


func _process(_delta: float) -> bool:
	_gn = root.get_node("/root/GestorNiveles")

	var contenedor := Node.new()
	root.add_child(contenedor)
	_gn.registrar(contenedor, null)

	# 1. Sin preparar_servidor(): _es_servidor sigue false.
	var resultado_sin_servidor = _gn.asegurar_nivel_cargado_servidor(_RUTA_CAMINO)
	print("Fuera de servidor devuelve null (esperado true): %s" % (resultado_sin_servidor == null))
	_null_fuera_de_servidor_ok = resultado_sin_servidor == null

	# 2. Como servidor, con el Camino ya como nivel inicial: Ciudad todavía
	# NO está cargada (nadie la visitó) — así se prueba de verdad el caso
	# "cargarla desde cero", no solo "ya estaba".
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_gn.preparar_servidor(_RUTA_CAMINO)

	var nivel_a = _gn.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	print("Como servidor, carga un nivel que nadie había visitado (esperado true): %s" % (nivel_a != null))
	_carga_el_nivel_ok = nivel_a != null

	var nivel_b = _gn.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	print("Llamarlo de nuevo devuelve la MISMA instancia, sin duplicar (esperado true): %s" % \
		(nivel_a == nivel_b))
	_no_duplica_al_repetir_ok = nivel_a == nivel_b

	return _informar()


func _informar() -> bool:
	var exito := _null_fuera_de_servidor_ok and _carga_el_nivel_ok and _no_duplica_al_repetir_ok
	print("PRUEBA GESTOR NIVELES ASEGURAR CARGADO SERVIDOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
