# =============================================================================
# Regresión: jitter_prioridad en SelectorHabilidades — pedido del usuario
# para el Guardián Quebrado ("una IA un poco más inteligente"): con varias
# habilidades de la MISMA prioridad disponibles a la vez, antes SIEMPRE
# elegía la misma (orden fijo del array), ahora con jitter_prioridad > 0
# varía entre corridas. jitter_prioridad = 0.0 (default) debe mantener el
# comportamiento EXACTO de siempre — no puede afectar a ningún mob
# existente que no lo configure.
#   godot --headless --path . --script res://pruebas/prueba_selector_habilidades_jitter.gd
# =============================================================================
extends SceneTree

var _sin_jitter_siempre_igual := false
var _con_jitter_varia := false


func _process(_delta: float) -> bool:
	_probar_sin_jitter()
	_probar_con_jitter()

	print("jitter_prioridad=0.0 elige siempre la misma (esperado true): %s" % _sin_jitter_siempre_igual)
	print("jitter_prioridad>0.0 varía entre corridas (esperado true): %s" % _con_jitter_varia)
	var exito := _sin_jitter_siempre_igual and _con_jitter_varia
	print("PRUEBA SELECTOR HABILIDADES JITTER %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _armar_selector(jitter: float) -> Node:
	var agente := Node2D.new()
	root.add_child(agente)
	var objetivo := Node2D.new()
	root.add_child(objetivo)
	objetivo.global_position = Vector2(10, 0)

	var memoria := MemoriaBT.new()
	memoria.establecer("agente", agente)
	memoria.establecer("objetivo", objetivo)

	var selector := SelectorHabilidades.new()
	selector.jitter_prioridad = jitter
	for i in 3:
		var h := HabilidadBT.new()
		h.nombre = "hab_%d" % i
		h.prioridad = 5
		h.rango_maximo = -1.0
		selector.habilidades.append(h)
	root.add_child(selector)
	selector.inicializar(memoria)
	return selector


func _probar_sin_jitter() -> void:
	var selector := _armar_selector(0.0)
	var elegido_inicial := ""
	_sin_jitter_siempre_igual = true
	for i in 20:
		selector.ejecutar()
		var elegido: String = selector._memoria.obtener("habilidad_activa")
		if i == 0:
			elegido_inicial = elegido
		elif elegido != elegido_inicial:
			_sin_jitter_siempre_igual = false


func _probar_con_jitter() -> void:
	var selector := _armar_selector(0.9)
	var vistos := {}
	for i in 60:
		selector.ejecutar()
		var elegido: String = selector._memoria.obtener("habilidad_activa")
		vistos[elegido] = true
	_con_jitter_varia = vistos.size() > 1
