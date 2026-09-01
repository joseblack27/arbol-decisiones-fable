# =============================================================================
# Prueba de la lista de características del panel de detalle de inventario:
#   1. Un ítem SIN bonos (bonos == null) no agrega ninguna fila.
#   2. Un ítem CON bonos agrega una fila por cada atributo != 0, con el
#      nombre a la izquierda y el valor a la derecha, y NO agrega fila para
#      los atributos en 0 (p. ej. tenacidad = 0 en este caso).
#   3. Al seleccionar otro ítem, la lista anterior se limpia (sin arrastrar
#      filas del ítem previo).
#   4. Un ítem con conjunto muestra el nombre del conjunto arriba (junto a
#      Tipo/Cantidad) y una fila indentada por tramo en la lista de abajo,
#      mostrando cuántas piezas hacen falta (pedido del usuario: "sets de
#      equipo" 31 ago 2026, reubicado el 1 sep 2026 tras pedir que el
#      nombre del conjunto vaya arriba y las filas queden con sangría real).
#   godot --headless --path . --script res://pruebas/prueba_caracteristicas_item.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _armadura: DatosItem
var _pocion: DatosItem
var _pieza_conjunto: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_armadura = DatosItem.new()
	_armadura.name = "Armadura de Prueba"
	_armadura.type = 3  # EQUIPABLE
	_armadura.can_equip = true
	var bonos := AtributosBase.new()
	bonos.defensa = 10.0
	bonos.tenacidad = 0.0  # debe quedar fuera de la lista
	bonos.fortaleza = 5.0
	_armadura.bonos = bonos

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba"
	_pocion.type = 2  # CONSUMIBLE

	var conjunto := ConjuntoDatos.new()
	conjunto.nombre = "Conjunto de Prueba"
	var tramo_2 := TramoConjunto.new()
	tramo_2.piezas_requeridas = 2
	tramo_2.bonos = AtributosBase.new()
	var tramo_4 := TramoConjunto.new()
	tramo_4.piezas_requeridas = 4
	tramo_4.bonos = AtributosBase.new()
	conjunto.tramos = [tramo_2, tramo_4]
	_pieza_conjunto = DatosItem.new()
	_pieza_conjunto.name = "Pieza de Prueba"
	_pieza_conjunto.type = 3  # EQUIPABLE
	_pieza_conjunto.conjunto = conjunto

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _informar() -> bool:
	var slot_armadura := (load("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn") as PackedScene).instantiate()
	slot_armadura.item_data = _armadura
	root.add_child(slot_armadura)

	_panel._update_details(slot_armadura)
	var filas_con_bonos: int = _panel.vbox_caracteristicas.get_child_count()
	var texto_defensa := ""
	var texto_fortaleza := ""
	for fila in _panel.vbox_caracteristicas.get_children():
		var nombre: String = fila.get_child(0).text
		var valor: String = fila.get_child(1).text
		if nombre == "Defensa":
			texto_defensa = valor
		elif nombre == "Fortaleza":
			texto_fortaleza = valor
	print("Filas con bonos (esperado 2: Defensa y Fortaleza, sin Tenacidad): %d" % filas_con_bonos)
	print("Valor mostrado de Defensa (esperado '+10'): %s" % texto_defensa)
	print("Valor mostrado de Fortaleza (esperado '+5'): %s" % texto_fortaleza)

	var slot_pocion := (load("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn") as PackedScene).instantiate()
	slot_pocion.item_data = _pocion
	root.add_child(slot_pocion)
	_panel._update_details(slot_pocion)
	var filas_sin_bonos: int = _panel.vbox_caracteristicas.get_child_count()
	print("Filas al seleccionar ítem sin bonos (esperado 0): %d" % filas_sin_bonos)

	var slot_conjunto := (load("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn") as PackedScene).instantiate()
	slot_conjunto.item_data = _pieza_conjunto
	root.add_child(slot_conjunto)
	_panel._update_details(slot_conjunto)

	var nombre_arriba_ok: bool = _panel.conjunto_label.visible and _panel.conjunto_value.visible \
		and _panel.conjunto_value.text == "Conjunto de Prueba"
	print("El nombre del conjunto aparece arriba, junto a Tipo/Cantidad (esperado true, obtenido '%s'): %s" % [
		_panel.conjunto_value.text, nombre_arriba_ok])

	# Espaciador + un tramo de 2 + un tramo de 4 = 3 filas (sin bonos != 0 en
	# ninguno de los dos tramos de esta prueba, no agregan filas extra).
	# Cada fila de tramo es un HBoxContainer directo (nombre/valor), SIN
	# sangría — pedido explícito del usuario tras ver una sangría de 12px
	# que se había agregado antes: "que aparezcan todo a la izquierda asi
	# como las estadisticas de arriba", mismo margen que las filas de
	# arriba. Sin nada equipado (GestorEquipo cae a su respaldo vacío en
	# --script), ambos tramos muestran "(0/N)".
	var filas_conjunto: Array = _panel.vbox_caracteristicas.get_children()
	var sin_titulo_ok: bool = filas_conjunto.size() == 3 and filas_conjunto[0] is Control \
		and not (filas_conjunto[0] is HBoxContainer)
	var fila_tramo_2: HBoxContainer = filas_conjunto[1]
	var fila_tramo_4: HBoxContainer = filas_conjunto[2]
	var tramo_2_nombre: String = (fila_tramo_2.get_child(0) as Label).text
	var tramo_2_texto: String = (fila_tramo_2.get_child(1) as Label).text
	var tramo_4_texto: String = (fila_tramo_4.get_child(1) as Label).text
	var sin_sangria_ok: bool = not (filas_conjunto[1] is MarginContainer)
	var tramos_ok: bool = tramo_2_nombre == "2 piezas" and tramo_2_texto == "(0/2)" and tramo_4_texto == "(0/4)"
	print("Sin título repetido dentro de la lista (esperado true, %d filas): %s" % [filas_conjunto.size(), sin_titulo_ok])
	print("Filas de tramo SIN sangría, alineadas como las estadísticas de arriba (esperado true): %s" % sin_sangria_ok)
	print("Tramos muestran piezas faltantes (esperado '2 piezas'/'(0/2)' / '(0/4)', obtenido '%s'/'%s' / '%s'): %s" % [
		tramo_2_nombre, tramo_2_texto, tramo_4_texto, tramos_ok])

	var exito: bool = filas_con_bonos == 2 \
		and texto_defensa == "+10" \
		and texto_fortaleza == "+5" \
		and filas_sin_bonos == 0 \
		and nombre_arriba_ok and sin_titulo_ok and sin_sangria_ok and tramos_ok
	print("PRUEBA CARACTERISTICAS ITEM %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
