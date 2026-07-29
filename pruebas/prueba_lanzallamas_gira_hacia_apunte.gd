# =============================================================================
# Prueba de que HabilidadLanzallamas gira al dueño hacia donde apunta el
# chorro (pedido del usuario: "tanto local como remoto"). Lanzallamas NO
# pasa por HabilidadBase.activar() (ver comentario de esa clase), que es
# donde vive el giro para el resto de las habilidades — sin el arreglo,
# direccion_mirada nunca se tocaba y el personaje seguía "mirando" hacia
# donde caminó por última vez mientras canalizaba el chorro para otro lado.
#
# Se prueba con un Jugador.tscn REAL (no el CharacterBody2D sintético de
# prueba_lanzallamas.gd, que no tiene "direccion_mirada"): arranca el canal
# apuntando a la derecha, re-apunta hacia arriba mientras sigue con el
# "dedo" puesto, y confirma que la orientación sigue el apunte en cada
# caso. Se verifica leyendo _ultima_direccion, no direccion_mirada
# directo: este último es un PULSO de un solo fotograma (Jugador.
# _aplicar_presentacion lo consume y lo vuelve a poner en ZERO apenas lo
# lee, cada physics_process — ver ese archivo), así que para cuando el
# _process() de esta prueba vuelve a correr ya se limpió solo. Justo
# _ultima_direccion es la que persiste Y la que Jugador._replicar_
# posicion_red() manda a los demás jugadores — confirmarla acá cubre
# también el caso remoto sin tener que levantar cliente+servidor reales.
#   godot --headless --path . --script res://pruebas/prueba_lanzallamas_gira_hacia_apunte.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _fotogramas := 0
var _mirada_al_arrancar := Vector2.ZERO
var _mirada_al_reapuntar := Vector2.ZERO


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			# Primer "toque": arranca el canal apuntando a la derecha.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		6:
			_mirada_al_arrancar = _jugador._ultima_direccion
			print("_ultima_direccion al arrancar el canal (esperado (1,0)): %s" % _mirada_al_arrancar)
		10:
			# Sigue con el "dedo" puesto pero re-apunta hacia arriba.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.UP, 1.0])
		11:
			_mirada_al_reapuntar = _jugador._ultima_direccion
			print("_ultima_direccion tras re-apuntar hacia arriba (esperado (0,-1)): %s" % _mirada_al_reapuntar)
			return _informar()
	return false


func _montar() -> void:
	var sm := root.get_node("/root/SeñalManager")
	sm.registrar("slot_0_apunte", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_lanzar", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_cancelar", "prueba", {})

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/lanzallamas/HabilidadLanzallamas.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.set("costo_energia", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.duracion_recarga = 2.0


func _informar() -> bool:
	var arranque_ok := _mirada_al_arrancar.is_equal_approx(Vector2.RIGHT)
	var reapunte_ok := _mirada_al_reapuntar.is_equal_approx(Vector2.UP)
	var exito := arranque_ok and reapunte_ok
	print("PRUEBA LANZALLAMAS GIRA HACIA APUNTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
