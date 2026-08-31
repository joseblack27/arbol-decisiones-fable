# =============================================================================
# Prueba de TiendaComponente — patrón RPC de "pedir → servidor valida →
# aplica → confirma solo al dueño" (mismo molde que MejorasComponente,
# ver prueba_lanzallamas_detiene_canal_por_servidor.gd para el mismo
# criterio de probar SIN transporte de red real).
#
# Bug de seguridad real encontrado y corregido acá: antes _pedir_comprar_red
# recibía el PRECIO como parámetro del cliente, y solo se validaba que no
# fuera negativo — un cliente modificado podía pedir precio=0 y llevarse
# cualquier ítem gratis. Ahora ni siquiera existe ese parámetro: el
# servidor vuelve a mirar el precio REAL en el catálogo de la tienda
# (DatosTienda.items_en_venta, por resource_path — mismo criterio que
# _vender_local ya usaba con DatosItem.valor). Esta prueba usa la tienda
# real del comerciante de ejemplo (Botiquín a 15 créditos) en vez de
# valores inventados, justamente para probar que el precio que importa es
# el del recurso, no el que diga cualquier llamador.
#
# multiplayer.get_remote_sender_id() devuelve 0 cuando _pedir_comprar_red()
# se llama DIRECTO (no vía RPC real, sin nadie conectado) — por eso
# peer_id_dueño = 0 simula "el pedido vino del dueño de verdad" y
# cualquier otro valor simula un sender ajeno (anti-spoof).
#   godot --headless --path . --script res://pruebas/prueba_tienda_comprar_item.gd
# =============================================================================
extends SceneTree

const _RUTA_TIENDA := "res://recursos/tienda/ejemplo_tienda_comerciante.tres"
const _PRECIO_REAL_BOTIQUIN := 15  # ver ejemplo_tienda_comerciante.tres.

var _jugador
var _creditos
var _inventario
var _tienda
var _item: DatosItem
var _ruta_item: String

var _sender_ajeno_rechaza_ok := false
var _creditos_insuficientes_rechaza_ok := false
var _item_fuera_de_catalogo_rechaza_ok := false
var _compra_valida_usa_precio_real_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno()
	_probar_creditos_insuficientes()
	_probar_item_fuera_de_catalogo()
	_probar_compra_valida()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	_creditos = _jugador.get_node("CreditosComponente")
	_inventario = _jugador.get_node("InventarioComponente")
	_tienda = _jugador.get_node("TiendaComponente")
	_creditos.agregar_creditos(100)

	_item = load("res://recursos/items/consumibles/botiquin.tres") as DatosItem
	_ruta_item = _item.resource_path


func _cantidad_en_inventario() -> int:
	var total := 0
	for item: DatosItem in _inventario.items:
		if item.name == _item.name:
			total += 1
	return total


func _probar_sender_ajeno() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	_tienda._pedir_comprar_red(_RUTA_TIENDA, _ruta_item)
	_sender_ajeno_rechaza_ok = _creditos.obtener_creditos() == 100 and _cantidad_en_inventario() == 0
	print("Sender que no es el dueño rechaza la compra (esperado true): %s" % _sender_ajeno_rechaza_ok)


func _probar_creditos_insuficientes() -> void:
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.
	_creditos._fijar_creditos_local(10)  # menos que el precio real (15).
	_tienda._pedir_comprar_red(_RUTA_TIENDA, _ruta_item)
	_creditos_insuficientes_rechaza_ok = _creditos.obtener_creditos() == 10 and _cantidad_en_inventario() == 0
	print("Créditos insuficientes (para el precio REAL) rechaza la compra (esperado true): %s" \
		% _creditos_insuficientes_rechaza_ok)
	_creditos._fijar_creditos_local(100)  # deja el saldo listo para el resto de la prueba.


## Ítem real, pero que esa tienda puntual no vende (Espada de Luz Azul no
## está en el catálogo del comerciante de ejemplo) — antes de este arreglo
## esto ni se validaba (el precio lo ponía el cliente); ahora se rechaza
## porque no aparece en items_en_venta de esa DatosTienda.
func _probar_item_fuera_de_catalogo() -> void:
	var item_ajeno := load("res://recursos/items/equipables/espada_luz_azul.tres") as DatosItem
	_tienda._pedir_comprar_red(_RUTA_TIENDA, item_ajeno.resource_path)
	_item_fuera_de_catalogo_rechaza_ok = _creditos.obtener_creditos() == 100
	print("Ítem que esa tienda no vende se rechaza (esperado true): %s" % _item_fuera_de_catalogo_rechaza_ok)


func _probar_compra_valida() -> void:
	_tienda._pedir_comprar_red(_RUTA_TIENDA, _ruta_item)
	_compra_valida_usa_precio_real_ok = _creditos.obtener_creditos() == 100 - _PRECIO_REAL_BOTIQUIN \
		and _cantidad_en_inventario() == 1
	print("Compra válida descuenta el precio REAL del catálogo (100 -> %d) y agrega el ítem (esperado true): %s" \
		% [100 - _PRECIO_REAL_BOTIQUIN, _compra_valida_usa_precio_real_ok])


func _informar() -> bool:
	var exito := _sender_ajeno_rechaza_ok and _creditos_insuficientes_rechaza_ok \
		and _item_fuera_de_catalogo_rechaza_ok and _compra_valida_usa_precio_real_ok
	print("PRUEBA TIENDA COMPRAR ITEM %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
