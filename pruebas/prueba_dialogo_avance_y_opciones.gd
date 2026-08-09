# =============================================================================
# Prueba de PanelDialogo — avance por índice (sin opciones) y por opciones
# (con siguiente_linea propio o -1 para cerrar). No corre red: es pura
# lógica de datos + Control local, ver Enums.Dialogo/DatosDialogo/
# LineaDialogo/OpcionDialogo.
#
# extends SceneTree: los identificadores de autoload sueltos (BusEventos,
# GestorUI) no resuelven acá — hay que ir por root.get_node("/root/X")
# (mismo criterio que el resto de las pruebas de este proyecto).
#   godot --headless --path . --script res://pruebas/prueba_dialogo_avance_y_opciones.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _gestor_ui: Node
var _panel: Control
var _datos: DatosDialogo
var _npc: Node2D

var _abre_y_muestra_primera_linea_ok := false
var _continuar_avanza_a_la_siguiente_ok := false
var _opciones_se_muestran_en_vez_de_continuar_ok := false
var _elegir_opcion_con_next_line_salta_ahi_ok := false
var _elegir_opcion_con_next_line_negativo_cierra_ok := false
var _pasarse_del_final_cierra_solo_ok := false
var _condicion_no_aceptada_oculta_las_otras_ok := false
var _sin_condicion_cumplida_solo_siempre_ok := false
var _condicion_lista_para_entregar_oculta_no_aceptada_ok := false
var _click_entre_lineas_con_opciones_no_deja_botones_pegados_ok := false
var _linea_next_line_explicito_salta_ahi_ok := false
var _icono_de_categoria_correcto_ok := false
var _sin_categoria_no_pone_icono_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_apertura()
	_probar_avance_simple()
	_probar_opciones()
	_probar_opcion_cierra()
	_probar_fin_de_lineas_cierra()
	_probar_opciones_condicionadas_por_mision()
	_probar_click_entre_lineas_con_opciones()
	_probar_linea_next_line_explicito()
	_probar_icono_por_categoria()
	return _informar()


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_gestor_ui = root.get_node("/root/GestorUI")

	_npc = Node2D.new()
	root.add_child(_npc)

	_panel = (load("res://escenas/ui/panel_dialogo/PanelDialogo.tscn") as PackedScene).instantiate()
	root.add_child(_panel)

	var op_si := OpcionDialogo.new()
	op_si.texto = "Sí"
	op_si.siguiente_linea = 2

	var op_no := OpcionDialogo.new()
	op_no.texto = "No"
	op_no.siguiente_linea = -1

	var linea0 := LineaDialogo.new()
	linea0.hablante = "Guardia"
	linea0.texto = "Bienvenido."

	var linea1 := LineaDialogo.new()
	linea1.hablante = "Guardia"
	linea1.texto = "¿Querés ayuda?"
	linea1.opciones = [op_si, op_no]

	var linea2 := LineaDialogo.new()
	linea2.hablante = "Guardia"
	linea2.texto = "Perfecto."

	_datos = DatosDialogo.new()
	_datos.lineas = [linea0, linea1, linea2]


func _texto_de(unique_name: String) -> String:
	return (_panel.get_node(unique_name) as Label).text


func _probar_apertura() -> void:
	_bus.dialogo_solicitado.emit(_npc, _datos)
	var muestra_linea_0: bool = _texto_de("%Speaker") == "Guardia" and _texto_de("%Texto") == "Bienvenido."
	_abre_y_muestra_primera_linea_ok = _panel.visible \
		and _gestor_ui.modo_actual == _gestor_ui.Modo.DIALOGO and muestra_linea_0
	print("Abre el panel, entra a Modo.DIALOGO y muestra la línea 0 (esperado true): %s" % _abre_y_muestra_primera_linea_ok)


func _probar_avance_simple() -> void:
	(_panel.get_node("%BotonContinuar") as Button).pressed.emit()
	_continuar_avanza_a_la_siguiente_ok = _texto_de("%Texto") == "¿Querés ayuda?"
	print("Continuar avanza de la línea 0 a la 1 (esperado true): %s" % _continuar_avanza_a_la_siguiente_ok)


func _probar_opciones() -> void:
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_continuar := _panel.get_node("%BotonContinuar") as Button
	_opciones_se_muestran_en_vez_de_continuar_ok = opciones.get_child_count() == 2 and not boton_continuar.visible
	print("La línea con 2 opciones muestra 2 botones y oculta Continuar (esperado true): %s" % _opciones_se_muestran_en_vez_de_continuar_ok)


