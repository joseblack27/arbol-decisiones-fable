# =============================================================================
# Prueba: los 27 recursos DatosItem creados en recursos/items/ cargan bien,
# tienen sus campos básicos completos y su ícono existe (no quedó ninguno
# con la textura vacía por una ruta mal escrita).
#   godot --headless --path . --script res://pruebas/prueba_items_creados.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0

const RUTAS := [
	"res://recursos/items/consumibles/jeringa_adrenalina.tres",
	"res://recursos/items/consumibles/botiquin.tres",
	"res://recursos/items/consumibles/desfibrilador.tres",
	"res://recursos/items/consumibles/pocion_vida.tres",
	"res://recursos/items/consumibles/pastilla_blanca.tres",
	"res://recursos/items/consumibles/pildora_roja.tres",
	"res://recursos/items/consumibles/pocion_azul.tres",
	"res://recursos/items/consumibles/zanahoria.tres",
	"res://recursos/items/equipables/armadura_1.tres",
	"res://recursos/items/equipables/armadura_2.tres",
	"res://recursos/items/equipables/armadura_3.tres",
	"res://recursos/items/equipables/armadura_4.tres",
	"res://recursos/items/equipables/escudo.tres",
	"res://recursos/items/equipables/espada_luz_azul.tres",
	"res://recursos/items/equipables/accesorio_1.tres",
	"res://recursos/items/equipables/accesorio_2.tres",
	"res://recursos/items/equipables/accesorio_3.tres",
	"res://recursos/items/equipables/accesorio_4.tres",
	"res://recursos/items/recursos/bateria_1.tres",
	"res://recursos/items/recursos/bateria_7.tres",
	"res://recursos/items/recursos/bateria_8.tres",
	"res://recursos/items/recursos/hoja_1.tres",
	"res://recursos/items/recursos/hoja_2.tres",
	"res://recursos/items/recursos/ticket_1.tres",
	"res://recursos/items/recursos/ticket_2.tres",
	"res://recursos/items/recursos/ticket_3.tres",
	"res://recursos/items/recursos/ticket_4.tres",
]


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		return _informar()
	return false


func _informar() -> bool:
	var fallos: Array[String] = []
	for ruta in RUTAS:
		var item := load(ruta) as DatosItem
		if not item:
			fallos.append("%s -> no cargó como DatosItem" % ruta)
			continue
		if item.name.is_empty():
			fallos.append("%s -> sin nombre" % ruta)
		if item.icon == null:
			fallos.append("%s -> sin ícono (ruta de textura rota)" % ruta)
		if item.type == 3 and item.type_equippable == 0:
			fallos.append("%s -> equipable sin type_equippable asignado" % ruta)

	print("Recursos revisados: %d" % RUTAS.size())
	for f in fallos:
		print("FALLO: %s" % f)

	var exito := fallos.is_empty()
	print("PRUEBA ITEMS CREADOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
