# =============================================================================
# Prueba de CreditosComponente — el monedero de créditos del jugador.
# Mutador simple sin RPC propio (ver TiendaComponente/MisionesComponente
# para quién sí lleva el patrón RPC completo al gastar/otorgar créditos).
#   godot --headless --path . --script res://pruebas/prueba_creditos_componente.gd
# =============================================================================
extends SceneTree

var _creditos

var _agregar_suma_ok := false
var _quitar_con_saldo_descuenta_ok := false
var _quitar_sin_saldo_rechaza_ok := false
var _tiene_creditos_ok := false
var _fijar_local_pisa_el_valor_ok := false
var _cantidad_cero_o_negativa_no_hace_nada_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_agregar()
	_probar_quitar_con_saldo()
	_probar_quitar_sin_saldo()
	_probar_tiene_creditos()
	_probar_fijar_local()
	_probar_cantidad_invalida()
	return _informar()


func _montar() -> void:
	_creditos = (load("res://componentes/CreditosComponente.gd") as GDScript).new()
	root.add_child(_creditos)


func _probar_agregar() -> void:
	_creditos.agregar_creditos(50)
	_agregar_suma_ok = _creditos.obtener_creditos() == 50
	print("agregar_creditos(50) deja el saldo en 50 (esperado true): %s" % _agregar_suma_ok)


func _probar_quitar_con_saldo() -> void:
	var resultado: bool = _creditos.quitar_creditos(20)
	_quitar_con_saldo_descuenta_ok = resultado and _creditos.obtener_creditos() == 30
	print("quitar_creditos(20) con saldo 50 descuenta a 30 (esperado true): %s" % _quitar_con_saldo_descuenta_ok)


func _probar_quitar_sin_saldo() -> void:
	var resultado: bool = _creditos.quitar_creditos(1000)
	_quitar_sin_saldo_rechaza_ok = not resultado and _creditos.obtener_creditos() == 30
	print("quitar_creditos(1000) sin saldo suficiente rechaza y no toca el saldo (esperado true): %s" % _quitar_sin_saldo_rechaza_ok)


func _probar_tiene_creditos() -> void:
	_tiene_creditos_ok = _creditos.tiene_creditos(30) and not _creditos.tiene_creditos(31)
	print("tiene_creditos() refleja el saldo exacto (esperado true): %s" % _tiene_creditos_ok)


func _probar_fijar_local() -> void:
	_creditos._fijar_creditos_local(777)
	_fijar_local_pisa_el_valor_ok = _creditos.obtener_creditos() == 777
	print("_fijar_creditos_local(777) pisa el saldo exacto (esperado true): %s" % _fijar_local_pisa_el_valor_ok)


func _probar_cantidad_invalida() -> void:
	_creditos.agregar_creditos(0)
	_creditos.agregar_creditos(-5)
	var quito_cero: bool = _creditos.quitar_creditos(0)
	_cantidad_cero_o_negativa_no_hace_nada_ok = _creditos.obtener_creditos() == 777 and quito_cero
	print("Cantidades <= 0 no cambian el saldo (esperado true): %s" % _cantidad_cero_o_negativa_no_hace_nada_ok)


func _informar() -> bool:
	var exito := _agregar_suma_ok and _quitar_con_saldo_descuenta_ok \
		and _quitar_sin_saldo_rechaza_ok and _tiene_creditos_ok \
		and _fijar_local_pisa_el_valor_ok and _cantidad_cero_o_negativa_no_hace_nada_ok
	print("PRUEBA CREDITOS COMPONENTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
