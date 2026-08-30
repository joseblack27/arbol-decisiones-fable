# =============================================================================
# Prueba de Aldeano.gd — pedido del usuario: "quiero que la ciudad se vea
# un poco más viva... aldeanos de fondo, que tenga un diálogo si les
# hablas y al interactuar con ellos que se detengan para hablarte".
#
# Cubre, con fotogramas físicos REALES (no todo en un _process()):
#   1. Deambula solo: sin nadie interactuando, su posición cambia con el
#      tiempo (camina hacia un destino elegido al azar cerca de donde
#      apareció).
#   2. Al interactuar (simula el Area2D real + tocar "Hablar"), se
#      detiene: dejar de moverse durante un rato con el diálogo "abierto"
#      no cambia su posición.
#   3. Al cerrarse el diálogo (simula GestorUI.modo_cambiado -> JUEGO),
#      retoma el deambular — la posición vuelve a cambiar.
#   4. Proximidad real: entrar registra en GestorInteraccion con la acción
#      "Hablar"; salir lo saca de la lista.
#   godot --headless --path . --script res://pruebas/prueba_aldeano_deambular_y_dialogo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _aldeano
var _jugador: Node2D
var _gestor: Node
var _ultimos_items: Array = []

var _posicion_antes_de_interactuar := Vector2.ZERO
var _posicion_durante_dialogo := Vector2.ZERO
var _posicion_tras_cerrar := Vector2.ZERO

var _deambula_solo_ok := false
var _se_detiene_al_hablar_ok := false
var _retoma_al_cerrar_ok := false
var _proximidad_registra_hablar_ok := false
var _alejarse_vacia_la_lista_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		60:
			_posicion_antes_de_interactuar = _aldeano.global_position
		120:
			_deambula_solo_ok = _aldeano.global_position.distance_to(_posicion_antes_de_interactuar) > 1.0
			print("Deambula solo, la posición cambia con el tiempo (esperado true): %s" % _deambula_solo_ok)
			_probar_proximidad()
			_interactuar()
			_posicion_durante_dialogo = _aldeano.global_position
		180:
			var se_movio: bool = _aldeano.global_position.distance_to(_posicion_durante_dialogo) > 1.0
			_se_detiene_al_hablar_ok = not se_movio
			print("Se queda quieto mientras 'habla' (esperado true): %s" % _se_detiene_al_hablar_ok)
			_cerrar_dialogo()
			_posicion_tras_cerrar = _aldeano.global_position
		240:
			_retoma_al_cerrar_ok = _aldeano.global_position.distance_to(_posicion_tras_cerrar) > 1.0
			print("Retoma el deambular al cerrarse el diálogo (esperado true): %s" % _retoma_al_cerrar_ok)
			return _informar()
	return false


func _montar() -> void:
	_aldeano = (load("res://escenas/npc/aldeano/Aldeano.tscn") as PackedScene).instantiate()
	_aldeano.datos_dialogo = load("res://recursos/dialogo/ejemplo_aldeano_1.tres")
	_aldeano.radio_deambulacion = 150.0
	_aldeano.espera_en_destino = 0.3
	root.add_child(_aldeano)
	_aldeano.global_position = Vector2(500, 500)

	_gestor = root.get_node("/root/GestorInteraccion")
	_gestor.cambio.connect(func(items): _ultimos_items = items)

	_jugador = Node2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)


func _probar_proximidad() -> void:
	_aldeano._al_entrar_cuerpo(_jugador)
	_proximidad_registra_hablar_ok = _ultimos_items.size() == 1 \
		and _ultimos_items[0]["nombre"] == "Aldeano" \
		and _ultimos_items[0]["acciones"][0]["texto"] == "Hablar"
	print("Acercarse registra su nombre y la acción 'Hablar' (esperado true): %s" % _proximidad_registra_hablar_ok)


func _interactuar() -> void:
	var accion: Dictionary = _ultimos_items[0]["acciones"][0]
	accion["callback"].call()


## Sin referenciar GestorUI.Modo directo (un enum se resuelve en tiempo de
## COMPILACIÓN) — mismo criterio ya establecido en esta suite (ver
## prueba_cofre_interaccion.gd): en un proceso --script fresco, resolver el
## identificador del autoload así de temprano puede pisarse con el orden
## de arranque. 0 = Modo.JUEGO (ver GestorUI.gd).
func _cerrar_dialogo() -> void:
	_aldeano._al_cambiar_modo(0)
	_aldeano._al_salir_cuerpo(_jugador)
	_alejarse_vacia_la_lista_ok = _ultimos_items.is_empty()
	print("Alejarse vacía la lista de interacción (esperado true): %s" % _alejarse_vacia_la_lista_ok)


func _informar() -> bool:
	var exito := _deambula_solo_ok and _se_detiene_al_hablar_ok and _retoma_al_cerrar_ok \
		and _proximidad_registra_hablar_ok and _alejarse_vacia_la_lista_ok
	print("PRUEBA ALDEANO DEAMBULAR Y DIALOGO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
