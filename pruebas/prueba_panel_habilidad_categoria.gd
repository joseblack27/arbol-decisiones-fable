# =============================================================================
# Prueba de que PanelDetalleHabilidad.gd oculta las filas de daño/tipo
# (y de rango, cuando no aplica) según Enums.Habilidad.Categoria — bug
# reportado: habilidades sin daño real (Gancho, Grito de Guerra) mostraban
# "Daño: 0-0", información que no significa nada para esa habilidad.
#
# Verifica:
#   1. ATAQUE: se muestran daño, tipo de daño Y rango (si tiene alcance).
#   2. POTENCIADOR (p. ej. Grito de Guerra, sin alcance_metros): se
#      esconden daño/tipo Y rango.
#   3. CONTROL con alcance real (p. ej. Gancho): se esconden daño/tipo,
#      pero el RANGO se sigue mostrando — el alcance del enganche sí es
#      información relevante aunque no sea una categoría de ataque.
#   godot --headless --path . --script res://pruebas/prueba_panel_habilidad_categoria.gd
# =============================================================================
extends SceneTree

var _panel
var _fotogramas := 0

var _ataque_muestra_dano := false
var _ataque_muestra_rango := false
var _potenciador_esconde_dano := false
var _potenciador_esconde_rango := false
var _control_esconde_dano := false
var _control_muestra_rango_si_tiene := false


func _fila(nombre: String) -> Control:
	return _panel.get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/" + nombre
	) as Control


static func _datos(categoria: int, alcance: int) -> DatosHabilidad:
	var d := DatosHabilidad.new()
	d.nombre = "Prueba"
	d.descripcion = "Descripción de prueba"
	d.categoria = categoria
	d.alcance_metros = alcance
	d.dano_base_min = 5
	d.dano_base_max = 10
	return d


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_panel.show_skill(_datos(Enums.Habilidad.Categoria.ATAQUE, 5))
		3:
			_ataque_muestra_dano  = _fila("HBoxDanoBase").visible and _fila("HBoxTipoDano").visible
			_ataque_muestra_rango = _fila("HBoxRangoLanzamiento").visible
			_panel.show_skill(_datos(Enums.Habilidad.Categoria.POTENCIADOR, 0))
		4:
			_potenciador_esconde_dano  = not _fila("HBoxDanoBase").visible and not _fila("HBoxTipoDano").visible
			_potenciador_esconde_rango = not _fila("HBoxRangoLanzamiento").visible
			_panel.show_skill(_datos(Enums.Habilidad.Categoria.CONTROL, 8))
		5:
			_control_esconde_dano = not _fila("HBoxDanoBase").visible and not _fila("HBoxTipoDano").visible
			_control_muestra_rango_si_tiene = _fila("HBoxRangoLanzamiento").visible
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	var raiz := escena.instantiate()
	root.add_child(raiz)
	_panel = raiz.get_node("MarginContainer/HBoxContainer/PanelDetalle")


func _informar() -> bool:
	print("ATAQUE muestra daño/tipo (esperado true): %s" % _ataque_muestra_dano)
	print("ATAQUE muestra rango (esperado true): %s" % _ataque_muestra_rango)
	print("POTENCIADOR esconde daño/tipo (esperado true): %s" % _potenciador_esconde_dano)
	print("POTENCIADOR (sin alcance) esconde rango (esperado true): %s" % _potenciador_esconde_rango)
	print("CONTROL esconde daño/tipo (esperado true): %s" % _control_esconde_dano)
	print("CONTROL con alcance real SÍ muestra rango (esperado true): %s" % _control_muestra_rango_si_tiene)

	var exito := _ataque_muestra_dano and _ataque_muestra_rango \
		and _potenciador_esconde_dano and _potenciador_esconde_rango \
		and _control_esconde_dano and _control_muestra_rango_si_tiene
	print("PRUEBA PANEL HABILIDAD CATEGORIA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
