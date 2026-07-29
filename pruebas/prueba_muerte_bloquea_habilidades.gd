# =============================================================================
# Prueba de que morir bloquea las habilidades hasta reaparecer — pedido
# del usuario. HabilidadBase.activar()/_activar_red() ya no dejaban que
# el EFECTO de una habilidad ocurriera estando _muerto (chequeo previo),
# pero el BOTÓN (UIHabilidad) seguía respondiendo al toque igual que si
# estuvieras vivo (arrastre del joystick, indicador de apunte) — pedido
# del usuario: bloquearlas de verdad, no solo que no tengan efecto.
#
# Verifica:
#   1. Un toque NUEVO sobre el botón mientras el dueño está _muerto no
#      arma el joystick (_activo se queda en false).
#   2. Vivo, ese mismo toque SÍ lo arma — confirma que el bloqueo es por
#      la muerte, no un bug que rompió el botón entero.
#   3. Un joystick YA sostenido cuando el jugador muere se suelta solo
#      (Jugador._morir() -> UIHabilidad.cancelar_todos_los_apuntes()).
#   godot --headless --path . --script res://pruebas/prueba_muerte_bloquea_habilidades.gd
# =============================================================================
extends SceneTree

var _jugador
var _slot_hab
var _boton
var _fotogramas := 0

var _bloquea_toque_nuevo_si_muerto := false
var _permite_toque_nuevo_si_vivo := false
var _suelta_joystick_ya_sostenido_al_morir := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_toque_bloqueado_muerto()
		6:
			_probar_toque_permitido_vivo()
		7:
			_probar_suelta_joystick_al_morir()
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


func _probar_toque_bloqueado_muerto() -> void:
	_jugador._muerto = true
	_tocar_centro_del_boton()
	_bloquea_toque_nuevo_si_muerto = not _boton._activo
	print("Toque NUEVO bloqueado si el dueño está muerto (esperado true): %s" % _bloquea_toque_nuevo_si_muerto)


func _probar_toque_permitido_vivo() -> void:
	_jugador._muerto = false
	_tocar_centro_del_boton()
	_permite_toque_nuevo_si_vivo = _boton._activo
	print("Ese mismo toque SÍ funciona estando vivo (esperado true): %s" % _permite_toque_nuevo_si_vivo)
	# Soltar a mano antes del siguiente sub-test, para que el joystick que
	# se arme ahí sea nuevo, no un resto de este.
	var evento := InputEventScreenTouch.new()
	evento.pressed = false
	evento.index = 0
	_boton._input(evento)


func _probar_suelta_joystick_al_morir() -> void:
	_jugador._muerto = false
	_tocar_centro_del_boton()
	var estaba_activo_antes_de_morir: bool = _boton._activo
	_jugador._morir()
	_suelta_joystick_ya_sostenido_al_morir = estaba_activo_antes_de_morir and not _boton._activo
	print("Joystick ya sostenido se suelta solo al morir (esperado true): %s" % _suelta_joystick_ya_sostenido_al_morir)


func _informar() -> bool:
	var exito := _bloquea_toque_nuevo_si_muerto and _permite_toque_nuevo_si_vivo \
		and _suelta_joystick_ya_sostenido_al_morir
	print("PRUEBA MUERTE BLOQUEA HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
