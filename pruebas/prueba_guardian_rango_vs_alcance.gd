# =============================================================================
# Regresión: "no le atinaba los golpes... solo le daba con una punta y de
# vaina", con el jugador QUIETO. Causa real: el rango que la IA considera
# "al alcance" (HabilidadBT.rango_maximo) estaba configurado por separado
# del alcance FÍSICO real del golpe (alcance_golpe+radio_golpe, largo,
# radio, o distancia_maxima_dash según la habilidad) — más generoso en
# CASI TODAS, así que la IA elegía atacar desde una distancia que el golpe
# después no llegaba a cubrir. No hacía falta que el jugador se moviera.
#
# Esta prueba carga cada HabilidadBT.tres real y el nodo de habilidad real
# (desde la escena del jefe, no valores a mano) y confirma que
# rango_maximo <= alcance físico, para las 7 habilidades que "apuntan"
# directo al objetivo (Muro se chequea aparte: se PLANTA a distancia fija,
# no se estira, así que el criterio es "no demasiado por encima" en vez de
# "menor o igual").
#   godot --headless --path . --script res://pruebas/prueba_guardian_rango_vs_alcance.gd
# =============================================================================
extends SceneTree

var _jefe
var _ok := true


func _process(_delta: float) -> bool:
	_montar()
	_verificar("ComboGuardian.tres", "Habilidades/HabilidadComboGuardian",
		func(n): return n.alcance_golpe + n.radio_golpe)
	_verificar("BarridoGuardian.tres", "Habilidades/HabilidadBarridoGuardian",
		func(n): return n.largo)
	_verificar("AmagueGuardian.tres", "Habilidades/HabilidadAmagueGuardian",
		func(n): return n.largo)
	_verificar("GolpeCorruptoGuardian.tres", "Habilidades/HabilidadGolpeCorruptoGuardian",
		func(n): return n.alcance_golpe + n.radio_golpe)
	_verificar("CastigoGuardian.tres", "Habilidades/HabilidadGolpeVerdaderoCastigo",
		func(n): return n.alcance_golpe + n.radio_golpe)
	_verificar("MiedoGuardian.tres", "Habilidades/HabilidadMiedoGuardian",
		func(n): return n.radio)
	_verificar("ArremetidaGuardian.tres", "Habilidades/HabilidadArremetidaGuardian",
		func(n): return n.distancia_maxima_dash)
	_verificar_muro()
	print("PRUEBA GUARDIAN RANGO VS ALCANCE %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz
	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)


func _verificar(nombre_bt: String, ruta_nodo: String, calcular_alcance: Callable) -> void:
	var bt = load("res://componentes/arbol_comportamiento/recursos/%s" % nombre_bt)
	var nodo = _jefe.get_node(ruta_nodo)
	var alcance: float = calcular_alcance.call(nodo)
	var en_rango: bool = bt.rango_maximo <= alcance
	if not en_rango:
		_ok = false
	print("%s: rango_maximo=%.1f <= alcance real=%.1f (esperado true): %s" % [
		nombre_bt, bt.rango_maximo, alcance, en_rango])


func _verificar_muro() -> void:
	var bt = load("res://componentes/arbol_comportamiento/recursos/MuroGuardian.tres")
	var nodo = _jefe.get_node("Habilidades/HabilidadMuroGuardian")
	# distancia_muro es ahora un TOPE (_ejecutar toma la menor entre esto y
	# la distancia real al objetivo) — mismo criterio que las demás:
	# rango_maximo <= distancia_muro, sin margen extra.
	var en_rango: bool = bt.rango_maximo <= nodo.distancia_muro
	if not en_rango:
		_ok = false
	print("MuroGuardian.tres: rango_maximo=%.1f <= distancia_muro=%.1f (esperado true): %s" % [
		bt.rango_maximo, nodo.distancia_muro, en_rango])
