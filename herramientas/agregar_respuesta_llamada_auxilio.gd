# =============================================================================
# agregar_respuesta_llamada_auxilio.gd
#
# Agrega la rama "ResponderLlamada" (Secuencia: CondicionMemoria
# "en_llamada_auxilio" + AccionIrAPunto) como PRIMER hijo del Selector raíz
# de cada mob listado en RUTAS — máxima prioridad, por encima de huir/
# atacar/perseguir/deambular. Ver Enemigo.responder_llamada_auxilio() y
# HabilidadLlamadaAuxilio.gd (la habilidad de la Reina de las Hormigas que
# dispara esto).
#
# Solo AGREGA nodos nuevos (con su propio script nuevo) a una escena ya
# instanciada — nunca toca set_script() de un nodo EXISTENTE, así que no
# puede pisar los node_paths ya resueltos del mob (ver el bug documentado en
# generar_hormigas_reskin.gd: ESE sí tocaba el script del nodo raíz y por
# eso necesitó edición de texto; esto es distinto, un simple add_child()).
#
# Reusable si se agrega un tercer tipo de hormiga más adelante.
#   godot --headless --path . --script res://herramientas/agregar_respuesta_llamada_auxilio.gd
# =============================================================================
extends SceneTree

const RUTAS := [
	"res://escenas/enemigos/EnemigoHormigaObrera.tscn",
	"res://escenas/enemigos/EnemigoHormigaSoldado.tscn",
]


func _process(_delta: float) -> bool:
	for ruta in RUTAS:
		_agregar_rama(ruta)
	quit(0)
	return true


func _agregar_rama(ruta: String) -> void:
	var mob := (load(ruta) as PackedScene).instantiate()
	var selector := mob.get_node("ArbolComportamiento/Selector")

	var secuencia := Node.new()
	secuencia.name = "ResponderLlamada"
	secuencia.set_script(load("res://componentes/arbol_comportamiento/composites/Secuencia.gd"))
	selector.add_child(secuencia)
	secuencia.owner = mob
	secuencia.set("nombre_nodo", "(Secuencia) Responder Llamada de Auxilio")
	selector.move_child(secuencia, 0)

	var condicion := Node.new()
	condicion.name = "CondLlamadaAuxilio"
	condicion.set_script(load("res://componentes/arbol_comportamiento/utilidades/condiciones/CondicionMemoria.gd"))
	secuencia.add_child(condicion)
	condicion.owner = mob
	condicion.set("nombre_variable", "en_llamada_auxilio")
	condicion.set("nombre_nodo", "(Condición) Llamada de auxilio activa")

	var accion := Node.new()
	accion.name = "IrHaciaLaReina"
	accion.set_script(load("res://componentes/arbol_comportamiento/utilidades/acciones/AccionIrAPunto.gd"))
	secuencia.add_child(accion)
	accion.owner = mob
	accion.set("nombre_nodo", "(Acción) Ir hacia la Reina")

	var escena := PackedScene.new()
	if escena.pack(mob) != OK:
		push_error("No se pudo empaquetar %s" % ruta)
		return
	if ResourceSaver.save(escena, ruta) != OK:
		push_error("No se pudo guardar %s" % ruta)
		return
	print("Rama ResponderLlamada agregada a %s" % ruta)
