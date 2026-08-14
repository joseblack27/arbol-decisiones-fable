# =============================================================================
# Prueba de persistencia de CofresComponente.contenidos (ver GestorGuardado
# ._serializar_cofres/_restaurar_cofres) — mismo criterio de ronda completa
# guardar→perder en memoria→cargar que prueba_guardado_partida.gd, acotado a
# esto solo. Lista DENSA tras el refactor a componentes genéricos: ya no
# hay "posición" que preservar (ver CofresComponente), solo que el ítem
# sobreviva con su cantidad. Cubre:
#   1. El contenido sobrevive guardar/cargar, cantidad incluida.
#   2. Restaurar NO vuelve a sortear el botín inicial (sería un cofre
#      gratis con cada guardado/cargado).
#   3. Una partida guardada con el cofre VIEJO (formato Array, "una vez
#      por jugador") no revienta al cargar — bug real reportado, ver el
#      comentario grande en _restaurar_cofres.
#   godot --headless --path . --script res://pruebas/prueba_cofres_guardado.gd
# =============================================================================
extends SceneTree

const _ID_COFRE := "cofre_persistencia_de_prueba"

var _jugador
var _cofres: CofresComponente
var _gestor_guardado: Node
var _gestor_cofres: Node
var _hoja: DatosItem

var _sobrevive_guardar_y_cargar_ok := false
var _preserva_cantidad_ok := false
var _no_vuelve_a_sortear_al_restaurar_ok := false
var _partida_vieja_formato_array_no_revienta_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_guardar_y_cargar()
	_probar_partida_vieja_formato_array_no_revienta()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_cofres = _jugador.get_node("CofresComponente")

	_hoja = load("res://recursos/items/recursos/hoja_1.tres") as DatosItem

	# tabla_botin VACÍA a propósito: esta prueba es sobre la PERSISTENCIA
	# de lo que el jugador dejó, no sobre el sorteo inicial (ya cubierto en
	# prueba_cofre_abrir_local.gd) — así el contenido arranca vacío y lo
	# que aparezca después es inequívocamente lo que se guardó.
	var datos := DatosCofre.new()
	datos.id = _ID_COFRE
	datos.capacidad = 5
	_gestor_cofres = root.get_node("/root/GestorCofres")
	_gestor_cofres.catalogo.append(datos)

	_gestor_guardado = root.get_node("/root/GestorGuardado")


func _probar_guardar_y_cargar() -> void:
	var hoja_con_cantidad := _hoja.duplicate() as DatosItem
	hoja_con_cantidad.id_recurso = _hoja.resource_path
	hoja_con_cantidad.quantity = 7
	_cofres.agregar(_ID_COFRE, hoja_con_cantidad)

	_gestor_guardado.call("guardar_partida")
	_cofres.contenidos.clear()
	_gestor_guardado.call("cargar_partida")

	var contenido := _cofres.obtener_contenido(_ID_COFRE)
	print("La hoja sobrevive guardar/cargar (esperado 1): %d" % contenido.size())
	print("Es la hoja correcta (esperado true): %s" % (contenido.size() > 0 and contenido[0].name == "Hoja Verde"))
	_sobrevive_guardar_y_cargar_ok = contenido.size() == 1 and contenido[0].name == "Hoja Verde"

	print("Cantidad preservada (esperado 7): %s" % (contenido[0].quantity if contenido.size() > 0 else "<vacío>"))
	_preserva_cantidad_ok = contenido.size() > 0 and contenido[0].quantity == 7

	# Ninguna otra entrada se agregó sola (si _restaurar_cofres volviera a
	# sortear el botín inicial en vez de solo restaurar lo guardado, esto
	# fallaría en cuanto tabla_botin dejara de estar vacía en el futuro —
	# queda como red de seguridad explícita, no solo una inferencia).
	print("Ningún ítem de más apareció (esperado 1 en total): %d" % contenido.size())
	_no_vuelve_a_sortear_al_restaurar_ok = contenido.size() == 1


## Bug real reportado: "Cannot call method 'get_root' on a null value" —
## no, ESTE no es ese bug (ver prueba_panel_cofre.gd para ese). Este cubre
## el otro fix de la misma área: una partida guardada con el cofre VIEJO
## ("una vez por jugador") tenía "cofres" como Array (lista de ids ya
## abiertos), no un Dictionary — cargar esa partida reventaba con "Cannot
## convert argument 1 from Array to Dictionary" (_restaurar_cofres tipaba
## el parámetro a Dictionary). Reproduce ese archivo a mano y confirma que
## cargar_partida() no revienta, y que además NO borra lo que ya había en
## memoria — la guarda de _restaurar_cofres corta ANTES de contenidos.
## clear(), así que un archivo viejo/ilegible se omite, no se aplica vacío.
func _probar_partida_vieja_formato_array_no_revienta() -> void:
	_cofres.contenidos.clear()
	_cofres.agregar(_ID_COFRE, _hoja)

	var datos_viejos := {"cofres": ["cofre_viejo_formato_de_prueba"]}
	var archivo := FileAccess.open("user://partida.save", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos_viejos))
	archivo.close()

	_gestor_guardado.call("cargar_partida")

	var contenido := _cofres.obtener_contenido(_ID_COFRE)
	print("cargar_partida() con 'cofres' en formato Array viejo no revienta, y no borra lo ya cargado (esperado true): %s" % \
		(_hoja in contenido))
	_partida_vieja_formato_array_no_revienta_ok = _hoja in contenido


func _informar() -> bool:
	var exito := _sobrevive_guardar_y_cargar_ok and _preserva_cantidad_ok \
		and _no_vuelve_a_sortear_al_restaurar_ok and _partida_vieja_formato_array_no_revienta_ok
	print("  contenido sobrevive guardar/cargar: %s" % _sobrevive_guardar_y_cargar_ok)
	print("  cantidad preservada: %s" % _preserva_cantidad_ok)
	print("  no vuelve a sortear al restaurar: %s" % _no_vuelve_a_sortear_al_restaurar_ok)
	print("  partida vieja (formato Array) no revienta: %s" % _partida_vieja_formato_array_no_revienta_ok)
	print("PRUEBA COFRES GUARDADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
