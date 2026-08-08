# =============================================================================
# Prueba ABREVIADA del esqueleto mínimo de EnemigoArañaReina (solo fase 1 +
# rama de Castigo) — la prueba de integración completa de las 3 fases vive
# en prueba_arana_reina_fases.gd, más adelante en el plan.
#
# Verifica:
#   1. La escena carga e instancia sin errores, con la vida/kit de un boss
#      (mucho más vida que una Araña normal, Arañazo + Bola de Telaraña).
#   2. Si el jugador está en rango melee y TODAS sus habilidades están en
#      recarga, la reina dispara el Golpe de Castigo (rama nueva del BT).
#   3. Si el jugador tiene alguna habilidad libre, el Castigo NO se dispara.
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_esqueleto.gd
# =============================================================================
extends SceneTree

var _f := 0
var _reina
var _jugador
var _castigo

var _carga_bien := false
var _vida_de_jefe := false
var _tiene_kit_base := false
var _castiga_si_indefenso := false
var _no_castiga_si_tiene_libre := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar_caso_indefenso()
		120:
			_castiga_si_indefenso = _castigo._recarga_restante > 0.0
			print("Castiga al jugador indefenso en rango (esperado true): %s" % _castiga_si_indefenso)
			_limpiar()
			_montar_caso_con_libre()
		240:
			_no_castiga_si_tiene_libre = _castigo._recarga_restante <= 0.0
			print("NO castiga si el jugador tiene una habilidad libre (esperado true): %s" % \
				_no_castiga_si_tiene_libre)
			return _informar()
	return false


func _montar_caso_indefenso() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_reina := load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene
	_reina = escena_reina.instantiate()
	raiz.add_child(_reina)
	_reina.global_position = Vector2.ZERO

	_carga_bien = is_instance_valid(_reina)
	print("La escena carga e instancia (esperado true): %s" % _carga_bien)

	var datos = _reina.get("datos")
	_vida_de_jefe = datos != null and datos.vida_maxima > 500.0
	print("Tiene vida de boss (esperado >500, %.0f): %s" % [
		datos.vida_maxima if datos else 0.0, _vida_de_jefe])

	var hab_arañazo = _reina.get_node_or_null("Habilidades/HabilidadArañazo")
	var hab_telaraña = _reina.get_node_or_null("Habilidades/HabilidadProyectilBolaTelaraña")
	_tiene_kit_base = hab_arañazo != null and hab_telaraña != null
	print("Tiene el kit base Arañazo+Telaraña (esperado true): %s" % _tiene_kit_base)

	_castigo = _reina.get_node("Habilidades/HabilidadGolpeCastigo")

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(50, 0)  # dentro del umbral melee (90px)

	# Todo Jugador arranca con TIEMPO_INVULNERABILIDAD_APARICION (3s) de
	# protección de aparición (ver Jugador._ready()) — mientras dura, ningún
	# mob lo detecta (a propósito, ver VisionComponente._es_objetivo_valido).
	# Sin esto, la reina nunca vería al jugador dentro de la prueba.
	_jugador.get_node("VidaComponente")._invulnerable_restante = 0.0

	var slots = _jugador.get_node("SlotHabilidades")
	var datos_hab = load("res://recursos/habilidades/golpe_basico.tres")
	slots.equipar(0, datos_hab)
	slots.equipar(1, datos_hab)
	# Todas en recarga: el jugador está indefenso.
	slots.obtener(0)._recarga_restante = 5.0
	slots.obtener(1)._recarga_restante = 5.0


func _montar_caso_con_libre() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_reina := load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene
	_reina = escena_reina.instantiate()
	raiz.add_child(_reina)
	_reina.global_position = Vector2.ZERO
	_castigo = _reina.get_node("Habilidades/HabilidadGolpeCastigo")

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(50, 0)
	_jugador.get_node("VidaComponente")._invulnerable_restante = 0.0

	var slots = _jugador.get_node("SlotHabilidades")
	var datos_hab = load("res://recursos/habilidades/golpe_basico.tres")
	slots.equipar(0, datos_hab)
	slots.equipar(1, datos_hab)
	# Una libre (slot 0 sin recarga): NO está indefenso.
	slots.obtener(0)._recarga_restante = 0.0
	slots.obtener(1)._recarga_restante = 5.0


func _limpiar() -> void:
	current_scene.queue_free()


func _informar() -> bool:
	var exito := _carga_bien and _vida_de_jefe and _tiene_kit_base \
		and _castiga_si_indefenso and _no_castiga_si_tiene_libre
	print("PRUEBA ARAÑA REINA ESQUELETO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
