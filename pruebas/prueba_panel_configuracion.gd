# =============================================================================
# Prueba del panel de Configuración del OS (pestaña nueva, ver
# escenas/ui/panel_os/paneles/configuracion/PanelConfiguracion.gd).
#
# Verifica:
#   1. El panel está REGISTRADO en OsPrincipal: existe el botón de la barra
#      superior, existe su pestaña, y tocar el botón cambia a esa pestaña.
#      (Registrar un panel acá es cablearlo a mano en 5 lugares distintos —
#      no hay auto-descubrimiento —, así que es fácil que quede a medias.)
#   2. La casilla refleja el valor actual de Utils.mostrar_depuracion al
#      abrirse, y cambiarla lo aplica Y lo persiste.
#   3. Guardar cuenta valida "PIN sin nombre" (mismo criterio que MenuInicio)
#      y no pisa los valores cuando la validación falla.
#   4. La persistencia compartida (Utils.guardar_config/cargar_config, que
#      antes eran privadas de MenuInicio) sobrevive un "reinicio" simulado.
#   5. La casilla tiene FIJADOS los 6 estados de color del texto. El tema
#      define solo 4 (font_color/hover/pressed/disabled): los que faltan
#      (focus y hover_pressed) caían al tema por defecto de Godot y pintaban
#      el texto oscuro — reportado: "al pasar el mouse y no estar
#      seleccionada, el texto se coloca negro y no se alcanza a leer".
#   6. Existe el botón de cerrar sesión y Mundo expone cerrar_sesion().
#   7. Pedido explícito del usuario (3 sep 2026): el slider "Volumen SFX"
#      refleja Utils.volumen_sfx al abrir, se aplica EN VIVO al bus "SFX"
#      real en cada tick de arrastre (value_changed) sin escribir a disco
#      todavía, y recién persiste al SOLTAR (drag_ended) — mismo criterio
#      que evitó escribir el .cfg en cada pixel del arrastre.
#   godot --headless --path . --script res://pruebas/prueba_panel_configuracion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _os
var _panel
var _utils

var _boton_existe := false
var _pestana_existe := false
var _cambia_de_pestana := false
var _casilla_refleja_estado := false
var _cambiar_casilla_aplica := false
var _rechaza_pin_sin_nombre := false
var _guarda_cuenta_valida := false
var _persiste_tras_reiniciar := false
var _casilla_colores_legibles := false
var _boton_cerrar_sesion_existe := false
var _mundo_expone_cerrar_sesion := false
var _slider_refleja_estado := false
var _slider_aplica_en_vivo_sin_guardar := false
var _slider_persiste_al_soltar := false
var _tabs_organizadas_ok := false
var _barra_nativa_oculta_ok := false
var _botones_toggle_ok := false


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_probar_registro()
		4:
			_probar_opciones()
			return _informar()
	return false


func _montar() -> void:
	_utils = root.get_node("/root/Utils")
	# Aislar de la config real del dispositivo.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_utils.RUTA_CONFIG))
	_utils.mostrar_depuracion = false
	_utils.nombre_conexion = "Probador"
	_utils.pin_conexion = ""
	_utils.volumen_sfx = 0.6

	_os = (load("res://escenas/ui/panel_os/principal/OsPrincipal.tscn") as PackedScene).instantiate()
	root.add_child(_os)
	current_scene = _os


func _probar_registro() -> void:
	var barra: Node = _os.get_node_or_null(
		"ColorRect/Margin/VBox/Panel/BarraSuperior/BtnConfiguracion")
	_boton_existe = barra != null
	print("Existe el botón 'Configuración' en la barra superior (esperado true): %s" % _boton_existe)

	var pestana: Node = _os.get_node_or_null("ColorRect/Margin/VBox/TabContainer/TabConfiguracion")
	_panel = pestana.get_node_or_null("PanelConfiguracion") if pestana else null
	_pestana_existe = pestana != null and _panel != null
	print("Existe la pestaña con el panel adentro (esperado true): %s" % _pestana_existe)

	if _boton_existe:
		# Se llama al handler igual que haría el botón: en headless no hay
		# input real, y toda la lógica vive en el handler.
		_os._on_btn_configuracion()
		_cambia_de_pestana = _os.tabs.current_tab == pestana.get_index()
		print("Tocar el botón cambia a su pestaña (esperado true, tab=%d): %s" % [
			_os.tabs.current_tab, _cambia_de_pestana])


