# =============================================================================
# Prueba de pasivas de ESTADÍSTICA (ver PasivaStatDesbloqueo): se desbloquean
# solas al alcanzar cierto nivel, igual que el crecimiento normal de
# vida/energía/daños, y aplican su bono UNA sola vez.
#
# Cubre:
#   1. Subir de nivel hasta cruzar un nivel_requerido aplica el bono.
#   2. Un salto de XP que cruza VARIOS niveles de una vez no duplica ni salta
#      la pasiva (mismo criterio que el crecimiento normal, que también
#      corre una vez por nivel dentro del while de agregar_xp()).
#   3. restaurar_xp() (reconexión) re-deriva el mismo bono sin duplicar.
#   4. La notificación BusEventos.pasiva_desbloqueada sale al desbloquear en
#      vivo, pero NO se repite al restaurar una partida (mismo criterio que
#      nivel_subido, que restaurar_xp() tampoco emite).
#   godot --headless --path . --script res://pruebas/prueba_pasiva_stat_por_nivel.gd
# =============================================================================
extends SceneTree

var _jugador
var _experiencia
var _atributos
var _bus
var _notificaciones := 0

var _bono_aplica_ok := false
var _no_duplica_en_salto_ok := false
var _sobrevive_reconexion_ok := false
var _notificacion_en_vivo_ok := false
var _sin_notificacion_al_restaurar_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_bono_por_nivel()
	_probar_salto_no_duplica()
	_probar_reconexion()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	_atributos.name = "AtributosComponente"
	_atributos.base = AtributosBase.new()
	_jugador.add_child(_atributos)
	_atributos._ready()

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"

	var pasiva := PasivaStatDesbloqueo.new()
	pasiva.nivel_requerido = 3
	pasiva.nombre = "Piel Curtida (prueba)"
	pasiva.descripcion = "descripción de prueba"
	pasiva.bono = AtributosBase.new()
	pasiva.bono.resistencia_fisica = 5.0
	_experiencia.pasivas_stat = [pasiva] as Array[PasivaStatDesbloqueo]

	_jugador.add_child(_experiencia)
	_experiencia._ready()

	_bus = root.get_node("/root/BusEventos")
	_bus.pasiva_desbloqueada.connect(func(_e, _n, _d): _notificaciones += 1)


func _probar_bono_por_nivel() -> void:
	# Curva triangular de TablaNiveles: XP para nivel 3 = 100*2*3/2 = 300.
	_experiencia.agregar_xp(300)
	print("Nivel tras 300 XP (esperado 3): %d" % _experiencia.nivel)
	print("Resistencia física tras cruzar nivel 3 (esperado 5): %.1f" % _atributos.base.resistencia_fisica)
	_bono_aplica_ok = _experiencia.nivel == 3 and is_equal_approx(_atributos.base.resistencia_fisica, 5.0)
	_notificacion_en_vivo_ok = _notificaciones == 1


func _probar_salto_no_duplica() -> void:
	# Nuevo jugador, XP que salta DIRECTO de nivel 1 a nivel 6 (XP nivel 6 =
	# 100*5*6/2 = 1500) — la pasiva de nivel 3 tiene que aplicarse UNA vez,
	# no acumular por cada iteración del while.
	var jugador2 := CharacterBody2D.new()
	jugador2.add_to_group("jugadores")
	root.add_child(jugador2)
	var atributos2 = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos2.name = "AtributosComponente"
	atributos2.base = AtributosBase.new()
	jugador2.add_child(atributos2)
	atributos2._ready()

	var experiencia2 = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia2.name = "ExperienciaComponente"
	var pasiva2 := PasivaStatDesbloqueo.new()
	pasiva2.nivel_requerido = 3
	pasiva2.bono = AtributosBase.new()
	pasiva2.bono.resistencia_fisica = 5.0
	experiencia2.pasivas_stat = [pasiva2] as Array[PasivaStatDesbloqueo]
	jugador2.add_child(experiencia2)
	experiencia2._ready()

	experiencia2.agregar_xp(1500)
	print("Resistencia física tras salto directo a nivel 6 (esperado 5, no duplicado): %.1f" % \
		atributos2.base.resistencia_fisica)
	_no_duplica_en_salto_ok = is_equal_approx(atributos2.base.resistencia_fisica, 5.0)


func _probar_reconexion() -> void:
	var antes := _notificaciones
	_experiencia.restaurar_xp(_experiencia.xp_total)  # simula reconexión con la MISMA xp
	print("Resistencia física tras restaurar_xp (esperado 5, no 10): %.1f" % _atributos.base.resistencia_fisica)
	_sobrevive_reconexion_ok = is_equal_approx(_atributos.base.resistencia_fisica, 5.0)
	_sin_notificacion_al_restaurar_ok = _notificaciones == antes
	print("Notificaciones tras restaurar_xp (esperado sin cambio, %d): %d" % [antes, _notificaciones])


func _informar() -> bool:
	var exito := _bono_aplica_ok and _no_duplica_en_salto_ok and _sobrevive_reconexion_ok \
		and _notificacion_en_vivo_ok and _sin_notificacion_al_restaurar_ok
	print("  bono se aplica al cruzar el nivel: %s" % _bono_aplica_ok)
	print("  salto de varios niveles no duplica: %s" % _no_duplica_en_salto_ok)
	print("  sobrevive a restaurar_xp sin duplicar: %s" % _sobrevive_reconexion_ok)
	print("  notificación sale en vivo: %s" % _notificacion_en_vivo_ok)
	print("  restaurar_xp no repite la notificación: %s" % _sin_notificacion_al_restaurar_ok)
	print("PRUEBA PASIVA STAT POR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
