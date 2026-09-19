# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "la
# segunda página de habilidades no funcionaba, detectaba el click pero no
# apuntaba ni lanzaba la habilidad". Causa real: Jugador/IndicadorApunte se
# conectan a slot_5.._9_apunte/lanzar desde su propio _ready(), esperando
# que ALGÚN UIHabilidad ya haya registrado esas señales (ver
# PaginadorHabilidades.registrar_indices_adicionales) — pero el orden en
# que Godot corre _ready() entre el Jugador (spawneado por red) y el HUD
# (parte estática de Mundo.tscn) no está garantizado, y SeñalManager.
# conectar() fallaba EN SILENCIO para siempre si la señal todavía no
# existía. Arreglado en SeñalManager.gd (ver _pendientes): un conectar()
# que llega antes que su registrar() ahora se resuelve solo en cuanto ese
# registrar() ocurre, sin importar el orden.
#
# Reproduce la estructura REAL del HUD (5 UIHabilidad físicos + 1
# PaginadorHabilidades, ver Mundo.tscn) con una habilidad de JOYSTICK
# equipada en un slot de la SEGUNDA página (índice 5, ver PaginadorHabilidades
# .POR_PAGINA=5) — a propósito con el Jugador entrando al árbol ANTES que
# el HUD (el peor de los dos órdenes posibles) — cambia de página, y simula
# el gesto completo (apretar -> arrastrar -> soltar) sobre el botón físico
# que ahora representa ese slot. Confirma que, pase lo que pase con el
# orden:
#   1. Al arrastrar, IndicadorApunte SÍ se activa (apunta) mostrando la
#      habilidad correcta.
#   2. Al soltar, Jugador SÍ recibe el lanzamiento (la habilidad entra en
#      recarga de verdad, prueba de que activar() corrió).
#   godot --headless --path . --script res://pruebas/prueba_paginador_apuntar_lanzar_pagina_2.gd
# =============================================================================
extends SceneTree

const SLOT_PAGINA_2 := 5  # POR_PAGINA(5) + índice físico 0.

var _f := 0
var _jugador
var _slot_habilidades
var _indicador
var _botones: Array = []
var _paginador

var _cambio_de_pagina_ok := false
var _apunta_en_pagina_2_ok := false
var _lanza_en_pagina_2_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		10:
			_cambiar_pagina_y_apuntar()
		11:
			_soltar_y_verificar()
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Control.new()
	contenedor.size = Vector2(1280, 720)
	root.add_child(contenedor)
	current_scene = contenedor

	# Cargar Jugador.tscn PRIMERO (fuerza que los autoloads que usan las
	# habilidades de proyectil, ej. GestorPiscinas, ya estén resueltos antes
	# de tocar cualquier HabilidadProyectil -- ver memoria del proyecto) Y
	# entrarlo al árbol ANTES que el HUD/paginador -- a propósito el "peor
	# caso" de orden (el Jugador spawneado por red podría en teoría llegar
	# antes de que el HUD termine de armarse): ver SeñalManager._pendientes,
	# el fix real es que este orden YA NO IMPORTE, sin importar cuál gane
	# la carrera en el juego de verdad.
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	contenedor.add_child(_jugador)

	# Misma estructura real que Mundo.tscn: 5 UIHabilidad físicos (slot_index
	# 0..4) + 1 PaginadorHabilidades apuntando a esos 5.
	var escena_uih := load("res://escenas/ui/ui_habilidad/UIHabilidad.tscn") as PackedScene
	for i in 5:
		var boton := escena_uih.instantiate()
		boton.name = "UIHabilidadSlot%d" % i
		boton.slot_index = i
		contenedor.add_child(boton)
		_botones.append(boton)

	_paginador = (load("res://escenas/ui/ui_habilidad/PaginadorHabilidades.gd") as GDScript).new()
	_paginador.name = "PaginadorHabilidades"
	# Mismo formato que Mundo.tscn de verdad ("../UIHabilidadSlot0"): rutas
	# relativas al PROPIO paginador (get_node_or_null corre sobre "self" en
	# PaginadorHabilidades._ready()), no al contenedor común.
	var rutas: Array[NodePath] = []
	for boton in _botones:
		rutas.append(NodePath("../%s" % boton.name))
	_paginador.rutas_botones = rutas
	contenedor.add_child(_paginador)

	_slot_habilidades = _jugador.get_node("SlotHabilidades")
	_indicador = _jugador.get_node("IndicadorApunte")

	# Habilidad de JOYSTICK (requiere dirección) equipada directo en un slot
	# de la SEGUNDA página -- mismo escenario que reportó el usuario.
	var escena_proyectil := load("res://escenas/habilidades/proyectil/HabilidadProyectil.tscn") as PackedScene
	_slot_habilidades.equipar_escena(SLOT_PAGINA_2, escena_proyectil)


func _cambiar_pagina_y_apuntar() -> void:
	_paginador._siguiente_pagina()
	var boton0 = _botones[0]
	_cambio_de_pagina_ok = boton0.slot_index == SLOT_PAGINA_2
	print("El botón físico 0 pasa a representar el slot %d de la página 2 (esperado true): %s" % [
		SLOT_PAGINA_2, _cambio_de_pagina_ok])

	# Apretar y arrastrar -- mismo gesto que haría un dedo real.
	boton0._iniciar_joystick(0)
	boton0._drag_offset = Vector2(50, 0)
	boton0._emitir_apunte()

	_apunta_en_pagina_2_ok = _indicador._activo and _indicador._hab == _slot_habilidades.obtener(SLOT_PAGINA_2)
	print("Arrastrar en la página 2 SÍ activa IndicadorApunte con la habilidad correcta (esperado true): %s" % \
		_apunta_en_pagina_2_ok)


func _soltar_y_verificar() -> void:
	var boton0 = _botones[0]
	boton0._soltar_joystick()

	var hab = _slot_habilidades.obtener(SLOT_PAGINA_2)
	_lanza_en_pagina_2_ok = hab != null and hab.obtener_recarga_restante() > 0.0
	print("Soltar en la página 2 SÍ lanza la habilidad (esperado true, recarga=%.2f): %s" % [
		hab.obtener_recarga_restante() if hab else -1.0, _lanza_en_pagina_2_ok])


func _informar() -> bool:
	var exito := _cambio_de_pagina_ok and _apunta_en_pagina_2_ok and _lanza_en_pagina_2_ok
	print("PRUEBA PAGINADOR APUNTAR LANZAR PAGINA 2 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
