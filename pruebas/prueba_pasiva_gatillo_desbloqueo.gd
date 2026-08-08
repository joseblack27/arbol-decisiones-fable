# =============================================================================
# Prueba del flujo de desbloqueo de una pasiva de GATILLO (por ítem especial,
# ver DatosItem.escena_pasiva / PasivasComponente / InventarioComponente
# .usar_item) — sin ninguna pasiva real todavía (esas llegan en
# prueba_pasiva_instinto_vengador.gd / prueba_pasiva_cosecha_de_vida.gd), solo
# la infraestructura: usar el ítem instancia PasivaBase, un segundo uso no
# duplica, y notificar=false (restaurar partida) no repite el aviso.
#   godot --headless --path . --script res://pruebas/prueba_pasiva_gatillo_desbloqueo.gd
# =============================================================================
extends SceneTree

const RUTA_PASIVA_PRUEBA := "res://pruebas/fixtures/PasivaDePrueba.tscn"

var _jugador
var _inventario
var _pasivas
var _bus
var _notificaciones := 0

var _instancia_al_usar_ok := false
var _dueño_correcto_ok := false
var _no_duplica_ok := false
var _consume_el_item_ok := false
var _notificacion_en_vivo_ok := false
var _sin_notificacion_restaurar_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_uso_desbloquea()
	_probar_segundo_uso_no_duplica()
	_probar_restaurar_sin_notificar()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_inventario = (load("res://componentes/InventarioComponente.gd") as GDScript).new()
	_inventario.name = "InventarioComponente"
	_jugador.add_child(_inventario)

	_pasivas = (load("res://componentes/PasivasComponente.gd") as GDScript).new()
	_pasivas.name = "PasivasComponente"
	_jugador.add_child(_pasivas)

	_bus = root.get_node("/root/BusEventos")
	_bus.pasiva_desbloqueada.connect(func(_e, _n, _d): _notificaciones += 1)


func _probar_uso_desbloquea() -> void:
	var item := DatosItem.new()
	item.name = "Tótem de prueba"
	item.type = Enums.Inventario.TipoItem.PASIVA
	item.can_use = true
	item.can_drop = true
	item.quantity = 1
	item.escena_pasiva = load(RUTA_PASIVA_PRUEBA) as PackedScene
	_inventario.items.append(item)

	_inventario.usar_item(item)

	var hijos_pasiva := 0
	for hijo in _pasivas.get_children():
		if hijo is PasivaBase:
			hijos_pasiva += 1
			_dueño_correcto_ok = hijo.entidad_dueña == _jugador
	print("Pasivas instanciadas tras usar el ítem (esperado 1): %d" % hijos_pasiva)
	print("Ruta registrada en gatillo_desbloqueadas (esperado true): %s" % \
		(RUTA_PASIVA_PRUEBA in _pasivas.gatillo_desbloqueadas))
	_instancia_al_usar_ok = hijos_pasiva == 1 and RUTA_PASIVA_PRUEBA in _pasivas.gatillo_desbloqueadas
	_consume_el_item_ok = not _inventario.items.has(item)
	print("El ítem se consume (una unidad, esperado true): %s" % _consume_el_item_ok)
	_notificacion_en_vivo_ok = _notificaciones == 1
	print("Notificación en vivo (esperado 1): %d" % _notificaciones)


func _probar_segundo_uso_no_duplica() -> void:
	# desbloquear_gatillo() llamado directo una segunda vez (simula un
	# segundo ítem igual, o un reintento) — no debe crear otra instancia.
	_pasivas.desbloquear_gatillo(RUTA_PASIVA_PRUEBA)
	var hijos_pasiva := 0
	for hijo in _pasivas.get_children():
		if hijo is PasivaBase:
			hijos_pasiva += 1
	print("Pasivas tras un segundo desbloqueo (esperado 1, no duplica): %d" % hijos_pasiva)
	_no_duplica_ok = hijos_pasiva == 1


func _probar_restaurar_sin_notificar() -> void:
	# Jugador NUEVO (simula una reconexión leyendo la partida guardada) —
	# GestorGuardado llamaría a esto con notificar=false para cada pasiva
	# ya conocida, sin repetir el aviso de pantalla.
	var jugador2 := CharacterBody2D.new()
	jugador2.add_to_group("jugadores")
	root.add_child(jugador2)
	var pasivas2 = (load("res://componentes/PasivasComponente.gd") as GDScript).new()
	pasivas2.name = "PasivasComponente"
	jugador2.add_child(pasivas2)

	var antes := _notificaciones
	pasivas2.desbloquear_gatillo(RUTA_PASIVA_PRUEBA, false)
	print("Notificaciones tras restaurar sin notificar (esperado sin cambio, %d): %d" % [antes, _notificaciones])
	_sin_notificacion_restaurar_ok = _notificaciones == antes and pasivas2.get_children().size() == 1


func _informar() -> bool:
	var exito := _instancia_al_usar_ok and _dueño_correcto_ok and _no_duplica_ok \
		and _consume_el_item_ok and _notificacion_en_vivo_ok and _sin_notificacion_restaurar_ok
	print("  usar el ítem instancia la pasiva: %s" % _instancia_al_usar_ok)
	print("  entidad_dueña queda correcta: %s" % _dueño_correcto_ok)
	print("  un segundo desbloqueo no duplica: %s" % _no_duplica_ok)
	print("  el ítem se consume: %s" % _consume_el_item_ok)
	print("  notificación sale en vivo: %s" % _notificacion_en_vivo_ok)
	print("  restaurar (notificar=false) no repite el aviso: %s" % _sin_notificacion_restaurar_ok)
	print("PRUEBA PASIVA GATILLO DESBLOQUEO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
