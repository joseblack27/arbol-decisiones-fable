# =============================================================================
# Prueba de SpawnerMobs:
#   1. cantidad_inicial genera de golpe al arrancar (y SOLO esa cantidad).
#   2. Respeta maximo_mobs: nunca sobrepasa el tope aunque pasen muchos
#      intervalos de generación.
#   3. Al morir uno, se libera un hueco y el spawner genera otro para
#      volver a llenarlo (tree_exiting -> bookkeeping de _vivos) — y se
#      queda en el tope, sin seguir generando de más.
#
# Estructura por FASES guiadas por condición (no por números de fotograma
# fijos): la versión anterior comprobaba la generación inicial en el
# fotograma 2 exacto y el rellenado en el 420 exacto, pero la generación
# inicial espera un physics_frame (sincronización de navegación) que a veces
# tarda un fotograma más, y el desvanecido de muerte no dura siempre lo
# mismo — fallaba de forma intermitente (~1 de cada 10-20 corridas) sin que
# hubiera ningún bug real en el spawner.
#   godot --headless --path . --script res://pruebas/prueba_spawner_mobs.gd
# =============================================================================
extends SceneTree

# 2 segundos simulados: tope generoso para esperas que en la práctica toman
# 1-3 fotogramas (physics_frame de navegación); si se agota, ESO sí es un
# fallo real del spawner, no timing de la prueba.
const MARGEN_ESPERA_INICIAL := 120
# El desvanecido de muerte dura ~0.8s en dos etapas (margen real observado
# ~2s) + el intervalo de spawn para rellenar: 10 s simulados de tope.
const MARGEN_ESPERA_RELLENO := 600
# 0.5s ≈ 10 intervalos de spawn (0.05s): si el spawner estuviera generando
# de más tras rellenar, en este lapso se pasaría del tope seguro.
const FOTOGRAMAS_CONFIRMACION_TOPE := 30

var _fotogramas := 0
# Sin tipar como SpawnerMobs: ese script referencia el autoload Utils
# (en_red()), y el análisis estático del --script de esta prueba lo
# compilaría antes de que los autoloads existan (mismo artefacto de
# siempre, ver otras pruebas).
var _spawner
var _contenedor: Node2D

var _fase := "esperando_inicial"
var _fotograma_referencia := 0
var _genero_inicial := false
var _maximo_observado := 0
var _relleno_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_fotograma_referencia = _fotogramas
		return false

	match _fase:
		"esperando_inicial":
			# Éxito: en el PRIMER fotograma con algo vivo debe haber
			# EXACTAMENTE cantidad_inicial (1) — ni cero ni un ciclo extra.
			if _spawner.cantidad_viva() > 0:
				_genero_inicial = _spawner.cantidad_viva() == 1
				print("Generó la cantidad_inicial (1) apenas arrancó: %s (vivos=%d, fotograma %d)" % [
					_genero_inicial, _spawner.cantidad_viva(), _fotogramas,
				])
				_cambiar_fase("llenando")
			elif _fotogramas - _fotograma_referencia > MARGEN_ESPERA_INICIAL:
				print("La generación inicial nunca ocurrió (vivos=0 tras %d fotogramas)" % MARGEN_ESPERA_INICIAL)
				_cambiar_fase("llenando")

		"llenando":
			# Con intervalo 0.05s durante ~3s simulados, de sobra para llenar
			# el tope (2) muchas veces si no se respetara el máximo.
			if _fotogramas - _fotograma_referencia >= 200:
				_maximo_observado = _spawner.cantidad_viva()
				print("Vivos tras dar tiempo de sobra (esperado <= 2): %d" % _maximo_observado)
				_matar_uno()
				_cambiar_fase("rellenando")

		"rellenando":
			# Éxito apenas el hueco quede rellenado — sin fijar cuándo exacto
			# (el desvanecido del muerto no dura siempre lo mismo).
			if _spawner.cantidad_viva() >= 2:
				print("Hueco rellenado (vivos=%d) tras %d fotogramas" % [
					_spawner.cantidad_viva(), _fotogramas - _fotograma_referencia,
				])
				_cambiar_fase("confirmando_tope")
			elif _fotogramas - _fotograma_referencia > MARGEN_ESPERA_RELLENO:
				print("El spawner nunca rellenó el hueco (vivos=%d tras %d fotogramas)" % [
					_spawner.cantidad_viva(), MARGEN_ESPERA_RELLENO,
				])
				_relleno_ok = false
				return _informar()

		"confirmando_tope":
			# Tras rellenar, debe QUEDARSE en 2 — si siguiera generando, en
			# ~10 intervalos de spawn ya se habría pasado del tope.
			if _fotogramas - _fotograma_referencia >= FOTOGRAMAS_CONFIRMACION_TOPE:
				var vivos: int = _spawner.cantidad_viva()
				_relleno_ok = vivos == 2
				print("cantidad_viva() estable tras rellenar (esperado 2): %d" % vivos)
				return _informar()
	return false


func _cambiar_fase(fase: String) -> void:
	_fase = fase
	_fotograma_referencia = _fotogramas


func _montar() -> void:
	_contenedor = Node2D.new()
	root.add_child(_contenedor)
	current_scene = _contenedor

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	# Con _spawner sin tipar, una asignación directa de array literal no
	# arma un Array[PackedScene] de verdad — Godot rechaza en runtime
	# guardar un Array genérico en una propiedad @export tipada.
	var mobs: Array[PackedScene] = [load("res://escenas/enemigos/EnemigoRaton.tscn")]
	_spawner.lista_mobs = mobs
	_spawner.maximo_mobs = 2
	_spawner.intervalo_spawn = 0.05
	_spawner.radio_spawn = 10.0
	_spawner.cantidad_inicial = 1
	_contenedor.add_child(_spawner)


func _matar_uno() -> void:
	var candidatos: Array[Node] = _contenedor.get_children().filter(
		func(n: Node) -> bool: return n != _spawner
	)
	var mob: Node = candidatos[0]
	# Sin tipar como VidaComponente por el mismo motivo de arriba (ese
	# script también referencia Utils.en_red() ahora).
	var vida = mob.get_node("VidaComponente")
	vida.quitar_vida(9999.0)


func _informar() -> bool:
	var exito := _genero_inicial and _maximo_observado <= 2 and _relleno_ok
	print("PRUEBA SPAWNER MOBS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
