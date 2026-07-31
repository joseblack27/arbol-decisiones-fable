# =============================================================================
# Prueba de MenuInicio: al tocar "Jugar", guarda IP/puerto/nombre en Utils
# (que sobreviven el cambio de escena hacia Mundo.tscn) y valida el puerto.
# También: persiste a user://config_conexion.cfg (ver Utils.guardar_config,
# compartido con el panel de Configuración del OS) para sobrevivir cerrar la
# app, y _ready() la relee al arrancar.
#
# La casilla de "datos de desarrollo" ya NO vive acá: se movió al panel de
# Configuración del OS, donde además se aplica en vivo. Su cobertura está en
# pruebas/prueba_panel_configuracion.gd.
#   godot --headless --path . --script res://pruebas/prueba_menu_inicio.gd
# =============================================================================
extends SceneTree

const _RUTA_CONFIG := "user://config_conexion.cfg"

var _fotogramas := 0
var _menu: Control
var _utils: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			return _informar()
	return false


func _montar() -> void:
	_utils = root.get_node("/root/Utils")
	# Aislar de cualquier config real dejada por una partida jugada en esta
	# máquina — sin esto, _ready() la leería ANTES de que este test pueda
	# comprobar el precargado desde Utils puro.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_RUTA_CONFIG))
	# Valores previos (de una hipotética partida anterior) para confirmar
	# que _ready() los precarga en los campos, no que arrancan vacíos.
	_utils.ip_conexion = "10.0.0.5"
	_utils.puerto_conexion = 1234
	_utils.nombre_conexion = ""

	var escena := (load("res://escenas/menu_inicio/MenuInicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	current_scene = escena
	_menu = escena


func _informar() -> bool:
	var campo_ip: LineEdit     = _menu.get_node("%CampoIp")
	var campo_puerto: LineEdit = _menu.get_node("%CampoPuerto")
	var campo_nombre: LineEdit = _menu.get_node("%CampoNombre")

	var precargo_ip := campo_ip.text == "10.0.0.5"
	var precargo_puerto := campo_puerto.text == "1234"
	print("Precargó ip previa (esperado '10.0.0.5'): %s" % campo_ip.text)
	print("Precargó puerto previo (esperado '1234'): %s" % campo_puerto.text)

	# Cambiar los campos y tocar "Jugar" — sin depender de un cambio de
	# escena real (SceneTree.change_scene_to_file no anda bien en --script),
	# se llama _on_jugar() directo, que es donde vive toda la lógica real.
	campo_ip.text     = "192.168.1.50"
	campo_puerto.text = "9999"
	campo_nombre.text = "  Jose  "
	_menu.call("_on_jugar")

	var ip_guardada: String = _utils.get("ip_conexion")
	var puerto_guardado: int = _utils.get("puerto_conexion")
	var nombre_guardado: String = _utils.get("nombre_conexion")
	var ip_ok: bool = ip_guardada == "192.168.1.50"
	var puerto_ok: bool = puerto_guardado == 9999
	var nombre_ok: bool = nombre_guardado == "Jose"
	print("Guardó IP nueva (esperado '192.168.1.50'): %s" % ip_guardada)
	print("Guardó puerto nuevo (esperado 9999): %d" % puerto_guardado)
	print("Guardó nombre recortado (esperado 'Jose'): '%s'" % nombre_guardado)

	# Puerto inválido: no debe pisar los valores ya guardados.
	campo_puerto.text = "no-es-un-numero"
	_menu.call("_on_jugar")
	var etiqueta_error: Label = _menu.get_node("%EtiquetaError")
	var puerto_tras_invalido: int = _utils.get("puerto_conexion")
	var rechazo_puerto_invalido: bool = etiqueta_error.visible and puerto_tras_invalido == 9999
	print("Rechazó puerto inválido sin pisar el anterior (esperado true): %s" % rechazo_puerto_invalido)

	# Simular "cerrar y volver a abrir la app": resetear Utils a sus
	# defaults de fábrica y montar un MenuInicio NUEVO — si la persistencia
	# a disco funciona, debe recuperar lo guardado arriba, no los defaults.
	_utils.ip_conexion = "0.0.0.0"
	_utils.puerto_conexion = 1
	_utils.nombre_conexion = ""
	var menu2 := (load("res://escenas/menu_inicio/MenuInicio.tscn") as PackedScene).instantiate()
	root.add_child(menu2)
	var ip_tras_reinicio: String = menu2.get_node("%CampoIp").text
	var puerto_tras_reinicio: String = menu2.get_node("%CampoPuerto").text
	var nombre_tras_reinicio: String = menu2.get_node("%CampoNombre").text
	var persiste_ok: bool = ip_tras_reinicio == "192.168.1.50" \
		and puerto_tras_reinicio == "9999" and nombre_tras_reinicio == "Jose"
	print("Sobrevive 'cerrar y abrir la app' (esperado ip/puerto/nombre guardados): %s" % persiste_ok)
	menu2.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_RUTA_CONFIG))

	var exito: bool = precargo_ip and precargo_puerto and ip_ok and puerto_ok and nombre_ok \
		and rechazo_puerto_invalido and persiste_ok
	print("PRUEBA MENU INICIO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