func _probar_opciones() -> void:
	if _panel == null:
		return
	var casilla: CheckBox = _panel.get_node("%CasillaDepuracion")
	_casilla_refleja_estado = casilla.button_pressed == false
	print("La casilla refleja Utils.mostrar_depuracion=false al abrir (esperado true): %s" % \
		_casilla_refleja_estado)

	# Encenderla debe aplicar el valor Y dejarlo guardado en disco.
	casilla.button_pressed = true
	var config := ConfigFile.new()
	var guardo_ok := config.load(_utils.RUTA_CONFIG) == OK \
		and bool(config.get_value("conexion", "depuracion", false))
	_cambiar_casilla_aplica = _utils.mostrar_depuracion and guardo_ok
	print("Cambiarla aplica en Utils y persiste en disco (esperado true): %s" % _cambiar_casilla_aplica)

	# Slider de volumen SFX: refleja el valor actual al abrir.
	var slider: HSlider = _panel.get_node("%SliderVolumenSfx")
	_slider_refleja_estado = is_equal_approx(slider.value, 0.6)
	print("El slider refleja Utils.volumen_sfx=0.6 al abrir (esperado true): %s" % _slider_refleja_estado)

	# Arrastrar (value_changed) aplica en vivo al bus real Y a Utils, pero
	# TODAVÍA no escribe a disco.
	var idx_bus_sfx := AudioServer.get_bus_index("SFX")
	slider.value = 0.25
	var config_sin_guardar := ConfigFile.new()
	var no_guardo_todavia: bool = config_sin_guardar.load(_utils.RUTA_CONFIG) != OK \
		or not config_sin_guardar.has_section_key("conexion", "volumen_sfx") \
		or not is_equal_approx(float(config_sin_guardar.get_value("conexion", "volumen_sfx", -1.0)), 0.25)
	_slider_aplica_en_vivo_sin_guardar = is_equal_approx(_utils.volumen_sfx, 0.25) \
		and is_equal_approx(AudioServer.get_bus_volume_db(idx_bus_sfx), linear_to_db(0.25)) \
		and no_guardo_todavia
	print("Arrastrar aplica en vivo (Utils + bus real) sin guardar todavía (esperado true): %s" % \
		_slider_aplica_en_vivo_sin_guardar)

	# Soltar (drag_ended) recién ahí persiste a disco.
	slider.emit_signal("drag_ended", true)
	var config_tras_soltar := ConfigFile.new()
	_slider_persiste_al_soltar = config_tras_soltar.load(_utils.RUTA_CONFIG) == OK \
		and is_equal_approx(float(config_tras_soltar.get_value("conexion", "volumen_sfx", -1.0)), 0.25)
	print("Soltar el slider persiste el volumen en disco (esperado true): %s" % _slider_persiste_al_soltar)

	# PIN sin nombre: mismo rechazo que en MenuInicio.
	_panel.get_node("%CampoNombre").text = ""
	_panel.get_node("%CampoPin").text = "1234"
	_panel._al_aplicar_cuenta()
	_rechaza_pin_sin_nombre = _utils.pin_conexion == "" and _utils.nombre_conexion == "Probador"
	print("Rechaza PIN sin nombre sin pisar lo anterior (esperado true): %s" % _rechaza_pin_sin_nombre)

	# Combinación válida: se guarda.
	_panel.get_node("%CampoNombre").text = "  Jose  "
	_panel.get_node("%CampoPin").text = "9876"
	_panel._al_aplicar_cuenta()
	_guarda_cuenta_valida = _utils.nombre_conexion == "Jose" and _utils.pin_conexion == "9876"
	print("Guarda nombre recortado + PIN (esperado true, '%s'/'%s'): %s" % [
		_utils.nombre_conexion, _utils.pin_conexion, _guarda_cuenta_valida])

	# "Reiniciar la app": borrar los valores en memoria y releer del disco.
	_utils.nombre_conexion = ""
	_utils.pin_conexion = ""
	_utils.mostrar_depuracion = false
	_utils.cargar_config()
	_persiste_tras_reiniciar = _utils.nombre_conexion == "Jose" \
		and _utils.pin_conexion == "9876" and _utils.mostrar_depuracion
	print("Todo sobrevive un reinicio simulado (esperado true): %s" % _persiste_tras_reiniciar)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_utils.RUTA_CONFIG))

	# Los 6 estados de color del texto de la casilla, fijados en el NODO (no
	# en el tema, para no cambiarle el aspecto al resto de la interfaz). Se
	# exige que TODOS sean claros: alcanza con que uno quede oscuro para que
	# el texto desaparezca en ese estado.
	var estados := ["font_color", "font_hover_color", "font_pressed_color",
		"font_hover_pressed_color", "font_focus_color"]
	_casilla_colores_legibles = true
	for estado in estados:
		if not casilla.has_theme_color_override(estado):
			_casilla_colores_legibles = false
			print("  falta el override '%s'" % estado)
			continue
		var c: Color = casilla.get_theme_color(estado)
		# Luminancia baja = texto que se pierde sobre el panel oscuro.
		if c.get_luminance() < 0.5:
			_casilla_colores_legibles = false
			print("  '%s' es demasiado oscuro (luminancia %.2f)" % [estado, c.get_luminance()])
	print("Los 6 estados de color de la casilla son legibles (esperado true): %s" % 		_casilla_colores_legibles)

	# Pedido explícito del usuario (5 sep 2026): las opciones quedan
	# organizadas por tabs/categorías en vez de dos columnas sueltas.
	var tabs: TabContainer = _panel.get_node_or_null("Margin/VBox/Tabs")
	var nombres_esperados := ["Interfaz", "Audio", "Partida", "Cuenta"]
	_tabs_organizadas_ok = tabs != null and tabs.get_tab_count() == nombres_esperados.size()
	if _tabs_organizadas_ok:
		for i in nombres_esperados.size():
			if tabs.get_tab_title(i) != nombres_esperados[i]:
				_tabs_organizadas_ok = false
	print("Las opciones quedan organizadas en tabs Interfaz/Audio/Partida/Cuenta (esperado true): %s" % \
		_tabs_organizadas_ok)

	# Pedido explícito del usuario (5 sep 2026): mismo patrón que
	# OsPrincipal (BarraSuperior de botones toggle_mode + TabContainer con
	# tabs_visible=false) en vez de la barra nativa del TabContainer, que no
	# respeta el tema del resto del OS.
	_barra_nativa_oculta_ok = tabs != null and not tabs.tabs_visible
	print("La barra nativa del TabContainer queda oculta (esperado true): %s" % _barra_nativa_oculta_ok)

	var botones_barra := [
		_panel.get_node_or_null("%BtnInterfaz"), _panel.get_node_or_null("%BtnAudio"),
		_panel.get_node_or_null("%BtnPartida"), _panel.get_node_or_null("%BtnCuenta")]
	_botones_toggle_ok = true
	for b in botones_barra:
		if b == null or not (b is Button) or not (b as Button).toggle_mode:
			_botones_toggle_ok = false
	print("Existen los 4 botones de categoría, todos toggle_mode (esperado true): %s" % _botones_toggle_ok)

	# Tocar un botón cambia de tab Y deja SOLO ese botón presionado/bloqueado
	# (mismo criterio que set_active_topbar_button: no se puede des-togglear
	# a mano el que está activo).
	_panel.get_node("%BtnAudio").pressed.emit()
	var boton_audio: Button = _panel.get_node("%BtnAudio")
	var boton_interfaz: Button = _panel.get_node("%BtnInterfaz")
	_tabs_organizadas_ok = _tabs_organizadas_ok and tabs.current_tab == 1 \
		and boton_audio.button_pressed and boton_audio.disabled \
		and not boton_interfaz.button_pressed and not boton_interfaz.disabled
	print("Tocar 'Audio' cambia de tab y deja solo ese botón presionado/bloqueado (esperado true): %s" % \
		_tabs_organizadas_ok)

	var boton_salir: Node = _panel.get_node_or_null("%BotonCerrarSesion")
	_boton_cerrar_sesion_existe = boton_salir != null
	print("Existe el botón de cerrar sesión (esperado true): %s" % _boton_cerrar_sesion_existe)

	# El panel delega en Mundo.cerrar_sesion() — se comprueba que ese método
	# exista de verdad, sin llamarlo (haría un cambio de escena real).
	var guion_mundo := load("res://escenas/mundo/Mundo.gd") as GDScript
	# (se instancia suelto solo para consultar su API, no entra al árbol)
	var suelto = guion_mundo.new()
	_mundo_expone_cerrar_sesion = suelto.has_method("cerrar_sesion")
	suelto.free()
	print("Mundo expone cerrar_sesion() (esperado true): %s" % _mundo_expone_cerrar_sesion)


func _informar() -> bool:
	var exito := _boton_existe and _pestana_existe and _cambia_de_pestana \
		and _casilla_refleja_estado and _cambiar_casilla_aplica \
		and _rechaza_pin_sin_nombre and _guarda_cuenta_valida and _persiste_tras_reiniciar 		and _casilla_colores_legibles and _boton_cerrar_sesion_existe 		and _mundo_expone_cerrar_sesion \
		and _slider_refleja_estado and _slider_aplica_en_vivo_sin_guardar and _slider_persiste_al_soltar \
		and _tabs_organizadas_ok and _barra_nativa_oculta_ok and _botones_toggle_ok
	print("PRUEBA PANEL CONFIGURACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
