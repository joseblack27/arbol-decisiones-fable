# =============================================================================
# Prueba: MarcaComponente con dano_base_detonacion — pensado para un jefe que
# sea la única fuente de daño del encuentro (ver EnemigoArañaReina): si nadie
# más golpea al marcado durante la ventana, _acumulado queda en 0 y antes la
# detonación no hacía NADA. Con un piso garantizado (dano_base_detonacion),
# la detonación igual aplica ese mínimo — sin acumular ningún daño real.
#   godot --headless --path . --script res://pruebas/prueba_marca_dano_base.gd
# =============================================================================
extends SceneTree

const RADIO := 150.0
const DANO_BASE := 40.0

var _f := 0
var _marcado: CharacterBody2D
var _vecino: CharacterBody2D
var _atacante: Node2D
var _marca

var _vida_vecino_antes := 0.0
var _nada_acumulado := false
var _detona_con_el_piso := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			# dano_base_detonacion=DANO_BASE, y a propósito NO se emite ningún
			# daño_aplicado sobre el marcado — _acumulado se queda en 0.
			_marca.activar(0.5, 0.5, RADIO, _atacante, 1, DANO_BASE)
		4:
			_nada_acumulado = is_equal_approx(_marca.acumulado(), 0.0)
			print("Nada acumulado (esperado 0.0, %.1f): %s" % [_marca.acumulado(), _nada_acumulado])
			_vida_vecino_antes = _vida(_vecino)
		# 0.5s = 30 fotogramas: acá ya detonó.
		45:
			var perdio := _vida_vecino_antes - _vida(_vecino)
			_detona_con_el_piso = perdio > 0.0
			print("Detona igual con el piso garantizado (esperado >0, perdió %.1f): %s" % [
				perdio, _detona_con_el_piso])
			return _informar()
	return false


func _nueva_marca() -> Node:
	var nodo := Node.new()
	nodo.name = "MarcaComponente"
	nodo.set_script(load("res://componentes/MarcaComponente.gd"))
	return nodo


func _vida(entidad: Node) -> float:
	var v := entidad.get_node_or_null("VidaComponente") as VidaComponente
	return v.obtener_vida() if v else 0.0


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	escena.add_child(_atacante)
	_atacante.global_position = Vector2(-400, 0)

	var escena_mob := load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene
	_marcado = _crear_mob(escena_mob, escena, Vector2.ZERO)
	_vecino  = _crear_mob(escena_mob, escena, Vector2(80, 0))

	_marca = _nueva_marca()
	_marcado.add_child(_marca)


func _crear_mob(escena_mob: PackedScene, padre: Node, pos: Vector2) -> CharacterBody2D:
	var mob := escena_mob.instantiate()
	padre.add_child(mob)
	mob.global_position = pos
	(mob.get_node("ArbolComportamiento")).activo = false
	return mob


func _informar() -> bool:
	var exito := _nada_acumulado and _detona_con_el_piso
	print("PRUEBA MARCA DAÑO BASE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
