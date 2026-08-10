# =============================================================================
# Prueba de integración sobre el CONTENIDO REAL (no sintético) del NPC
# comerciante de ejemplo: carga ejemplo_comerciante.tres y el catálogo real
# de GestorMisiones tal como se despliegan, y valida que las 3 misiones de
# ejemplo (lobos, plaga multi-tipo, reina secuencial) se ofrecen/ocultan
# bien a medida que se aceptan y se cumplen sus objetivos.
#   godot --headless --path . --script res://pruebas/prueba_npc_comerciante_contenido_real.gd
# =============================================================================
extends SceneTree

var _bus: Node
var _panel: Control
var _gestor_ui: Node
var _jugador
var _misiones
var _npc: Node2D
var _datos: DatosDialogo

var _catalogo_tiene_3_misiones_ok := false
var _estado_inicial_ok := false
var _plaga_completa_habilita_entrega_ok := false
var _reina_secuencial_no_ofrece_entrega_antes_ok := false
var _reina_secuencial_ofrece_entrega_al_final_ok := false
var _aceptar_mision_vuelve_al_menu_ok := false
var _entregar_mision_vuelve_al_menu_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_catalogo()
	_probar_estado_inicial()
	_probar_plaga()
	_probar_entregar_vuelve_al_menu()
	_probar_reina()
	_probar_aceptar_mision_vuelve_al_menu()
	return _informar()


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_gestor_ui = root.get_node("/root/GestorUI")
	_panel = (load("res://escenas/ui/panel_dialogo/PanelDialogo.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")
	_npc = Node2D.new()
	root.add_child(_npc)
	_datos = load("res://recursos/dialogo/ejemplo_comerciante.tres") as DatosDialogo


## Pedido explícito del usuario: el saludo y el menú de opciones se
## fusionaron en una sola línea — abrir el diálogo ya muestra las
## opciones de una, sin un Continuar extra en el medio (antes hacía
## falta para llegar del saludo al menú).
func _abrir_en_linea_de_opciones() -> void:
	_bus.dialogo_solicitado.emit(_npc, _datos)


func _textos_opciones_actuales() -> Array:
	var opciones: Node = _panel.get_node("%Opciones")
	var textos := []
	for boton in opciones.get_children():
		textos.append((boton as Button).text)
	return textos


func _click_opcion_por_texto(texto: String) -> void:
	var opciones: Node = _panel.get_node("%Opciones")
	for boton in opciones.get_children():
		if (boton as Button).text == texto:
			(boton as Button).pressed.emit()
			return


func _probar_catalogo() -> void:
	var ids := []
	for m in root.get_node("/root/GestorMisiones").catalogo:
		ids.append(m.id)
	_catalogo_tiene_3_misiones_ok = ids.size() == 3 and "cazar_lobos" in ids \
		and "plaga_pradera" in ids and "reina_nido" in ids
	print("GestorMisiones.catalogo tiene las 3 misiones de ejemplo (esperado true): %s" % _catalogo_tiene_3_misiones_ok)


func _probar_estado_inicial() -> void:
	_abrir_en_linea_de_opciones()
	var textos := _textos_opciones_actuales()
	_estado_inicial_ok = textos.size() == 5 \
		and "Ver mercancía" in textos \
		and "Tengo una misión para vos" in textos \
		and "También hay una plaga que atender" in textos \
		and "¿Alguien se anima a la Araña Reina?" in textos \
		and "Nada, gracias" in textos
	print("Sin ninguna misión aceptada: 5 opciones, ninguna de 'entregar' (esperado true): %s" % _estado_inicial_ok)


func _probar_plaga() -> void:
	var mision_plaga: DatosMision = root.get_node("/root/GestorMisiones").obtener_por_id("plaga_pradera")
	_misiones.aceptar_mision(mision_plaga)

	for objetivo in mision_plaga.objetivos:
		for i in objetivo.cantidad_meta:
			var enemigo := EnemigoDatos.new()
			enemigo.id = objetivo.id_meta
			_misiones.notificar_matar(enemigo)

	_abrir_en_linea_de_opciones()
	var textos := _textos_opciones_actuales()
	_plaga_completa_habilita_entrega_ok = "Ya me encargué de la plaga" in textos \
		and not ("También hay una plaga que atender" in textos)
	print("Plaga con los 3 tipos de enemigo cumplidos: aparece 'ya me encargué', no la oferta (esperado true): %s" % _plaga_completa_habilita_entrega_ok)


## Bug real reportado dos veces: primero cerraba el diálogo entero al
## entregar (a las 3 opciones de entrega les faltaba siguiente_linea,
## quedaba en el -1 por defecto que _elegir_opcion interpreta como
## "cerrar"). Pedido explícito de corrección: no saltar directo al menú —
## debe mostrarse antes una línea de agradecimiento con SOLO el botón
## Continuar (mismo criterio que "Acepto" -> "¡Gracias! Volvé cuando
## termines."), y RECIÉN al tocar Continuar volver al menú. Sigue directo
## del estado que deja _probar_plaga (misión lista para entregar, diálogo
## ya abierto en el menú).
func _probar_entregar_vuelve_al_menu() -> void:
	_click_opcion_por_texto("Ya me encargué de la plaga")
	var opciones: Node = _panel.get_node("%Opciones")
	var boton_continuar := _panel.get_node("%BotonContinuar") as Button
	var texto_agradecimiento := (_panel.get_node("%Texto") as Label).text
	var _muestra_agradecimiento_solo_continuar_ok := \
		texto_agradecimiento == "¡Muchas gracias por tu ayuda!" \
		and opciones.get_child_count() == 0 and boton_continuar.visible

	boton_continuar.pressed.emit()
	var texto_menu := (_panel.get_node("%Texto") as Label).text
	_entregar_mision_vuelve_al_menu_ok = _muestra_agradecimiento_solo_continuar_ok \
		and _gestor_ui.modo_actual == _gestor_ui.Modo.DIALOGO \
		and texto_menu == "Bienvenido a mi puesto, viajero. ¿En qué te puedo ayudar?"
	print("Entregar muestra agradecimiento con solo Continuar, y ESE lleva al menú (esperado true): %s (agradecimiento: %s, tras continuar: %s)" % [
		_entregar_mision_vuelve_al_menu_ok, texto_agradecimiento, texto_menu])


func _probar_reina() -> void:
	var mision_reina: DatosMision = root.get_node("/root/GestorMisiones").obtener_por_id("reina_nido")
	# reina_nido pide nivel_requerido=8 a propósito (es la mazmorra del
	# jefe) — el jugador recién instanciado nace en nivel 1, así que sin
	# esto aceptar_mision() rechaza en silencio por nivel, no por nada
	# relacionado con la lógica secuencial que esta prueba quiere ejercitar.
	var experiencia: Node = _jugador.get_node("ExperienciaComponente")
	experiencia.nivel = mision_reina.nivel_requerido
	_misiones.aceptar_mision(mision_reina)

	# Pegarle a la reina ANTES de limpiar las 3 arañas de la fase 1 no debe
	# habilitar la entrega todavía — esa es la regla "por fases" pedida.
	var enemigo_reina := EnemigoDatos.new()
	enemigo_reina.id = "Araña Reina"
	_misiones.notificar_matar(enemigo_reina)

	_abrir_en_linea_de_opciones()
	var textos_antes := _textos_opciones_actuales()
	_reina_secuencial_no_ofrece_entrega_antes_ok = not ("Acabé con la Araña Reina" in textos_antes)
	print("Reina: matarla antes de limpiar las arañas no habilita la entrega (esperado true): %s" % _reina_secuencial_no_ofrece_entrega_antes_ok)

	var enemigo_arana := EnemigoDatos.new()
	enemigo_arana.id = "Araña"
	for i in 3:
		_misiones.notificar_matar(enemigo_arana)
	_misiones.notificar_matar(enemigo_reina)

	_abrir_en_linea_de_opciones()
	var textos_despues := _textos_opciones_actuales()
	_reina_secuencial_ofrece_entrega_al_final_ok = "Acabé con la Araña Reina" in textos_despues
	print("Reina: tras las 3 arañas y matarla, sí habilita la entrega (esperado true): %s" % _reina_secuencial_ofrece_entrega_al_final_ok)


## Bug real reportado: aceptar una misión y tocar Continuar en la línea de
## cierre ("¡Gracias! Volvé cuando termines.") mostraba el DETALLE de la
## siguiente misión del array (plaga), como si el jugador la hubiera
## elegido — en vez de volver al menú principal del NPC. Camino real: menú
## -> "Tengo una misión para vos" -> detalle -> "Acepto" -> "¡Gracias!" ->
## Continuar. Debe terminar en el menú, no en "Ratones, arañas y lobos...".
func _probar_aceptar_mision_vuelve_al_menu() -> void:
	_abrir_en_linea_de_opciones()
	_click_opcion_por_texto("Tengo una misión para vos")
	_click_opcion_por_texto("Acepto")
	(_panel.get_node("%BotonContinuar") as Button).pressed.emit()

	var texto_linea := (_panel.get_node("%Texto") as Label).text
	_aceptar_mision_vuelve_al_menu_ok = texto_linea == "Bienvenido a mi puesto, viajero. ¿En qué te puedo ayudar?"
	print("Tras aceptar y continuar, vuelve al menú (esperado true, no el detalle de otra misión): %s (texto: %s)" % [
		_aceptar_mision_vuelve_al_menu_ok, texto_linea])


func _informar() -> bool:
	var exito := _catalogo_tiene_3_misiones_ok and _estado_inicial_ok \
		and _plaga_completa_habilita_entrega_ok and _entregar_mision_vuelve_al_menu_ok \
		and _reina_secuencial_no_ofrece_entrega_antes_ok and _reina_secuencial_ofrece_entrega_al_final_ok \
		and _aceptar_mision_vuelve_al_menu_ok
	print("PRUEBA NPC COMERCIANTE CONTENIDO REAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
