extends "res://autoloads/GestorAlmacenCompartido.gd"
## Instancia una sola vez el Minero.tscn (ver Minero.gd) y guarda el almacén
## compartido donde deposita el mineral (ver GestorAlmacenCompartido.gd). A
## diferencia del leñador, el minero nunca cruza de nivel (mina y almacén viven
## dentro de NivelMina), así que alcanza con mantener activo ese nivel.

const _RUTA_MINA := "res://escenas/niveles/NivelMina.tscn"
const _ESCENA_MINERO := preload("res://escenas/npc/minero/Minero.tscn")


func _ruta_guardado() -> String:
	return "user://almacen_minero.save"


func _preparar_mundo() -> void:
	var nivel_mina := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_MINA)
	# La mina se mantiene activa aunque no haya ningún jugador ahí, o el minero
	# se apagaría junto con el nivel.
	GestorNiveles.mantener_siempre_activo(_RUTA_MINA)

	var contenedor := GestorNiveles.contenedor_errantes()
	if contenedor and nivel_mina:
		var minero := _ESCENA_MINERO.instantiate()
		contenedor.add_child(minero)
		# "En casa" al arrancar: junto al almacén.
		var almacen := nivel_mina.get_node_or_null("Decoraciones/AlmacenMinero1")
		if almacen:
			minero.global_position = almacen.global_position
