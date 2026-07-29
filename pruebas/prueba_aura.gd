# =============================================================================
# Prueba de HabilidadAura/AuraDanoComponente (sin red): activa un aura de
# daño alrededor de quien la usa — cualquier enemigo dentro del radio
# recibe daño cada segundo mientras dure, sin importar cuántas veces
# entre o salga (se recalcula de cero en cada tick, no es una foto fija
# del momento de activar).
#
# NOTA: sin "is AuraDanoComponente" en ningún lado — referenciar por tipo
# estático una clase recién creada en el propio script de entrada
# --script ya causó un cuelgue (prueba_ticket_consumible_xp.gd) y una
# falla de compilación (prueba_veneno.gd) en esta misma sesión. Todo acá
# se verifica por duck typing.
#
# Verifica:
#   1. Un enemigo YA dentro del radio al activar recibe daño en el tick.
#   2. Un enemigo FUERA del radio al activar no recibe nada.
#   3. Ese mismo enemigo, si CAMINA hacia adentro después, sí recibe daño
#      en un tick posterior — confirma que no es una foto fija inicial.
#   4. Pasada la duración, el aura se apaga sola (no tickea más).
#   godot --headless --path . --script res://pruebas/prueba_aura.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador
var _enemigo_cerca
var _enemigo_lejos
var _habilidad

var _dano_al_que_esta_cerca := false
var _sin_dano_al_que_esta_lejos := false
var _dano_al_que_camina_adentro := false
var _se_apaga_sola_al_vencer := false


static func _script_enemigo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_c: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _crear_enemigo(pos: Vector2) -> Node:
	var e := CharacterBody2D.new()
	e.set_script(_script_enemigo())
	e.add_to_group("enemigos")
	e.collision_layer = 2
	e.global_position = pos
	root.add_child(e)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	e.add_child(forma)
	return e


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_habilidad.activar(Vector2.ZERO, 1.0)
		15:
			# intervalo_tick=0.2s (~12 fotogramas) ya pasó de sobra: el
			# cercano debería haber recibido su primer tick.
			_dano_al_que_esta_cerca = _enemigo_cerca.golpes > 0
			print("Enemigo YA cerca recibe daño (esperado true, golpes=%d): %s" % [
				_enemigo_cerca.golpes, _dano_al_que_esta_cerca])
			_sin_dano_al_que_esta_lejos = _enemigo_lejos.golpes == 0
			print("Enemigo lejos NO recibe nada (esperado true, golpes=%d): %s" % [
				_enemigo_lejos.golpes, _sin_dano_al_que_esta_lejos])
			# Ahora lo acerco DESPUÉS de activar — si el aura fuera una foto
			# fija del momento de activar, esto nunca le pegaría.
			_enemigo_lejos.global_position = _jugador.global_position
		45:
			# Margen generoso (30 fotogramas = 0.5s desde que caminó adentro
			# en el frame 15, muy por encima de un intervalo_tick de 0.2s) y
			# bien lejos todavía de que venza duracion_aura=1.0s (~60
			# fotogramas) — nada de márgenes ajustados con la desactivación.
			_dano_al_que_camina_adentro = _enemigo_lejos.golpes > 0
			print("Enemigo que caminó adentro SÍ recibe daño después (esperado true, golpes=%d): %s" % [
				_enemigo_lejos.golpes, _dano_al_que_camina_adentro])
		90:
			# duracion_aura=1.0s (~60 fotogramas desde que se activó en el
			# frame 1) ya venció con margen de sobra.
			var comp = _jugador.get_node_or_null("AuraDanoComponente")
			_se_apaga_sola_al_vencer = comp == null or not comp.esta_activa()
			print("Aura se apaga sola al vencer la duración (esperado true): %s" % _se_apaga_sola_al_vencer)
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)

	_enemigo_cerca = _crear_enemigo(Vector2(15, 0))   # dentro del radio de prueba (25px).
	_enemigo_lejos = _crear_enemigo(Vector2(500, 0))  # bien fuera.

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/aura/HabilidadAura.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.radio = 25.0
	_habilidad.dano_por_tick = 6.0
	_habilidad.intervalo_tick = 0.2
	_habilidad.duracion_aura = 1.0
	_habilidad.costo_energia = 0.0
	_habilidad.duracion_recarga = 0.1
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador


func _informar() -> bool:
	var exito := _dano_al_que_esta_cerca and _sin_dano_al_que_esta_lejos \
		and _dano_al_que_camina_adentro and _se_apaga_sola_al_vencer
	print("PRUEBA AURA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
