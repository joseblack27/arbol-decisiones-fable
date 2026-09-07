# =============================================================================
# Prueba de HabilidadGolpeVampirico: AoE centrada en quien la usa (mismo
# patrón que Golpe Básico/Onda de Choque) que daña a TODOS los enemigos en
# el radio y cura a quien la usa un % del daño TOTAL infligido.
#
# Cambiado por pedido del usuario: antes pegaba solo al enemigo más cercano
# dentro de un alcance ("golpe_vampirico"); ahora es un área alrededor del
# jugador, "como golpe básico", conservando la ventaja del robo de vida.
#
# Verifica:
#   1. Golpea a TODOS los enemigos dentro del radio (no solo al más cercano).
#   2. Un enemigo FUERA del radio no recibe daño.
#   3. Un aliado (mismo equipo) dentro del radio no recibe daño (sin fuego amigo).
#   4. Se cura exactamente porcentaje_robo * daño TOTAL infligido (sumado
#      entre todos los golpeados, no por-golpe).
#   5. golpe_vampirico.tres REAL (no sintético) carga radio_golpe=60.0.
#   godot --headless --path . --script res://pruebas/prueba_golpe_vampirico.gd
# =============================================================================
extends SceneTree

var _jugador
var _vida_jugador
var _mob_cerca_a
var _mob_cerca_b
var _mob_lejos
var _aliado
var _habilidad
var _fotogramas := 0
## Ver el mismo comentario en prueba_vortice.gd: la consulta de daño ahora
## corre en _physics_process, así que hay que esperar a que AVANCE un
## fotograma físico real, no solo contar fotogramas idle de este script.
var _fisica_en_activacion := -1

var _vida_antes := 0.0
var _golpea_a_ambos_cercanos := false
var _no_golpea_al_lejano := false
var _aliado_sin_dano := false
var _se_cura_el_total_correcto := false
var _tres_real_carga_radio_correcto := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		_vida_jugador.quitar_vida(50.0)  # vida: 100 -> 50, para poder ver la curación subir.
		_vida_antes = _vida_jugador.obtener_vida()
		_habilidad._ejecutar(Vector2.ZERO, 1.0)
		_fisica_en_activacion = Engine.get_physics_frames()
		return false
	if _fotogramas > 2 and Engine.get_physics_frames() == _fisica_en_activacion:
		return false  # todavía no corrió ningún _physics_process nuevo.

	_golpea_a_ambos_cercanos = _mob_cerca_a.golpes == 1 and _mob_cerca_b.golpes == 1
	_no_golpea_al_lejano = _mob_lejos.golpes == 0
	_aliado_sin_dano = _aliado.golpes == 0
	print("Golpea a ambos mobs dentro del radio (esperado true): %s" % _golpea_a_ambos_cercanos)
	print("No golpea al mob fuera del radio (esperado true): %s" % _no_golpea_al_lejano)
	print("El aliado no recibe daño (esperado true): %s" % _aliado_sin_dano)

	# daño=10 por golpe (sin AtributosComponente en los mobs ni en el
	# jugador acá, calcular_pipeline devuelve el mismo valor de
	# entrada) * 2 golpeados = 20 de daño total * 0.5 de robo = 10.
	var vida_despues: float = _vida_jugador.obtener_vida()
	var curado: float = vida_despues - _vida_antes
	_se_cura_el_total_correcto = is_equal_approx(curado, 10.0)
	print("Se cura el 50%% del daño TOTAL infligido (esperado true, +10, real +%.1f): %s" % [
		curado, _se_cura_el_total_correcto])
	_probar_tres_real()
	return _informar()


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _crear_objetivo(pos: Vector2, grupo: String) -> Node:
	var obj := CharacterBody2D.new()
	obj.set_script(_script_objetivo())
	obj.add_to_group(grupo)
	obj.collision_layer = 2
	obj.global_position = pos
	root.add_child(obj)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	obj.add_child(forma)
	return obj


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)
	current_scene = _jugador  # AreaEfecto/GolpeVampirico no lo necesita, pero mantiene el patrón de las otras pruebas.

	_vida_jugador = VidaComponente.new()
	_vida_jugador.name = "VidaComponente"
	_vida_jugador.salud_maxima = 100.0
	_jugador.add_child(_vida_jugador)
	_vida_jugador.restaurar_vida(100.0)

	# Ambos DENTRO del radio (60px), a distinta distancia — así se prueba de
	# verdad "golpea a TODOS", no solo "al único en rango".
	_mob_cerca_a = _crear_objetivo(Vector2(30, 0), "enemigos")
	_mob_cerca_b = _crear_objetivo(Vector2(0, 45), "enemigos")
	_mob_lejos   = _crear_objetivo(Vector2(200, 0), "enemigos")
	_aliado      = _crear_objetivo(Vector2(-20, 0), "jugadores")

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/golpe_vampirico/HabilidadGolpeVampirico.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.daño = 10.0
	_habilidad.porcentaje_robo = 0.5
	_habilidad.radio_golpe = 60.0
	_habilidad.costo_energia = 0.0


func _probar_tres_real() -> void:
	var datos := load("res://recursos/habilidades/golpe_vampirico.tres") as DatosHabilidad
	var hab_suelta = (load("res://escenas/habilidades/golpe_vampirico/HabilidadGolpeVampirico.gd") as GDScript).new()
	hab_suelta.aplicar_datos(datos)
	_tres_real_carga_radio_correcto = is_equal_approx(hab_suelta.radio_golpe, 60.0)
	print("golpe_vampirico.tres real: radio_golpe=%.1f (esperado 60.0): %s" % [
		hab_suelta.radio_golpe, _tres_real_carga_radio_correcto])
	hab_suelta.free()


func _informar() -> bool:
	var exito := _golpea_a_ambos_cercanos and _no_golpea_al_lejano and _aliado_sin_dano \
		and _se_cura_el_total_correcto and _tres_real_carga_radio_correcto
	print("PRUEBA GOLPE VAMPIRICO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
