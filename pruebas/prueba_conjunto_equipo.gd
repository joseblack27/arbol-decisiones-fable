# =============================================================================
# Bonos de CONJUNTO de equipo (ConjuntoDatos/TramoConjunto + DatosItem.conjunto
# + AtributosComponente._sumar_bonos_de_conjuntos): pedido explícito del
# usuario, "vamos por profundidad de itemizacion" -> "sets de equipo y mas
# variedad de items fijos" (31 ago 2026).
#
#   1. Con piezas de DISTINTOS conjuntos (o sin conjunto), ningún tramo se
#      activa — solo suman sus bonos individuales.
#   2. Con 2 piezas del MISMO conjunto, se activa el tramo de 2 piezas
#      ADEMÁS de los bonos individuales de cada pieza (no en su lugar).
#   3. Con 4 piezas, se activan AMBOS tramos (2 y 4) — se acumulan, no se
#      reemplazan.
#   4. Al desequipar hasta quedar con menos piezas que un tramo, ese bono
#      desaparece (recalcular_con_equipo() reconstruye "base" desde cero
#      cada vez, no acumula tramos viejos).
#   5. Los 4 .tres reales del Conjunto del Guardián Quebrado (armadura_1..4)
#      apuntan todos a la MISMA instancia de conjunto_guardian.tres.
#   godot --headless --path . --script res://pruebas/prueba_conjunto_equipo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atributos: Node
var _conjunto_a: ConjuntoDatos
var _conjunto_b: ConjuntoDatos
var _pieza_a1: DatosItem
var _pieza_a2: DatosItem
var _pieza_a3: DatosItem
var _pieza_a4: DatosItem
var _pieza_b1: DatosItem
var _sin_conjunto: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _crear_conjunto(nombre: String, tramos_def: Array) -> ConjuntoDatos:
	var conjunto := ConjuntoDatos.new()
	conjunto.nombre = nombre
	var tramos: Array[TramoConjunto] = []
	for def in tramos_def:
		var tramo := TramoConjunto.new()
		tramo.piezas_requeridas = def[0]
		tramo.bonos = AtributosBase.new()
		def[1].call(tramo.bonos)
		tramos.append(tramo)
	conjunto.tramos = tramos
	return conjunto


func _crear_pieza(conjunto: ConjuntoDatos, danos: float) -> DatosItem:
	var item := DatosItem.new()
	item.bonos = AtributosBase.new()
	item.bonos.danos = danos
	item.conjunto = conjunto
	return item


func _montar() -> void:
	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	var base := AtributosBase.new()
	_atributos.base = base
	root.add_child(_atributos)

	_conjunto_a = _crear_conjunto("Conjunto A", [
		[2, func(b: AtributosBase): b.defensa = 5.0],
		[4, func(b: AtributosBase): b.fortaleza = 8.0],
	])
	_conjunto_b = _crear_conjunto("Conjunto B", [
		[2, func(b: AtributosBase): b.probabilidad_critico = 10.0],
	])

	_pieza_a1 = _crear_pieza(_conjunto_a, 1.0)
	_pieza_a2 = _crear_pieza(_conjunto_a, 1.0)
	_pieza_a3 = _crear_pieza(_conjunto_a, 1.0)
	_pieza_a4 = _crear_pieza(_conjunto_a, 1.0)
	_pieza_b1 = _crear_pieza(_conjunto_b, 1.0)
	_sin_conjunto = DatosItem.new()
	_sin_conjunto.bonos = AtributosBase.new()
	_sin_conjunto.bonos.danos = 1.0


