# =============================================================================
# Prueba del panel "Buffs Activos" (antes "Actividad Reciente" — el log de
# daño se mudó a GestorLogRed/PanelLogRed, ver prueba_log_red_dano.gd).
# Pedido del usuario: en ese mismo espacio de PanelTablero, mostrar los
# buffs/debuffs activos del jugador con ícono, nombre, descripción y tiempo
# restante.
#
# Verifica:
#   1. Al agregar un buff, aparece una fila con nombre/descripción correctos.
#   2. El tiempo restante mostrado se actualiza fotograma a fotograma (no
#      se queda pegado en el valor inicial).
#   3. Al vencer, la fila desaparece.
#   godot --headless --path . --script res://pruebas/prueba_panel_buffs_activos.gd
# =============================================================================
extends SceneTree

var _jugador
var _buffs
var _panel
var _fotogramas := 0
var _tiempo_inicial := ""

var _aparece_fila_con_datos_correctos := false
var _tiempo_se_actualiza := false
var _desaparece_al_vencer := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# duracion=3s: suficientemente largo para ver el texto de tiempo
			# cambiar de valor entero (no solo de fracción) entre chequeos.
			_buffs.agregar("test_buff", null, 3.0, false, "Prueba", "Descripción de prueba")
		3:
			var fila = _panel._filas_buff.get("test_buff")
			_aparece_fila_con_datos_correctos = fila != null \
				and fila._nombre.text == "Prueba" and fila._descripcion.text == "Descripción de prueba"
			_tiempo_inicial = fila._tiempo.text if fila else ""
			print("Aparece la fila con nombre/descripción correctos (esperado true): %s" % _aparece_fila_con_datos_correctos)
		150:
			var fila = _panel._filas_buff.get("test_buff")
			var tiempo_actual: String = fila._tiempo.text if fila else ""
			_tiempo_se_actualiza = fila != null and tiempo_actual != _tiempo_inicial
			print("El tiempo restante se actualiza (esperado true, '%s' -> '%s'): %s" % [
				_tiempo_inicial, tiempo_actual, _tiempo_se_actualiza])
		250:
			# duracion=3s (180 fotogramas) desde el frame 2 -> ya venció de sobra.
			_desaparece_al_vencer = not _panel._filas_buff.has("test_buff")
			print("La fila desaparece al vencer (esperado true): %s" % _desaparece_al_vencer)
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_buffs = (load("res://componentes/BuffsComponente.gd") as GDScript).new()
	_buffs.name = "BuffsComponente"
	_jugador.add_child(_buffs)

	var escena := load("res://escenas/ui/panel_os/paneles/tablero/PanelTablero.tscn") as PackedScene
	_panel = escena.instantiate()
	root.add_child(_panel)
	_panel.visible = true


func _informar() -> bool:
	var exito := _aparece_fila_con_datos_correctos and _tiempo_se_actualiza and _desaparece_al_vencer
	print("PRUEBA PANEL BUFFS ACTIVOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
