# =============================================================================
# Prueba de que EfectoAturdir también bloquea el APUNTADO (UIHabilidad), no
# solo el efecto real de la habilidad (ver prueba_aturdir_bloquea_jugador,
# que ya cubre eso) — reportado por el usuario: "si estoy apuntando alguna
# habilidad, debe cancelarse el apuntado y bloquear las habilidades mientras
# siga aturdido". Antes del parche, Jugador.esta_bloqueado() (que
# UIHabilidad._dueño_muerto ya consulta) no tenía en cuenta _bloqueos_control,
# así que un toque NUEVO mientras el jugador estaba aturdido armaba igual el
# joystick de apuntado — mismo bug que ya se había resuelto para _muerto (ver
# prueba_muerte_bloquea_habilidades.gd, que esta prueba imita para aturdir).
#
# Verifica:
#   1. Un joystick YA sostenido se suelta solo al aplicarse el aturdimiento.
#   2. Un toque NUEVO mientras dura el aturdimiento no arma el joystick.
#   3. Al vencer el aturdimiento, ese mismo toque SÍ lo arma de nuevo.
#   godot --headless --path . --script res://pruebas/prueba_aturdir_bloquea_apuntado.gd
# =============================================================================
extends SceneTree

var _jugador
var _slot_hab
var _boton
var _fotogramas := 0

var _suelta_joystick_ya_sostenido_al_aturdir := false
var _bloquea_toque_nuevo_mientras_dura := false
var _permite_toque_nuevo_al_vencer := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_suelta_joystick_al_aturdir()
		6:
			_probar_toque_bloqueado_mientras_dura()
		70:
			# duracion=0.5s del efecto + margen de sobra (70 fotogramas ~1.1s).
			_probar_toque_permitido_al_vencer()
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	_slot_hab = _jugador.get_node("SlotHabilidades")
	var hab := HabilidadBase.new()
	hab.requiere_direccion = true
	hab.costo_energia = 0.0
	hab.duracion_recarga = 0.0
	hab.slot_index = 0
	hab.entidad_dueña = _jugador
	_slot_hab._instancias[0] = hab

	var escena := load("res://escenas/ui/ui_habilidad/UIHabilidad.tscn") as PackedScene
	_boton = escena.instantiate()
	_boton.slot_index = 0
	root.add_child(_boton)
	_boton.size = Vector2(80, 80)
	_boton._slot_habilidades = _slot_hab  # saltea el _conectar_slot() diferido, mismo criterio que otras pruebas.


func _tocar_centro_del_boton() -> void:
	var centro_global: Vector2 = _boton.get_global_rect().position + _boton._get_centro()
	var evento := InputEventScreenTouch.new()
	evento.pressed = true
	evento.index = 0
	evento.position = centro_global
	_boton._input(evento)


func _soltar_toque() -> void:
	var evento := InputEventScreenTouch.new()
	evento.pressed = false
	evento.index = 0
	_boton._input(evento)


func _probar_suelta_joystick_al_aturdir() -> void:
	_tocar_centro_del_boton()
	var estaba_activo_antes: bool = _boton._activo
	var efecto = (load("res://escenas/efectos/EfectoAturdir.gd") as GDScript).new()
	efecto.objetivo = _jugador
	efecto.duracion = 0.5
	_jugador.add_child(efecto)
	_suelta_joystick_ya_sostenido_al_aturdir = estaba_activo_antes and not _boton._activo
	print("Joystick ya sostenido se suelta solo al aturdir (esperado true): %s" % \
		_suelta_joystick_ya_sostenido_al_aturdir)


func _probar_toque_bloqueado_mientras_dura() -> void:
	_tocar_centro_del_boton()
	_bloquea_toque_nuevo_mientras_dura = not _boton._activo
	print("Toque NUEVO bloqueado mientras dura el aturdimiento (esperado true): %s" % \
		_bloquea_toque_nuevo_mientras_dura)
	_soltar_toque()


func _probar_toque_permitido_al_vencer() -> void:
	_tocar_centro_del_boton()
	_permite_toque_nuevo_al_vencer = _boton._activo
	print("Ese mismo toque SÍ funciona al vencer el aturdimiento (esperado true): %s" % \
		_permite_toque_nuevo_al_vencer)


func _informar() -> bool:
	var exito := _suelta_joystick_ya_sostenido_al_aturdir and _bloquea_toque_nuevo_mientras_dura \
		and _permite_toque_nuevo_al_vencer
	print("PRUEBA ATURDIR BLOQUEA APUNTADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
