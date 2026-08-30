# =============================================================================
# Prueba de ListaInteraccion.gd — pedido del usuario: "quiero que arriba
# haya un label que si estás en la lista del menú para seleccionar entre
# múltiples objetos interactuables, esté invisible, pero cuando selecciones
# uno o vayas directamente a un objeto que está solo, aparezca en el label
# el nombre del objeto". Ninguna prueba anterior de la lista de interacción
# instanciaba el PANEL de verdad (solo GestorInteraccion en aislado) — esta
# instancia Mundo.tscn completo para ejercitar %EtiquetaNombre/%Lista tal
# cual los ve un jugador real, mismo patrón que prueba_muerte_jugador.gd.
#
# Cubre:
#   1. Un solo objeto en rango (caso directo): el label muestra su nombre
#      desde el primer momento, sin pasar por ninguna lista.
#   2. Dos objetos en rango: el label queda OCULTO mientras se ve la lista
#      de objetos a elegir.
#   3. Elegir uno de los dos: el label aparece con el nombre del elegido.
#   4. "Volver" a la lista de objetos: el label vuelve a ocultarse.
#   godot --headless --path . --script res://pruebas/prueba_lista_interaccion_etiqueta_nombre.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mundo: Node2D
var _lista
var _etiqueta
var _lista_botones

var _directo_muestra_nombre_ok := false
var _multiple_oculta_label_ok := false
var _elegir_uno_muestra_nombre_ok := false
var _volver_oculta_de_nuevo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			root.get_node("/root/Utils").modo_local_pruebas = true
			_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
			root.add_child(_mundo)
			current_scene = _mundo
		10:
			_montar_referencias()
			_probar_caso_directo()
			_probar_caso_multiple()
			_probar_elegir_uno()
			_probar_volver()
			return _informar()
	return false


func _montar_referencias() -> void:
	_lista = _mundo.get_node("CanvasLayer/Control/ListaInteraccion")
	_etiqueta = _lista.get_node("Margen/VBoxRaiz/EtiquetaNombre")
	_lista_botones = _lista.get_node("Margen/VBoxRaiz/Lista")


func _objeto_de_prueba(nombre: String) -> Dictionary:
	return {"objeto": Node.new(), "nombre": nombre, "acciones": [{"texto": "Probar", "callback": func(): pass}]}


func _probar_caso_directo() -> void:
	var items: Array[Dictionary] = [_objeto_de_prueba("Cofre A")]
	_lista._al_cambiar(items)
	_directo_muestra_nombre_ok = _etiqueta.visible and _etiqueta.text == "Cofre A"
	print("Un solo objeto: el label muestra su nombre directo (esperado true, 'Cofre A'): %s, %s" % [
		_etiqueta.visible, _etiqueta.text
	])


func _probar_caso_multiple() -> void:
	var items: Array[Dictionary] = [_objeto_de_prueba("Cofre A"), _objeto_de_prueba("Cofre B")]
	_lista._al_cambiar(items)
	_multiple_oculta_label_ok = not _etiqueta.visible
	print("Dos objetos: el label queda oculto mientras se elige (esperado true): %s" % _multiple_oculta_label_ok)


func _probar_elegir_uno() -> void:
	# Mismo estado que dejó _probar_caso_multiple: la lista de DOS objetos
	# sigue mostrada, _lista_botones tiene un botón por objeto.
	var boton_b: Button = _lista_botones.get_child(1)
	boton_b.pressed.emit()
	_elegir_uno_muestra_nombre_ok = _etiqueta.visible and _etiqueta.text == "Cofre B"
	print("Elegir 'Cofre B' de la lista muestra su nombre en el label (esperado true, 'Cofre B'): %s, %s" % [
		_etiqueta.visible, _etiqueta.text
	])


func _probar_volver() -> void:
	# El botón "Volver" es el último de la lista de acciones (ver
	# ListaInteraccion._mostrar_acciones) — con 2+ objetos en rango, la
	# acción "Probar" más "Volver" = 2 botones.
	var boton_volver: Button = _lista_botones.get_child(_lista_botones.get_child_count() - 1)
	boton_volver.pressed.emit()
	_volver_oculta_de_nuevo_ok = not _etiqueta.visible
	print("Volver a la lista de objetos vuelve a ocultar el label (esperado true): %s" % _volver_oculta_de_nuevo_ok)


func _informar() -> bool:
	var exito := _directo_muestra_nombre_ok and _multiple_oculta_label_ok \
		and _elegir_uno_muestra_nombre_ok and _volver_oculta_de_nuevo_ok
	print("PRUEBA LISTA INTERACCION ETIQUETA NOMBRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
