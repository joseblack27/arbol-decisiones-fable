# =============================================================================
# Prueba de CofresComponente — lógica pura (ver prueba_casilla_objeto_
# arrastre.gd para el arrastre real vía UI). Lista DENSA tras el refactor a
# componentes genéricos (ver ese archivo): capacidad es un TOPE de cuántos
# ítems puede haber, no una grilla de casillas fijas — pedido del usuario:
# "no quiero slots precreados". Cubre:
#   1. obtener_contenido() siembra la primera vez, respetando la
#      probabilidad de cada entrada Y la capacidad como tope (no como
#      tamaño fijo — con capacidad=2 y 3 entradas que pasan, solo entran 2).
#   2. Pedirlo de nuevo devuelve la MISMA referencia (no vuelve a sortear).
#   3. agregar() respeta la capacidad (false si ya está lleno); quitar()
#      saca por REFERENCIA, no por índice.
#   4. id vacío o cofre inexistente en el catálogo no revienta (arranca
#      vacío, capacidad de respaldo 20).
#   5. capacidad = -1 significa SIN LÍMITE: la siembra no corta y agregar()
#      nunca rechaza.
#   godot --headless --path . --script res://pruebas/prueba_cofre_abrir_local.gd
# =============================================================================
extends SceneTree

var _jugador
var _cofres: CofresComponente
var _gestor_cofres: Node
var _pocion: DatosItem
var _hoja: DatosItem

var _siembra_respeta_probabilidad_y_capacidad_ok := false
var _misma_referencia_no_vuelve_a_sortear_ok := false
var _agregar_respeta_capacidad_ok := false
var _quitar_por_referencia_ok := false
var _id_inexistente_no_revienta_ok := false
var _capacidad_sin_limite_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_siembra_inicial()
	_probar_misma_referencia()
	_probar_agregar_y_quitar()
	_probar_id_inexistente()
	_probar_capacidad_sin_limite()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_cofres = _jugador.get_node("CofresComponente")

	_pocion = load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	_hoja = load("res://recursos/items/recursos/hoja_1.tres") as DatosItem

	# 3 entradas de probabilidad 1.0 (siempre entran) + 1 de probabilidad
	# 0.0 (nunca) — con capacidad=2, la siembra debe cortar apenas junta 2,
	# sin importar que la tabla tenga más entradas "ganadoras" atrás.
	var siempre_a := LootDrop.new()
	siempre_a.item = _pocion
	siempre_a.probabilidad = 1.0
	var nunca := LootDrop.new()
	nunca.item = _hoja
	nunca.probabilidad = 0.0
	var siempre_b := LootDrop.new()
	siempre_b.item = _pocion
	siempre_b.probabilidad = 1.0
	var siempre_c := LootDrop.new()
	siempre_c.item = _pocion
	siempre_c.probabilidad = 1.0

	var datos := DatosCofre.new()
	datos.id = "cofre_local_de_prueba"
	datos.capacidad = 2
	datos.tabla_botin = [siempre_a, nunca, siempre_b, siempre_c] as Array[LootDrop]
	_gestor_cofres = root.get_node("/root/GestorCofres")
	_gestor_cofres.catalogo.append(datos)


func _probar_siembra_inicial() -> void:
	var contenido := _cofres.obtener_contenido("cofre_local_de_prueba")
	print("La capacidad corta la siembra como TOPE, no como tamaño fijo (esperado 2): %d" % contenido.size())
	print("La hoja (probabilidad 0.0) nunca entra (esperado true): %s" % (not _hoja in contenido))
	_siembra_respeta_probabilidad_y_capacidad_ok = contenido.size() == 2 and not (_hoja in contenido)


func _probar_misma_referencia() -> void:
	var primera := _cofres.obtener_contenido("cofre_local_de_prueba")
	primera[0] = _hoja  # mutación directa, para comprobar que es la MISMA array.
	var segunda := _cofres.obtener_contenido("cofre_local_de_prueba")
	print("obtener_contenido() de nuevo devuelve la MISMA referencia (esperado true): %s" % \
		(segunda[0] == _hoja))
	_misma_referencia_no_vuelve_a_sortear_ok = segunda[0] == _hoja


