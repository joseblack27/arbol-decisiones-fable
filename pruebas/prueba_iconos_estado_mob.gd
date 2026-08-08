# =============================================================================
# Prueba: Enemigo.gd muestra los íconos de estado del mob (veneno, lentitud,
# aturdido...) ENCIMA del nombre — pedido del usuario: "una barra de estados
# así como los efectos del jugador, para saber cuando está aturdido,
# ralentizado, o tenga algún efecto presente", y después: "quiero que
# aparezca por encima del nombre no por debajo".
#
# BuffsComponente puede no existir todavía cuando el mob arranca (recién se
# crea con el PRIMER debuff) — el mob tiene que encontrarlo solo,
# reintentando, sin importar si ya estaba o si aparece después.
#   godot --headless --path . --script res://pruebas/prueba_iconos_estado_mob.gd
# =============================================================================
extends SceneTree

var _f := 0
var _mob: Node
var _icono := PlaceholderTexture2D.new()

var _sin_debuffs_ok := false
var _detecta_debuff_ok := false
var _muestra_los_dos_ok := false
var _queda_encima_del_nombre_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			# Sin ningún debuff todavía: el mob no tiene que fallar ni
			# mostrar nada (BuffsComponente ni existe aún).
			_sin_debuffs_ok = _mob._buffs_activos.is_empty()
			print("Sin debuffs, no hay nada que mostrar (esperado true): %s" % _sin_debuffs_ok)

			# Se pega un aturdimiento real al mob (mismo camino que Sacudida).
			var efecto = (load("res://escenas/efectos/EfectoAturdir.gd") as GDScript).new()
			efecto.objetivo = _mob
			efecto.duracion = 5.0
			efecto.icono_debuff = _icono
			_mob.add_child(efecto)
		# _INTERVALO_REINTENTO_BUFFS = 0.5s -> de sobra a los 40 fotogramas.
		40:
			_detecta_debuff_ok = "aturdido" in _mob._buffs_activos
			print("Detecta el debuff nuevo (esperado true): %s (%s)" % [
				_detecta_debuff_ok, _mob._buffs_activos])

			# Un segundo debuff (lentitud) — tiene que mostrar los DOS.
			var lentitud = (load("res://escenas/efectos/EfectoLentitud.gd") as GDScript).new()
			lentitud.objetivo = _mob
			lentitud.duracion = 5.0
			lentitud.icono_debuff = _icono
			_mob.add_child(lentitud)
		42:
			_muestra_los_dos_ok = "aturdido" in _mob._buffs_activos and "lentitud" in _mob._buffs_activos
			print("Muestra los dos debuffs a la vez (esperado true): %s (%s)" % [
				_muestra_los_dos_ok, _mob._buffs_activos])

			# Los íconos se dibujan en el MISMO nodo que el nombre (NombreMob),
			# a una Y local más negativa que 0 (el nombre crece hacia arriba
			# desde ahí, ver _dibujar_nombre_mob) — "más negativa" = más
			# arriba en pantalla, encima del texto. Se llama a la función
			# REAL que usa el propio _draw(), no una recalculada aparte.
			var y_iconos: float = _mob.call("_altura_iconos_estado")
			# Tiene que quedar por encima del BORDE SUPERIOR del texto (no
			# solo de la línea base en 0): el texto ocupa desde 0 hacia
			# arriba hasta -altura_de_la_fuente (misma fuente que usa el mob).
			var fuente := load("res://assets/fonts/jet brain mono/JetBrainsMono-Medium.ttf") as Font
			var borde_superior_texto := -fuente.get_height(_mob.tamano_fuente_nombre)
			_queda_encima_del_nombre_ok = y_iconos < borde_superior_texto
			print("Los íconos quedan arriba del nombre (Y=%.1f, borde del texto=%.1f, esperado Y < borde): %s" % [
				y_iconos, borde_superior_texto, _queda_encima_del_nombre_ok])
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	(_mob.get_node("ArbolComportamiento")).activo = false


func _informar() -> bool:
	var exito := _sin_debuffs_ok and _detecta_debuff_ok and _muestra_los_dos_ok \
		and _queda_encima_del_nombre_ok
	print("  sin debuffs: %s" % _sin_debuffs_ok)
	print("  detecta debuff nuevo: %s" % _detecta_debuff_ok)
	print("  muestra los dos a la vez: %s" % _muestra_los_dos_ok)
	print("  queda encima del nombre: %s" % _queda_encima_del_nombre_ok)
	print("PRUEBA ICONOS ESTADO MOB %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
