# =============================================================================
# Prueba de Cofre.gd — proximidad + registro en GestorInteraccion (mismo
# patrón que prueba_interaccion_npc.gd._probar_proximidad_real_npc, tras el
# rediseño a la señal cambio(items) — ver ese archivo/GestorInteraccion.gd)
# y que interactuar() abre PanelCofre de verdad (emite BusEventos.
# cofre_solicitado + activa GestorUI.Modo.DIALOGO, mismo modo que
# PanelTienda). A diferencia de la versión vieja (loot una sola vez), un
# cofre se puede volver a abrir cuantas veces haga falta — no hay
# "ya_abierto" que revisar acá.
#
# Cubre:
#   1. Acercarse registra el cofre con la acción "Abrir" en GestorInteraccion.
#   2. Invocar ese callback emite cofre_solicitado con el id/nombre correctos
#      y activa el modo DIALOGO (bloquea juego mientras el panel está abierto).
#   3. Alejarse vacía la lista.
#   godot --headless --path . --script res://pruebas/prueba_cofre_interaccion.gd
# =============================================================================
extends SceneTree

var _gestor: Node
var _gestor_ui: Node
var _jugador: Node2D
var _cofre

var _ultimos_items: Array = []

var _id_recibido := ""
var _nombre_recibido := ""
var _cofre_solicitado_veces := 0

var _proximidad_registra_abrir_ok := false
var _interactuar_emite_solicitud_y_abre_modo_ok := false
var _alejarse_vacia_la_lista_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_proximidad()
	_probar_interactuar()
	_probar_alejarse()
	return _informar()


func _on_cambio(items: Array) -> void:
	_ultimos_items = items


func _on_cofre_solicitado(id_cofre: String, nombre_cofre: String) -> void:
	_id_recibido = id_cofre
	_nombre_recibido = nombre_cofre
	_cofre_solicitado_veces += 1


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInteraccion")
	_gestor.cambio.connect(_on_cambio)
	root.get_node("/root/BusEventos").cofre_solicitado.connect(_on_cofre_solicitado)
	_gestor_ui = root.get_node("/root/GestorUI")

	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)

	_cofre = (load("res://escenas/objetos/Cofre.tscn") as PackedScene).instantiate()
	_cofre.id = "cofre_interaccion_de_prueba"
	_cofre.nombre = "Cofre de Prueba"
	_cofre.texto_interaccion = "Abrir"
	escena.add_child(_cofre)


## Simula lo que en juego real hace el Area2D al superponerse (mismo
## criterio que prueba_interaccion_npc.gd).
func _probar_proximidad() -> void:
	_cofre._al_entrar_cuerpo(_jugador)
	_proximidad_registra_abrir_ok = _ultimos_items.size() == 1 \
		and _ultimos_items[0]["nombre"] == "Cofre de Prueba" \
		and _ultimos_items[0]["acciones"][0]["texto"] == "Abrir"
	print("Acercarse a un cofre registra 'Abrir' como acción disponible (esperado true): %s" % \
		_proximidad_registra_abrir_ok)


## Sin referenciar GestorUI.Modo directo (un enum se resuelve en tiempo de
## COMPILACIÓN) — en un proceso --script fresco, resolver el identificador
## del autoload así de temprano puede pisarse con el orden de arranque
## (mismo motivo por el que "_cofre" más arriba tampoco está tipado como
## Cofre). _gestor_ui (Node crudo, resuelto recién en _montar()) + valores
## crudos esquivan el problema. 0 = Modo.JUEGO, 2 = Modo.DIALOGO (ver
## GestorUI.gd).
func _probar_interactuar() -> void:
	_gestor_ui.modo_actual = 0  # Modo.JUEGO
	var accion_abrir: Dictionary = _ultimos_items[0]["acciones"][0]
	accion_abrir["callback"].call()
	_interactuar_emite_solicitud_y_abre_modo_ok = _cofre_solicitado_veces == 1 \
		and _id_recibido == "cofre_interaccion_de_prueba" and _nombre_recibido == "Cofre de Prueba" \
		and _gestor_ui.modo_actual == 2  # Modo.DIALOGO
	print("Ejecutar la acción 'Abrir' emite cofre_solicitado(id, nombre) y activa Modo.DIALOGO (esperado true): %s" % \
		_interactuar_emite_solicitud_y_abre_modo_ok)


func _probar_alejarse() -> void:
	_cofre._al_salir_cuerpo(_jugador)
	_alejarse_vacia_la_lista_ok = _ultimos_items.is_empty()
	print("Alejarse del cofre vacía la lista (esperado true): %s" % _alejarse_vacia_la_lista_ok)


func _informar() -> bool:
	var exito := _proximidad_registra_abrir_ok and _interactuar_emite_solicitud_y_abre_modo_ok \
		and _alejarse_vacia_la_lista_ok
	print("  proximidad registra 'Abrir': %s" % _proximidad_registra_abrir_ok)
	print("  interactuar emite solicitud y activa modo diálogo: %s" % _interactuar_emite_solicitud_y_abre_modo_ok)
	print("  alejarse vacía la lista: %s" % _alejarse_vacia_la_lista_ok)
	print("PRUEBA COFRE INTERACCION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
