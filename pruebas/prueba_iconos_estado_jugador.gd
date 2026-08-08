# =============================================================================
# Prueba: Jugador.gd muestra los íconos de estado (veneno, lentitud,
# aturdido...) ENCIMA de su propio sprite — mismo mecanismo que ya tienen los
# mobs (ver prueba_iconos_estado_mob.gd, que esta prueba imita). Pedido del
# usuario: "colocar el indicador de aturdido encima del jugador así como lo
# tienen los mobs, para que el jugador se entere ya que a veces no se tiene en
# cuenta que se está aturdido y pienso que es lag hasta que miro los estados
# del lado izquierdo" (BarraBuffs, la fila fija de la esquina — a diferencia
# de esa, esto vive en el mundo, pegado al propio personaje).
#
# BuffsComponente puede no existir todavía cuando el jugador arranca (recién
# se crea con el PRIMER debuff) — el jugador tiene que encontrarlo solo,
# reintentando, igual que el mob.
#   godot --headless --path . --script res://pruebas/prueba_iconos_estado_jugador.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador: Node
var _icono := PlaceholderTexture2D.new()

var _sin_debuffs_ok := false
var _detecta_debuff_ok := false
var _muestra_los_dos_ok := false
var _queda_encima_del_sprite_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			# Sin ningún debuff todavía: no tiene que fallar ni mostrar nada
			# (BuffsComponente ni existe aún).
			_sin_debuffs_ok = _jugador._buffs_activos_estado.is_empty()
			print("Sin debuffs, no hay nada que mostrar (esperado true): %s" % _sin_debuffs_ok)

			# Se pega un aturdimiento real (mismo camino que Sacudida).
			var efecto = (load("res://escenas/efectos/EfectoAturdir.gd") as GDScript).new()
			efecto.objetivo = _jugador
			efecto.duracion = 5.0
			efecto.icono_debuff = _icono
			_jugador.add_child(efecto)
		# _INTERVALO_REINTENTO_BUFFS_ESTADO = 0.5s -> de sobra a los 40 fotogramas.
		40:
			_detecta_debuff_ok = "aturdido" in _jugador._buffs_activos_estado
			print("Detecta el debuff nuevo (esperado true): %s (%s)" % [
				_detecta_debuff_ok, _jugador._buffs_activos_estado])

			# Un segundo debuff (lentitud) — tiene que mostrar los DOS.
			var lentitud = (load("res://escenas/efectos/EfectoLentitud.gd") as GDScript).new()
			lentitud.objetivo = _jugador
			lentitud.duracion = 5.0
			lentitud.icono_debuff = _icono
			_jugador.add_child(lentitud)
		42:
			_muestra_los_dos_ok = "aturdido" in _jugador._buffs_activos_estado \
				and "lentitud" in _jugador._buffs_activos_estado
			print("Muestra los dos debuffs a la vez (esperado true): %s (%s)" % [
				_muestra_los_dos_ok, _jugador._buffs_activos_estado])

			# El nodo de íconos tiene que quedar arriba del BORDE SUPERIOR real
			# del sprite (no un número fijo a ojo) — mismo criterio que
			# prueba_iconos_estado_mob.gd.
			var sprite: Sprite2D = _jugador.sprite
			var alto_frame: float = (sprite.texture.get_height() / float(sprite.vframes)) * sprite.scale.y
			var borde_superior_sprite: float = sprite.position.y - alto_frame / 2.0
			_queda_encima_del_sprite_ok = _jugador._nodo_iconos_estado.position.y < borde_superior_sprite
			print("Los íconos quedan arriba del sprite (Y=%.1f, borde del sprite=%.1f, esperado Y < borde): %s" % [
				_jugador._nodo_iconos_estado.position.y, borde_superior_sprite, _queda_encima_del_sprite_ok])
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	current_scene = _jugador


func _informar() -> bool:
	var exito := _sin_debuffs_ok and _detecta_debuff_ok and _muestra_los_dos_ok \
		and _queda_encima_del_sprite_ok
	print("  sin debuffs: %s" % _sin_debuffs_ok)
	print("  detecta debuff nuevo: %s" % _detecta_debuff_ok)
	print("  muestra los dos a la vez: %s" % _muestra_los_dos_ok)
	print("  queda encima del sprite: %s" % _queda_encima_del_sprite_ok)
	print("PRUEBA ICONOS ESTADO JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
