# =============================================================================
# Prueba de que el Muro ya no decide su propia destrucción por predicción
# local en cada peer (bug reportado: el mismo muro moría para un jugador y
# seguía vivo para otro, con el proyectil atravesándolo en uno y chocando
# en el otro). Verifica:
#   1. Sin red (single-player/servidor): quitar_vida() SÍ rompe el muro de
#      verdad, y HabilidadMuroJugador se entera (_on_muro_muerte).
#   2. Como CLIENTE puro (en red, no servidor): quitar_vida()/recibir_
#      impacto() son no-op — el muro NO se rompe por predicción local.
#   3. El aviso de red (_recibir_destruccion_muro_red, lo que en el juego
#      real manda el servidor) SÍ fuerza la destrucción de la copia local,
#      identificando el muro correcto por su id aunque haya más de uno
#      vivo a la vez.
#   godot --headless --path . --script res://pruebas/prueba_muro_sincronizado_por_red.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _muro_a
var _muro_b
var _muro_c
var _id_b: int = -1
var _id_c: int = -1
var _vida_c_antes: float = 0.0
var _fotogramas := 0

var _sin_red_rompe_de_verdad := false
var _limpia_el_diccionario_local := false
var _cliente_no_rompe_por_prediccion := false
var _aviso_red_fuerza_destruccion := false
var _no_afecta_al_otro_muro := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_sin_red()
		3:
			_probar_cliente_no_rompe()
		4:
			_probar_dos_muros_a_la_vez()
		5:
			_probar_aviso_red_fuerza_destruccion()
		6:
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/muro/HabilidadMuroJugador.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador


func _probar_sin_red() -> void:
	_habilidad._ejecutar(Vector2.RIGHT, 1.0)
	var id_a: int = _habilidad._contador_muros
	_muro_a = _habilidad._muros_activos[id_a]

	_muro_a.quitar_vida(99999.0)
	_sin_red_rompe_de_verdad = _muro_a.obtener_vida() <= 0.0
	_limpia_el_diccionario_local = not _habilidad._muros_activos.has(id_a)


func _probar_cliente_no_rompe() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 34567)  # puerto sin nadie escuchando: no hace falta que conecte.
	root.multiplayer.multiplayer_peer = peer

	_habilidad._ejecutar(Vector2.UP, 1.0)
	_id_b = _habilidad._contador_muros
	_muro_b = _habilidad._muros_activos[_id_b]

	var vida_antes: float = _muro_b.obtener_vida()
	_muro_b.quitar_vida(99999.0)
	var rompio_por_impacto: bool = _muro_b.recibir_impacto(99999.0)
	_cliente_no_rompe_por_prediccion = is_equal_approx(_muro_b.obtener_vida(), vida_antes) \
		and not rompio_por_impacto and _habilidad._muros_activos.has(_id_b)


## El usuario confirmó que puede tener más de un muro vivo a la vez — clave
## para justificar el Dictionary por id en vez de una sola referencia.
## Acá conviven _muro_b y _muro_c; el próximo paso solo destruye _muro_b
## por su id y hay que confirmar que _muro_c no se entera de nada.
func _probar_dos_muros_a_la_vez() -> void:
	_habilidad._ejecutar(Vector2.DOWN, 1.0)
	_id_c = _habilidad._contador_muros
	_muro_c = _habilidad._muros_activos[_id_c]
	_vida_c_antes = _muro_c.obtener_vida()


func _probar_aviso_red_fuerza_destruccion() -> void:
	_habilidad._recibir_destruccion_muro_red(_id_b)
	_aviso_red_fuerza_destruccion = not _habilidad._muros_activos.has(_id_b)
	_no_afecta_al_otro_muro = _habilidad._muros_activos.has(_id_c) \
		and is_equal_approx(_muro_c.obtener_vida(), _vida_c_antes)

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _informar() -> bool:
	print("Sin red, quitar_vida() rompe el muro de verdad: %s" % _sin_red_rompe_de_verdad)
	print("HabilidadMuroJugador limpia su diccionario al romperse: %s" % _limpia_el_diccionario_local)
	print("Como cliente puro, ni quitar_vida() ni recibir_impacto() rompen el muro: %s" % _cliente_no_rompe_por_prediccion)
	print("El aviso de red (_recibir_destruccion_muro_red) SÍ fuerza la destrucción: %s" % _aviso_red_fuerza_destruccion)
	print("Con 2 muros vivos a la vez, destruir uno por id NO afecta al otro: %s" % _no_afecta_al_otro_muro)

	var exito := _sin_red_rompe_de_verdad and _limpia_el_diccionario_local \
		and _cliente_no_rompe_por_prediccion and _aviso_red_fuerza_destruccion \
		and _no_afecta_al_otro_muro
	print("PRUEBA MURO SINCRONIZADO POR RED %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
