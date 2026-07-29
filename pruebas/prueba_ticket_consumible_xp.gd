# =============================================================================
# Prueba de que los tickets (recursos/items/recursos/ticket_1..4.tres) son
# consumibles que dan 100 de experiencia al usarse (pedido del usuario:
# "quiero hacer del item de tickets unos consumibles que de 100 de xp").
#
# Verifica:
#   1. Los 4 tickets cargan como CONSUMIBLE (type=2), can_use=true y
#      experiencia=100 — no quedó ninguno a medio convertir.
#   2. Usar un ticket real (InventarioComponente.usar_item) SÍ suma 100 a
#      ExperienciaComponente.xp_total (sin red: aplica directo, sin RPC).
#   3. Gasta una unidad de verdad (quantity baja) — no es un efecto
#      "gratis" que deja el ticket intacto.
#   4. Usarlo una SEGUNDA vez (con las unidades que le quedan) vuelve a
#      sumar 100 — no es un efecto de una sola vez por bug.
#   godot --headless --path . --script res://pruebas/prueba_ticket_consumible_xp.gd
# =============================================================================
extends SceneTree

const _RUTAS_TICKETS := [
	"res://recursos/items/recursos/ticket_1.tres",
	"res://recursos/items/recursos/ticket_2.tres",
	"res://recursos/items/recursos/ticket_3.tres",
	"res://recursos/items/recursos/ticket_4.tres",
]

var _jugador
## Sin tipar explícito (InventarioComponente/ExperienciaComponente/
## DatosItem): tipar estas variables acá hace que el script de entrada
## --script se cuelgue al arrancar (visto en vivo, reproducible) — mismo
## síntoma que la caché global de clases yéndose stale tras editar estas
## clases (ver otros comentarios de este proyecto sobre --headless
## --import), solo que acá en vez de un cast a "Nil" da un cuelgue
## directo. Sin tipo estático no hay nada que resolver contra esa caché.
var _inventario
var _experiencia
var _ticket
var _fotogramas := 0

var _los_4_son_consumibles_con_100_xp := false
var _usar_suma_100_xp := false
var _gasta_una_unidad_real := false
var _segundo_uso_vuelve_a_sumar := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_verificar_los_4_tickets()
			_montar()
		2:
			var xp_antes: int = _experiencia.xp_total
			var cantidad_antes: int = _ticket.quantity
			_inventario.usar_item(_ticket)
			_usar_suma_100_xp = _experiencia.xp_total == xp_antes + 100
			print("Usar el ticket suma 100 XP (esperado true): %s (xp %d -> %d)" % [
				_usar_suma_100_xp, xp_antes, _experiencia.xp_total])
			_gasta_una_unidad_real = _ticket.quantity == cantidad_antes - 1
			print("Gasta una unidad real (esperado true): %s (quantity %d -> %d)" % [
				_gasta_una_unidad_real, cantidad_antes, _ticket.quantity])
		3:
			var xp_antes: int = _experiencia.xp_total
			_inventario.usar_item(_ticket)
			_segundo_uso_vuelve_a_sumar = _experiencia.xp_total == xp_antes + 100
			print("Segundo uso vuelve a sumar 100 XP (esperado true): %s" % _segundo_uso_vuelve_a_sumar)
			return _informar()
	return false


func _verificar_los_4_tickets() -> void:
	_los_4_son_consumibles_con_100_xp = true
	for ruta in _RUTAS_TICKETS:
		var datos := load(ruta) as DatosItem
		var ok := datos.type == Enums.Inventario.TipoItem.CONSUMIBLE \
			and datos.can_use and datos.experiencia == 100
		print("%s: type=%d can_use=%s experiencia=%d (esperado CONSUMIBLE/true/100): %s" % [
			ruta, datos.type, datos.can_use, datos.experiencia, ok])
		_los_4_son_consumibles_con_100_xp = _los_4_son_consumibles_con_100_xp and ok


func _montar() -> void:
	_jugador = Node.new()
	root.add_child(_jugador)

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_jugador.add_child(_experiencia)

	_inventario = (load("res://componentes/InventarioComponente.gd") as GDScript).new()
	_inventario.name = "InventarioComponente"
	_jugador.add_child(_inventario)

	# Duplicado (no la referencia directa al .tres): usar_item()/quitar_una_
	# unidad() mutan "quantity" en el sitio — sin duplicar, correr esta
	# prueba dos veces seguidas iría gastando el mismo recurso compartido
	# en disco (mismo motivo que ya documenta InventarioComponente.
	# agregar_item()).
	_ticket = (load("res://recursos/items/recursos/ticket_1.tres") as DatosItem).duplicate()
	_ticket.quantity = 5


func _informar() -> bool:
	var exito := _los_4_son_consumibles_con_100_xp and _usar_suma_100_xp \
		and _gasta_una_unidad_real and _segundo_uso_vuelve_a_sumar
	print("PRUEBA TICKET CONSUMIBLE XP %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