func _probar_agregar_y_quitar() -> void:
	# Ya hay 2 (el paso anterior dejó [hoja, poción]) y la capacidad es 2 —
	# agregar() debe rechazar sin tocar nada.
	var lleno: bool = _cofres.agregar("cofre_local_de_prueba", _hoja)
	print("agregar() rechaza cuando ya está lleno (esperado false): %s" % lleno)
	print("El contenido no cambió de tamaño al rechazar (esperado 2): %d" % \
		_cofres.obtener_contenido("cofre_local_de_prueba").size())
	_agregar_respeta_capacidad_ok = not lleno and _cofres.obtener_contenido("cofre_local_de_prueba").size() == 2

	# quitar() por REFERENCIA (no por índice) — libera lugar.
	# "quito_bien" se captura ACÁ, antes del agregar() de abajo: obtener_
	# contenido() siempre devuelve la MISMA array — si se comparara
	# después de volver a agregar la hoja, ese mismo agregar() ya la
	# habría vuelto a meter en esa array, dando un falso "no se quitó".
	_cofres.quitar("cofre_local_de_prueba", _hoja)
	var quito_bien: bool = not (_hoja in _cofres.obtener_contenido("cofre_local_de_prueba"))
	print("quitar() saca la hoja por referencia (esperado true): %s" % quito_bien)
	var con_lugar: bool = _cofres.agregar("cofre_local_de_prueba", _hoja)
	print("agregar() funciona una vez que hay lugar (esperado true): %s" % con_lugar)
	_quitar_por_referencia_ok = quito_bien and con_lugar


func _probar_id_inexistente() -> void:
	var contenido := _cofres.obtener_contenido("id_que_no_existe_en_ningun_catalogo")
	print("Cofre sin definición en el catálogo no revienta, arranca vacío (esperado 0): %d" % contenido.size())
	var tope := _cofres.capacidad("id_que_no_existe_en_ningun_catalogo")
	print("Capacidad de respaldo (esperado 20): %d" % tope)
	_id_inexistente_no_revienta_ok = contenido.size() == 0 and tope == 20


## capacidad = -1: la siembra no debe cortar (entran las 3 entradas
## "siempre", no solo 2) y agregar() nunca debe rechazar por llenarse.
func _probar_capacidad_sin_limite() -> void:
	var siempre_a := LootDrop.new()
	siempre_a.item = _pocion
	siempre_a.probabilidad = 1.0
	var siempre_b := LootDrop.new()
	siempre_b.item = _pocion
	siempre_b.probabilidad = 1.0
	var siempre_c := LootDrop.new()
	siempre_c.item = _pocion
	siempre_c.probabilidad = 1.0

	var datos := DatosCofre.new()
	datos.id = "cofre_sin_limite_de_prueba"
	datos.capacidad = -1
	datos.tabla_botin = [siempre_a, siempre_b, siempre_c] as Array[LootDrop]
	_gestor_cofres.catalogo.append(datos)

	var contenido := _cofres.obtener_contenido("cofre_sin_limite_de_prueba")
	print("Con capacidad=-1 la siembra no corta (esperado 3): %d" % contenido.size())
	var siembra_ok: bool = contenido.size() == 3

	var agregado: bool = _cofres.agregar("cofre_sin_limite_de_prueba", _hoja)
	print("agregar() nunca rechaza con capacidad=-1 (esperado true): %s" % agregado)
	_capacidad_sin_limite_ok = siembra_ok and agregado


func _informar() -> bool:
	var exito := _siembra_respeta_probabilidad_y_capacidad_ok and _misma_referencia_no_vuelve_a_sortear_ok \
		and _agregar_respeta_capacidad_ok and _quitar_por_referencia_ok and _id_inexistente_no_revienta_ok \
		and _capacidad_sin_limite_ok
	print("  siembra inicial respeta probabilidad y capacidad como tope: %s" % _siembra_respeta_probabilidad_y_capacidad_ok)
	print("  misma referencia, no vuelve a sortear: %s" % _misma_referencia_no_vuelve_a_sortear_ok)
	print("  agregar() respeta la capacidad: %s" % _agregar_respeta_capacidad_ok)
	print("  quitar() por referencia: %s" % _quitar_por_referencia_ok)
	print("  id inexistente no revienta: %s" % _id_inexistente_no_revienta_ok)
	print("  capacidad = -1 (sin límite): %s" % _capacidad_sin_limite_ok)
	print("PRUEBA COFRE ABRIR LOCAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
