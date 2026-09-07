extends NivelBase
## Mina de Cristal + Forja de Fuego + Corrupción — mismo patrón exacto que
## NivelSantuarioGuardian.gd (ver ese archivo para el porqué completo): cada
## jefe vive COLOCADO A MANO en la escena, no generado por spawner, porque
## el servidor nunca libera un nivel ya cargado — sin reponerlo a mano, el
## nivel se quedaría sin jefe para siempre tras la primera muerte.
##
## Tres bloques EN PARALELO, uno por jefe/compuerta (mismo patrón repetido a
## propósito en vez de una versión genérica — mismo criterio que
## EnemigoNucleoForja.gd mirror de EnemigoCorazonCristal.gd en vez de
## compartir una clase base): cada jefe abre/cierra SOLO su propia compuerta.

const _RUTA_JEFE_CRISTAL := "Enemigos/EnemigoCorazonCristal"
const _ESCENA_JEFE_CRISTAL := preload("res://escenas/enemigos/EnemigoCorazonCristal.tscn")
const _RUTA_COMPUERTA_CRISTAL := "Decoraciones/CompuertaAtajoMina1"

const _RUTA_JEFE_FORJA := "Enemigos/EnemigoNucleoForja"
const _ESCENA_JEFE_FORJA := preload("res://escenas/enemigos/EnemigoNucleoForja.tscn")
const _RUTA_COMPUERTA_FORJA := "Decoraciones/CompuertaAtajoForja"

const _RUTA_JEFE_CORRUPCION := "Enemigos/EnemigoHeraldoCorrupcion"
const _ESCENA_JEFE_CORRUPCION := preload("res://escenas/enemigos/EnemigoHeraldoCorrupcion.tscn")
const _RUTA_COMPUERTA_CORRUPCION := "Decoraciones/CompuertaAtajoCorrupcion"

var _jefe_cristal_muerto := false
var _posicion_jefe_cristal: Vector2 = Vector2.ZERO

var _jefe_forja_muerto := false
var _posicion_jefe_forja: Vector2 = Vector2.ZERO

var _jefe_corrupcion_muerto := false
var _posicion_jefe_corrupcion: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	if not Utils.en_red() or not multiplayer.is_server():
		return
	var jefe_cristal := get_node_or_null(_RUTA_JEFE_CRISTAL)
	if jefe_cristal:
		_posicion_jefe_cristal = jefe_cristal.global_position
		_conectar_muerte_cristal(jefe_cristal)
	var jefe_forja := get_node_or_null(_RUTA_JEFE_FORJA)
	if jefe_forja:
		_posicion_jefe_forja = jefe_forja.global_position
		_conectar_muerte_forja(jefe_forja)
	var jefe_corrupcion := get_node_or_null(_RUTA_JEFE_CORRUPCION)
	if jefe_corrupcion:
		_posicion_jefe_corrupcion = jefe_corrupcion.global_position
		_conectar_muerte_corrupcion(jefe_corrupcion)
	GestorNiveles.peer_listo.connect(_al_peer_listo)


# =============================================================================
# Corazón de Cristal
# =============================================================================

func _conectar_muerte_cristal(jefe: Node) -> void:
	if jefe.componente_vida and not jefe.componente_vida.muerte.is_connected(_al_morir_jefe_cristal):
		jefe.componente_vida.muerte.connect(_al_morir_jefe_cristal)


func _al_morir_jefe_cristal(_valor: float) -> void:
	_jefe_cristal_muerto = true
	var compuerta := get_node_or_null(_RUTA_COMPUERTA_CRISTAL)
	if compuerta:
		compuerta.abrir_servidor()


func _respawnear_jefe_cristal() -> void:
	_jefe_cristal_muerto = false
	var contenedor := get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var viejo := contenedor.get_node_or_null("EnemigoCorazonCristal")
	if viejo:
		viejo.free()
	var jefe := _ESCENA_JEFE_CRISTAL.instantiate()
	contenedor.add_child(jefe)
	jefe.global_position = _posicion_jefe_cristal
	_conectar_muerte_cristal(jefe)

	var compuerta := get_node_or_null(_RUTA_COMPUERTA_CRISTAL)
	if compuerta:
		compuerta.cerrar_servidor()


