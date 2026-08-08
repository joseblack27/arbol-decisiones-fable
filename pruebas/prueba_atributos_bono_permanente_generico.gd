# =============================================================================
# Prueba: AtributosComponente.agregar_crecimiento_permanente() ahora recibe un
# AtributosBase completo (no solo "danos") — necesario para que las pasivas de
# estadística (ver plan de habilidades pasivas) puedan sumar cualquier campo
# permanentemente al subir de nivel.
#
# Cubre:
#   1. Un bono con varios campos a la vez (no solo daños) se suma de verdad.
#   2. Sobrevive a recalcular_con_equipo() — mismo bug que ya cubría el caso
#      de "danos" ("al cargar la partida las estadísticas no se reflejan"):
#      un bono permanente aplicado solo a "base" se perdía en el próximo
#      cambio de equipo porque recalcular_con_equipo() SOBREESCRIBE base
#      entero desde _base_sin_equipo.
#   3. capturar_linea_base()/restablecer_linea_base() (usados por
#      ExperienciaComponente en cada reconexión) vuelven exacto al snapshot,
#      sin duplicar ningún campo — no solo "danos".
#   godot --headless --path . --script res://pruebas/prueba_atributos_bono_permanente_generico.gd
# =============================================================================
extends SceneTree

var _bono_multiple_ok := false
var _sobrevive_recalculo_ok := false
var _snapshot_restablece_ok := false


func _process(_delta: float) -> bool:
	_probar_bono_multiple()
	_probar_sobrevive_recalculo()
	_probar_snapshot()
	return _informar()


func _crear_atributos() -> Node:
	var atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos.name = "AtributosComponente"
	atributos.base = AtributosBase.new()
	atributos.base.danos = 5.0
	atributos.base.resistencia_fisica = 2.0
	root.add_child(atributos)
	atributos._ready()  # captura _base_sin_equipo desde "base"
	return atributos


func _probar_bono_multiple() -> void:
	var atributos := _crear_atributos()
	var bono := AtributosBase.new()
	bono.danos = 3.0
	bono.resistencia_fisica = 5.0
	bono.probabilidad_critico = 1.5
	atributos.agregar_crecimiento_permanente(bono)
	print("Daños tras bono múltiple (esperado 8): %.1f" % atributos.base.danos)
	print("Resistencia física tras bono múltiple (esperado 7): %.1f" % atributos.base.resistencia_fisica)
	print("Crítico tras bono múltiple (esperado 1.5): %.1f" % atributos.base.probabilidad_critico)
	_bono_multiple_ok = is_equal_approx(atributos.base.danos, 8.0) \
		and is_equal_approx(atributos.base.resistencia_fisica, 7.0) \
		and is_equal_approx(atributos.base.probabilidad_critico, 1.5)
	atributos.queue_free()


func _probar_sobrevive_recalculo() -> void:
	var atributos := _crear_atributos()
	var bono := AtributosBase.new()
	bono.defensa = 10.0
	atributos.agregar_crecimiento_permanente(bono)

	var item := DatosItem.new()
	item.bonos = AtributosBase.new()
	item.bonos.danos = 2.0
	atributos.recalcular_con_equipo([item] as Array[DatosItem])

	print("Defensa tras recalcular_con_equipo (esperado 10, sobrevive): %.1f" % atributos.base.defensa)
	print("Daños tras recalcular_con_equipo (esperado 7 = 5 base + 2 ítem): %.1f" % atributos.base.danos)
	_sobrevive_recalculo_ok = is_equal_approx(atributos.base.defensa, 10.0) \
		and is_equal_approx(atributos.base.danos, 7.0)
	atributos.queue_free()


func _probar_snapshot() -> void:
	var atributos := _crear_atributos()
	var snapshot = atributos.capturar_linea_base()

	var bono := AtributosBase.new()
	bono.resistencia_fuego = 4.0
	atributos.agregar_crecimiento_permanente(bono)
	print("Resistencia fuego tras crecer (esperado 4): %.1f" % atributos.base.resistencia_fuego)

	atributos.restablecer_linea_base(snapshot)
	print("Resistencia fuego tras restablecer_linea_base (esperado 0, vuelve a fábrica): %.1f" % \
		atributos.base.resistencia_fuego)
	print("Daños tras restablecer_linea_base (esperado 5, fábrica original): %.1f" % atributos.base.danos)

	# Reaplicar el mismo bono una segunda vez (simula una segunda
	# reconexión) NO debe duplicar — restablecer_linea_base tiene que haber
	# vuelto _base_sin_equipo al punto de partida real, no a uno a medio
	# resetear.
	atributos.agregar_crecimiento_permanente(bono)
	print("Resistencia fuego tras reaplicar una vez (esperado 4, no 8): %.1f" % \
		atributos.base.resistencia_fuego)

	_snapshot_restablece_ok = is_equal_approx(atributos.base.danos, 5.0) \
		and is_equal_approx(atributos.base.resistencia_fuego, 4.0)
	atributos.queue_free()


func _informar() -> bool:
	var exito := _bono_multiple_ok and _sobrevive_recalculo_ok and _snapshot_restablece_ok
	print("  bono múltiple aplica todos los campos: %s" % _bono_multiple_ok)
	print("  sobrevive a recalcular_con_equipo: %s" % _sobrevive_recalculo_ok)
	print("  snapshot/restablecer no duplica: %s" % _snapshot_restablece_ok)
	print("PRUEBA ATRIBUTOS BONO PERMANENTE GENERICO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
