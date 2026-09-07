# =============================================================================
# Prueba de fase 3 ("Corrupción") del Guardián Quebrado:
#   1. GolpeCorruptoGuardian daña Y aplica un debuff (veneno o lentitud).
#   2. HabilidadMuroGuardian invoca un Muro real, con bloquea_enemigos=false
#      (decisión confirmada: zona de peligro, no pared física).
#   3. HabilidadEscudoReflectanteGuardian crea un EscudoReflectanteComponente
#      (no un EscudoComponente plano) al activarse.
#   4. Al cruzar el umbral de fase 3, el SelectorHabilidades principal suma
#      golpe corrupto/muro/escudo reflectante, y SelectorCastigo (la rama
#      de "leer el cooldown de Corte") pasa de vacío a tener 1 habilidad.
#
# Sin tipos estáticos hacia clases nuevas del jefe en el TOP-LEVEL del
# script (ver cabecera de prueba_area_no_daña_aliados.gd).
#   godot --headless --path . --script res://pruebas/prueba_guardian_fase3.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
## Ver el mismo comentario en prueba_vortice.gd: la consulta de daño de
## GolpeCorruptoGuardian ahora corre en _physics_process, así que hay que
## esperar a que AVANCE un fotograma físico real (no solo contar fotogramas
## idle) antes de leer el resultado.
var _antes_golpe_corrupto := 0.0
var _fisica_en_golpe_corrupto := -1
var _golpe_corrupto_verificado := false

var _golpe_corrupto_dano_ok := false
var _golpe_corrupto_debuff_ok := false
var _muro_aparece_ok := false
var _muro_no_bloquea_ok := false
var _escudo_es_reflectante_ok := false
var _fase3_agrega_habilidades_ok := false
var _fase3_activa_castigo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas > 5 and not _golpe_corrupto_verificado:
		if Engine.get_physics_frames() == _fisica_en_golpe_corrupto:
			return false  # todavía no corrió ningún _physics_process nuevo.
		_golpe_corrupto_verificado = true
		_probar_golpe_corrupto_resultado(_antes_golpe_corrupto)
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_golpe_corrupto()
			_probar_muro()
			_disparar_transicion_fase2()
		500:
			# Margen generoso: el jefe queda INVULNERABLE durante
			# pausa_cambio_fase (1.3s) al entrar en fase 2 — un segundo golpe
			# demasiado pronto queda absorbido en silencio por esa misma
			# invulnerabilidad (comportamiento correcto, ver VidaComponente
			# .quitar_vida) y _entrar_fase(3) nunca llega a dispararse.
			_disparar_transicion_fase3()
		900:
			# El escudo reflectante se prueba ACÁ, no antes: activarlo antes de
			# las transiciones bloqueaba el propio golpe de transición del
			# jefe contra sí mismo (100% de reducción con reduccion=1.0),
			# tapando en silencio el daño que dispara _on_vida_cambiada — no
			# es un bug del jefe, era orden equivocado en la prueba.
			_probar_escudo_reflectante()
			_probar_transicion_fase3()
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	# Apaga la IA autónoma — ver el mismo comentario en prueba_guardian_fase2.gd.
	_jefe.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	# Con la IA autónoma apagada (arriba), ya no hay quién detecte al
	# jugador por visión y llene "objetivo" solo — GolpeCorruptoGuardian lo
	# necesita para saber a quién aplicarle el debuff (el daño en sí llega
	# igual por overlap físico directo, por eso esto no se notaba en el
	# check de daño, solo en el de veneno/lentitud).
	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _probar_golpe_corrupto() -> void:
	var golpe = _jefe.get_node("Habilidades/HabilidadGolpeCorruptoGuardian")
	_antes_golpe_corrupto = _vida_jugador.salud_actual
	golpe.activar(Vector2.RIGHT, 1.0)
	# El daño de GolpeCorruptoGuardian se aplica en el próximo
	# _physics_process (igual que GolpeBasico/GolpeVerdaderoGuardian) — el
	# chequeo real ocurre en _process() una vez que Engine.get_physics_frames()
	# avanza, ver ahí.
	_fisica_en_golpe_corrupto = Engine.get_physics_frames()


