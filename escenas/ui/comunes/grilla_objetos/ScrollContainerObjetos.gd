extends ScrollContainer
class_name ScrollContainerObjetos
## Segundo blanco de un arrastre dentro de una GrillaObjetos — cubre el
## hueco vacío alrededor/debajo de las casillas (CasillaObjeto TAMBIÉN
## acepta drops directo, ver ese archivo, para el caso más común: soltar
## sobre una casilla puntual). El ScrollContainer cubre TODA el área
## visible de la grilla, así que es quien atrapa lo que ninguna casilla
## individual puede (soltar donde no hay ninguna casilla todavía). La
## lógica real de "hacer algo o no" vive en GrillaObjetos.recibir_desde()
## (compartida con CasillaObjeto._drop_data) — nunca acá.

func _can_drop_data(_at_position, data) -> bool:
	return data is CasillaObjeto and data.item_data != null


func _drop_data(_at_position, data) -> void:
	var origen: CasillaObjeto = data
	if origen.item_data == null:
		return
	var grilla: GrillaObjetos = owner
	if grilla == null:
		return
	grilla.recibir_desde(origen.fuente, origen.grilla_dueña, origen.item_data)