# =============================================================================
# Núcleo de la Forja
# =============================================================================

func _conectar_muerte_forja(jefe: Node) -> void:
	if jefe.componente_vida and not jefe.componente_vida.muerte.is_connected(_al_morir_jefe_forja):
		jefe.componente_vida.muerte.connect(_al_morir_jefe_forja)


func _al_morir_jefe_forja(_valor: float) -> void:
	_jefe_forja_muerto = true
	var compuerta := get_node_or_null(_RUTA_COMPUERTA_FORJA)
	if compuerta:
		compuerta.abrir_servidor()


func _respawnear_jefe_forja() -> void:
	_jefe_forja_muerto = false
	var contenedor := get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var viejo := contenedor.get_node_or_null("EnemigoNucleoForja")
	if viejo:
		viejo.free()
	var jefe := _ESCENA_JEFE_FORJA.instantiate()
	contenedor.add_child(jefe)
	jefe.global_position = _posicion_jefe_forja
	_conectar_muerte_forja(jefe)

	var compuerta := get_node_or_null(_RUTA_COMPUERTA_FORJA)
	if compuerta:
		compuerta.cerrar_servidor()


# =============================================================================
# Heraldo de la Corrupción
# =============================================================================

func _conectar_muerte_corrupcion(jefe: Node) -> void:
	if jefe.componente_vida and not jefe.componente_vida.muerte.is_connected(_al_morir_jefe_corrupcion):
		jefe.componente_vida.muerte.connect(_al_morir_jefe_corrupcion)


func _al_morir_jefe_corrupcion(_valor: float) -> void:
	_jefe_corrupcion_muerto = true
	var compuerta := get_node_or_null(_RUTA_COMPUERTA_CORRUPCION)
	if compuerta:
		compuerta.abrir_servidor()


func _respawnear_jefe_corrupcion() -> void:
	_jefe_corrupcion_muerto = false
	var contenedor := get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var viejo := contenedor.get_node_or_null("EnemigoHeraldoCorrupcion")
	if viejo:
		viejo.free()
	var jefe := _ESCENA_JEFE_CORRUPCION.instantiate()
	contenedor.add_child(jefe)
	jefe.global_position = _posicion_jefe_corrupcion
	_conectar_muerte_corrupcion(jefe)

	var compuerta := get_node_or_null(_RUTA_COMPUERTA_CORRUPCION)
	if compuerta:
		compuerta.cerrar_servidor()


# =============================================================================
# Compartido
# =============================================================================

## Cubre tanto a quien vuelve a entrar tras matar a cualquiera de los 3
## jefes como a un jugador nuevo que llega después. También resincroniza el
## estado de cada compuerta para quien entra después de que ya se abrió (el
## broadcast rpc() de abrir_servidor() solo llega a quien ya estaba
## conectado en ese momento).
func _al_peer_listo(peer_id: int) -> void:
	if GestorNiveles.nivel_de_peer(peer_id) != self:
		return

	var compuerta_cristal := get_node_or_null(_RUTA_COMPUERTA_CRISTAL)
	if compuerta_cristal and compuerta_cristal.abierta:
		compuerta_cristal.rpc_id(peer_id, "_abrir_red")
	if _jefe_cristal_muerto:
		_respawnear_jefe_cristal()

	var compuerta_forja := get_node_or_null(_RUTA_COMPUERTA_FORJA)
	if compuerta_forja and compuerta_forja.abierta:
		compuerta_forja.rpc_id(peer_id, "_abrir_red")
	if _jefe_forja_muerto:
		_respawnear_jefe_forja()

	var compuerta_corrupcion := get_node_or_null(_RUTA_COMPUERTA_CORRUPCION)
	if compuerta_corrupcion and compuerta_corrupcion.abierta:
		compuerta_corrupcion.rpc_id(peer_id, "_abrir_red")
	if _jefe_corrupcion_muerto:
		_respawnear_jefe_corrupcion()
