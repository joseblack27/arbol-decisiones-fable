# =============================================================================
# Prueba de integración de "Llamada de Auxilio" (ver HabilidadLlamadaAuxilio.gd
# y Enemigo.responder_llamada_auxilio() — la firma de la Reina de las
# Hormigas, pedida por el usuario: al activarse, TODA hormiga viva en el
# MISMO nivel abandona lo que esté haciendo -incluso pelear con un jugador
# cerca- y viaja directo hacia la reina, ignorando jugadores en el camino;
# solo vuelve a atacar al llegar. Una hormiga en OTRO nivel no se entera.
#   1. Activar la habilidad marca en_llamada_auxilio=true y destino_llamada
#      en la memoria de la hormiga del MISMO nivel (Hormiguero).
#   2. Una hormiga en OTRO nivel (Pradera) NO se entera.
#   3. Con un jugador pegado a la hormiga lejana (que sin la llamada activa
#      la atacaría), la hormiga camina hacia la reina en vez de acercarse al
#      jugador -- la distancia a la reina baja con los ticks del árbol.
#   4. Al llegar cerca de la reina, la bandera se apaga sola (vuelve a poder
#      atacar normal).
#   godot --headless --path . --script res://pruebas/prueba_reina_hormigas_llamada_auxilio.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _reina
var _hormiga_lejana
var _hormiga_otro_nivel
var _jugador

var _flag_activada_ok := false
var _destino_ok := false
var _otro_nivel_no_afectado_ok := false
var _se_acerco_a_la_reina_ok := false
var _flag_se_apaga_al_llegar_ok := false

var _distancia_inicial := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_activar_llamada()
		4:
			_verificar_activacion()
		220:
			_verificar_se_acerco()
			_forzar_llegada()
		230:
			return _informar()
	return false


func _montar() -> void:
	_hormiga_lejana = null

	var nivel_hormiguero := (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(nivel_hormiguero)
	current_scene = nivel_hormiguero
	var enemigos_hormiguero := nivel_hormiguero.get_node("Enemigos")

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	enemigos_hormiguero.add_child(_reina)
	_reina.global_position = nivel_hormiguero.get_node("PuntoAparicion").global_position
	_reina.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	_hormiga_lejana = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	enemigos_hormiguero.add_child(_hormiga_lejana)
	# Bien lejos de la reina (varias salas de distancia) y con un jugador
	# PEGADO -- sin la llamada activa, la detectaría y la atacaría en vez de
	# viajar hacia la reina.
	_hormiga_lejana.global_position = _reina.global_position + Vector2(900, 0)
	_distancia_inicial = _hormiga_lejana.global_position.distance_to(_reina.global_position)

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	enemigos_hormiguero.add_child(_jugador)
	_jugador.global_position = _hormiga_lejana.global_position + Vector2(20, 0)

	# Segundo nivel (Pradera) con OTRA hormiga -- no debe enterarse de nada:
	# la llamada es solo para el hormiguero.
	var nivel_pradera := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(nivel_pradera)
	_hormiga_otro_nivel = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	nivel_pradera.get_node("Enemigos").add_child(_hormiga_otro_nivel)
	_hormiga_otro_nivel.global_position = Vector2(200, 200)


func _activar_llamada() -> void:
	var llamada: Node = _reina.get_node("Habilidades/HabilidadLlamadaAuxilio")
	llamada.activar(Vector2.ZERO, 1.0)


func _verificar_activacion() -> void:
	var memoria_lejana: Node = _hormiga_lejana.get_node("ArbolComportamiento/MemoriaBT")
	var activa: bool = memoria_lejana.obtener("en_llamada_auxilio", false)
	var destino = memoria_lejana.obtener("destino_llamada", null)
	_flag_activada_ok = activa
	print("Hormiga lejana del MISMO nivel queda en_llamada_auxilio=true (esperado true): %s" % _flag_activada_ok)

	_destino_ok = destino is Vector2 and (destino as Vector2).distance_to(_reina.global_position) < 1.0
	print("destino_llamada apunta a la posición de la reina (esperado true): %s" % _destino_ok)

	var memoria_otro_nivel: Node = _hormiga_otro_nivel.get_node("ArbolComportamiento/MemoriaBT")
	_otro_nivel_no_afectado_ok = not memoria_otro_nivel.obtener("en_llamada_auxilio", false)
	print("Hormiga de OTRO nivel (Pradera) NO se entera (esperado true): %s" % _otro_nivel_no_afectado_ok)


func _verificar_se_acerco() -> void:
	var distancia_ahora: float = _hormiga_lejana.global_position.distance_to(_reina.global_position)
	_se_acerco_a_la_reina_ok = distancia_ahora < _distancia_inicial * 0.7
	print("Con un jugador pegado, la hormiga ignora y camina hacia la reina (esperado true, %.0f -> %.0f): %s" % [
		_distancia_inicial, distancia_ahora, _se_acerco_a_la_reina_ok])


## Teletransporta a la hormiga justo al lado de la reina para no depender de
## cuántos segundos reales de simulación hacen falta para cruzar 900px --
## sólo interesa confirmar que AL LLEGAR la bandera se apaga sola.
func _forzar_llegada() -> void:
	_hormiga_lejana.global_position = _reina.global_position + Vector2(30, 0)


func _informar() -> bool:
	var memoria_lejana: Node = _hormiga_lejana.get_node("ArbolComportamiento/MemoriaBT")
	_flag_se_apaga_al_llegar_ok = not memoria_lejana.obtener("en_llamada_auxilio", true)
	print("Al llegar cerca de la reina, en_llamada_auxilio se apaga sola (esperado true): %s" \
		% _flag_se_apaga_al_llegar_ok)

	var exito := _flag_activada_ok and _destino_ok and _otro_nivel_no_afectado_ok \
		and _se_acerco_a_la_reina_ok and _flag_se_apaga_al_llegar_ok
	print("PRUEBA REINA HORMIGAS LLAMADA DE AUXILIO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
