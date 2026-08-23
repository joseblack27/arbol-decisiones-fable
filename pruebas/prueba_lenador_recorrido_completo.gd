# =============================================================================
# Prueba del pedido del usuario: "un npc leñador, que salga de la ciudad,
# hacia la pradera para cortar arboles y vuelva a la ciudad y deje la madera
# en un cofre" — y, tras el rediseño ("que el leñador use el mismo tp que
# uso yo para moverme por los mapas"), UNA sola instancia que nunca se
# reparenta, solo cambia de posición al cruzar (ver Lenador._cruzar_a_*).
#
# Deja que GestorLenador arme todo tal cual lo hace en el servidor real
# (GestorNiveles.preparar_servidor() dispara GestorLenador._al_nivel_cargado,
# que fuerza cargar Ciudad y Pradera, las marca siempre-activas, y crea la
# única instancia de Lenador.tscn) en vez de armar niveles de mentira a
# mano — así la prueba ejercita el camino REAL de principio a fin, con los
# nombres de nodo reales (PortalAPradera, Objetos/AlmacenLenador1,
# Decoraciones) que Lenador._ready() resuelve.
#
# No se verifica "el árbol quedó agotado" AL FINAL: con el cooldown bajado a
# 10s (pedido del usuario), una corrida larga puede alcanzar a verlo
# respawnear de nuevo antes de terminar — se registra en cambio si estuvo
# agotado ALGUNA VEZ durante la corrida (_vio_arbol_agotado).
#
# Deja correr fotogramas físicos REALES (no todo en un solo _process(), ver
# el "return false" de abajo) — Lenador._physics_process corre solo, como
# cualquier nodo normal, y es lo que hace avanzar la máquina de estados Y lo
# que deja que MovimientoComponente._physics_process (un nodo aparte) mueva
# el cuerpo de verdad. Mismo criterio que las pruebas de araña/lobo/ratón:
# "más de 1000 fotogramas", ver correr_todas.sh.
#   godot --headless --path . --script res://pruebas/prueba_lenador_recorrido_completo.gd
# =============================================================================
extends SceneTree

const _MAX_FOTOGRAMAS := 4000
## Lenador.Estado.ESPERANDO_CASA — el primero del enum (=0). Sin tipar
## "Lenador" como referencia estática acá (mismo criterio ya establecido en
## esta suite: un --script referenciando un class_name recién creado como
## TIPO puede disparar un error de compilación en cadena sobre el propio
## Lenador.gd al compilarlo como dependencia).
const _ESTADO_ESPERANDO_CASA := 0

var _fotogramas := 0
var _gl
var _lenador
var _arbol
var _vio_arbol_agotado := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _lenador == null:
		_lenador = _buscar_lenador()
	if _lenador == null and _fotogramas < 60:
		return false  # add_child() dentro de preparar_servidor() ya lo creó; margen chico por las dudas.

	if _arbol and _arbol.esta_agotado():
		_vio_arbol_agotado = true


	# "Almacén no vacío" no alcanza para saber que YA hubo una tala real en
	# esta corrida — sirve como filtro, pero la señal confiable es haber
	# visto al árbol agotado en algún momento (ver _vio_arbol_agotado): el
	# almacén puede venir con contenido de una corrida anterior si quedó un
	# user://almacen_lenador.save en el disco de la máquina (persistencia
	# real, ver GestorLenador._cargar_desde_disco()).
	var terminado: bool = _lenador != null and _vio_arbol_agotado \
			and not _gl.almacen_replicado.is_empty() \
			and _lenador._estado == _ESTADO_ESPERANDO_CASA
	if terminado or _fotogramas >= _MAX_FOTOGRAMAS:
		return _verificar()
	return false


func _montar() -> void:
	# Arrancar sin ningún user://almacen_lenador.save de una corrida
	# anterior en esta máquina — GestorLenador._al_nivel_cargado() lo carga
	# solo, y un archivo viejo con contenido haría que _verificar() mida
	# madera que no depositó ESTA corrida.
	if FileAccess.file_exists("user://almacen_lenador.save"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://almacen_lenador.save"))

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	var gn := root.get_node("/root/GestorNiveles")
	_gl = root.get_node("/root/GestorLenador")
	_gl._almacen.clear()
	_gl.almacen_replicado.clear()

	var contenedor_nivel := Node.new()
	root.add_child(contenedor_nivel)
	gn.registrar(contenedor_nivel, null)

	var contenedor_errantes := Node2D.new()
	root.add_child(contenedor_errantes)
	gn.registrar_errantes(contenedor_errantes)

	# Mismo nivel_inicial que ServidorDedicado.gd en el juego real — dispara
	# GestorLenador._al_nivel_cargado(), que arma todo lo demás solo.
	gn.preparar_servidor("res://escenas/niveles/NivelPradera.tscn")

	_arbol = contenedor_nivel.get_node("NivelPradera/Decoraciones/ArbolTalable1")


func _buscar_lenador() -> Node:
	var contenedor: Node = root.get_node("/root/GestorNiveles").contenedor_errantes()
	if contenedor and contenedor.get_child_count() > 0:
		return contenedor.get_child(0)
	return null


func _verificar() -> bool:
	print("Fotogramas usados: %d" % _fotogramas)

	var lenador_existe := _lenador != null
	print("El leñador se creó solo (esperado true): %s" % lenador_existe)

	print("El árbol quedó agotado en algún momento (esperado true): %s" % _vio_arbol_agotado)

	var total_lena := 0
	for cantidad in _gl.almacen_replicado.values():
		total_lena += int(cantidad)
	print("Madera en el almacén compartido tras el recorrido (esperado >= 1): %d" % total_lena)

	var volvio_a_casa: bool = lenador_existe and _lenador._estado == _ESTADO_ESPERANDO_CASA
	print("El leñador volvió a ESPERANDO_CASA (esperado true): %s" % volvio_a_casa)

	var exito := lenador_existe and _vio_arbol_agotado and total_lena >= 1 and volvio_a_casa
	print("PRUEBA LEÑADOR RECORRIDO COMPLETO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
