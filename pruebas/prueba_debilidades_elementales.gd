# =============================================================================
# Prueba de debilidades/resistencias elementales en mobs:
#   1. calcular_dano_entrante() con resistencia NEGATIVA amplifica el daño
#      (antes el clamp tenía piso en 0%, así que una debilidad no hacía
#      nada — el mismo bug para CUALQUIER mob con resistencia negativa).
#   2. Tope de amplificación: -100% de resistencia = como mucho el doble
#      de daño, nunca más (evita un one-shot con una sola debilidad).
#   3. Perfil elemental real de cada mob activo del roster: Esqueletos
#      (Caballero/Jefe) resisten tierra pero son débiles al fuego; Lobo/
#      Lobo Feroz débiles al fuego; Araña muy débil al fuego (su mayor
#      debilidad del roster).
#   godot --headless --path . --script res://pruebas/prueba_debilidades_elementales.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _ok := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 2:
		_ok = _prueba_amplificacion_directa() and _ok
		_ok = _prueba_tope_amplificacion() and _ok
		_ok = _prueba_perfil_mobs() and _ok
		print("PRUEBA DEBILIDADES ELEMENTALES %s" % ("OK" if _ok else "FALLIDA"))
		quit(0 if _ok else 1)
		return true
	return false


func _atributos_con(resistencia_fuego: float) -> Node:
	var atrib = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	var base := AtributosBase.new()
	base.resistencia_fuego = resistencia_fuego
	atrib.base = base
	return atrib


func _prueba_amplificacion_directa() -> bool:
	var atrib := _atributos_con(-25.0)  # -25% resistencia = +25% daño.
	var dano: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.FUEGO)
	var ok := is_equal_approx(dano, 125.0)
	print("100 de FUEGO contra -25%% resistencia (debilidad, esperado 125): %.1f" % dano)
	return ok


func _prueba_tope_amplificacion() -> bool:
	var atrib := _atributos_con(-500.0)  # debilidad absurda a propósito.
	var dano: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.FUEGO)
	var ok := is_equal_approx(dano, 200.0)
	print("100 de FUEGO contra debilidad extrema -500%% (tope, esperado 200, nunca más): %.1f" % dano)
	return ok


func _prueba_perfil_mobs() -> bool:
	var casos := [
		["res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn", true],
		["res://escenas/enemigos/EnemigoJefeEsqueleto.tscn", true],
		["res://escenas/enemigos/EnemigoLobo.tscn", false],
		["res://escenas/enemigos/EnemigoLoboFeroz.tscn", false],
		["res://escenas/enemigos/EnemigoAraña.tscn", false],
	]
	var todos_ok := true
	for caso in casos:
		var ruta: String = caso[0]
		var resiste_tierra: bool = caso[1]
		var mob = (load(ruta) as PackedScene).instantiate()
		root.add_child(mob)
		var atrib := mob.get_node("AtributosComponente") as AtributosComponente

		var dano_fuego: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.FUEGO)
		var debil_fuego_ok := dano_fuego > 100.0
		print("%s: 100 FUEGO -> %.1f (esperado >100, débil al fuego): %s" % [
			ruta.get_file(), dano_fuego, debil_fuego_ok,
		])
		if not debil_fuego_ok:
			todos_ok = false

		if resiste_tierra:
			var dano_tierra: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.TIERRA)
			var resiste_ok := dano_tierra < 100.0
			print("%s: 100 TIERRA -> %.1f (esperado <100, resiste tierra): %s" % [
				ruta.get_file(), dano_tierra, resiste_ok,
			])
			if not resiste_ok:
				todos_ok = false

		mob.queue_free()
	return todos_ok
