# =============================================================================
# Prueba de HabilidadTrampa/Trampa (sin red): coloca una trampa oculta que
# espera a que un enemigo entre en su radio de detección — recién ahí
# hace daño en área y se libera. Si nadie la pisa, se apaga sola.
#
# Verifica:
#   1. Un enemigo dentro del radio de detección la activa (queda
#      _activada=true) y recibe daño real.
#   2. Tras el destello (duracion_destello), vuelve sola a la piscina.
#   3. Una trampa SIN nadie cerca (duracion_maxima corta para la prueba)
#      se apaga sola, sin activarse ni hacer daño.
#   4. El marcador tenue mientras espera (pedido del usuario: "que quede
#      un poco visible para el jugador") solo se muestra en la pantalla
#      de QUIEN LA COLOCÓ — la misma condición que usa Trampa._draw() se
#      prueba acá directo (no se puede afirmar nada sobre píxeles
#      dibujados en headless, pero sí sobre la condición booleana real).
#   godot --headless --path . --script res://pruebas/prueba_trampa.gd
# =============================================================================
extends SceneTree

var _jugador
var _enemigo
var _habilidad
var _gestor_piscinas: Node
var _fotogramas := 0

var _trampa: Trampa = null

var _se_activa_con_enemigo_cerca := false
var _hace_dano_real := false
var _vuelve_a_la_piscina_tras_destello := false
var _trampa_sin_activar_se_apaga_sola := false
var _marcador_visible_para_quien_la_coloco := false
var _marcador_oculto_para_un_jugador_ajeno := false


static func _script_enemigo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_c: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_habilidad.activar(Vector2.RIGHT, 1.0)
		5:
			_trampa = null
			for nodo in _gestor_piscinas._activos:
				if nodo is Trampa:
					_trampa = nodo
			_se_activa_con_enemigo_cerca = _trampa != null and _trampa._activada
			print("Trampa se activa con el enemigo cerca (esperado true): %s" % _se_activa_con_enemigo_cerca)
			_hace_dano_real = _enemigo.golpes > 0
			print("Hace daño real al activarse (esperado true, golpes=%d): %s" % [_enemigo.golpes, _hace_dano_real])
		30:
			# duracion_destello=0.3s (~18 fotogramas) ya pasó de sobra.
			_vuelve_a_la_piscina_tras_destello = _trampa == null or not _gestor_piscinas._activos.has(_trampa)
			print("Vuelve a la piscina tras el destello (esperado true): %s" % _vuelve_a_la_piscina_tras_destello)
			_probar_trampa_sin_activar()
		90:
			# duracion_maxima de PRUEBA = 0.5s (~30 fotogramas) ya pasó de
			# sobra, y no hay ningún enemigo cerca de esta segunda trampa.
			_trampa_sin_activar_se_apaga_sola = not _gestor_piscinas._activos.has(_trampa)
			print("Trampa sin activar se apaga sola (esperado true): %s" % _trampa_sin_activar_se_apaga_sola)
			_probar_marcador_local_only()
		91:
			return _informar()
	return false


## Misma condición que Trampa._draw() usa para decidir si dibuja el
## marcador tenue mientras espera: "entidad_fuente == Utils.jugador_
## local()". Con un peer local (sin conectar a nadie) se puede distinguir
## de verdad "mi" jugador de uno "ajeno" — mismo patrón que ya usan otras
## pruebas de este proyecto (ver prueba_oclusion_solo_jugador_local.gd).
func _probar_marcador_local_only() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()

	var trampa: Trampa = _gestor_piscinas.obtener(load("res://escenas/habilidades/trampa/Trampa.tscn"))

	var guion_jugador := GDScript.new()
	guion_jugador.source_code = "extends CharacterBody2D\nvar peer_id_dueño: int = -1\n"
	guion_jugador.reload()

	var propio := CharacterBody2D.new()
	propio.set_script(guion_jugador)
	propio.peer_id_dueño = mi_id
	propio.add_to_group("jugadores")
	root.add_child(propio)

	var ajeno := CharacterBody2D.new()
	ajeno.set_script(guion_jugador)
	ajeno.peer_id_dueño = mi_id + 999
	ajeno.add_to_group("jugadores")
	root.add_child(ajeno)

	trampa.entidad_fuente = propio
	_marcador_visible_para_quien_la_coloco = trampa.entidad_fuente == root.get_node("/root/Utils").jugador_local()
	print("Marcador visible para quien la colocó (esperado true): %s" % _marcador_visible_para_quien_la_coloco)

	trampa.entidad_fuente = ajeno
	_marcador_oculto_para_un_jugador_ajeno = trampa.entidad_fuente != root.get_node("/root/Utils").jugador_local()
	print("Marcador oculto si la colocó un jugador ajeno (esperado true): %s" % _marcador_oculto_para_un_jugador_ajeno)

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _montar() -> void:
	_gestor_piscinas = root.get_node("/root/GestorPiscinas")

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)

	_enemigo = CharacterBody2D.new()
	_enemigo.set_script(_script_enemigo())
	_enemigo.add_to_group("enemigos")
	_enemigo.collision_layer = 2
	_enemigo.global_position = Vector2(30, 0)  # dentro del radio_deteccion (40px) del punto de colocación.
	root.add_child(_enemigo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	forma.shape = circ
	_enemigo.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/trampa/HabilidadTrampa.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.escena_trampa = load("res://escenas/habilidades/trampa/Trampa.tscn")
	_habilidad.alcance_maximo = 30.0  # la trampa cae justo donde está el enemigo (30, 0).
	_habilidad.radio_deteccion = 40.0
	_habilidad.radio_dano = 60.0
	_habilidad.dano_trampa = 15.0
	_habilidad.duracion_maxima = 20.0
	_habilidad.costo_energia = 0.0
	_habilidad.duracion_recarga = 0.1
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador


## Segunda trampa, colocada lejos de cualquier enemigo, con una duración
## máxima corta a propósito para no tener que esperar los 20s reales.
func _probar_trampa_sin_activar() -> void:
	_habilidad.duracion_maxima = 0.5
	_habilidad.activar(Vector2.LEFT, 1.0)  # (-30, 0): a 60px del enemigo, bien fuera de su radio_deteccion (40px).
	_trampa = null
	for nodo in _gestor_piscinas._activos:
		if nodo is Trampa:
			_trampa = nodo


func _informar() -> bool:
	var exito := _se_activa_con_enemigo_cerca and _hace_dano_real \
		and _vuelve_a_la_piscina_tras_destello and _trampa_sin_activar_se_apaga_sola \
		and _marcador_visible_para_quien_la_coloco and _marcador_oculto_para_un_jugador_ajeno
	print("PRUEBA TRAMPA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
