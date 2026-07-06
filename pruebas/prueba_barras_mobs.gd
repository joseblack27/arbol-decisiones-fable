# =============================================================================
# Prueba de BarraVidaEnergiaComponente:
#   1. Al montar, la fracción de vida/energía arranca en 1.0 (llenas).
#   2. Al quitar vida, la fracción de la barra de vida baja acorde.
#   3. Al consumir energía, la fracción de la barra de energía baja acorde.
#   4. Un mob sin EnergiaComponente (ratón) no falla: simplemente no dibuja
#      esa segunda barra (_tiene_energia == false).
#   godot --headless --path . --script res://pruebas/prueba_barras_mobs.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: Node
var _raton: Node
var _barra_lobo: Node
var _barra_raton: Node
var _frac_vida_lobo: float
var _frac_energia_lobo: float


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			# BarraVidaEnergiaComponente espera un process_frame antes de leer
			# los valores iniciales (para no ganarle la carrera al _ready del
			# nodo raíz, que aplica EnemigoDatos); un fotograma después de
			# montar ya está lista.
			_frac_vida_lobo = _barra_lobo.get("_fraccion_vida")
			_frac_energia_lobo = _barra_lobo.get("_fraccion_energia")
		5:
			return _informar()
	return false


func _montar() -> void:
	_lobo = (load("res://enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_raton = (load("res://enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_raton)

	_barra_lobo = _lobo.get_node("BarraVidaEnergia")
	_barra_raton = _raton.get_node("BarraVidaEnergia")

	# Sin tipar como VidaComponente/EnergiaComponente: EnergiaComponente.gd
	# referencia BusEventos, y tiparlo estáticamente aquí forzaría compilarlo
	# antes de que los autoloads existan (mismo artefacto de --script de siempre).
	var vida_lobo: Node = _lobo.get_node("VidaComponente")
	vida_lobo.call("quitar_vida", vida_lobo.call("obtener_vida_maxima") * 0.5)

	var energia_lobo: Node = _lobo.get_node("EnergiaComponente")
	energia_lobo.call("consumir", energia_lobo.call("obtener_energia_maxima") * 0.25)


func _informar() -> bool:
	var frac_vida_lobo: float = _frac_vida_lobo
	var frac_energia_lobo: float = _frac_energia_lobo
	var tiene_energia_lobo: bool = _barra_lobo.get("_tiene_energia")
	var tiene_energia_raton: bool = _barra_raton.get("_tiene_energia")
	var frac_vida_raton: float = _barra_raton.get("_fraccion_vida")

	print("Lobo: fracción vida tras quitar 50%% (esperado ~0.5): %.2f" % frac_vida_lobo)
	print("Lobo: tiene barra de energía (esperado true): %s" % tiene_energia_lobo)
	print("Lobo: fracción energía tras consumir 25%% (esperado ~0.75): %.2f" % frac_energia_lobo)
	print("Ratón: tiene barra de energía (esperado false): %s" % tiene_energia_raton)
	print("Ratón: fracción vida intacta (esperado 1.0): %.2f" % frac_vida_raton)

	var exito := is_equal_approx(frac_vida_lobo, 0.5) \
		and tiene_energia_lobo and absf(frac_energia_lobo - 0.75) < 0.05 \
		and not tiene_energia_raton and is_equal_approx(frac_vida_raton, 1.0)
	print("PRUEBA BARRAS MOBS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
