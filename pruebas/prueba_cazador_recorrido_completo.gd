# =============================================================================
# Prueba del pedido del usuario: "un npc cazador, que caze ratones y deje
# los recursos en el mismo cofre del leñador" — combate REAL a distancia
# (flechas cada 1s, no un kill instantáneo como el leñador con los
# árboles), compartiendo el pool de Ratones de SpawnerMobs.
#
# Mismo criterio que prueba_lenador_recorrido_completo.gd: deja que
# GestorCazador arme todo tal cual lo hace en el servidor real
# (GestorNiveles.preparar_servidor() dispara GestorCazador._al_nivel_
# cargado igual que GestorLenador._al_nivel_cargado, ambos escuchando la
# misma señal nivel_cargado) — así la prueba ejercita el camino REAL de
# principio a fin. Deja correr fotogramas físicos REALES (no todo en un
# solo _process()) — Cazador._physics_process corre solo, como cualquier
# nodo normal.
#
# Se agrega un jugador de prueba (a diferencia de prueba_lenador_
# recorrido_completo, que no necesita ninguno) específicamente para poder
# verificar que ExperienciaComponenteNoOp corta el fallback de Enemigo.
# _otorgar_xp() a GestorExperiencia — sin un jugador real en el árbol, ese
# fallback no tendría a quién beneficiar por error, y el caso no se
# probaría de verdad.
#   godot --headless --path . --script res://pruebas/prueba_cazador_recorrido_completo.gd
# =============================================================================
extends SceneTree

const _MAX_FOTOGRAMAS := 4000
## Cazador.Estado.ESPERANDO_CASA — el primero del enum (=0). Sin tipar
## "Cazador" como referencia estática acá (mismo criterio ya establecido en
## esta suite, ver prueba_lenador_recorrido_completo.gd: un --script
## referenciando un class_name recién creado como TIPO puede disparar un
## error de compilación en cadena sobre el propio Cazador.gd).
const _ESTADO_ESPERANDO_CASA := 0

var _fotogramas := 0
var _gl
var _cazador
var _jugador
var _xp_inicial_jugador := 0
var _vio_raton_muerto := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _cazador == null:
		_cazador = _buscar_cazador()
	if _cazador == null and _fotogramas < 60:
		return false  # add_child() dentro de preparar_servidor() ya lo creó; margen chico por las dudas.

	if not _vio_raton_muerto and _algun_raton_muerto():
		_vio_raton_muerto = true

	var terminado: bool = _cazador != null and _vio_raton_muerto \
			and not _gl.almacen_replicado.is_empty() \
			and _cazador._estado == _ESTADO_ESPERANDO_CASA
	if terminado or _fotogramas >= _MAX_FOTOGRAMAS:
		return _verificar()
	return false


func _montar() -> void:
	# Arrancar sin ningún user://almacen_lenador.save de una corrida
	# anterior en esta máquina — mismo motivo que prueba_lenador_recorrido_
	# completo.gd.
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

	# Algunos mobs de la Pradera (ej. Arquero Esqueleto) pueden disparar
	# proyectiles propios durante la corrida — Proyectil._spawnear_efecto_
	# impacto() asume que hay un current_scene válido para colgar efectos de
	# impacto (veneno, etc.), igual que en el juego real (Mundo.tscn).
	var escena_raiz := Node2D.new()
	root.add_child(escena_raiz)
	current_scene = escena_raiz

	# Jugador de prueba, sin agregarlo a "jugadores" un peer real — solo
	# para leer su XP y confirmar que se quedó en 0 (ver cabecera).
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	var experiencia = _jugador.get_node_or_null("ExperienciaComponente")
	_xp_inicial_jugador = experiencia.xp_total if experiencia else 0

	# Mismo nivel_inicial que ServidorDedicado.gd en el juego real — dispara
	# GestorLenador._al_nivel_cargado Y GestorCazador._al_nivel_cargado
	# (ambos escuchan la misma señal), que arman todo lo demás solos.
	gn.preparar_servidor("res://escenas/niveles/NivelPradera.tscn")


## Sin "is Cazador" a propósito — mismo motivo que prueba_lenador_recorrido_
## completo.gd evita tipar Lenador/ObjetoRecolectable como TIPO estático en
## el propio script de prueba (ver ese comentario): acá, con Leñador Y
## Cazador spawneando los dos en el mismo contenedor_errantes() (ambos
## GestorLenador/GestorCazador escuchan la misma señal nivel_cargado), ni
## siquiera alcanza con get_child(0) — hace falta identificarlo por nombre
## de nodo, que es estable (Cazador.tscn tiene su raíz llamada "Cazador").
func _buscar_cazador() -> Node:
	var contenedor: Node = root.get_node("/root/GestorNiveles").contenedor_errantes()
	if contenedor == null:
		return null
	return contenedor.get_node_or_null("Cazador")


## Sin "is EnemigoRaton" por el mismo motivo — alcanza con duck-typing
## (esta_muerto() existe en cualquier Enemigo) porque en este escenario
## aislado (sin jugadores reales, sin otro combate posible) el único que
## puede matar algo acá es el propio Cazador, y el propio Cazador.gd (un
## script de JUEGO, no de prueba, sin el mismo problema de compilación) ya
## filtra por Ratón puertas adentro.
func _algun_raton_muerto() -> bool:
	for nodo in get_nodes_in_group("enemigos"):
		if nodo.has_method("esta_muerto") and nodo.esta_muerto():
			return true
	return false


func _verificar() -> bool:
	print("Fotogramas usados: %d" % _fotogramas)

	var cazador_existe := _cazador != null
	print("El cazador se creó solo (esperado true): %s" % cazador_existe)

	print("Algún Ratón quedó muerto en algún momento (esperado true): %s" % _vio_raton_muerto)

	var total_almacen := 0
	for cantidad in _gl.almacen_replicado.values():
		total_almacen += int(cantidad)
	print("El almacén compartido recibió algo del botín cazado (esperado >= 1): %d" % total_almacen)

	var volvio_a_casa: bool = cazador_existe and _cazador._estado == _ESTADO_ESPERANDO_CASA
	print("El cazador volvió a ESPERANDO_CASA (esperado true): %s" % volvio_a_casa)

	var experiencia = _jugador.get_node_or_null("ExperienciaComponente")
	var xp_final: int = experiencia.xp_total if experiencia else 0
	print("El jugador de prueba NO ganó XP por las muertes del cazador (esperado %d): %d" % [
		_xp_inicial_jugador, xp_final
	])
	var xp_no_se_filtro_ok: bool = xp_final == _xp_inicial_jugador

	var exito := cazador_existe and _vio_raton_muerto and total_almacen >= 1 \
			and volvio_a_casa and xp_no_se_filtro_ok
	print("PRUEBA CAZADOR RECORRIDO COMPLETO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
