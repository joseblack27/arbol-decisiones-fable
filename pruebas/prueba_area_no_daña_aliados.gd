# =============================================================================
# Prueba: AreaEfecto (AoE, p. ej. la explosión de bola de fuego) NO debe
# dañar a los aliados de quien la lanza — ni entre jugadores ni entre mobs
# ("las habilidades lanzadas por jugadores no pueden pegarle a los demás
# jugadores... y lo mismo pasa con el enemigo"). Antes usaba
# respetar_equipo=false y golpeaba a todo lo que pisara.
#   godot --headless --path . --script res://pruebas/prueba_area_no_daña_aliados.gd
# =============================================================================
extends SceneTree

# Sin tipos estáticos hacia clases del juego (VidaComponente, AreaEfecto...):
# en modo --script se compilan ANTES de que existan los autoloads que usan
# (Utils, GestorPiscinas) y revienta la compilación — mismo motivo por el que
# las demás pruebas usan load() en runtime y variables sin tipar.
var _fotogramas := 0
var _lanzador: CharacterBody2D
var _jugador_aliado: CharacterBody2D
var _enemigo: CharacterBody2D
var _vida_aliado: Node
var _vida_enemigo: Node
var _area


## Combate.golpear_area solo considera objetivo válido a un collider que sea
## VidaComponente o exponga quitar_vida() él mismo (mismo criterio que
## Enemigo.gd/Jugador.gd reales, que reenvían a su VidaComponente) — un
## CharacterBody2D pelado no alcanza (mismo patrón que la prueba del dash).
static func _script_quitar_vida() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
func quitar_vida(cantidad: float, fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	var vida := get_node_or_null("VidaComponente")
	if vida:
		vida.quitar_vida(cantidad, fuente)
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			# Recién acá: los cuerpos creados en _montar() necesitan unos
			# fotogramas para registrarse en el servidor de física — activar
			# el AoE en el mismo fotograma daba una query vacía (nadie
			# recibía daño, ni siquiera el enemigo).
			_area.configurar(25.0, _lanzador)
		30:
			return _informar()
	return false


func _crear_cuerpo(grupo: String, posicion: Vector2, padre: Node) -> CharacterBody2D:
	var cuerpo := CharacterBody2D.new()
	cuerpo.set_script(_script_quitar_vida())
	cuerpo.add_to_group(grupo)
	cuerpo.global_position = posicion
	padre.add_child(cuerpo)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 12.0
	forma.shape = circulo
	cuerpo.add_child(forma)
	return cuerpo


func _agregar_vida(cuerpo: CharacterBody2D) -> Node:
	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 100.0
	cuerpo.add_child(vida)
	vida.restaurar_vida(100.0)
	return vida


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	# Jugador que lanza el AoE, con un jugador aliado Y un enemigo, ambos
	# dentro del radio de la explosión.
	_lanzador = _crear_cuerpo("jugadores", Vector2.ZERO, escena)
	_jugador_aliado = _crear_cuerpo("jugadores", Vector2(30, 0), escena)
	_vida_aliado = _agregar_vida(_jugador_aliado)
	_enemigo = _crear_cuerpo("enemigos", Vector2(-30, 0), escena)
	_vida_enemigo = _agregar_vida(_enemigo)

	_area = (load("res://escenas/habilidades/area_efecto/AreaEfecto.tscn") as PackedScene).instantiate()
	_area.global_position = Vector2.ZERO
	escena.add_child(_area)


func _informar() -> bool:
	var vida_aliado: float = _vida_aliado.obtener_vida()
	var vida_enemigo: float = _vida_enemigo.obtener_vida()
	print("Vida del jugador aliado tras el AoE (esperado 100, SIN daño): %.0f" % vida_aliado)
	print("Vida del enemigo tras el AoE (esperado < 100, SÍ con daño): %.0f" % vida_enemigo)
	var aliado_ok := is_equal_approx(vida_aliado, 100.0)
	var enemigo_ok := vida_enemigo < 100.0
	var exito := aliado_ok and enemigo_ok
	print("PRUEBA AREA NO DAÑA ALIADOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
