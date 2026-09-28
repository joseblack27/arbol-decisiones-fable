extends "res://autoloads/GestorAlmacenCompartido.gd"
## Instancia una sola vez el Lenador.tscn (ver Lenador.gd) y guarda el almacén
## compartido donde deposita la madera (ver GestorAlmacenCompartido.gd).
##
## El leñador es UNA sola instancia, colgada de
## GestorNiveles.contenedor_errantes(), fuera de cualquier nivel: al "cruzar"
## solo cambia global_position, como un jugador en un portal (ver NpcErrante.gd).

const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const _ESCENA_LENADOR := preload("res://escenas/npc/leñador/Lenador.tscn")


func _ruta_guardado() -> String:
	return "user://almacen_lenador.save"


func _preparar_mundo() -> void:
	var nivel_ciudad := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_PRADERA)
	# Ciudad y Pradera siempre activas: GestorNiveles apaga los niveles sin
	# jugadores (ahorro de CPU, ver _actualizar_actividad_niveles), y el
	# leñador se congelaría si estuviera en el que se apaga.
	GestorNiveles.mantener_siempre_activo(_RUTA_CIUDAD)
	GestorNiveles.mantener_siempre_activo(_RUTA_PRADERA)

	var contenedor := GestorNiveles.contenedor_errantes()
	if contenedor and nivel_ciudad:
		var lenador := _ESCENA_LENADOR.instantiate()
		contenedor.add_child(lenador)
		# "En casa" al arrancar: junto al portal de salida de Ciudad, mismo
		# criterio que el punto de aparición de un jugador.
		var portal := nivel_ciudad.get_node_or_null("PortalAPradera")
		if portal:
			lenador.global_position = portal.global_position
