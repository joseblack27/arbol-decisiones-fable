# =============================================================================
# Prueba de XP:
#   1. GestorExperiencia.agregar_xp() acumula (no reemplaza) y emite
#      BusEventos.xp_agregada(cantidad, xp_total).
#   2. Al morir un enemigo con xp_otorgada > 0, esa XP llega a
#      GestorExperiencia automáticamente.
#   3. PanelNotificacionesLoot también reacciona a xp_agregada con una fila
#      de solo texto ("+N XP"), sin ícono.
#   4. PanelTablero (la pestaña "Atributos") muestra el progreso DENTRO del
#      nivel actual ("X / Y", ver TablaNiveles) — no el campo suelto
#      DatosJugador.experiencia_max (fijo, nunca se movía) ni el acumulado
#      total a secas.
#   godot --headless --path . --script res://pruebas/prueba_experiencia.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor: Node
var _panel: Node
var _raton: Node
var _jugador_falso: CharacterBody2D
var _tablero: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			print("XP tras agregar_xp(10) (esperado 10): %d" % _gestor.xp_total)
			_gestor.agregar_xp(5)
			print("XP acumulada, no reemplazada (esperado 15): %d" % _gestor.xp_total)
		3:
			# Matar al ratón: su xp_otorgada debe sumarse sola.
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
		4:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorExperiencia")
	_gestor.xp_total = 0

	_panel = (load("res://escenas/ui/notificaciones_loot/PanelNotificacionesLoot.tscn") as PackedScene).instantiate()
	root.add_child(_panel)

	# Jugador mínimo para que PanelTablero._conectar_jugador() lo encuentre
	# (busca el primer nodo del grupo "jugadores").
	_jugador_falso = CharacterBody2D.new()
	_jugador_falso.add_to_group("jugadores")
	root.add_child(_jugador_falso)

	_tablero = (load("res://escenas/ui/panel_os/paneles/tablero/PanelTablero.tscn") as PackedScene).instantiate()
	root.add_child(_tablero)

	_gestor.agregar_xp(10)

	_raton = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_raton)
	_raton.xp_otorgada = 7
	# Aislar esta prueba de cualquier botín que ya tenga configurado el ratón
	# en su escena: aquí solo interesa comprobar la XP, no el loot (que ya
	# tiene su propia prueba dedicada).
	var sin_botin: Array[LootDrop] = []
	_raton.tabla_botin = sin_botin


func _informar() -> bool:
	print("XP tras matar al ratón (esperado 22 = 15 + 7): %d" % _gestor.xp_total)

	var filas := _panel.get_child_count()
	var ultima_fila: Node = _panel.get_child(filas - 1)
	var icono_oculto: bool = not (ultima_fila.get_node("Margen/HBox/Icono") as CanvasItem).visible
	var texto: String = ultima_fila.get_node("Margen/HBox/Texto").text
	print("Filas de notificación generadas (esperado 3): %d" % filas)
	print("Última fila es de XP: ícono oculto=%s texto=%s (esperado '+7 XP')" % [icono_oculto, texto])

	var lbl_experiencia: Label = _tablero.get("_lbl_experiencia")
	var texto_tablero := lbl_experiencia.text
	# Nivel 1 pide 100 XP para el nivel 2 (ver TablaNiveles) — con 22 XP
	# acumulada, sigue en nivel 1, progreso "22 / 100".
	print("Panel de estadísticas muestra el progreso del nivel (esperado '22 / 100'): %s" % texto_tablero)

	var xp_total: int = _gestor.xp_total
	var exito: bool = xp_total == 22 \
		and filas == 3 \
		and icono_oculto \
		and texto == "+7 XP" \
		and texto_tablero == "22 / 100"
	print("PRUEBA EXPERIENCIA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
