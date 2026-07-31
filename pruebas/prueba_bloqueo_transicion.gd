# =============================================================================
# Prueba del BLOQUEO AL LLEGAR A UN NIVEL NUEVO (ver
# Jugador.bloquear_por_transicion). Pedido del usuario: "deshabilitar el
# movimiento mientras se hace la transición de mapa y darle 3 segundos de
# invulnerabilidad; mientras está invulnerable, quitarle el movimiento y sin
# poder lanzar las habilidades".
#
# Verifica:
#   1. Al mover un jugador a otro nivel queda BLOQUEADO e INVULNERABLE.
#   2. Bloqueado NO se mueve, aunque se le ordene una dirección — es lo que
#      antes lo hacía deslizarse al aterrizar (el servidor seguía caminando
#      con la última dirección del joystick mientras el cliente fundía).
#   3. Bloqueado NO puede lanzar habilidades.
#   4. Son 3 segundos, y al vencer vuelve a moverse y a poder lanzar.
#   godot --headless --path . --script res://pruebas/prueba_bloqueo_transicion.gd
# =============================================================================
extends SceneTree

const PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const CUEVA := "res://escenas/niveles/NivelCueva.tscn"

var _gestor
var _contenedor: Node2D
var _jugador: CharacterBody2D
var _fotogramas := 0
var _pos_al_bloquear := Vector2.ZERO

var _queda_bloqueado := false
var _queda_invulnerable := false
var _duracion_es_3s := false
var _no_se_mueve := false
var _no_lanza_habilidades := false
var _se_desbloquea := false


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_al_llegar()
		# ~0.5s después: sigue bloqueado y no se movió ni un píxel.
		30:
			_probar_que_no_se_mueve()
		# 3s son 180 fotogramas; con margen, al 220 ya venció.
		220:
			_probar_desbloqueo()
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorNiveles")
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena
	_contenedor = Node2D.new()
	_contenedor.name = "ContenedorNivel"
	escena.add_child(_contenedor)
	var jugadores := Node2D.new()
	jugadores.name = "Jugadores"
	escena.add_child(jugadores)

	_gestor.registrar(_contenedor, null)
	_gestor.preparar_servidor(PRADERA)

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	jugadores.add_child(_jugador)
	_gestor.colocar_jugador_nuevo(1, _jugador)
	# Un jugador recién aparecido ya trae su propia invulnerabilidad: se la
	# saca para que lo que se mida acá sea SOLO la de la transición.
	_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()
	_jugador._bloqueo_transicion = 0.0


func _probar_al_llegar() -> void:
	_gestor.mover_peer_a_nivel(1, CUEVA)
	_pos_al_bloquear = _jugador.global_position

	_queda_bloqueado = _jugador.esta_bloqueado()
	_queda_invulnerable = _jugador.get_node("VidaComponente").es_invulnerable()
	_duracion_es_3s = is_equal_approx(_jugador.TIEMPO_BLOQUEO_TRANSICION, 3.0)
	print("Al llegar queda bloqueado (esperado true): %s" % _queda_bloqueado)
	print("Al llegar queda invulnerable (esperado true): %s" % _queda_invulnerable)
	print("El bloqueo dura 3s (esperado true, %.1f): %s" % [
		_jugador.TIEMPO_BLOQUEO_TRANSICION, _duracion_es_3s])

	# Habilidad: se pide lanzar el slot 0 y no debe pasar nada.
	_no_lanza_habilidades = not _puede_lanzar()
	print("Bloqueado NO puede lanzar habilidades (esperado true): %s" % _no_lanza_habilidades)


## Se le ordena caminar a la derecha durante medio segundo: bloqueado, el
## cuerpo no se tiene que haber movido nada.
func _probar_que_no_se_mueve() -> void:
	_jugador.direccion = Vector2.RIGHT
	var recorrido: float = _jugador.global_position.distance_to(_pos_al_bloquear)
	_no_se_mueve = recorrido < 1.0
	print("Bloqueado no se movió en ~0.5s (esperado true, %.2f px): %s" % [
		recorrido, _no_se_mueve])


func _probar_desbloqueo() -> void:
	var libre: bool = not _jugador.esta_bloqueado()
	var lanza: bool = _puede_lanzar()
	_se_desbloquea = libre and lanza
	print("Pasados los 3s vuelve a estar libre (%s) y a poder lanzar (%s): %s" % [
		libre, lanza, _se_desbloquea])


## ¿El camino real de lanzar (Jugador._activar_slot) deja pasar la habilidad?
## Se detecta mirando si la habilidad quedó en enfriamiento tras pedirla.
func _puede_lanzar() -> bool:
	var slots := _jugador.get_node("SlotHabilidades")
	var h = slots.obtener(0)
	if h == null:
		# Sin habilidad equipada no se puede medir por enfriamiento: se cae al
		# estado del bloqueo, que es lo que el gate consulta.
		return not _jugador.esta_bloqueado()
	_jugador._activar_slot(0)
	return h.en_enfriamiento() if h.has_method("en_enfriamiento") else not _jugador.esta_bloqueado()


func _informar() -> bool:
	var exito := _queda_bloqueado and _queda_invulnerable and _duracion_es_3s \
		and _no_se_mueve and _no_lanza_habilidades and _se_desbloquea
	print("PRUEBA BLOQUEO TRANSICION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
