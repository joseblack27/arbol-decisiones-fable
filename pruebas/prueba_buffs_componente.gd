# =============================================================================
# Prueba de BuffsComponente (registro genérico de buffs/debuffs para el HUD):
#   1. agregar() dispara buff_agregado la primera vez.
#   2. Reagregar el mismo id ANTES de que venza renueva (buff_actualizado,
#      no un segundo buff_agregado) y estira tiempo_restante.
#   3. Al vencerse el tiempo, se quita solo y dispara buff_quitado.
#   4. nombre/descripcion (pedidos por el usuario para el panel "Buffs
#      Activos" de PanelTablero) quedan guardados y se pueden leer con
#      obtener() — parámetros nuevos, con default "" para no romper
#      llamadas viejas de 4 argumentos.
#   godot --headless --path . --script res://pruebas/prueba_buffs_componente.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _buffs: Node
var _eventos: Array[String] = []
var _nombre_y_descripcion_correctos := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_buffs.agregar("escudo", null, 1.0, false, "Escudo", "Reduce el daño recibido en 100%")
			var buff = _buffs.obtener("escudo")
			_nombre_y_descripcion_correctos = buff.nombre == "Escudo" \
				and buff.descripcion == "Reduce el daño recibido en 100%"
		10:
			# Renovar antes de que venza (1.0s = 60 fotogramas, estamos en el 10).
			_buffs.agregar("escudo", null, 1.0, false)
		# 10 + 60 = 70 ya venció la renovación; dar margen.
		80:
			return _informar()
	return false


func _montar() -> void:
	var guion := load("res://componentes/BuffsComponente.gd") as GDScript
	_buffs = guion.new()
	root.add_child(_buffs)
	_buffs.buff_agregado.connect(func(id): _eventos.append("agregado:" + id))
	_buffs.buff_actualizado.connect(func(id): _eventos.append("actualizado:" + id))
	_buffs.buff_quitado.connect(func(id): _eventos.append("quitado:" + id))


func _informar() -> bool:
	print("Eventos: %s" % [_eventos])
	var agregados := _eventos.count("agregado:escudo")
	var quitados := _eventos.count("quitado:escudo")
	var tuvo_actualizacion := _eventos.has("actualizado:escudo")
	print("agregado:escudo exactamente 1 vez (esperado true): %s" % (agregados == 1))
	print("hubo al menos una actualización por la renovación (esperado true): %s" % tuvo_actualizacion)
	print("quitado:escudo exactamente 1 vez, al final (esperado true): %s" % (quitados == 1))
	print("nombre/descripcion guardados y legibles (esperado true): %s" % _nombre_y_descripcion_correctos)
	var exito := agregados == 1 and tuvo_actualizacion and quitados == 1 \
		and _eventos.find("quitado:escudo") > _eventos.find("agregado:escudo") \
		and _nombre_y_descripcion_correctos
	print("PRUEBA BUFFS COMPONENTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