func _probar_golpe_corrupto_resultado(antes: float) -> void:
	_golpe_corrupto_dano_ok = _vida_jugador.salud_actual < antes
	print("Golpe corrupto daña (esperado que baje de %.1f): %.1f" % [antes, _vida_jugador.salud_actual])

	var tiene_debuff := false
	for hijo in _jugador.get_children():
		var script: Script = hijo.get_script()
		if script and (script.resource_path.ends_with("EfectoVeneno.gd") \
				or script.resource_path.ends_with("EfectoLentitud.gd")):
			tiene_debuff = true
			break
	_golpe_corrupto_debuff_ok = tiene_debuff
	print("Golpe corrupto aplica veneno o lentitud (esperado true): %s" % _golpe_corrupto_debuff_ok)


func _probar_muro() -> void:
	var muro_hab = _jefe.get_node("Habilidades/HabilidadMuroGuardian")
	muro_hab.activar(Vector2.UP, 1.0)
	var piscinas := root.get_node("/root/GestorPiscinas")
	var encontrado := false
	for activo in piscinas.activos():
		var script = activo.get_script()
		if script and script.resource_path.ends_with("Muro.gd"):
			encontrado = true
			break
	_muro_aparece_ok = encontrado
	print("HabilidadMuroGuardian invoca un Muro real (esperado true): %s" % _muro_aparece_ok)
	# bloquea_enemigos=false es una const en el script — se verifica leyendo
	# la propia habilidad, más directo que inspeccionar el Muro instanciado.
	_muro_no_bloquea_ok = not muro_hab.bloquea_enemigos
	print("El muro del jefe NO bloquea físicamente (esperado true): %s" % _muro_no_bloquea_ok)


func _probar_escudo_reflectante() -> void:
	var escudo_hab = _jefe.get_node("Habilidades/HabilidadEscudoReflectanteGuardian")
	escudo_hab.activar(Vector2.ZERO, 1.0)
	var componente = _jefe.get_node_or_null("EscudoComponente")
	_escudo_es_reflectante_ok = componente != null and componente.get_script() != null \
		and componente.get_script().resource_path.ends_with("EscudoReflectanteComponente.gd")
	print("HabilidadEscudoReflectanteGuardian crea EscudoReflectanteComponente (esperado true): %s" % \
		_escudo_es_reflectante_ok)


func _disparar_transicion_fase2() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	vida_jefe.quitar_vida(750.0)  # 2200 -> 1450 (0.659) -> cruza el umbral de fase 2 (0.75).


func _disparar_transicion_fase3() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	vida_jefe.quitar_vida(400.0)  # 1450 -> 1050 (0.477) -> cruza el umbral de fase 3 (0.50).


func _probar_transicion_fase3() -> void:
	var selector = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	# 3 (fase1) + 2 (fase2) + 3 (fase3: corrupto/muro/escudo reflectante).
	var tamaño_selector: int = selector.habilidades.size() if selector else -1
	_fase3_agrega_habilidades_ok = tamaño_selector == 8
	print("Fase 3 suma golpe corrupto/muro/escudo reflectante (esperado true, size=%d): %s" % [
		tamaño_selector, _fase3_agrega_habilidades_ok])

	var selector_castigo = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/CastigoCorte/AtacarCastigo/SelectorCastigo")
	var tamaño_castigo: int = selector_castigo.habilidades.size() if selector_castigo else -1
	_fase3_activa_castigo_ok = tamaño_castigo == 1
	print("Fase 3 activa la rama de castigo por cooldown de Corte (esperado true, size=%d): %s" % [
		tamaño_castigo, _fase3_activa_castigo_ok])


func _informar() -> bool:
	var exito := _golpe_corrupto_dano_ok and _golpe_corrupto_debuff_ok and _muro_aparece_ok \
		and _muro_no_bloquea_ok and _escudo_es_reflectante_ok and _fase3_agrega_habilidades_ok \
		and _fase3_activa_castigo_ok
	print("PRUEBA GUARDIAN FASE3 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
