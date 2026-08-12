# =============================================================================
# Prueba de que PanelTablero.gd suma el bono de daño temporal (buffs como
# Grito de Guerra) al número de Daño que muestra — pedido del usuario:
# "que se sumara en el daño que ya muestra para no estar haciendo
# cálculos mentales en pleno combate".
#
# Por señal (AtributosComponente.bono_dano_cambiado), NO por sondeo: el
# panel se entera al toque cuando el bono aparece o vence, sin tener que
# revisar a cada rato aunque nada haya cambiado (corrección del usuario
# sobre la primera versión, que sondeaba cada 0.5s).
#
# Verifica:
#   1. Al activar el bono, el label de Daño muestra la suma (base + bono)
#      DE INMEDIATO — sin que la prueba llame _actualizar_ofensivas() a
#      mano, solo por la señal.
#   2. Al vencer el bono (AtributosComponente._process lo detecta solo),
#      el número vuelve a la base también por la señal, sin sondeo de
#      ningún lado.
#   godot --headless --path . --script res://pruebas/prueba_panel_tablero_bono_dano.gd
# =============================================================================
extends SceneTree

var _jugador
var _atrib_comp: AtributosComponente
var _panel
var _fotogramas := 0

var _muestra_suma_con_bono := false
var _vuelve_a_la_base_al_vencer := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Bono corto (0.2s) para no tener que esperar los 10s reales de
			# un buff de verdad — solo la señal debe mover el label, en
			# ningún momento se llama _actualizar_ofensivas() a mano.
			_atrib_comp.agregar_bono_temporal("prueba_buff", 15.0, 0.0, 0.0, 0.0, 0.2)
		3:
			_muestra_suma_con_bono = _panel._lbl_danos.text == "25.0"
			print("Label de Daño muestra la suma con el bono, YA (esperado true, '25.0'): %s (\"%s\")" % [
				_muestra_suma_con_bono, _panel._lbl_danos.text])
		20:
			# ~0.3s reales: de sobra para que el bono (0.2s) haya vencido —
			# AtributosComponente._process() lo detecta y emite la señal
			# sola, sin que nada más lo empuje.
			_vuelve_a_la_base_al_vencer = _panel._lbl_danos.text == "10.0"
			print("Vuelve a la base al vencer, por la señal (esperado true, '10.0'): %s (\"%s\")" % [
				_vuelve_a_la_base_al_vencer, _panel._lbl_danos.text])
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_atrib_comp = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	_atrib_comp.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos = 10.0
	_atrib_comp.base = base
	_jugador.add_child(_atrib_comp)

	var escena := load("res://escenas/ui/panel_os/paneles/tablero/PanelTablero.tscn") as PackedScene
	_panel = escena.instantiate()
	root.add_child(_panel)
	_panel.visible = true


func _informar() -> bool:
	var exito := _muestra_suma_con_bono and _vuelve_a_la_base_al_vencer
	print("PRUEBA PANEL TABLERO BONO DANO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
