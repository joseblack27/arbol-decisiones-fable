# =============================================================================
# Prueba: los MÁXIMOS de vida y energía derivados del nivel llegan enteros al
# jugador autoritativo del servidor, y el cliente no puede mostrar un techo
# que el servidor no respete.
#
# Bug que motiva esta prueba (reportado: "la energía sólo sube hasta 105 de
# 200 que me muestra el UI que puedo llegar y me descuenta la adrenalina",
# "la vida igual"): al reconectar, GestorGuardado le manda al servidor la XP
# guardada para que ExperienciaComponente.restaurar_xp() reconstruya
# vida_maxima/energia_maxima del nivel real. Ese RPC estaba METIDO DENTRO del
# "if hay posición guardada y no se está mudando de nivel", así que cualquiera
# que se desconectara fuera del nivel inicial volvía con un servidor
# convencido de que era nivel 1: la jeringa de adrenalina llegaba, se
# descontaba, y agregar_energia() la clampeaba contra un máximo de 100.
#
# Cubre tres cosas:
#   1. restaurar_xp() reconstruye los máximos del nivel (lo que el servidor
#      hace al recibir la XP del cliente).
#   2. Con esos máximos, una jeringa de 50 SÍ sube la energía por encima de
#      100 — el síntoma exacto que se reportó.
#   3. La réplica de energía viaja con su máximo, para que la barra del
#      cliente no pueda quedar mostrando un techo distinto al del servidor.
#   4. El RPC de restauración de estado NO está anidado bajo la condición de
#      posición/mudanza (la regresión concreta).
#   godot --headless --path . --script res://pruebas/prueba_maximos_por_nivel.gd
# =============================================================================
# Sin tipos estáticos hacia clases del juego: en modo --script se compilarían
# antes de que existan los autoloads que usan. Mismo criterio que
# prueba_curacion_al_subir_nivel.
extends SceneTree

## XP acumulada para estar en nivel 6 (curva triangular: 100*5*6/2).
const XP_NIVEL_6 := 1500
const VIDA_ESPERADA := 150.0     # 100 + 10 por cada uno de los 5 niveles
const ENERGIA_ESPERADA := 125.0  # 100 + 5 por cada uno de los 5 niveles

var _fotogramas := 0
var _jugador: CharacterBody2D
var _vida
var _energia
var _experiencia

var _maximos_ok := false
var _jeringa_ok := false
var _replica_ok := false
var _rpc_incondicional_ok := false
var _servidor_solo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_probar_maximos()
			_probar_jeringa()
			_probar_replica_maxima()
			_rpc_incondicional_ok = _probar_rpc_incondicional()
			_probar_restauracion_del_servidor()
		4:
			return _informar()
	return false


## Lo importante de verdad: el SERVIDOR reconstruye los máximos por su cuenta
## desde el JSON guardado, sin depender de que el cliente se los mande. Un APK
## viejo contra un servidor nuevo no manda nada, y así el jugador quedaba
## eternamente en nivel 1 (vida 100) por más que el servidor estuviera
## parchado — que es como siguió fallando después del primer arreglo.
func _probar_restauracion_del_servidor() -> void:
	var otro := CharacterBody2D.new()
	otro.add_to_group("jugadores")
	root.add_child(otro)
	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 100.0
	vida.intervalo_regeneracion = 0.0
	otro.add_child(vida)
	var energia = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	energia.name = "EnergiaComponente"
	energia.energia_maxima = 100.0
	energia.intervalo_regeneracion = 9999.0
	otro.add_child(energia)
	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	otro.add_child(experiencia)

	var texto := JSON.stringify({
		"xp_total": XP_NIVEL_6,
		"jugador": {"vida_actual": 42.0},
	})
	var guardado = root.get_node("/root/GestorGuardado")
	guardado._restaurar_estado_autoritativo(otro, texto)

	var vida_max: float = vida.obtener_vida_maxima()
	var energia_max: float = energia.obtener_energia_maxima()
	var vida_actual: float = vida.obtener_vida()
	print("Servidor solo — nivel (esperado 6): %d" % experiencia.nivel)
	print("Servidor solo — vida (esperado 42 de %.0f): %.0f / %.0f" % [
		VIDA_ESPERADA, vida_actual, vida_max])
	print("Servidor solo — energía máxima (esperado %.0f): %.0f" % [
		ENERGIA_ESPERADA, energia_max])
	_servidor_solo_ok = experiencia.nivel == 6 \
		and is_equal_approx(vida_max, VIDA_ESPERADA) \
		and is_equal_approx(energia_max, ENERGIA_ESPERADA) \
		and is_equal_approx(vida_actual, 42.0)


