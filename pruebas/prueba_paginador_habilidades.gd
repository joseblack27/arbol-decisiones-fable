# =============================================================================
# Prueba de PaginadorHabilidades + UIHabilidad.cambiar_slot():
#   1. Arranca en página 1: los 5 botones muestran slot_index 0..4.
#   2. TODAS las señales slot_0.._9 (apunte/lanzar/cancelar/activar) ya
#      están registradas DESDE EL ARRANQUE, aunque nadie haya visitado la
#      página 2 todavía — sin esto, Jugador/IndicadorApunte (que escuchan
#      los 10 slots completos apenas aparecen) fallaban en silencio al
#      conectarse a los de la página 2 ("Señal 'slot_5_activar' no esta
#      registrada" reportado en juego real), y esas habilidades quedaban
#      sordas para siempre aunque después sí cambiaras de página.
#   3. Al presionar el paginador, pasa a página 2: slot_index 5..9.
#   4. Presionar de nuevo vuelve a la página 1 (ciclo).
#   godot --headless --path . --script res://pruebas/prueba_paginador_habilidades.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _botones: Array = []
var _paginador: Button
var _registro_temprano_ok := false
var _pagina1_ok := false
var _pagina2_ok := false
var _vuelta_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Todavía NO se presionó el paginador ni una vez — la página 2
			# nunca fue "visitada", pero sus señales ya deben existir.
			var señal_manager := root.get_node("/root/SeñalManager")
			var todas_registradas := true
			for i in 10:
				for sufijo in ["apunte", "lanzar", "cancelar", "activar"]:
					if not señal_manager.registros.has("slot_%d_%s" % [i, sufijo]):
						todas_registradas = false
						print("  falta registrar: slot_%d_%s" % [i, sufijo])
			_registro_temprano_ok = todas_registradas
			print("Señales de los 10 slots registradas desde el arranque (esperado true): %s" % _registro_temprano_ok)
		3:
			var indices_pagina_1: Array = _indices_actuales()
			print("Página 1 (esperado [0,1,2,3,4]): %s" % [indices_pagina_1])
			_pagina1_ok = indices_pagina_1 == [0, 1, 2, 3, 4]
			_paginador.call("_siguiente_pagina")  # ya no via pressed: el paginador escucha toques crudos (multitouch)
		5:
			var indices_pagina_2: Array = _indices_actuales()
			print("Página 2 (esperado [5,6,7,8,9]): %s" % [indices_pagina_2])
			_pagina2_ok = indices_pagina_2 == [5, 6, 7, 8, 9]
			_paginador.call("_siguiente_pagina")  # ya no via pressed: el paginador escucha toques crudos (multitouch)
		7:
			var indices_vuelta: Array = _indices_actuales()
			print("Vuelta a página 1 (esperado [0,1,2,3,4]): %s" % [indices_vuelta])
			_vuelta_ok = indices_vuelta == [0, 1, 2, 3, 4]
			return _informar()
	return false


func _indices_actuales() -> Array:
	var out := []
	for b in _botones:
		out.append(b.slot_index)
	return out


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	var contenedor_control := Control.new()
	escena.add_child(contenedor_control)

	var guion_uih := load("res://escenas/ui/ui_habilidad/UIHabilidad.tscn") as PackedScene
	for i in 5:
		var boton := guion_uih.instantiate()
		boton.name = "UIHabilidadSlot%d" % i
		boton.slot_index = i
		contenedor_control.add_child(boton)
		_botones.append(boton)

	_paginador = Button.new()
	_paginador.name = "PaginadorHabilidades"
	var guion_pag := load("res://escenas/ui/ui_habilidad/PaginadorHabilidades.gd") as GDScript
	_paginador.set_script(guion_pag)
	var rutas: Array[NodePath] = []
	for i in 5:
		rutas.append(NodePath("../UIHabilidadSlot%d" % i))
	_paginador.set("rutas_botones", rutas)
	_paginador.set("total_paginas", 2)
	contenedor_control.add_child(_paginador)


func _informar() -> bool:
	var exito := _registro_temprano_ok and _pagina1_ok and _pagina2_ok and _vuelta_ok
	print("PRUEBA PAGINADOR HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
