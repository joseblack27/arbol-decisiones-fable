# =============================================================================
# Prueba de que UIHabilidad se oscurece mientras el dueño tiene el control
# bloqueado (Jugador._bloqueos_control > 0 — el margen de 0.5s tras lanzar
# otra habilidad en red, ver HabilidadBase._MARGEN_CONGELAMIENTO_RED). El
# toque ya estaba bloqueado sin esto (Jugador.esta_bloqueado(), que
# _dueño_muerto() ya consulta) — lo nuevo es el AVISO visual: pedido del
# usuario, "que se vea claramente lo que pasa" en vez de sentirse como lag.
#
# Mismo molde que prueba_muerte_bloquea_habilidades.gd: instancia un
# Jugador.tscn real (bloquear_control()/desbloquear_control() son sus
# métodos de verdad) y una UIHabilidad.tscn real, saltando el
# _conectar_slot() diferido.
#   godot --headless --path . --script res://pruebas/prueba_ui_oscurece_bloqueo_control.gd
# =============================================================================
extends SceneTree

var _jugador
var _slot_hab
var _boton
var _fotogramas := 0

var _color_normal: Color
var _oscurecido_al_bloquear := false
var _vuelve_al_normal_al_desbloquear := false
var _toque_sigue_funcionando_bloqueado := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_color_normal = _boton._base.self_modulate
			_jugador.bloquear_control()
		5:
			# _process() de UIHabilidad sondea _dueño_bloqueado_por_control()
			# cada fotograma (no hay señal para esto) — un par de fotogramas
			# de margen de sobra.
			_oscurecido_al_bloquear = _boton._base.self_modulate != _color_normal \
				and _boton._icono.modulate != _boton._COLOR_ICONO_NORMAL
			print("Se oscurece mientras el control está bloqueado (esperado true): %s (color=%s, normal=%s)" % [
				_oscurecido_al_bloquear, _boton._base.self_modulate, _color_normal])

			# El toque YA estaba bloqueado sin nada de este cambio —
			# _dueño_muerto() (ver ese comentario) llama a
			# Jugador.esta_bloqueado(), que incluye _bloqueos_control > 0.
			# Confirma que oscurecer no rompió ese camino existente (mismo
			# molde que prueba_muerte_bloquea_habilidades.gd).
			var evento := InputEventScreenTouch.new()
			evento.pressed = true
			evento.index = 0
			evento.position = _boton.get_global_rect().position + _boton._get_centro()
			_boton._input(evento)
			_toque_sigue_funcionando_bloqueado = not _boton._activo
			print("El toque sigue bloqueado (esperado true, ya lo hacía _dueño_muerto()/esta_bloqueado()): %s" % _toque_sigue_funcionando_bloqueado)
			var soltar := InputEventScreenTouch.new()
			soltar.pressed = false
			soltar.index = 0
			_boton._input(soltar)

			_jugador.desbloquear_control()
		7:
			_vuelve_al_normal_al_desbloquear = _boton._base.self_modulate == _color_normal
			print("Vuelve al color normal al desbloquear (esperado true): %s (color=%s, normal=%s)" % [
				_vuelve_al_normal_al_desbloquear, _boton._base.self_modulate, _color_normal])
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
	_boton._slot_habilidades = _slot_hab
	# El ícono necesita una textura real para que _refrescar_visual() toque
	# su modulate (si no, el check de _icono.modulate quedaría siempre en
	# el valor de fábrica sin importar el bloqueo).
	_boton._icono.texture = PlaceholderTexture2D.new()


func _informar() -> bool:
	var exito := _oscurecido_al_bloquear and _vuelve_al_normal_al_desbloquear \
		and _toque_sigue_funcionando_bloqueado
	print("PRUEBA UI OSCURECE BLOQUEO CONTROL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
