# =============================================================================
# Pedido explícito del usuario: con pocas opciones, el panel (alto fijo en
# 300px para el peor caso de 8 opciones) dejaba mucho espacio vacío abajo.
# _ajustar_alto_fondo() calcula el alto real según la cantidad de opciones
# (medición segura — ver el comentario grande en PanelDialogo.gd sobre por
# qué Texto NO se mide en runtime) y lo deja pegado abajo siempre.
#
# Necesita fotogramas de verdad entre instanciar el panel y abrir el
# diálogo: Godot avisa (warning real, visto en pruebas manuales) que
# "Nodes with non-equal opposite anchors will have their size overridden
# after _ready()" — el primer pase de layout de Godot puede pisar una
# posición fijada a mano en el MISMO fotograma en que el panel recién
# entra al árbol. Dos fotogramas de por medio (igual que en juego real,
# donde el panel se instancia al cargar el nivel y el jugador lo abre
# recién varios fotogramas/segundos después) alcanzan para que se asiente.
#   godot --headless --path . --script res://pruebas/prueba_dialogo_alto_segun_opciones.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _panel: Control
var _fondo: Control
var _npc: Node2D
var _fotogramas := 0

var _alto_2: float
var _alto_8: float
var _pegado_2 := false
var _pegado_8 := false

var _alto_2_opciones_ok := false
var _alto_8_opciones_ok := false
var _2_opciones_mas_bajo_que_8_ok := false
var _ambos_pegados_abajo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_abrir_con_2_opciones()
		5:
			_alto_2 = _fondo.size.y
			_pegado_2 = is_equal_approx(_fondo.global_position.y + _fondo.size.y, _panel.size.y)
			print("DEBUG 2op: fondo.global_position=%s fondo.size=%s panel.size=%s panel.global_position=%s suma=%s" % [
				_fondo.global_position, _fondo.size, _panel.size, _panel.global_position,
				_fondo.global_position.y + _fondo.size.y])
			_panel._cerrar()
		7:
			_abrir_con_8_opciones()
		9:
			_alto_8 = _fondo.size.y
			_pegado_8 = is_equal_approx(_fondo.global_position.y + _fondo.size.y, _panel.size.y)
			return _informar()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_panel = (load("res://escenas/ui/panel_dialogo/PanelDialogo.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_fondo = _panel.get_node("Fondo")
	_npc = Node2D.new()
	root.add_child(_npc)


func _abrir_con_2_opciones() -> void:
	var op1 := OpcionDialogo.new()
	op1.texto = "Ver mercancía"
	op1.categoria = Enums.Dialogo.CategoriaOpcion.MERCADO
	var op2 := OpcionDialogo.new()
	op2.texto = "Nada, gracias"
	var linea := LineaDialogo.new()
	linea.hablante = "Comerciante"
	linea.texto = "Bienvenido a mi puesto, viajero. ¿En qué te puedo ayudar?"
	linea.opciones = [op1, op2]
	var datos := DatosDialogo.new()
	datos.lineas = [linea]
	_bus.dialogo_solicitado.emit(_npc, datos)


func _abrir_con_8_opciones() -> void:
	var datos := load("res://recursos/dialogo/ejemplo_comerciante.tres") as DatosDialogo
	_bus.dialogo_solicitado.emit(_npc, datos)


func _informar() -> bool:
	_alto_2_opciones_ok = _alto_2 < 300.0 and _alto_2 > 100.0
	print("Con 2 opciones, el alto es razonable y no el máximo (esperado true): %s (alto: %s)" % [_alto_2_opciones_ok, _alto_2])

	_alto_8_opciones_ok = _alto_8 > _alto_2
	print("Con 8 opciones (comerciante real), el alto es mayor que con 2 (esperado true): %s (alto: %s)" % [_alto_8_opciones_ok, _alto_8])

	_2_opciones_mas_bajo_que_8_ok = _alto_2 < _alto_8
	print("El alto con 2 opciones es menor que con 8 (esperado true): %s (%s < %s)" % [_2_opciones_mas_bajo_que_8_ok, _alto_2, _alto_8])

	_ambos_pegados_abajo_ok = _pegado_2 and _pegado_8
	print("En ambos casos el panel queda pegado abajo (esperado true): %s (2 opciones: %s, 8 opciones: %s)" % [
		_ambos_pegados_abajo_ok, _pegado_2, _pegado_8])

	var exito := _alto_2_opciones_ok and _alto_8_opciones_ok and _2_opciones_mas_bajo_que_8_ok and _ambos_pegados_abajo_ok
	print("PRUEBA DIALOGO ALTO SEGUN OPCIONES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
