# =============================================================================
# Prueba de que el daño real por tick del Aura es el 50% del daño YA
# calculado (dano_base_min/max de aura.tres + atributos), Y que
# PanelDetalleHabilidad.gd muestra ESE MISMO valor reducido en "Daño
# Calculado" — pedido del usuario. Mismo mecanismo que ya usa
# HabilidadLanzallamas.multiplicador_dano_tick: mismo nombre de
# propiedad, el panel lo lee solo, sin tocarlo para nada.
#
# Carga aura.tres REAL (no sintético): dano_base_min/max=6/8,
# multiplicador_dano_tick=0.5 (default de HabilidadAura.gd) -> el daño
# real de cada tick debe caer siempre en [3.0, 4.0], y el panel debe
# mostrar "3 - 4".
#   godot --headless --path . --script res://pruebas/prueba_aura_multiplicador_dano.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador
var _enemigo
var _habilidad
var _panel

var _dano_real_reducido_ok := true
var _panel_muestra_el_mismo_valor := false


static func _script_enemigo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var danos_recibidos: Array[float] = []
func quitar_vida(cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	danos_recibidos.append(cantidad)
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_habilidad.activar(Vector2.ZERO, 1.0)
	# intervalo_tick=1.0s (~60 fotogramas, valor real de HabilidadAura.tscn)
	# — con margen de sobra ya tickeó un par de veces.
	if _fotogramas == 140:
		_verificar()
		return _informar()
	return false


func _verificar() -> void:
	print("Daños recibidos: %s" % [_enemigo.danos_recibidos])
	for d in _enemigo.danos_recibidos:
		if d < 3.0 or d > 4.0:
			_dano_real_reducido_ok = false
	_dano_real_reducido_ok = _dano_real_reducido_ok and _enemigo.danos_recibidos.size() > 0
	print("Daño real de cada tick cae en [3.0, 4.0] (50%% de 6-8) (esperado true): %s" % _dano_real_reducido_ok)

	var datos := load("res://recursos/habilidades/aura.tres") as DatosHabilidad
	_panel.show_skill(datos)
	var dmg_calc_texto: String = _panel.dmg_calc_label.text
	_panel_muestra_el_mismo_valor = dmg_calc_texto == "3 - 4"
	print("Panel muestra el mismo valor reducido (esperado true, '3 - 4'): %s (\"%s\")" % [
		_panel_muestra_el_mismo_valor, dmg_calc_texto])


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)

	_enemigo = CharacterBody2D.new()
	_enemigo.set_script(_script_enemigo())
	_enemigo.add_to_group("enemigos")
	_enemigo.collision_layer = 2
	_enemigo.global_position = Vector2(10, 0)  # dentro del radio real (75px, ver HabilidadAura.tscn).
	root.add_child(_enemigo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	_enemigo.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/aura/HabilidadAura.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.aplicar_datos(load("res://recursos/habilidades/aura.tres") as DatosHabilidad)
	_habilidad.costo_energia = 0.0

	var escena_panel := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	var raiz_panel := escena_panel.instantiate()
	root.add_child(raiz_panel)
	_panel = raiz_panel.get_node("MarginContainer/HBoxContainer/PanelDetalle")


func _informar() -> bool:
	var exito := _dano_real_reducido_ok and _panel_muestra_el_mismo_valor
	print("PRUEBA AURA MULTIPLICADOR DANO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
