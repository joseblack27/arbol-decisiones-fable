# =============================================================================
# Prueba de MisionesComponente — patrón RPC de "pedir -> servidor valida ->
# aplica -> confirma solo al dueño" para aceptar_mision/completar_mision
# (mismo molde que prueba_tienda_comprar_item.gd). multiplayer.
# get_remote_sender_id() devuelve 0 al llamar _pedir_X_red() directo (sin
# transporte real) — peer_id_dueño=0 simula "el pedido vino del dueño de
# verdad", cualquier otro valor simula un sender ajeno.
#   godot --headless --path . --script res://pruebas/prueba_misiones_aceptar_completar.gd
# =============================================================================
extends SceneTree

var _jugador
var _misiones
var _datos_mision: DatosMision

var _sender_ajeno_rechaza_ok := false
var _aceptar_valido_ok := false
var _nivel_insuficiente_rechaza_ok := false
var _nivel_suficiente_acepta_ok := false
var _completar_sin_aceptar_rechaza_ok := false
var _completar_con_objetivo_incompleto_rechaza_ok := false
var _completar_valido_ok := false
var _aplicar_progreso_local_avisa_ui_ok := false
var _aviso_progreso_recibido := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno()
	_probar_aceptar_valido()
	_probar_nivel_insuficiente_rechaza_aceptar()
	_probar_aplicar_progreso_local_avisa_ui()
	_probar_completar_sin_aceptar()
	_probar_completar_con_objetivo_incompleto()
	_probar_completar_valido()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")

	var objetivo := DatosObjetivoMision.new()
	objetivo.id = "obj1"
	objetivo.tipo = Enums.Mision.TipoObjetivo.MATAR
	objetivo.id_meta = "algo"
	objetivo.cantidad_meta = 1

	_datos_mision = DatosMision.new()
	_datos_mision.id = "mision_red_prueba"
	_datos_mision.nivel_requerido = 1
	_datos_mision.objetivos = [objetivo]
	_datos_mision.recompensas = DatosRecompensaMision.new()

	var catalogo: Array[DatosMision] = [_datos_mision]
	root.get_node("/root/GestorMisiones").catalogo = catalogo


func _probar_sender_ajeno() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	_misiones._pedir_aceptar_mision_red(_datos_mision.id)
	_sender_ajeno_rechaza_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.BLOQUEADA
	print("Sender que no es el dueño rechaza aceptar (esperado true): %s" % _sender_ajeno_rechaza_ok)


func _probar_aceptar_valido() -> void:
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.
	_misiones._pedir_aceptar_mision_red(_datos_mision.id)
	_aceptar_valido_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Sender dueño acepta la misión (esperado true, EN_PROGRESO): %s" % _aceptar_valido_ok)


## Pedido explícito del usuario (1 sep 2026): una misión con nivel_requerido
## mayor al nivel actual del jugador se rechaza al aceptar (server-side, ya
## existía) Y MisionesComponente.cumple_requisitos() lo refleja ANTES de
## intentar aceptar (lo que usa PanelDialogo para no ofrecerla como opción).
func _probar_nivel_insuficiente_rechaza_aceptar() -> void:
	var mision_alta := DatosMision.new()
	mision_alta.id = "mision_nivel_alto"
	mision_alta.nivel_requerido = 5
	mision_alta.objetivos = []
	mision_alta.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_alta)

	var experiencia = _jugador.get_node("ExperienciaComponente")
	experiencia.nivel = 1
	var cumple_antes: bool = _misiones.cumple_requisitos(mision_alta)
	_jugador.peer_id_dueño = 0
	_misiones._pedir_aceptar_mision_red(mision_alta.id)
	var rechazada: bool = _misiones.estado_de(mision_alta.id) == Enums.Mision.Estado.BLOQUEADA
	_nivel_insuficiente_rechaza_ok = not cumple_antes and rechazada
	print("Nivel insuficiente: cumple_requisitos()=false y el servidor rechaza aceptar (esperado true): %s" \
		% _nivel_insuficiente_rechaza_ok)

	experiencia.nivel = 5
	var cumple_despues: bool = _misiones.cumple_requisitos(mision_alta)
	_misiones._pedir_aceptar_mision_red(mision_alta.id)
	var aceptada: bool = _misiones.estado_de(mision_alta.id) == Enums.Mision.Estado.EN_PROGRESO
	_nivel_suficiente_acepta_ok = cumple_despues and aceptada
	print("Nivel suficiente: cumple_requisitos()=true y el servidor acepta (esperado true): %s" \
		% _nivel_suficiente_acepta_ok)


