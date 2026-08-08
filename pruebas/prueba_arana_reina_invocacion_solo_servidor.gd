# =============================================================================
# Bug reportado: "en una invocación de la araña reina salieron como 6 mobs y
# solo 3 se movían". Causa: EnemigoArañaReina._on_vida_cambiada corre A
# PROPÓSITO en TODOS los peers (para que el respiro de cambio de fase se
# vea igual en todos lados — ver ese comentario), pero _invocar_refuerzos()
# no tenía ningún corte de "solo servidor": la RÉPLICA de la reina en cada
# cliente terminaba invocando SU PROPIA copia local de los refuerzos (nunca
# replicada, sin IA real — Enemigo._physics_process solo corre del lado del
# servidor) ADEMÁS de la real que manda el servidor — de ahí los mobs de
# más, quietos porque nadie los mueve de verdad.
#
# No arma una red real de 2 peers conectados (mismo motivo que prueba_
# lanzallamas_detiene_canal_por_servidor.gd: lento/flaky) — alcanza con
# asignar un ENetMultiplayerPeer en modo CLIENTE (sin conectar) para que
# Utils.en_red()==true y multiplayer.is_server()==false, exactamente lo que
# ve la réplica de un cliente real.
#
# Cubre:
#   1. Como CLIENTE (no servidor) en red, cruzar el umbral de fase 2 NO
#      invoca ningún refuerzo local (_adds se queda vacío).
#   2. Fuera de red (single-player/servidor, ver prueba_arana_reina_fase2.gd
#      para la cobertura completa) SÍ los invoca — regresión rápida acá
#      mismo para no depender solo del otro archivo.
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_invocacion_solo_servidor.gd
# =============================================================================
extends SceneTree

var _reina
var _f := 0

var _cliente_no_invoca_local_ok := false
var _servidor_si_invoca_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
			_probar_como_cliente()
		2:
			_probar_como_servidor()
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Node2D.new()
	contenedor.name = "Enemigos"
	root.add_child(contenedor)
	current_scene = contenedor

	var escena_reina := load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene
	_reina = escena_reina.instantiate()
	contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO


## Como CLIENTE (réplica ajena, no la autoridad): _reanudar_fase(2) sigue
## corriendo local (el respiro visual es igual en todos lados a propósito),
## pero _invocar_refuerzos() tiene que cortarse solo.
func _probar_como_cliente() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 34598)  # puerto sin nadie escuchando: no hace falta conectar.
	root.multiplayer.multiplayer_peer = peer

	_reina._invocar_refuerzos(_reina._refuerzos_fase2)

	_cliente_no_invoca_local_ok = _reina._adds.is_empty()
	print("Como cliente NO invoca refuerzos locales (esperado true, adds=%d): %s" % [
		_reina._adds.size(), _cliente_no_invoca_local_ok])

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Fuera de red (single-player/servidor): el comportamiento de siempre.
func _probar_como_servidor() -> void:
	_reina._invocar_refuerzos(_reina._refuerzos_fase2)

	_servidor_si_invoca_ok = _reina._adds.size() == 2
	print("Fuera de red SI invoca los refuerzos (esperado true, adds=%d): %s" % [
		_reina._adds.size(), _servidor_si_invoca_ok])


func _informar() -> bool:
	var exito := _cliente_no_invoca_local_ok and _servidor_si_invoca_ok
	print("PRUEBA ARAÑA REINA INVOCACION SOLO SERVIDOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
