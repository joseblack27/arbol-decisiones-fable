# =============================================================================
# Prueba: CondicionObjetivoSinHabilidades — la rama de "castigo" de un jefe
# (ver EnemigoArañaReina) solo debe activarse si el jugador está en rango
# melee Y NINGUNA de sus habilidades equipadas está lista.
# Verifica las 4 combinaciones cerca/lejos × todas-en-cooldown/alguna-libre.
#   godot --headless --path . --script res://pruebas/prueba_condicion_castigo.gd
# =============================================================================
extends SceneTree

const UMBRAL := 90.0
const CERCA := Vector2(50, 0)
const LEJOS := Vector2(300, 0)

var _agente: Node2D
var _objetivo
var _memoria
var _condicion
var _hab_a
var _hab_b
var _f := 0

var _cerca_sin_habilidades_exitoso := false
var _cerca_con_habilidad_libre_fallido := false
var _lejos_sin_habilidades_fallido := false
var _lejos_con_habilidad_libre_fallido := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			# A: cerca + ambas en cooldown -> ÉXITO.
			_agente.global_position = CERCA
			_hab_a._recarga_restante = 5.0
			_hab_b._recarga_restante = 5.0
			var r = _condicion.ejecutar()
			_cerca_sin_habilidades_exitoso = r == NodoBT.Estado.EXITOSO
			print("A) cerca + todas en cooldown -> EXITOSO (esperado true): %s" % \
				_cerca_sin_habilidades_exitoso)

			# B: cerca + una libre -> FALLIDO.
			_hab_b._recarga_restante = 0.0
			r = _condicion.ejecutar()
			_cerca_con_habilidad_libre_fallido = r == NodoBT.Estado.FALLIDO
			print("B) cerca + una libre -> FALLIDO (esperado true): %s" % \
				_cerca_con_habilidad_libre_fallido)

			# C: lejos + ambas en cooldown -> FALLIDO.
			_agente.global_position = LEJOS
			_hab_b._recarga_restante = 5.0
			r = _condicion.ejecutar()
			_lejos_sin_habilidades_fallido = r == NodoBT.Estado.FALLIDO
			print("C) lejos + todas en cooldown -> FALLIDO (esperado true): %s" % \
				_lejos_sin_habilidades_fallido)

			# D: lejos + una libre -> FALLIDO.
			_hab_b._recarga_restante = 0.0
			r = _condicion.ejecutar()
			_lejos_con_habilidad_libre_fallido = r == NodoBT.Estado.FALLIDO
			print("D) lejos + una libre -> FALLIDO (esperado true): %s" % \
				_lejos_con_habilidad_libre_fallido)

			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_agente = Node2D.new()
	raiz.add_child(_agente)
	_agente.global_position = Vector2.ZERO

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_objetivo = escena_jugador.instantiate()
	_objetivo.name = "1"
	raiz.add_child(_objetivo)
	_objetivo.global_position = Vector2.ZERO

	var slots = _objetivo.get_node("SlotHabilidades")
	var datos = load("res://recursos/habilidades/golpe_basico.tres")
	slots.equipar(0, datos)
	slots.equipar(1, datos)
	_hab_a = slots.obtener(0)
	_hab_b = slots.obtener(1)

	_memoria = (load("res://componentes/arbol_comportamiento/MemoriaBT.gd") as GDScript).new()
	raiz.add_child(_memoria)
	_memoria.establecer("agente", _agente)
	_memoria.establecer("objetivo", _objetivo)

	_condicion = (load(
		"res://componentes/arbol_comportamiento/utilidades/condiciones/CondicionObjetivoSinHabilidades.gd"
	) as GDScript).new()
	_condicion.umbral_melee = UMBRAL
	raiz.add_child(_condicion)
	_condicion.inicializar(_memoria)


func _informar() -> bool:
	var exito := _cerca_sin_habilidades_exitoso and _cerca_con_habilidad_libre_fallido \
		and _lejos_sin_habilidades_fallido and _lejos_con_habilidad_libre_fallido
	print("PRUEBA CONDICION CASTIGO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
