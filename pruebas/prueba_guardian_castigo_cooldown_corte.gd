# =============================================================================
# Prueba: CondicionHabilidadObjetivoEnCooldown — la rama de "castigo" de la
# fase Corrupción del Guardián Quebrado solo debe activarse si el objetivo
# tiene Corte equipado Y está en cooldown ahora mismo.
#   godot --headless --path . --script res://pruebas/prueba_guardian_castigo_cooldown_corte.gd
# =============================================================================
extends SceneTree

var _objetivo
var _memoria
var _condicion
var _hab_corte
var _f := 0

var _en_cooldown_exitoso := false
var _disponible_fallido := false
var _sin_corte_fallido := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_hab_corte._recarga_restante = 2.0
			var r = _condicion.ejecutar()
			_en_cooldown_exitoso = r == NodoBT.Estado.EXITOSO
			print("A) Corte en cooldown -> EXITOSO (esperado true): %s" % _en_cooldown_exitoso)

			_hab_corte._recarga_restante = 0.0
			r = _condicion.ejecutar()
			_disponible_fallido = r == NodoBT.Estado.FALLIDO
			print("B) Corte disponible -> FALLIDO (esperado true): %s" % _disponible_fallido)

			var slots = _objetivo.get_node("SlotHabilidades")
			slots.equipar(0, null)
			r = _condicion.ejecutar()
			_sin_corte_fallido = r == NodoBT.Estado.FALLIDO
			print("C) sin Corte equipado -> FALLIDO (esperado true): %s" % _sin_corte_fallido)

			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_objetivo = escena_jugador.instantiate()
	_objetivo.name = "1"
	raiz.add_child(_objetivo)
	_objetivo.global_position = Vector2.ZERO

	var slots = _objetivo.get_node("SlotHabilidades")
	var datos = load("res://recursos/habilidades/corte.tres")
	slots.equipar(0, datos)
	_hab_corte = slots.obtener(0)

	_memoria = (load("res://componentes/arbol_comportamiento/MemoriaBT.gd") as GDScript).new()
	raiz.add_child(_memoria)
	_memoria.establecer("objetivo", _objetivo)

	_condicion = (load(
		"res://componentes/arbol_comportamiento/utilidades/condiciones/CondicionHabilidadObjetivoEnCooldown.gd"
	) as GDScript).new()
	raiz.add_child(_condicion)
	_condicion.inicializar(_memoria)


func _informar() -> bool:
	var exito := _en_cooldown_exitoso and _disponible_fallido and _sin_corte_fallido
	print("PRUEBA GUARDIAN CASTIGO COOLDOWN CORTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