## Lo que corre en el SERVIDOR al recibir la XP guardada del cliente.
func _probar_maximos() -> void:
	_experiencia.restaurar_xp(XP_NIVEL_6)
	var vida_max: float = _vida.obtener_vida_maxima()
	var energia_max: float = _energia.obtener_energia_maxima()
	print("Nivel restaurado (esperado 6): %d" % _experiencia.nivel)
	print("Vida máxima (esperado %.0f): %.0f" % [VIDA_ESPERADA, vida_max])
	print("Energía máxima (esperado %.0f): %.0f" % [ENERGIA_ESPERADA, energia_max])
	_maximos_ok = _experiencia.nivel == 6 \
		and is_equal_approx(vida_max, VIDA_ESPERADA) \
		and is_equal_approx(energia_max, ENERGIA_ESPERADA)


## El síntoma tal cual lo describió el usuario: gastar energía y usar la
## jeringa de adrenalina (50 puntos) tiene que pasar de 100.
func _probar_jeringa() -> void:
	_energia.consumir(_energia.obtener_energia_maxima())
	_energia.agregar_energia(80.0)
	var antes: float = _energia.obtener_energia()
	_energia.agregar_energia(50.0)  # jeringa_adrenalina.tres
	var despues: float = _energia.obtener_energia()
	print("Energía tras la jeringa (esperado %.0f, antes %.0f): %.0f" % [
		ENERGIA_ESPERADA, antes, despues])
	_jeringa_ok = despues > 100.0 and is_equal_approx(despues, ENERGIA_ESPERADA)


## La réplica del servidor lleva el máximo: un cliente cuyo componente tenga
## otro techo lo adopta en vez de clampear contra el suyo y mostrar un número
## que el servidor nunca va a alcanzar.
func _probar_replica_maxima() -> void:
	var espejo = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	espejo.name = "EspejoCliente"
	espejo.energia_maxima = 200.0
	_jugador.add_child(espejo)
	espejo._recibir_energia_red(105.0, 125.0)
	var max_espejo: float = espejo.obtener_energia_maxima()
	var val_espejo: float = espejo.obtener_energia()
	print("Máximo del cliente tras la réplica (esperado 125, tenía 200): %.0f" % max_espejo)
	_replica_ok = is_equal_approx(max_espejo, 125.0) and is_equal_approx(val_espejo, 105.0)


## El RPC que restaura XP/vida en el servidor tiene que salir SIEMPRE, no
## sólo cuando hay posición guardada y no hay mudanza de nivel. Se comprueba
## por la INDENTACIÓN: al mismo nivel que el cuerpo de la función (un tabulador)
## significa incondicional; más adentro significa que volvió a quedar anidado
## bajo un "if", que es exactamente cómo apareció el bug.
func _probar_rpc_incondicional() -> bool:
	var archivo := FileAccess.open("res://autoloads/GestorGuardado.gd", FileAccess.READ)
	if archivo == null:
		print("No se pudo abrir GestorGuardado.gd")
		return false
	var encontrado := false
	var incondicional := false
	while not archivo.eof_reached():
		var linea := archivo.get_line()
		if not linea.contains("rpc_id(1, \"_aplicar_estado_red\""):
			continue
		encontrado = true
		var sangria := linea.length() - linea.lstrip("\t").length()
		print("Sangría del rpc_id de _aplicar_estado_red (esperado 1 tab): %d" % sangria)
		incondicional = sangria == 1
	archivo.close()
	if not encontrado:
		print("No se encontró la llamada rpc_id a _aplicar_estado_red")
	return encontrado and incondicional


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	_vida.intervalo_regeneracion = 0.0
	_jugador.add_child(_vida)

	_energia = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	_energia.name = "EnergiaComponente"
	_energia.energia_maxima = 100.0
	# Sin ticks de regeneración: acá se mide lo que agrega la jeringa, no lo
	# que devuelve el tiempo.
	_energia.intervalo_regeneracion = 9999.0
	_jugador.add_child(_energia)

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_jugador.add_child(_experiencia)


func _informar() -> bool:
	var exito := _maximos_ok and _jeringa_ok and _replica_ok \
		and _rpc_incondicional_ok and _servidor_solo_ok
	print("  máximos por nivel: %s" % _maximos_ok)
	print("  jeringa pasa de 100: %s" % _jeringa_ok)
	print("  la réplica trae el máximo: %s" % _replica_ok)
	print("  el RPC de estado sale siempre: %s" % _rpc_incondicional_ok)
	print("  el servidor restaura sin el cliente: %s" % _servidor_solo_ok)
	print("PRUEBA MAXIMOS POR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
