# =============================================================================
# Prueba de bonos de atributos por equipo (DatosItem.bonos + AtributosComponente
# .recalcular_con_equipo + GestorEquipo):
#   1. Sin nada equipado, AtributosComponente.base son los de fábrica.
#   2. Al equipar un ítem con bonos, "base" pasa a incluir esos bonos SUMADOS
#      a los de fábrica (no los reemplaza).
#   3. Equipar un segundo ítem sigue sumando (no pisa el primero).
#   4. Al desequipar todo, vuelve exactamente a los valores de fábrica —
#      no quedan bonos "pegados" de una recalculación anterior.
#   5. Los recursos reales creados (armadura_3.tres, escudo.tres) cargan
#      con sus bonos tal cual se configuraron.
#   godot --headless --path . --script res://pruebas/prueba_atributos_equipo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atributos: Node
var _item_a: DatosItem
var _item_b: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


var _base_original_id: int

func _montar() -> void:
	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	var base := AtributosBase.new()
	base.defensa   = 10.0
	base.danos     = 5.0
	_atributos.base = base
	root.add_child(_atributos)  # dispara _ready(), captura _base_sin_equipo
	# Simula a PanelTablero: guarda una referencia a "base" UNA sola vez, como
	# si la cacheara al abrirse — si recalcular_con_equipo() alguna vez vuelve
	# a REEMPLAZAR el objeto en vez de mutarlo, esta referencia quedaría
	# obsoleta y el bug ("no subieron las estadísticas") reaparecería.
	_base_original_id = base.get_instance_id()

	_item_a = DatosItem.new()
	_item_a.bonos = AtributosBase.new()
	_item_a.bonos.defensa = 3.0

	_item_b = DatosItem.new()
	_item_b.bonos = AtributosBase.new()
	_item_b.bonos.danos = 2.0
	_item_b.bonos.tenacidad = 1.0


func _informar() -> bool:
	var sin_equipo_ok := is_equal_approx(_atributos.base.defensa, 10.0) \
		and is_equal_approx(_atributos.base.danos, 5.0)

	var vacio: Array[DatosItem] = []
	var uno: Array[DatosItem] = [_item_a]
	var dos: Array[DatosItem] = [_item_a, _item_b]

	_atributos.recalcular_con_equipo(uno)
	var un_item_ok := is_equal_approx(_atributos.base.defensa, 13.0) \
		and is_equal_approx(_atributos.base.danos, 5.0)
	print("Con armadura (+3 defensa): defensa=%.1f daños=%.1f (esperado 13.0 / 5.0)" % [
		_atributos.base.defensa, _atributos.base.danos,
	])

	_atributos.recalcular_con_equipo(dos)
	var dos_items_ok := is_equal_approx(_atributos.base.defensa, 13.0) \
		and is_equal_approx(_atributos.base.danos, 7.0) \
		and is_equal_approx(_atributos.base.tenacidad, 1.0)
	print("Con armadura + espada (+2 daños, +1 tenacidad): defensa=%.1f daños=%.1f tenacidad=%.1f (esperado 13.0 / 7.0 / 1.0)" % [
		_atributos.base.defensa, _atributos.base.danos, _atributos.base.tenacidad,
	])

	_atributos.recalcular_con_equipo(vacio)
	var desequipado_ok := is_equal_approx(_atributos.base.defensa, 10.0) \
		and is_equal_approx(_atributos.base.danos, 5.0) \
		and is_equal_approx(_atributos.base.tenacidad, 0.0)
	print("Tras desequipar todo, vuelve a fábrica: defensa=%.1f daños=%.1f tenacidad=%.1f (esperado 10.0 / 5.0 / 0.0)" % [
		_atributos.base.defensa, _atributos.base.danos, _atributos.base.tenacidad,
	])

	var armadura3 := load("res://recursos/items/equipables/armadura_3.tres") as DatosItem
	var escudo := load("res://recursos/items/equipables/escudo.tres") as DatosItem
	var recursos_ok := armadura3.bonos != null and is_equal_approx(armadura3.bonos.defensa, 10.0) \
		and escudo.bonos != null and is_equal_approx(escudo.bonos.defensa, 8.0) \
		and is_equal_approx(escudo.bonos.tenacidad, 4.0)
	print("Recursos reales (armadura_3=+10 def, escudo=+8 def/+4 ten): %s" % recursos_ok)

	var id_actual: int = _atributos.base.get_instance_id()
	var identidad_preservada: bool = id_actual == _base_original_id
	print("El objeto 'base' es SIEMPRE el mismo (mutado, no reemplazado) — esperado true: %s" % identidad_preservada)

	var exito := sin_equipo_ok and un_item_ok and dos_items_ok and desequipado_ok \
		and recursos_ok and identidad_preservada
	print("PRUEBA ATRIBUTOS EQUIPO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
