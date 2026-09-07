# =============================================================================
# Prueba del Minero (mirror de prueba_lenador_recorrido_completo.gd — ver ese
# archivo para el porqué completo de cada decisión de la prueba). Deja que
# GestorMinero arme todo tal cual lo hace en el servidor real
# (GestorNiveles.preparar_servidor() dispara GestorMinero._al_nivel_cargado,
# que crea la única instancia de Minero.tscn) en vez de armar niveles de
# mentira a mano.
#
# A diferencia del Leñador, el Minero nunca cruza de nivel (mina y almacén
# viven los dos en NivelMina) y su máquina de estados no tiene un estado
# "en casa" propio: vuelve directo a BUSCANDO_VETA después de depositar, así
# que "terminó" se mide como "vio la veta agotada alguna vez Y ya depositó Y
# volvió a estar buscando/esperando la próxima" en vez de un estado de reposo
# dedicado.
#   godot --headless --path . --script res://pruebas/prueba_minero_recorrido_completo.gd
# =============================================================================
extends SceneTree

const _MAX_FOTOGRAMAS := 4000
## Minero.Estado.BUSCANDO_VETA / ESPERANDO_VETA — los dos primeros del enum
## (=0 y =1). Sin tipar "Minero" como referencia estática acá (mismo
## criterio ya establecido en esta suite).
const _ESTADO_BUSCANDO_VETA := 0
const _ESTADO_ESPERANDO_VETA := 1

var _fotogramas := 0
var _gm
var _minero
var _veta
var _vio_veta_agotada := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _minero == null:
		_minero = _buscar_minero()
	if _minero == null and _fotogramas < 60:
		return false  # add_child() dentro de preparar_servidor() ya lo creó; margen chico por las dudas.

	if _veta and _veta.esta_agotado():
		_vio_veta_agotada = true

	var estado_reposo: bool = _minero != null \
			and (_minero._estado == _ESTADO_BUSCANDO_VETA or _minero._estado == _ESTADO_ESPERANDO_VETA)
	var terminado: bool = _minero != null and _vio_veta_agotada \
			and not _gm.almacen_replicado.is_empty() and estado_reposo
	if terminado or _fotogramas >= _MAX_FOTOGRAMAS:
		return _verificar()
	return false


func _montar() -> void:
	# Arrancar sin ningún user://almacen_minero.save de una corrida anterior
	# en esta máquina — GestorMinero._al_nivel_cargado() lo carga solo, y un
	# archivo viejo con contenido haría que _verificar() mida mineral que no
	# depositó ESTA corrida.
	if FileAccess.file_exists("user://almacen_minero.save"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://almacen_minero.save"))

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	var gn := root.get_node("/root/GestorNiveles")
	_gm = root.get_node("/root/GestorMinero")
	_gm._almacen.clear()
	_gm.almacen_replicado.clear()

	var contenedor_nivel := Node.new()
	root.add_child(contenedor_nivel)
	gn.registrar(contenedor_nivel, null)

	var contenedor_errantes := Node2D.new()
	root.add_child(contenedor_errantes)
	gn.registrar_errantes(contenedor_errantes)

	# Mismo nivel_inicial que ServidorDedicado.gd en el juego real — dispara
	# GestorMinero._al_nivel_cargado(), que arma todo lo demás solo.
	gn.preparar_servidor("res://escenas/niveles/NivelMina.tscn")

	_veta = contenedor_nivel.get_node("NivelMina/Decoraciones/VetaCristal1")


func _buscar_minero() -> Node:
	var contenedor: Node = root.get_node("/root/GestorNiveles").contenedor_errantes()
	if contenedor and contenedor.get_child_count() > 0:
		return contenedor.get_child(0)
	return null


func _verificar() -> bool:
	print("Fotogramas usados: %d" % _fotogramas)

	var minero_existe := _minero != null
	print("El minero se creó solo (esperado true): %s" % minero_existe)

	print("Alguna veta quedó agotada en algún momento (esperado true): %s" % _vio_veta_agotada)

	var total_mineral := 0
	for cantidad in _gm.almacen_replicado.values():
		total_mineral += int(cantidad)
	print("Mineral en el almacén compartido tras el recorrido (esperado >= 1): %d" % total_mineral)

	var volvio_a_buscar: bool = minero_existe \
		and (_minero._estado == _ESTADO_BUSCANDO_VETA or _minero._estado == _ESTADO_ESPERANDO_VETA)
	print("El minero volvió a buscar la próxima veta (esperado true): %s" % volvio_a_buscar)

	var exito := minero_existe and _vio_veta_agotada and total_mineral >= 1 and volvio_a_buscar
	print("PRUEBA MINERO RECORRIDO COMPLETO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