## Bug reportado en juego real: el progreso se guardaba bien pero el panel
## de misiones nunca se enteraba, porque _aplicar_progreso_local() (lo que
## corre en la copia del CLIENTE al recibir la confirmación del servidor)
## no emitía mision_progreso_actualizado — solo lo hacía _avanzar_
## objetivos(), que corre del lado servidor, donde no hay ningún panel
## mirando. "obj_fake" (no es un objetivo real de _datos_mision) para no
## interferir con _probar_completar_con_objetivo_incompleto de abajo, que
## necesita que el objetivo REAL siga sin cumplirse.
func _probar_aplicar_progreso_local_avisa_ui() -> void:
	var bus := root.get_node("/root/BusEventos")
	bus.mision_progreso_actualizado.connect(_on_progreso_actualizado_prueba)
	_misiones._aplicar_progreso_local(_datos_mision.id, "obj_fake", 1)
	bus.mision_progreso_actualizado.disconnect(_on_progreso_actualizado_prueba)
	_aplicar_progreso_local_avisa_ui_ok = _aviso_progreso_recibido \
		and _misiones.progreso_objetivo(_datos_mision.id, "obj_fake") == 1
	print("_aplicar_progreso_local avisa a la UI vía BusEventos (esperado true): %s" % _aplicar_progreso_local_avisa_ui_ok)


func _on_progreso_actualizado_prueba(_j, _im, _io, _a, _r) -> void:
	_aviso_progreso_recibido = true


func _probar_completar_sin_aceptar() -> void:
	var otra := DatosMision.new()
	otra.id = "mision_no_aceptada"
	otra.objetivos = []
	otra.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(otra)
	_misiones._pedir_completar_mision_red(otra.id)
	_completar_sin_aceptar_rechaza_ok = _misiones.estado_de(otra.id) == Enums.Mision.Estado.BLOQUEADA
	print("Completar sin haber aceptado rechaza (esperado true): %s" % _completar_sin_aceptar_rechaza_ok)


func _probar_completar_con_objetivo_incompleto() -> void:
	# "mision_red_prueba" ya está aceptada (paso anterior) pero su único
	# objetivo (matar "algo") nunca se acreditó — el SERVIDOR tiene que
	# rechazar esto sin importar qué diga el cliente.
	_misiones._pedir_completar_mision_red(_datos_mision.id)
	_completar_con_objetivo_incompleto_rechaza_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Completar con un objetivo sin cumplir rechaza (esperado true, sigue EN_PROGRESO): %s" % _completar_con_objetivo_incompleto_rechaza_ok)


func _probar_completar_valido() -> void:
	_misiones.notificar_matar(_crear_datos_enemigo("algo"))
	_misiones._pedir_completar_mision_red(_datos_mision.id)
	_completar_valido_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.COMPLETADA
	print("Completar con el objetivo ya cumplido concreta (esperado true, COMPLETADA): %s" % _completar_valido_ok)


func _crear_datos_enemigo(id_objetivo: String) -> EnemigoDatos:
	var datos := EnemigoDatos.new()
	datos.id = id_objetivo
	return datos


func _informar() -> bool:
	var exito := _sender_ajeno_rechaza_ok and _aceptar_valido_ok and _completar_sin_aceptar_rechaza_ok \
		and _completar_con_objetivo_incompleto_rechaza_ok and _completar_valido_ok \
		and _aplicar_progreso_local_avisa_ui_ok \
		and _nivel_insuficiente_rechaza_ok and _nivel_suficiente_acepta_ok
	print("PRUEBA MISIONES ACEPTAR COMPLETAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
