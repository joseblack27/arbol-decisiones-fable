extends EfectoAreaBase
class_name EfectoInmovilizar
## Efecto de área que impide moverse al objetivo mientras esté dentro.
## Usa un contador en MovimientoComponente para soportar efectos apilados.


func _aplicar_efecto(objetivo: Node) -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.agregar_inmovilizacion()


func _quitar_efecto(objetivo: Node) -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.quitar_inmovilizacion()