func _informar() -> bool:
	# 1. Piezas de conjuntos distintos (o sin conjunto): ningún tramo activo.
	var mezcla: Array[DatosItem] = [_pieza_a1, _pieza_b1, _sin_conjunto]
	_atributos.recalcular_con_equipo(mezcla)
	var sin_tramo_ok: bool = is_equal_approx(_atributos.base.defensa, 0.0) \
		and is_equal_approx(_atributos.base.fortaleza, 0.0) \
		and is_equal_approx(_atributos.base.probabilidad_critico, 0.0) \
		and is_equal_approx(_atributos.base.danos, 3.0)  # 1 pieza de cada 3 ítems, bono individual siempre suma.
	print("Sin 2 piezas del mismo conjunto, ningún tramo se activa (esperado true — def=%.1f fort=%.1f crit=%.1f dan=%.1f): %s" % [
		_atributos.base.defensa, _atributos.base.fortaleza, _atributos.base.probabilidad_critico, _atributos.base.danos, sin_tramo_ok])

	# 2. 2 piezas del mismo conjunto A: tramo de 2 piezas activo, más bonos individuales.
	var dos_piezas: Array[DatosItem] = [_pieza_a1, _pieza_a2]
	_atributos.recalcular_con_equipo(dos_piezas)
	var dos_piezas_ok: bool = is_equal_approx(_atributos.base.defensa, 5.0) \
		and is_equal_approx(_atributos.base.fortaleza, 0.0) \
		and is_equal_approx(_atributos.base.danos, 2.0)
	print("Con 2 piezas del conjunto A, se activa el tramo de 2 (esperado true — def=%.1f fort=%.1f dan=%.1f): %s" % [
		_atributos.base.defensa, _atributos.base.fortaleza, _atributos.base.danos, dos_piezas_ok])

	# 3. 4 piezas: se acumulan AMBOS tramos (2 y 4), no se reemplazan.
	var cuatro_piezas: Array[DatosItem] = [_pieza_a1, _pieza_a2, _pieza_a3, _pieza_a4]
	_atributos.recalcular_con_equipo(cuatro_piezas)
	var cuatro_piezas_ok: bool = is_equal_approx(_atributos.base.defensa, 5.0) \
		and is_equal_approx(_atributos.base.fortaleza, 8.0) \
		and is_equal_approx(_atributos.base.danos, 4.0)
	print("Con 4 piezas, se acumulan los tramos de 2 Y de 4 (esperado true — def=%.1f fort=%.1f dan=%.1f): %s" % [
		_atributos.base.defensa, _atributos.base.fortaleza, _atributos.base.danos, cuatro_piezas_ok])

	# 4. Desequipar hasta quedar con menos piezas: el bono desaparece.
	var una_pieza: Array[DatosItem] = [_pieza_a1]
	_atributos.recalcular_con_equipo(una_pieza)
	var desequipar_ok: bool = is_equal_approx(_atributos.base.defensa, 0.0) \
		and is_equal_approx(_atributos.base.fortaleza, 0.0) \
		and is_equal_approx(_atributos.base.danos, 1.0)
	print("Con 1 sola pieza, ya no hay ningún tramo activo (esperado true — def=%.1f fort=%.1f dan=%.1f): %s" % [
		_atributos.base.defensa, _atributos.base.fortaleza, _atributos.base.danos, desequipar_ok])

	# 5. Recursos reales: las 4 piezas del Guardián comparten la MISMA instancia de conjunto.
	var casco := load("res://recursos/items/equipables/armadura_1.tres") as DatosItem
	var pechera := load("res://recursos/items/equipables/armadura_2.tres") as DatosItem
	var grebas := load("res://recursos/items/equipables/armadura_3.tres") as DatosItem
	var botas := load("res://recursos/items/equipables/armadura_4.tres") as DatosItem
	var mismo_conjunto_ok: bool = casco.conjunto != null and casco.conjunto == pechera.conjunto \
		and casco.conjunto == grebas.conjunto and casco.conjunto == botas.conjunto
	print("Las 4 piezas reales del Guardián comparten el mismo ConjuntoDatos (esperado true): %s" % mismo_conjunto_ok)

	var guardian_completo: Array[DatosItem] = [casco, pechera, grebas, botas]
	_atributos.recalcular_con_equipo(guardian_completo)
	# defensa de fábrica: 3+6+10+15=34, +tramo 2pc (defensa+5) = 39; fortaleza de fábrica: 5(botas)+3(grebas)=8, +tramo 4pc (fortaleza+8)=16.
	var guardian_real_ok: bool = is_equal_approx(_atributos.base.defensa, 39.0) \
		and is_equal_approx(_atributos.base.fortaleza, 16.0) \
		and is_equal_approx(_atributos.base.tenacidad, 5.0)
	print("Con el set completo del Guardián puesto (esperado def=39.0 fort=16.0 tenacidad=5.0, obtenido def=%.1f fort=%.1f tenacidad=%.1f): %s" % [
		_atributos.base.defensa, _atributos.base.fortaleza, _atributos.base.tenacidad, guardian_real_ok])

	var exito := sin_tramo_ok and dos_piezas_ok and cuatro_piezas_ok and desequipar_ok \
		and mismo_conjunto_ok and guardian_real_ok
	print("PRUEBA CONJUNTO EQUIPO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
