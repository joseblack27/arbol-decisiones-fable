# =============================================================================
# Bug real reportado dos veces: la primera vez que se abre el diálogo el
# panel se ve bien, pero al cerrarlo y volver a abrirlo aparece con otro
# tamaño/en otra posición (llegó a "volar" al techo de la pantalla en el
# cliente real). Causa: el ancho/alto de Texto (autowrap) no se asienta de
# forma confiable de un fotograma al otro (comprobado a mano: texto.size
# pasaba de (1, 20) a (794, 20) entre la primera y la segunda apertura).
#
# Se probaron varios arreglos con números de píxeles fijos (reset_size(),
# call_deferred, alto fijo + ScrollContainer, clip_text) — a pedido
# explícito del usuario se revirtieron todos: nada de tamaños fijos,
# rechazado de raíz como técnica para este panel (ver memoria
# feedback_no_tamanos_fijos_panel_dialogo). El arreglo que quedó no toca
# ningún tamaño: la causa real no era el tamaño en sí, sino que
# PanelDialogo apagaba su layout con visible=false al cerrarse, y al
# reabrir (visible=true) Texto medía su ancho "en frío" antes de que se
# asentara. Ahora PanelDialogo.gd nunca toca "visible" — se oculta con
# modulate/mouse_filter en su lugar, así el layout de Texto sigue
# corriendo (y asentado) todo el tiempo, con diálogo abierto o cerrado.
#   godot --headless --path . --script res://pruebas/prueba_dialogo_tamano_consistente_al_reabrir.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _panel: Control
var _fondo: Control
var _datos: DatosDialogo
var _npc: Node2D
var _fotogramas := 0

var _tamano_primera_apertura: Vector2
var _posicion_primera_apertura: Vector2
var _tamano_segunda_apertura: Vector2
var _posicion_segunda_apertura: Vector2

var _tamano_igual_entre_aperturas_ok := false
var _pegado_abajo_primera_vez_ok := false
var _pegado_abajo_segunda_vez_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_bus.dialogo_solicitado.emit(_npc, _datos)
		6:
			_tamano_primera_apertura = _fondo.size
			_posicion_primera_apertura = _fondo.global_position
			_panel._cerrar()
		9:
			_bus.dialogo_solicitado.emit(_npc, _datos)
		12:
			_tamano_segunda_apertura = _fondo.size
			_posicion_segunda_apertura = _fondo.global_position
			return _informar()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_panel = (load("res://escenas/ui/panel_dialogo/PanelDialogo.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_fondo = _panel.get_node("Fondo")

	_npc = Node2D.new()
	root.add_child(_npc)

	# El diálogo real del comerciante: 8 opciones en la línea inicial —
	# el caso que más fácil dispara cualquier problema de tamaño.
	_datos = load("res://recursos/dialogo/ejemplo_comerciante.tres") as DatosDialogo


func _informar() -> bool:
	_tamano_igual_entre_aperturas_ok = _tamano_primera_apertura.is_equal_approx(_tamano_segunda_apertura)
	print("El tamaño de la primera y la segunda apertura coinciden (esperado true): %s (primera: %s, segunda: %s)" % [
		_tamano_igual_entre_aperturas_ok, _tamano_primera_apertura, _tamano_segunda_apertura])

	# Pegado abajo = el borde inferior de Fondo coincide con el borde
	# inferior del panel completo (que ocupa toda la pantalla) — si esto
	# falla es exactamente el bug reportado ("el panel voló al techo").
	var abajo_panel: float = _panel.size.y
	_pegado_abajo_primera_vez_ok = is_equal_approx(_posicion_primera_apertura.y + _tamano_primera_apertura.y, abajo_panel)
	print("Primera apertura: el fondo queda pegado abajo (esperado true): %s" % _pegado_abajo_primera_vez_ok)

	_pegado_abajo_segunda_vez_ok = is_equal_approx(_posicion_segunda_apertura.y + _tamano_segunda_apertura.y, abajo_panel)
	print("Segunda apertura: el fondo queda pegado abajo (esperado true): %s" % _pegado_abajo_segunda_vez_ok)

	var exito := _tamano_igual_entre_aperturas_ok and _pegado_abajo_primera_vez_ok and _pegado_abajo_segunda_vez_ok
	print("PRUEBA DIALOGO TAMAÑO CONSISTENTE AL REABRIR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
