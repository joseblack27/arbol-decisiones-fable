# =============================================================================
# Prueba de GestorInteraccion — el registro central que reemplazó al botón
# "Hablar" propio de cada NPC por un botón fijo en pantalla (ver
# BotonInteraccion.gd, a la izquierda del paginador de habilidades en
# Mundo.tscn). Cubre: registrar/quitar, pila (dos interactuables
# superpuestos), y el flujo real con un Npc de verdad por proximidad.
#   godot --headless --path . --script res://pruebas/prueba_interaccion_npc.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _gestor: Node
var _npc
var _jugador: Node2D
var _datos_dialogo: DatosDialogo

var _disponible_texto := ""
var _disponible_veces := 0
var _no_disponible_veces := 0

var _registrar_avisa_disponible_ok := false
var _quitar_unico_avisa_no_disponible_ok := false
var _pila_vuelve_al_anterior_ok := false
var _interactuar_llama_al_objeto_ok := false
var _proximidad_real_de_npc_ok := false
var _alejarse_apaga_boton_ok := false
var _interactuar_desde_el_registro_abre_dialogo_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_registrar_quitar()
	_probar_pila()
	_probar_interactuar_generico()
	_probar_proximidad_real_npc()
	return _informar()


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_gestor = root.get_node("/root/GestorInteraccion")
	_gestor.disponible.connect(_on_disponible)
	_gestor.no_disponible.connect(_on_no_disponible)


func _on_disponible(_objeto: Node, texto: String) -> void:
	_disponible_texto = texto
	_disponible_veces += 1


func _on_no_disponible() -> void:
	_no_disponible_veces += 1


func _probar_registrar_quitar() -> void:
	var obj := Node.new()
	_gestor.registrar(obj, "Probar")
	_registrar_avisa_disponible_ok = _disponible_veces == 1 and _disponible_texto == "Probar"
	print("registrar() avisa 'disponible' con el texto (esperado true): %s" % _registrar_avisa_disponible_ok)

	_gestor.quitar(obj)
	_quitar_unico_avisa_no_disponible_ok = _no_disponible_veces == 1
	print("quitar() del único registrado avisa 'no_disponible' (esperado true): %s" % _quitar_unico_avisa_no_disponible_ok)
	obj.free()


func _probar_pila() -> void:
	var obj_a := Node.new()
	var obj_b := Node.new()
	_gestor.registrar(obj_a, "A")
	_gestor.registrar(obj_b, "B")
	_gestor.quitar(obj_b)
	_pila_vuelve_al_anterior_ok = _disponible_texto == "A"
	print("Quitar el último registrado (B) vuelve a mostrar el anterior (A) (esperado true): %s" % _pila_vuelve_al_anterior_ok)
	_gestor.quitar(obj_a)
	obj_a.free()
	obj_b.free()


func _probar_interactuar_generico() -> void:
	# Sin helper dedicado: un Node simple con un método interactuar() propio alcanza.
	var script := GDScript.new()
	script.source_code = "extends Node\nvar llamado := false\nfunc interactuar():\n\tllamado = true\n"
	script.reload()
	var obj = script.new()
	_gestor.registrar(obj, "X")
	_gestor.interactuar()
	_interactuar_llama_al_objeto_ok = obj.llamado
	print("interactuar() llama al método interactuar() del objeto activo (esperado true): %s" % _interactuar_llama_al_objeto_ok)
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

	_bus.dialogo_solicitado.connect(_on_dialogo_solicitado)

	# Simula lo que en juego real hace el Area2D al superponerse.
	_npc._al_entrar_cuerpo(_jugador)
	_proximidad_real_de_npc_ok = _disponible_texto == "Hablar" and _disponible_veces > 0

	_gestor.interactuar()
	_interactuar_desde_el_registro_abre_dialogo_ok = _dialogo_recibido

	_npc._al_salir_cuerpo(_jugador)
	_alejarse_apaga_boton_ok = _no_disponible_veces > 0

	print("Acercarse a un Npc real registra 'Hablar' como disponible (esperado true): %s" % _proximidad_real_de_npc_ok)
	print("interactuar() desde el registro abre el diálogo del Npc (esperado true): %s" % _interactuar_desde_el_registro_abre_dialogo_ok)
	print("Alejarse del Npc apaga el botón (esperado true): %s" % _alejarse_apaga_boton_ok)


var _dialogo_recibido := false


func _on_dialogo_solicitado(_npc_emisor: Node, _datos: DatosDialogo) -> void:
	_dialogo_recibido = true


func _informar() -> bool:
	var exito := _registrar_avisa_disponible_ok and _quitar_unico_avisa_no_disponible_ok \
		and _pila_vuelve_al_anterior_ok and _interactuar_llama_al_objeto_ok \
		and _proximidad_real_de_npc_ok and _interactuar_desde_el_registro_abre_dialogo_ok \
		and _alejarse_apaga_boton_ok
	print("PRUEBA INTERACCION NPC %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
