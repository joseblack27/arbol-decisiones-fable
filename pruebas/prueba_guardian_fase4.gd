# =============================================================================
# Prueba de fase 4 ("Quiebre") del Guardián Quebrado:
#   1. HabilidadMiedoGuardian empuja (MovimientoComponente.aplicar_empuje) y
#      aturde (EfectoAturdir) a un objetivo cercano.
#   2. HabilidadArremetidaGuardian conecta daño VERDADERO (ignora_defensa=
#      true) durante el dash real — con un objetivo de defensa alta, el
#      daño tiene que pasar casi entero, igual que HabilidadCorte.
#   3. Al cruzar el umbral de fase 4 (25% de vida), se invocan refuerzos
#      (Lobo/Araña) reales bajo el mismo contenedor que el jefe, y el
#      SelectorHabilidades principal suma arremetida/miedo.
#
# Sin tipos estáticos hacia clases nuevas del jefe en el TOP-LEVEL del
# script (ver cabecera de prueba_area_no_daña_aliados.gd).
#   godot --headless --path . --script res://pruebas/prueba_guardian_fase4.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _vida_antes_arremetida := 0.0

var _miedo_aturde_ok := false
var _arremetida_dano_ok := false
var _fase4_refuerzos_ok := false
var _fase4_agrega_habilidades_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_miedo()
		6:
			_probar_miedo_resultado()
			_vida_antes_arremetida = _vida_jugador.salud_actual
			var arremetida = _jefe.get_node("Habilidades/HabilidadArremetidaGuardian")
			arremetida.activar(Vector2.RIGHT, 1.0)
		120:
			# 0.6s de preparación + margen de sobra para que el dash real
			# recorra los 60px hasta el jugador (ver _montar, jugador a la
			# derecha, en línea recta con la arremetida).
			_probar_arremetida()
			_disparar_transicion_fase2()
		500:
			_disparar_transicion_fase3()
		1000:
			_disparar_transicion_fase4()
		1500:
			_probar_transicion_fase4()
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

	var atributos = _jugador.get_node_or_null("AtributosComponente")
	if atributos and atributos.base:
		atributos.base.defensa = 500.0
		atributos.base.resistencia_fisica = 80.0

	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _probar_miedo() -> void:
	var miedo = _jefe.get_node("Habilidades/HabilidadMiedoGuardian")
	miedo.activar(Vector2.ZERO, 1.0)


## El empuje (aplicar_empuje) no tiene un getter público de "está empujado
## ahora mismo" para verificar aparte — MovimientoComponente.aplicar_empuje
## ya es API pública ya usada/probada en otras habilidades (ver la cabecera
## de esta prueba); lo que sí es nuevo y observable acá es el aturdimiento.
func _probar_miedo_resultado() -> void:
	var tiene_aturdido := false
	for hijo in _jugador.get_children():
		var script: Script = hijo.get_script()
		if script and script.resource_path.ends_with("EfectoAturdir.gd"):
			tiene_aturdido = true
			break
	_miedo_aturde_ok = tiene_aturdido
	print("Miedo aturde al objetivo cercano (esperado true): %s" % _miedo_aturde_ok)


func _probar_arremetida() -> void:
	var perdida: float = _vida_antes_arremetida - _vida_jugador.salud_actual
	# Defensa 500 + resistencia física 80%: sin ignorar defensa, esto
	# reduciría un golpe de 45 prácticamente a 0 — con ignora_defensa=true
	# tiene que pasar casi entero, igual que ya se probó con HabilidadCorte
	# y GolpeVerdaderoGuardian.
	_arremetida_dano_ok = perdida >= 30.0
	print("Arremetida conecta daño verdadero real (esperado >= 30.0): %.1f" % perdida)


func _disparar_transicion_fase2() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	vida_jefe.quitar_vida(750.0)  # 2200 -> 1450 (0.659) -> cruza el umbral de fase 2 (0.75).


func _disparar_transicion_fase3() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	vida_jefe.quitar_vida(400.0)  # 1450 -> 1050 (0.477) -> cruza el umbral de fase 3 (0.50).


func _disparar_transicion_fase4() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	vida_jefe.quitar_vida(500.0)  # 1050 -> 550 (0.25) -> cruza el umbral de fase 4 (0.25).


func _probar_transicion_fase4() -> void:
	var contenedor = _jefe.get_parent()
	var refuerzos := 0
	for hijo in contenedor.get_children():
		if hijo == _jefe or hijo == _jugador:
			continue
		var script: Script = hijo.get_script()
		if script and (script.resource_path.ends_with("EnemigoLobo.gd") \
				or script.resource_path.ends_with("EnemigoAraña.gd")):
			refuerzos += 1
	_fase4_refuerzos_ok = refuerzos == 2
	print("Fase 4 invoca los 2 refuerzos (Lobo + Araña) (esperado true, encontrados=%d): %s" % [
		refuerzos, _fase4_refuerzos_ok])

	var selector = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	# 3 (fase1) + 2 (fase2) + 3 (fase3) + 2 (fase4: arremetida/miedo).
	var tamaño: int = selector.habilidades.size() if selector else -1
	_fase4_agrega_habilidades_ok = tamaño == 10
	print("Fase 4 suma arremetida y miedo al selector (esperado true, size=%d): %s" % [
		tamaño, _fase4_agrega_habilidades_ok])


func _informar() -> bool:
	var exito := _miedo_aturde_ok and _arremetida_dano_ok and _fase4_refuerzos_ok \
		and _fase4_agrega_habilidades_ok
	print("PRUEBA GUARDIAN FASE4 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
