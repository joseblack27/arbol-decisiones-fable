# =============================================================================
# Prueba: la fila "Daño Calculado" (y el {damage1} de la descripción) del
# panel de detalle de una habilidad deben mostrar dano_base + los atributos
# ofensivos ACTUALES del jugador (bonus plano "danos" + "potencia"), y
# recalcularse solos cuando el equipo del jugador cambia (BusEventos.
# equipo_cambiado) mientras el panel sigue mostrando la misma habilidad.
#   godot --headless --path . --script res://pruebas/prueba_dano_calculado_habilidad.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador: CharacterBody2D
var _atributos: AtributosComponente
var _panel_habilidades: Control
var _panel_detalle: Node
var _datos: DatosHabilidad


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_atributos = AtributosComponente.new()
	_atributos.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos    = 5.0   # bonus plano
	base.potencia = 20.0  # +20 %
	_atributos.base = base
	_jugador.add_child(_atributos)

	_panel_habilidades = (load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene).instantiate()
	root.add_child(_panel_habilidades)
	_panel_detalle = _panel_habilidades.get_node("MarginContainer/HBoxContainer/PanelDetalle")

	_datos = DatosHabilidad.new()
	_datos.nombre       = "Prueba"
	_datos.descripcion  = "Golpea por {damage1}"
	_datos.dano_base_min = 10
	_datos.dano_base_max = 12
	_panel_detalle.call("show_skill", _datos)


func _informar() -> bool:
	# (10+5)*1.2=18, (12+5)*1.2=20.4 -> int() trunca a 20.
	var calc_label: Label = _panel_detalle.get("dmg_calc_label")
	var desc_label: RichTextLabel = _panel_detalle.get("description_label")
	print("Daño calculado inicial (esperado '18 - 20'): %s" % calc_label.text)
	print("Descripción inicial (esperado 'Golpea por 18 - 20'): %s" % desc_label.text)
	var inicial_ok := calc_label.text == "18 - 20" and desc_label.text == "Golpea por 18 - 20"

	# Sube "danos" a 10 (equivalente a equipar algo con ese bono) y avisa
	# como haría GestorEquipo.actualizar() al equipar/desequipar de verdad.
	_atributos.base.danos = 10.0
	root.get_node("/root/BusEventos").emit_signal("equipo_cambiado", [])

	# (10+10)*1.2=24, (12+10)*1.2=26.4 -> 26.
	print("Daño calculado tras subir 'danos' (esperado '24 - 26'): %s" % calc_label.text)
	print("Descripción tras el cambio (esperado 'Golpea por 24 - 26'): %s" % desc_label.text)
	var actualizado_ok := calc_label.text == "24 - 26" and desc_label.text == "Golpea por 24 - 26"

	var exito := inicial_ok and actualizado_ok
	print("PRUEBA DAÑO CALCULADO HABILIDAD %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