func _probar_opcion_cierra() -> void:
	# "No" (siguiente_linea = -1) tiene que cerrar el diálogo entero.
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_no := opciones.get_child(1) as Button
	boton_no.pressed.emit()
	_elegir_opcion_con_next_line_negativo_cierra_ok = not _panel.visible \
		and _gestor_ui.modo_actual == _gestor_ui.Modo.JUEGO
	print("Elegir 'No' (siguiente_linea=-1) cierra el panel y vuelve a Modo.JUEGO (esperado true): %s" % _elegir_opcion_con_next_line_negativo_cierra_ok)


func _probar_fin_de_lineas_cierra() -> void:
	# Reabrir, avanzar a la línea 1, elegir "Sí" (siguiente_linea=2), después
	# Continuar desde la última línea (sin siguiente_linea válido) cierra solo.
	_bus.dialogo_solicitado.emit(_npc, _datos)
	(_panel.get_node("%BotonContinuar") as Button).pressed.emit()
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_si := opciones.get_child(0) as Button
	boton_si.pressed.emit()
	_elegir_opcion_con_next_line_salta_ahi_ok = _texto_de("%Texto") == "Perfecto." and _panel.visible
	print("Elegir 'Sí' (siguiente_linea=2) salta a la línea 2 sin cerrar (esperado true): %s" % _elegir_opcion_con_next_line_salta_ahi_ok)

	(_panel.get_node("%BotonContinuar") as Button).pressed.emit()
	_pasarse_del_final_cierra_solo_ok = not _panel.visible and _gestor_ui.modo_actual == _gestor_ui.Modo.JUEGO
	print("Continuar desde la última línea cierra solo (esperado true): %s" % _pasarse_del_final_cierra_solo_ok)


