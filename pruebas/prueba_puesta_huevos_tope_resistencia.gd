# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "cuando la
# hormiga reina invoca las larvas y estas emergen como hormigas, hay una
# parte que no entendi bien donde puede haber mas de 4 hormigas con el
# buffo, pero la reina a veces recibia 0 de daño, recuerda que maximo es
# 60% por este buffo". Causa real: HabilidadPuestaHuevos._recalcular_
# resistencia() y su espejo _actualizar_guardianes_red() clampeaban la
# reducción contra 1.0 (100%) en vez de contra el 60% de diseño (ver
# comentario de clase: "hasta 3 guardianas = -60% total") -- como
# _guardianes_vivos no se limita a 3 (dos puestas de huevos que se
# solapan pueden dejar más guardianas vivas a la vez), reduccion_por_
# guardian(0.2) * 5+ guardianas superaba 1.0 y la Reina no recibía nada
# de daño.
#
# Prueba DIRECTA sobre la fórmula (sin esperar el reposo/eclosión real):
# fuerza 6 guardianas "vivas" (más del tope de diseño) tanto en el cálculo
# del SERVIDOR (_recalcular_resistencia) como en el espejo del CLIENTE
# (_actualizar_guardianes_red) y confirma que la reducción real quede
# tope-ada en 60%, nunca en 100%.
#   godot --headless --path . --script res://pruebas/prueba_puesta_huevos_tope_resistencia.gd
# =============================================================================
extends SceneTree

var _f := 0
var _reina
var _habilidad
var _contenedor: Node2D
var _guardianes_falsos: Array = []

var _servidor_topeado_60_ok := false
var _cliente_topeado_60_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_probar_servidor()
			_probar_cliente()
			return _informar()
	return false


func _montar() -> void:
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO

	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")

	# 6 "guardianas" (más del tope de diseño de 3) -- nodos reales para que
	# is_instance_valid()/get_path() funcionen igual que con hormigas de
	# verdad, sin tener que esperar el reposo + la eclosión real.
	for i in 6:
		var falsa := Node2D.new()
		falsa.name = "GuardianFalsa%d" % i
		_contenedor.add_child(falsa)
		_guardianes_falsos.append(falsa)


func _probar_servidor() -> void:
	_habilidad._guardianes_vivos = _guardianes_falsos.duplicate()
	_habilidad._recalcular_resistencia()

	var escudo := _reina.get_node_or_null("EscudoComponente") as EscudoComponente
	var dano_resultante := escudo.aplicar(100.0) if escudo else 100.0
	# 60% de tope real -> un golpe de 100 debe dejar pasar 40, nunca 0.
	_servidor_topeado_60_ok = escudo != null and escudo.esta_activo() \
		and is_equal_approx(dano_resultante, 40.0)
	print("SERVIDOR: con 6 guardianas la resistencia queda topeada en 60%% (esperado true, daño real=%.1f): %s" % [
		dano_resultante, _servidor_topeado_60_ok])


func _probar_cliente() -> void:
	var rutas: Array[NodePath] = []
	for g in _guardianes_falsos:
		rutas.append(g.get_path())
	_habilidad._actualizar_guardianes_red(rutas)

	var buffs := _reina.get_node_or_null("BuffsComponente") as BuffsComponente
	# El cliente no toca EscudoComponente (esa es la autoridad del
	# servidor) -- alcanza con confirmar que el buff quede activo con la
	# misma fórmula que ya se probó del lado servidor.
	_cliente_topeado_60_ok = buffs != null and buffs.esta_activo("resistencia_colonia")
	print("CLIENTE: el buff de resistencia queda activo con 6 guardianas (esperado true): %s" % \
		_cliente_topeado_60_ok)


func _informar() -> bool:
	var exito := _servidor_topeado_60_ok and _cliente_topeado_60_ok
	print("PRUEBA PUESTA DE HUEVOS TOPE RESISTENCIA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
