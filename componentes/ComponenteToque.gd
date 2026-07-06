# TouchComponent.gd
extends Node2D
class_name ComponenteToque

#region Documentación

## Notas
#	Debe desplegarse en el nodo que se desea controlar el input, ya que este toma el id del padre

## Modo de uso

#func _ready():
#	SignalManager.conectar(str("touch_iniciado_",get_instance_id()), self, "_on_touch_iniciado")
#	SignalManager.conectar(str("touch_movido_",get_instance_id()), self, "_on_touch_movido")
#	SignalManager.conectar(str("touch_finalizado_",get_instance_id()), self, "_on_touch_finalizado")
#
#func _on_touch_iniciado(index, posicion):
#	print(name,", touch_iniciado, index: ", index, ", posicion: ", posicion)
#
#func _on_touch_movido(index, posicion):
#	print(name,", touch_movido, index: ", index, ", posicion: ", posicion)
#
#func _on_touch_finalizado(index, posicion):
#	print(name,", touch_finalizado, index: ", index, ", posicion: ", posicion)

#endregion

var signal_id: String = "default"
@export var habilitado: bool = true

func _ready():
	signal_id = str(get_parent().get_instance_id())
	SeñalManager.registrar(str("touch_iniciado_", signal_id), signal_id, {"index": TYPE_INT, "posicion": TYPE_VECTOR2})
	SeñalManager.registrar(str("touch_finalizado_", signal_id), signal_id, {"index": TYPE_INT, "posicion": TYPE_VECTOR2})
	SeñalManager.registrar(str("touch_movido_", signal_id), signal_id, {"index": TYPE_INT, "posicion": TYPE_VECTOR2})

func _input(event):
	if habilitado == true:
		if event is InputEventScreenTouch:
			if event.pressed:
				touch_iniciado(event.index, event.position)
			else:
				touch_finalizado(event.index, event.position)
		elif event is InputEventScreenDrag:
			touch_movido(event.index, event.position)

func touch_iniciado(index, posicion):
	if posicion_dentro(posicion):
		SeñalManager.emitir(str("touch_iniciado_", signal_id), signal_id, [index, posicion])

func touch_movido(index, posicion):
	if posicion_dentro(posicion):
		SeñalManager.emitir(str("touch_movido_", signal_id), signal_id, [index, posicion])

func touch_finalizado(index, posicion):
	if posicion_dentro(posicion):
		SeñalManager.emitir(str("touch_finalizado_", signal_id), signal_id, [index, posicion])

func posicion_dentro(posicion):
	var parent = get_parent()
	if parent is Control:
		return parent.get_global_rect().has_point(posicion)
	return true
