# =============================================================================
# Prueba de la descripción del buff de Veneno (BuffsComponente) — mismo bug
# ya encontrado y arreglado en Aura, reproducido acá: la descripción usaba
# dano_por_tick crudo (sin pasar por los atributos de quien disparó el
# veneno) y "%.0f" para el intervalo (redondeaba un valor fraccionario a un
# entero engañoso).
#
# Verifica:
#   1. La descripción incluye el daño YA pasado por los atributos del
#      atacante (dano_por_tick=8 + atributos.danos=5 -> 13).
#   2. El intervalo fraccionario (0.5) se muestra tal cual, sin redondear.
#   godot --headless --path . --script res://pruebas/prueba_veneno_descripcion_buff.gd
# =============================================================================
extends SceneTree

var _atacante
var _mob
var _fotogramas := 0

var _ok_dano_con_atributos := false
var _ok_intervalo_fraccionario := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 3:
		return _informar()
	return false


func _montar() -> void:
	_atacante = CharacterBody2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)

	var atrib_comp = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atrib_comp.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos = 5.0
	atrib_comp.base = base
	_atacante.add_child(atrib_comp)

	_mob = CharacterBody2D.new()
	_mob.add_to_group("enemigos")
	root.add_child(_mob)

	var efecto = (load("res://escenas/efectos/EfectoVeneno.gd") as GDScript).new()
	efecto.objetivo = _mob
	efecto.fuente = _atacante
	efecto.dano_por_tick = 8.0
	efecto.intervalo_tick = 0.5
	efecto.duracion = 5.0
	efecto.icono_debuff = load("res://icon.svg")
	_mob.add_child(efecto)


func _informar() -> bool:
	var buffs = _mob.get_node_or_null("BuffsComponente")
	var descripcion := ""
	if buffs:
		var buff = buffs.obtener("veneno")
		descripcion = buff.descripcion if buff else ""
	print("Descripción: \"%s\"" % descripcion)

	# dano_por_tick=8 + atributos.danos=5 (sin potencia) -> vista previa 13.
	_ok_dano_con_atributos = descripcion.contains("13")
	_ok_intervalo_fraccionario = descripcion.contains("0.5s")
	print("Muestra el daño con atributos aplicados, '13' (esperado true): %s" % _ok_dano_con_atributos)
	print("Muestra el intervalo fraccionario '0.5s' sin redondear (esperado true): %s" % _ok_intervalo_fraccionario)

	var exito := _ok_dano_con_atributos and _ok_intervalo_fraccionario
	print("PRUEBA VENENO DESCRIPCION BUFF %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