## Pedido explícito del usuario: "ya me encargué de los lobos" no debe
## ofrecerse antes de aceptar ni mientras la misión sigue en curso, solo
## cuando los objetivos ya están cumplidos — y "tengo una misión para vos"
## no debe seguir ofreciéndose una vez aceptada.
func _probar_opciones_condicionadas_por_mision() -> void:
	var jugador := (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	var misiones = jugador.get_node("MisionesComponente")

	var objetivo := DatosObjetivoMision.new()
	objetivo.id = "obj1"
	objetivo.tipo = Enums.Mision.TipoObjetivo.MATAR
	objetivo.id_meta = "algo"
	objetivo.cantidad_meta = 1

	var mision := DatosMision.new()
	mision.id = "mision_condicion_prueba"
	mision.objetivos = [objetivo]
	mision.recompensas = DatosRecompensaMision.new()
	var catalogo: Array[DatosMision] = [mision]
	root.get_node("/root/GestorMisiones").catalogo = catalogo

	var op_ofrecer := OpcionDialogo.new()
	op_ofrecer.texto = "Tengo una misión para vos"
	op_ofrecer.condicion = Enums.Dialogo.CondicionMision.NO_ACEPTADA
	op_ofrecer.mision_condicion = mision
	op_ofrecer.siguiente_linea = -1

	var op_entregar := OpcionDialogo.new()
	op_entregar.texto = "Ya me encargué"
	op_entregar.condicion = Enums.Dialogo.CondicionMision.LISTA_PARA_ENTREGAR
	op_entregar.mision_condicion = mision
	op_entregar.siguiente_linea = -1

	var op_siempre := OpcionDialogo.new()
	op_siempre.texto = "Nada, gracias"
	op_siempre.siguiente_linea = -1

	var linea := LineaDialogo.new()
	linea.hablante = "Comerciante"
	linea.texto = "¿En qué te ayudo?"
	linea.opciones = [op_ofrecer, op_entregar, op_siempre]

	var datos := DatosDialogo.new()
	datos.lineas = [linea]

	var npc := Node2D.new()
	root.add_child(npc)

	# Sin aceptar todavía: solo "Tengo una misión" (NO_ACEPTADA) y "Nada,
	# gracias" (sin condición) — "Ya me encargué" tiene que estar oculta.
	_bus.dialogo_solicitado.emit(npc, datos)
	var opciones: Node = _panel.get_node("%Opciones")
	_condicion_no_aceptada_oculta_las_otras_ok = opciones.get_child_count() == 2
	print("Sin aceptar la misión: se ofrecen 2 opciones, sin 'ya me encargué' (esperado true): %s" % _condicion_no_aceptada_oculta_las_otras_ok)

	# Aceptada pero objetivo sin cumplir: NINGUNA de las dos condicionales
	# aplica — solo queda "Nada, gracias".
	misiones.aceptar_mision(mision)
	_bus.dialogo_solicitado.emit(npc, datos)
	opciones = _panel.get_node("%Opciones")
	_sin_condicion_cumplida_solo_siempre_ok = opciones.get_child_count() == 1
	print("En curso sin cumplir el objetivo: solo queda la opción sin condición (esperado true): %s" % _sin_condicion_cumplida_solo_siempre_ok)

	# Objetivo cumplido: ahora "ya me encargué" sí aparece, "tengo una
	# misión" ya no (NO_ACEPTADA dejó de ser cierto).
	var datos_enemigo := EnemigoDatos.new()
	datos_enemigo.id = "algo"
	misiones.notificar_matar(datos_enemigo)
	_bus.dialogo_solicitado.emit(npc, datos)
	opciones = _panel.get_node("%Opciones")
	var textos := []
	for boton in opciones.get_children():
		textos.append((boton as Button).text)
	_condicion_lista_para_entregar_oculta_no_aceptada_ok = opciones.get_child_count() == 2 \
		and "Ya me encargué" in textos and not ("Tengo una misión para vos" in textos)
	print("Con el objetivo cumplido: aparece 'ya me encargué', ya no 'tengo una misión' (esperado true): %s" % _condicion_lista_para_entregar_oculta_no_aceptada_ok)


## Repro directa del bug reportado: NO alcanza con re-emitir dialogo_solicitado
## (eso prueba otro camino) — acá se hace clic (pressed.emit(), igual que el
## resto de este archivo) sobre un botón de una línea CON opciones que lleva
## a otra línea que TAMBIÉN tiene opciones (la forma real del diálogo del
## comerciante: "Tengo una misión para vos" → línea con "Acepto"/"Ahora no").
## El botón tocado es uno de los que _limpiar_opciones() tiene que liberar,
## en la misma pila que su propia señal pressed todavía emitiendo — con
## .free() a secas Godot lo rechaza ("Object is locked") y lo deja pegado.
func _probar_click_entre_lineas_con_opciones() -> void:
	var op_ir := OpcionDialogo.new()
	op_ir.texto = "Ir a la línea con opciones"
	op_ir.siguiente_linea = 1

	var op_cerrar := OpcionDialogo.new()
	op_cerrar.texto = "Cerrar"
	op_cerrar.siguiente_linea = -1

	var linea0 := LineaDialogo.new()
	linea0.hablante = "X"
	linea0.texto = "Línea 0"
	linea0.opciones = [op_ir, op_cerrar]

	var op_uno := OpcionDialogo.new()
	op_uno.texto = "Uno"
	op_uno.siguiente_linea = -1

	var op_dos := OpcionDialogo.new()
	op_dos.texto = "Dos"
	op_dos.siguiente_linea = -1

	var linea1 := LineaDialogo.new()
	linea1.hablante = "X"
	linea1.texto = "Línea 1"
	linea1.opciones = [op_uno, op_dos]

	var datos := DatosDialogo.new()
	datos.lineas = [linea0, linea1]

	var npc := Node2D.new()
	root.add_child(npc)

	_bus.dialogo_solicitado.emit(npc, datos)
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_ir := opciones.get_child(0) as Button
	boton_ir.pressed.emit()

	opciones = _panel.get_node("%Opciones")
	var textos := []
	for boton in opciones.get_children():
		textos.append((boton as Button).text)
	_click_entre_lineas_con_opciones_no_deja_botones_pegados_ok = opciones.get_child_count() == 2 \
		and "Uno" in textos and "Dos" in textos \
		and not ("Ir a la línea con opciones" in textos) and not ("Cerrar" in textos)
	print("Clic real entre línea con opciones y otra línea con opciones, sin botones pegados (esperado true): %s" % _click_entre_lineas_con_opciones_no_deja_botones_pegados_ok)


## Bug real reportado: un NPC con varias misiones reusaba la misma línea de
## cierre ("¡Gracias! Volvé cuando termines.") para las tres — al no tener
## siguiente_linea propio, Continuar caía en índice+1, que pasó a ser el
## DETALLE de la siguiente misión en el array en cuanto se agregaron más
## líneas después. Con siguiente_linea explícito, esa línea de cierre
## vuelve al menú (índice 1) sin importar qué más se agregue más adelante
## en el array.
func _probar_linea_next_line_explicito() -> void:
	var op_ir := OpcionDialogo.new()
	op_ir.texto = "Ir al detalle"
	op_ir.siguiente_linea = 2

	var linea0 := LineaDialogo.new()
	linea0.hablante = "X"
	linea0.texto = "menú"
	linea0.opciones = [op_ir]

	var linea1_relleno := LineaDialogo.new()
	linea1_relleno.hablante = "X"
	linea1_relleno.texto = "relleno sin usar"

	var linea2_detalle := LineaDialogo.new()
	linea2_detalle.hablante = "X"
	linea2_detalle.texto = "detalle"
	linea2_detalle.siguiente_linea = 0  # Tiene que volver al "menú", no caer en la línea 3.

	var linea3_trampa := LineaDialogo.new()
	linea3_trampa.hablante = "X"
	linea3_trampa.texto = "trampa: esto NO debería mostrarse"

	var datos := DatosDialogo.new()
	datos.lineas = [linea0, linea1_relleno, linea2_detalle, linea3_trampa]

	var npc := Node2D.new()
	root.add_child(npc)

	_bus.dialogo_solicitado.emit(npc, datos)
	var opciones: Node = _panel.get_node("%Opciones")
	(opciones.get_child(0) as Button).pressed.emit()
	(_panel.get_node("%BotonContinuar") as Button).pressed.emit()

	_linea_next_line_explicito_salta_ahi_ok = _texto_de("%Texto") == "menú"
	print("Línea con siguiente_linea explícito vuelve al menú, no a índice+1 (esperado true): %s" % _linea_next_line_explicito_salta_ahi_ok)


## Pedido explícito del usuario: cada opción puede llevar un ícono según su
## categoría (misión nueva, hablar de misión, mercado, lore) — puramente
## visual, PanelDialogo lo pone en Button.icon al crear el botón.
func _probar_icono_por_categoria() -> void:
	var op_mision := OpcionDialogo.new()
	op_mision.texto = "Con categoría"
	op_mision.categoria = Enums.Dialogo.CategoriaOpcion.MISION

	var op_sin_categoria := OpcionDialogo.new()
	op_sin_categoria.texto = "Sin categoría"

	var linea := LineaDialogo.new()
	linea.hablante = "X"
	linea.texto = "elegí algo"
	linea.opciones = [op_mision, op_sin_categoria]

	var datos := DatosDialogo.new()
	datos.lineas = [linea]

	var npc := Node2D.new()
	root.add_child(npc)

	_bus.dialogo_solicitado.emit(npc, datos)
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_con_categoria := opciones.get_child(0) as Button
	var boton_sin_categoria := opciones.get_child(1) as Button

	_icono_de_categoria_correcto_ok = boton_con_categoria.icon != null
	print("Opción con categoria=MISION pone un ícono (esperado true): %s" % _icono_de_categoria_correcto_ok)

	_sin_categoria_no_pone_icono_ok = boton_sin_categoria.icon == null
	print("Opción sin categoría (default NINGUNA) no pone ícono (esperado true): %s" % _sin_categoria_no_pone_icono_ok)


func _informar() -> bool:
	var exito := _abre_y_muestra_primera_linea_ok and _continuar_avanza_a_la_siguiente_ok \
		and _opciones_se_muestran_en_vez_de_continuar_ok and _elegir_opcion_con_next_line_salta_ahi_ok \
		and _elegir_opcion_con_next_line_negativo_cierra_ok and _pasarse_del_final_cierra_solo_ok \
		and _condicion_no_aceptada_oculta_las_otras_ok and _sin_condicion_cumplida_solo_siempre_ok \
		and _condicion_lista_para_entregar_oculta_no_aceptada_ok \
		and _click_entre_lineas_con_opciones_no_deja_botones_pegados_ok \
		and _linea_next_line_explicito_salta_ahi_ok \
		and _icono_de_categoria_correcto_ok and _sin_categoria_no_pone_icono_ok
	print("PRUEBA DIALOGO AVANCE Y OPCIONES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
