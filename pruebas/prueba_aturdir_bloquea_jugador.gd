# =============================================================================
# Prueba: EfectoAturdir aplicado a un JUGADOR real (no solo a un mob) tiene
# que bloquear movimiento Y activación de habilidades — antes del parche,
# EfectoAturdir buscaba un nodo hijo "Habilidades" que Enemigo.gd sí tiene
# pero Jugador NO (sus habilidades cuelgan directo de él, ver
# SlotHabilidades._instanciar), así que aplicado a un jugador solo bloqueaba
# el movimiento. El parche llama Jugador.bloquear_control()/
# desbloquear_control() (duck-typed, has_method) además de lo de siempre.
#   godot --headless --path . --script res://pruebas/prueba_aturdir_bloquea_jugador.gd
# =============================================================================
extends SceneTree

var _jugador
var _movimiento
var _hab
var _efecto
var _fotogramas := 0

var _bloqueado_al_aplicar := false
var _movimiento_bloqueado := false
var _activar_no_hizo_nada_mientras_dura := false
var _liberado_al_vencer := false
var _activar_funciona_despues := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Sanity check: sin aturdir, activar() SÍ arranca la recarga.
			_hab.activar(Vector2.ZERO, 1.0)
		3:
			var funciono_sin_aturdir: bool = _hab._recarga_restante > 0.0
			print("Sanity: activar() funciona SIN aturdir (esperado true): %s" % funciono_sin_aturdir)
			_hab._recarga_restante = 0.0  # limpiar para la prueba real

			_efecto = (load("res://escenas/efectos/EfectoAturdir.gd") as GDScript).new()
			_efecto.objetivo = _jugador
			_efecto.duracion = 0.5
			_jugador.add_child(_efecto)

			_bloqueado_al_aplicar = _jugador._bloqueos_control > 0
			_movimiento_bloqueado = _movimiento._contador_inmovilizacion > 0
			print("_bloqueos_control > 0 al aplicar (esperado true): %s" % _bloqueado_al_aplicar)
			print("Movimiento inmovilizado (esperado true): %s" % _movimiento_bloqueado)
		5:
			_hab.activar(Vector2.ZERO, 1.0)
			_activar_no_hizo_nada_mientras_dura = _hab._recarga_restante <= 0.0
			print("activar() NO hace nada mientras dura el aturdimiento (esperado true): %s" % \
				_activar_no_hizo_nada_mientras_dura)
		60:
			# 0.5s de duracion + margen de sobra (60 fotogramas ~1s reales).
			_liberado_al_vencer = _jugador._bloqueos_control == 0 \
				and _movimiento._contador_inmovilizacion == 0
			print("Liberado al vencer el aturdimiento (esperado true): %s" % _liberado_al_vencer)
			_hab.activar(Vector2.ZERO, 1.0)
		61:
			_activar_funciona_despues = _hab._recarga_restante > 0.0
			print("activar() vuelve a funcionar después (esperado true): %s" % _activar_funciona_despues)
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena.instantiate()
	_jugador.name = "1"
	root.add_child(_jugador)
	current_scene = _jugador

	_movimiento = _jugador.get_node("MovimientoComponente")

	var slots = _jugador.get_node("SlotHabilidades")
	var datos = load("res://recursos/habilidades/golpe_basico.tres")
	slots.equipar(0, datos)
	_hab = slots.obtener(0)


func _informar() -> bool:
	var exito := _bloqueado_al_aplicar and _movimiento_bloqueado \
		and _activar_no_hizo_nada_mientras_dura and _liberado_al_vencer and _activar_funciona_despues
	print("PRUEBA ATURDIR BLOQUEA JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
