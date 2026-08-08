# =============================================================================
# Prueba de HabilidadSacudida/EfectoAturdir: golpe en área que aturde a los
# enemigos cercanos sin dañarlos — bloquea movimiento Y pausa su IA/
# habilidades (a diferencia de Inmovilizar, que solo bloquea movimiento), y
# se revierte todo solo al vencer.
#   godot --headless --path . --script res://pruebas/prueba_sacudida.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador: CharacterBody2D
var _enemigo: CharacterBody2D
var _mov
var _arbol: Node
var _habilidades: Node
var _sacudida

var _inmoviliza_ok := false
var _pausa_arbol_y_habilidades_ok := false
var _icono_puesto_ok := false
var _revierte_al_vencer_ok := false
var _indicador_zona_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_sacudida.call("_ejecutar", Vector2.ZERO, 1.0)
		4:
			_inmoviliza_ok = _mov._contador_inmovilizacion > 0
			print("Aturdido bloquea el movimiento (esperado true): %s" % _inmoviliza_ok)

			_pausa_arbol_y_habilidades_ok = _arbol.process_mode == Node.PROCESS_MODE_DISABLED \
				and _habilidades.process_mode == Node.PROCESS_MODE_DISABLED
			print("Aturdido pausa el árbol de IA y las habilidades (esperado true): %s" % _pausa_arbol_y_habilidades_ok)

			var buffs := _enemigo.get_node_or_null("BuffsComponente")
			_icono_puesto_ok = buffs != null and buffs.esta_activo("aturdido")
			print("Deja el ícono de aturdido puesto (esperado true): %s" % _icono_puesto_ok)

			# Feedback visual del radio real (pedido del usuario) — tiene que
			# aparecer en la escena, centrado en el jugador, con el radio real.
			var indicador: Node = null
			for hijo in current_scene.get_children():
				if hijo.get_script() == load("res://escenas/efectos/IndicadorZonaEfecto.gd"):
					indicador = hijo
					break
			_indicador_zona_ok = indicador != null \
				and indicador.global_position.distance_to(_jugador.global_position) < 0.01 \
				and is_equal_approx(indicador.radio, _sacudida.radio)
			print("Aparece el indicador de zona (esperado true): %s" % _indicador_zona_ok)
		# duracion_aturdimiento = 0.3s en esta prueba -> de sobra a los 40 fotogramas.
		40:
			var sigue_inmovilizado: bool = _mov._contador_inmovilizacion > 0
			var sigue_pausado: bool = _arbol.process_mode == Node.PROCESS_MODE_DISABLED \
				or _habilidades.process_mode == Node.PROCESS_MODE_DISABLED
			_revierte_al_vencer_ok = not sigue_inmovilizado and not sigue_pausado
			print("Al vencer, se revierte todo (esperado true): %s" % _revierte_al_vencer_ok)
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	escena.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_enemigo = CharacterBody2D.new()
	_enemigo.add_to_group("enemigos")
	escena.add_child(_enemigo)
	_enemigo.global_position = Vector2(20, 0)  # dentro del radio de la prueba (90px)

	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 10.0
	forma.shape = circulo
	_enemigo.add_child(forma)

	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	_enemigo.add_child(vida)

	_mov = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	_mov.name = "MovimientoComponente"
	_enemigo.add_child(_mov)

	_arbol = Node.new()
	_arbol.name = "ArbolComportamiento"
	_enemigo.add_child(_arbol)

	_habilidades = Node.new()
	_habilidades.name = "Habilidades"
	_enemigo.add_child(_habilidades)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/sacudida/HabilidadSacudida.gd") as GDScript
	_sacudida = guion.new()
	_sacudida.slot_index = 0
	_sacudida.costo_energia = 0.0
	_sacudida.duracion_recarga = 0.1
	_sacudida.radio = 90.0
	_sacudida.duracion_aturdimiento = 0.3
	_sacudida.icono_debuff = PlaceholderTexture2D.new()
	contenedor.add_child(_sacudida)
	_sacudida.entidad_dueña = _jugador


func _informar() -> bool:
	var exito := _inmoviliza_ok and _pausa_arbol_y_habilidades_ok and _icono_puesto_ok \
		and _revierte_al_vencer_ok and _indicador_zona_ok
	print("  inmoviliza: %s" % _inmoviliza_ok)
	print("  pausa árbol y habilidades: %s" % _pausa_arbol_y_habilidades_ok)
	print("  ícono puesto: %s" % _icono_puesto_ok)
	print("  revierte al vencer: %s" % _revierte_al_vencer_ok)
	print("  indicador de zona: %s" % _indicador_zona_ok)
	print("PRUEBA SACUDIDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
