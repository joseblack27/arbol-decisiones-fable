# =============================================================================
# Prueba de GestorInteraccion — el registro central que reemplazó al botón
# "Hablar" propio de cada NPC por una lista fija en pantalla (ver
# ListaInteraccion.gd, a la izquierda del paginador de habilidades en
# Mundo.tscn). Reescrita tras el rediseño: registrar()/quitar() ya no
# avisan "disponible/no_disponible" con un solo texto — transmiten la pila
# COMPLETA por la señal cambio(items), pedido real del usuario ("con dos
# cofres uno al lado del otro no había forma de elegir cuál abrir").
#
# Cubre: registrar/quitar transmiten la lista completa (no solo el tope),
# dos interactuables superpuestos aparecen los DOS a la vez, ejecutar el
# callback de una acción corre de verdad, y el flujo real con un Npc de
# verdad por proximidad.
#   godot --headless --path . --script res://pruebas/prueba_interaccion_npc.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _gestor: Node
var _npc
var _jugador: Node2D
var _datos_dialogo: DatosDialogo
var _dialogo_recibido := false

var _ultimos_items: Array = []

var _registrar_avisa_cambio_ok := false
var _quitar_unico_vacia_la_lista_ok := false
var _pila_incluye_ambos_ok := false
var _quitar_uno_deja_al_otro_ok := false
var _accion_ejecuta_callback_ok := false
var _proximidad_real_de_npc_ok := false
var _interactuar_desde_el_registro_abre_dialogo_ok := false
var _alejarse_vacia_la_lista_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_registrar_quitar()
	_probar_pila()
	_probar_accion_generica()
	_probar_proximidad_real_npc()
	return _informar()


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_gestor = root.get_node("/root/GestorInteraccion")
	_gestor.cambio.connect(_on_cambio)


func _on_cambio(items: Array) -> void:
	_ultimos_items = items


func _probar_registrar_quitar() -> void:
	var obj := Node.new()
	var acciones: Array[Dictionary] = [{"texto": "Probar", "callback": func(): pass}]
	_gestor.registrar(obj, "Objeto de Prueba", acciones)
	_registrar_avisa_cambio_ok = _ultimos_items.size() == 1 \
		and _ultimos_items[0]["nombre"] == "Objeto de Prueba"
	print("registrar() transmite la lista con el nombre (esperado true): %s" % _registrar_avisa_cambio_ok)

	_gestor.quitar(obj)
	_quitar_unico_vacia_la_lista_ok = _ultimos_items.is_empty()
	print("quitar() del único registrado vacía la lista (esperado true): %s" % _quitar_unico_vacia_la_lista_ok)
	obj.free()


func _probar_pila() -> void:
	var obj_a := Node.new()
	var obj_b := Node.new()
	var acciones_a: Array[Dictionary] = [{"texto": "A", "callback": func(): pass}]
	var acciones_b: Array[Dictionary] = [{"texto": "B", "callback": func(): pass}]
	_gestor.registrar(obj_a, "A", acciones_a)
	_gestor.registrar(obj_b, "B", acciones_b)
	_pila_incluye_ambos_ok = _ultimos_items.size() == 2
	print("Dos interactuables superpuestos aparecen los DOS a la vez (esperado true, 2): %s, %d" % [
		_pila_incluye_ambos_ok, _ultimos_items.size()
	])

	_gestor.quitar(obj_b)
	_quitar_uno_deja_al_otro_ok = _ultimos_items.size() == 1 and _ultimos_items[0]["nombre"] == "A"
	print("Quitar uno deja al otro solo en la lista (esperado true): %s" % _quitar_uno_deja_al_otro_ok)

	_gestor.quitar(obj_a)
	obj_a.free()
	obj_b.free()


func _probar_accion_generica() -> void:
	var obj := Node.new()
	var estado := {"llamado": false}
	var callback := func(): estado["llamado"] = true
	var acciones: Array[Dictionary] = [{"texto": "Tocar", "callback": callback}]
	_gestor.registrar(obj, "X", acciones)

	# Simula lo que hace ListaInteraccion al tocar el botón de una acción:
	# invocar el callback tal cual viene en la lista transmitida.
	var accion: Dictionary = _ultimos_items[0]["acciones"][0]
	accion["callback"].call()
	_accion_ejecuta_callback_ok = estado["llamado"]
	print("Invocar el callback de una acción corre de verdad (esperado true): %s" % _accion_ejecuta_callback_ok)

	_gestor.quitar(obj)
	obj.free()


func _probar_proximidad_real_npc() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = Node2D.new()
	_jugador.add_to_group("jugadores")
	escena.add_child(_jugador)

	var linea := LineaDialogo.new()
	linea.hablante = "Comerciante"
	linea.texto = "Hola."
	_datos_dialogo = DatosDialogo.new()
	_datos_dialogo.lineas = [linea]

	_npc = (load("res://escenas/npc/Npc.tscn") as PackedScene).instantiate()
	_npc.datos_dialogo = _datos_dialogo
	_npc.texto_interaccion = "Hablar"
	escena.add_child(_npc)
	_npc._label_nombre.text = "Comerciante"

	_bus.dialogo_solicitado.connect(_on_dialogo_solicitado)

	# Simula lo que en juego real hace el Area2D al superponerse.
	_npc._al_entrar_cuerpo(_jugador)
	_proximidad_real_de_npc_ok = _ultimos_items.size() == 1 \
		and _ultimos_items[0]["nombre"] == "Comerciante" \
		and _ultimos_items[0]["acciones"][0]["texto"] == "Hablar"
	print("Acercarse a un Npc real registra su nombre y la acción 'Hablar' (esperado true): %s" % \
		_proximidad_real_de_npc_ok)

	var accion_hablar: Dictionary = _ultimos_items[0]["acciones"][0]
	accion_hablar["callback"].call()
	_interactuar_desde_el_registro_abre_dialogo_ok = _dialogo_recibido
	print("Ejecutar la acción 'Hablar' abre el diálogo del Npc (esperado true): %s" % \
		_interactuar_desde_el_registro_abre_dialogo_ok)

	_npc._al_salir_cuerpo(_jugador)
	_alejarse_vacia_la_lista_ok = _ultimos_items.is_empty()
	print("Alejarse del Npc vacía la lista (esperado true): %s" % _alejarse_vacia_la_lista_ok)


func _on_dialogo_solicitado(_npc_emisor: Node, _datos: DatosDialogo) -> void:
	_dialogo_recibido = true


func _informar() -> bool:
	var exito := _registrar_avisa_cambio_ok and _quitar_unico_vacia_la_lista_ok \
		and _pila_incluye_ambos_ok and _quitar_uno_deja_al_otro_ok \
		and _accion_ejecuta_callback_ok and _proximidad_real_de_npc_ok \
		and _interactuar_desde_el_registro_abre_dialogo_ok and _alejarse_vacia_la_lista_ok
	print("PRUEBA INTERACCION NPC %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
