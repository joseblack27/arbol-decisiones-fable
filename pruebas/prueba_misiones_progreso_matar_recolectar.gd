# =============================================================================
# Prueba de progreso automático de misiones — objetivos MATAR (Enemigo.
# _notificar_objetivo_matar, vía EnemigoDatos.obtener_id()) y RECOLECTAR
# (InventarioComponente.agregar_item -> notificar_recolectar), más aceptar/
# completar/abandonar. Todo local (sin red): Utils.en_red() da false sin
# ningún multiplayer_peer activo, así que _avanzar_objetivos() nunca corta
# por el gate de "solo servidor" — se ejercita el camino real de principio
# a fin (agregar_item de verdad, no llamar notificar_recolectar directo).
#   godot --headless --path . --script res://pruebas/prueba_misiones_progreso_matar_recolectar.gd
# =============================================================================
extends SceneTree

var _jugador
var _misiones
var _inventario
var _creditos
var _experiencia
var _datos_mision: DatosMision
var _obj_matar: DatosObjetivoMision
var _obj_recolectar: DatosObjetivoMision
var _datos_enemigo: EnemigoDatos
var _item: DatosItem

var _aceptar_ok := false
var _matar_una_vez_no_completa_ok := false
var _matar_dos_veces_completa_objetivo_ok := false
var _recolectar_completa_objetivo_ok := false
var _completar_antes_de_tiempo_rechaza_ok := false
var _completar_con_todo_listo_ok := false
var _recompensas_otorgadas_ok := false
var _abandonar_borra_progreso_ok := false
var _objetivos_completos_false_antes_ok := false
var _objetivos_completos_true_despues_ok := false
var _repetible_resetea_a_disponible_ok := false
var _repetible_se_puede_reaceptar_ok := false
var _reparar_resetea_completada_vieja_repetible_ok := false
var _reparar_no_toca_completada_no_repetible_ok := false
var _secuencial_fase2_no_avanza_antes_ok := false
var _secuencial_fase1_no_bloqueada_ok := false
var _secuencial_fase2_avanza_tras_fase1_ok := false
var _secuencial_no_secuencial_no_se_bloquea_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_aceptar()
	_probar_matar()
	_probar_recolectar()
	_probar_completar_antes_de_tiempo()
	_probar_completar()
	_probar_abandonar()
	_probar_mision_repetible()
	_probar_reparar_completadas_repetibles()
	_probar_mision_secuencial()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")
	_inventario = _jugador.get_node("InventarioComponente")
	_creditos = _jugador.get_node("CreditosComponente")
	_experiencia = _jugador.get_node("ExperienciaComponente")

	_datos_enemigo = EnemigoDatos.new()
	_datos_enemigo.nombre_tipo = "LoboDePrueba"

	_item = load("res://recursos/items/consumibles/botiquin.tres") as DatosItem

	_obj_matar = DatosObjetivoMision.new()
	_obj_matar.id = "matar_lobos"
	_obj_matar.descripcion = "Matar 2 lobos de prueba"
	_obj_matar.tipo = Enums.Mision.TipoObjetivo.MATAR
	_obj_matar.id_meta = _datos_enemigo.obtener_id()
	_obj_matar.cantidad_meta = 2

	_obj_recolectar = DatosObjetivoMision.new()
	_obj_recolectar.id = "juntar_botiquin"
	_obj_recolectar.descripcion = "Conseguir un botiquín"
	_obj_recolectar.tipo = Enums.Mision.TipoObjetivo.RECOLECTAR
	_obj_recolectar.id_meta = _item.name
	_obj_recolectar.cantidad_meta = 1

	var recompensas := DatosRecompensaMision.new()
	recompensas.xp = 50
	recompensas.creditos = 20

	_datos_mision = DatosMision.new()
	_datos_mision.id = "mision_prueba"
	_datos_mision.titulo = "Misión de prueba"
	_datos_mision.nivel_requerido = 1
	_datos_mision.objetivos = [_obj_matar, _obj_recolectar]
	_datos_mision.recompensas = recompensas

	var catalogo: Array[DatosMision] = [_datos_mision]
	root.get_node("/root/GestorMisiones").catalogo = catalogo


func _probar_aceptar() -> void:
	_misiones.aceptar_mision(_datos_mision)
	_aceptar_ok = _misiones.estado_de("mision_prueba") == Enums.Mision.Estado.EN_PROGRESO
	print("Aceptar deja la misión EN_PROGRESO (esperado true): %s" % _aceptar_ok)


func _probar_matar() -> void:
	_misiones.notificar_matar(_datos_enemigo)
	_matar_una_vez_no_completa_ok = _misiones.progreso_objetivo("mision_prueba", "matar_lobos") == 1
	print("Matar 1 de 2 dea el progreso en 1 (esperado true): %s" % _matar_una_vez_no_completa_ok)

	_misiones.notificar_matar(_datos_enemigo)
	_matar_dos_veces_completa_objetivo_ok = _misiones.progreso_objetivo("mision_prueba", "matar_lobos") == 2
	print("Matar 2 de 2 deja el progreso en 2 (esperado true): %s" % _matar_dos_veces_completa_objetivo_ok)

	# Un tercer kill NO debe seguir sumando de largo (cantidad_meta=2).
	_misiones.notificar_matar(_datos_enemigo)
	_matar_dos_veces_completa_objetivo_ok = _matar_dos_veces_completa_objetivo_ok \
		and _misiones.progreso_objetivo("mision_prueba", "matar_lobos") == 2
	print("Un tercer kill no sigue sumando de largo (esperado true, sigue en 2): %s" % _matar_dos_veces_completa_objetivo_ok)


func _probar_recolectar() -> void:
	# Camino REAL de integración: agregar_item(), no notificar_recolectar()
	# directo — así se ejercita el hook agregado en InventarioComponente.
	_inventario.agregar_item(_item, 1)
	_recolectar_completa_objetivo_ok = _misiones.progreso_objetivo("mision_prueba", "juntar_botiquin") == 1
	print("Recolectar el ítem completa ese objetivo (esperado true): %s" % _recolectar_completa_objetivo_ok)


func _probar_completar_antes_de_tiempo() -> void:
	# Objetivos completos recién en el paso anterior — a propósito, chequeo
	# ANTES de completar acá no aplica (ya están completos). En cambio se
	# prueba con una misión NUEVA sin ningún objetivo cumplido.
	var mision_incompleta := DatosMision.new()
	mision_incompleta.id = "mision_incompleta"
	mision_incompleta.objetivos = [_obj_matar]
	mision_incompleta.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_incompleta)
	_misiones.aceptar_mision(mision_incompleta)
	var resultado: bool = _misiones._completar_mision_local(mision_incompleta)
	_completar_antes_de_tiempo_rechaza_ok = not resultado \
		and _misiones.estado_de("mision_incompleta") == Enums.Mision.Estado.EN_PROGRESO
	print("Completar sin cumplir objetivos rechaza (esperado true): %s" % _completar_antes_de_tiempo_rechaza_ok)


func _probar_completar() -> void:
	var xp_antes: int = _experiencia.xp_total
	var creditos_antes: int = _creditos.obtener_creditos()
	var resultado: bool = _misiones._completar_mision_local(_datos_mision)
	_completar_con_todo_listo_ok = resultado and _misiones.estado_de("mision_prueba") == Enums.Mision.Estado.COMPLETADA
	print("Completar con todos los objetivos listos concreta (esperado true): %s" % _completar_con_todo_listo_ok)
	_recompensas_otorgadas_ok = _experiencia.xp_total == xp_antes + 50 and _creditos.obtener_creditos() == creditos_antes + 20
	print("Recompensas de XP y créditos otorgadas (esperado true): %s" % _recompensas_otorgadas_ok)


func _probar_abandonar() -> void:
	_misiones.abandonar_mision("mision_incompleta")
	_abandonar_borra_progreso_ok = _misiones.estado_de("mision_incompleta") == Enums.Mision.Estado.BLOQUEADA
	print("Abandonar borra el progreso (vuelve a BLOQUEADA/sin entrada, esperado true): %s" % _abandonar_borra_progreso_ok)


## Pedido explícito del usuario: la misión del NPC de ejemplo debe poder
## rehacerse — al completarla, en vez de quedar en COMPLETADA para
## siempre, el progreso se borra (mismo resultado visible que abandonar)
## así que se puede volver a aceptar como si fuera la primera vez.
func _probar_mision_repetible() -> void:
	var obj := DatosObjetivoMision.new()
	obj.id = "obj_rep"
	obj.tipo = Enums.Mision.TipoObjetivo.MATAR
	obj.id_meta = _datos_enemigo.obtener_id()
	obj.cantidad_meta = 1

	var mision_rep := DatosMision.new()
	mision_rep.id = "mision_repetible"
	mision_rep.repetible = true
	mision_rep.objetivos = [obj]
	mision_rep.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_rep)

	_misiones.aceptar_mision(mision_rep)
	_objetivos_completos_false_antes_ok = not _misiones.objetivos_completos("mision_repetible")
	print("objetivos_completos() da false antes de matar (esperado true): %s" % _objetivos_completos_false_antes_ok)

	_misiones.notificar_matar(_datos_enemigo)
	_objetivos_completos_true_despues_ok = _misiones.objetivos_completos("mision_repetible")
	print("objetivos_completos() da true tras cumplir el objetivo (esperado true): %s" % _objetivos_completos_true_despues_ok)

	_misiones._completar_mision_local(mision_rep)
	_repetible_resetea_a_disponible_ok = _misiones.estado_de("mision_repetible") == Enums.Mision.Estado.BLOQUEADA
	print("Completar una misión repetible borra el progreso (esperado true, BLOQUEADA/sin entrada): %s" % _repetible_resetea_a_disponible_ok)

	_misiones.aceptar_mision(mision_rep)
	_repetible_se_puede_reaceptar_ok = _misiones.estado_de("mision_repetible") == Enums.Mision.Estado.EN_PROGRESO \
		and _misiones.progreso_objetivo("mision_repetible", "obj_rep") == 0
	print("Se puede volver a aceptar de cero (esperado true, EN_PROGRESO con progreso en 0): %s" % _repetible_se_puede_reaceptar_ok)


## Bug reportado: una misión completada ANTES de marcarse repetible (o
## antes de que existiera este mecanismo) quedaba con estado COMPLETADA
## para siempre en el save — el NPC nunca la volvía a ofrecer aunque la
## definición actual diga repetible=true. Simula esa entrada "vieja"
## escribiendo el dict directo (mismo resultado que dejaría un
## misiones.progreso = datos.duplicate(true) de una partida guardada de
## antes de este arreglo) en vez de pasar por completar_mision().
func _probar_reparar_completadas_repetibles() -> void:
	var mision_vieja := DatosMision.new()
	mision_vieja.id = "mision_vieja_repetible"
	mision_vieja.repetible = true
	mision_vieja.objetivos = []
	mision_vieja.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_vieja)
	_misiones.progreso["mision_vieja_repetible"] = {"estado": Enums.Mision.Estado.COMPLETADA, "objetivos": {}}

	var mision_vieja_no_repetible := DatosMision.new()
	mision_vieja_no_repetible.id = "mision_vieja_no_repetible"
	mision_vieja_no_repetible.repetible = false
	mision_vieja_no_repetible.objetivos = []
	mision_vieja_no_repetible.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_vieja_no_repetible)
	_misiones.progreso["mision_vieja_no_repetible"] = {"estado": Enums.Mision.Estado.COMPLETADA, "objetivos": {}}

	_misiones.reparar_completadas_repetibles()

	_reparar_resetea_completada_vieja_repetible_ok = \
		_misiones.estado_de("mision_vieja_repetible") == Enums.Mision.Estado.BLOQUEADA
	print("Reparar borra el progreso de una COMPLETADA repetible vieja (esperado true): %s" % _reparar_resetea_completada_vieja_repetible_ok)

	_reparar_no_toca_completada_no_repetible_ok = \
		_misiones.estado_de("mision_vieja_no_repetible") == Enums.Mision.Estado.COMPLETADA
	print("Reparar NO toca una COMPLETADA que no es repetible (esperado true, sigue COMPLETADA): %s" % _reparar_no_toca_completada_no_repetible_ok)


## Pedido explícito del usuario: una misión "por fases" (ej. matar 3 arañas
## y DESPUÉS a la reina) — la fase 2 no debe acreditar ni un solo golpe
## hasta que la fase 1 esté 100% cumplida, sin importar en qué orden
## lleguen los notificar_matar() reales.
func _probar_mision_secuencial() -> void:
	var datos_enemigo_fase2 := EnemigoDatos.new()
	datos_enemigo_fase2.nombre_tipo = "ReinaDePrueba"

	var obj_fase1 := DatosObjetivoMision.new()
	obj_fase1.id = "fase1"
	obj_fase1.tipo = Enums.Mision.TipoObjetivo.MATAR
	obj_fase1.id_meta = _datos_enemigo.obtener_id()
	obj_fase1.cantidad_meta = 2

	var obj_fase2 := DatosObjetivoMision.new()
	obj_fase2.id = "fase2"
	obj_fase2.tipo = Enums.Mision.TipoObjetivo.MATAR
	obj_fase2.id_meta = datos_enemigo_fase2.obtener_id()
	obj_fase2.cantidad_meta = 1

	var mision_secuencial := DatosMision.new()
	mision_secuencial.id = "mision_secuencial"
	mision_secuencial.secuencial = true
	mision_secuencial.objetivos = [obj_fase1, obj_fase2]
	mision_secuencial.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_secuencial)

	_misiones.aceptar_mision(mision_secuencial)

	_secuencial_fase1_no_bloqueada_ok = _misiones.objetivo_habilitado(mision_secuencial, "fase1")
	print("Secuencial: la fase 1 está habilitada desde el principio (esperado true): %s" % _secuencial_fase1_no_bloqueada_ok)

	# Matar al enemigo de la fase 2 ANTES de terminar la fase 1 no debe
	# acreditar nada — ni siquiera objetivo_habilitado() lo deja pasar.
	_misiones.notificar_matar(datos_enemigo_fase2)
	_secuencial_fase2_no_avanza_antes_ok = _misiones.progreso_objetivo("mision_secuencial", "fase2") == 0 \
		and not _misiones.objetivo_habilitado(mision_secuencial, "fase2")
	print("Secuencial: matar el objetivo de la fase 2 antes de tiempo no suma nada (esperado true, sigue en 0): %s" % _secuencial_fase2_no_avanza_antes_ok)

	# Completar la fase 1 de verdad.
	_misiones.notificar_matar(_datos_enemigo)
	_misiones.notificar_matar(_datos_enemigo)

	# Ahora sí: el mismo notificar_matar de recién ya debería acreditar.
	_misiones.notificar_matar(datos_enemigo_fase2)
	_secuencial_fase2_avanza_tras_fase1_ok = _misiones.progreso_objetivo("mision_secuencial", "fase2") == 1 \
		and _misiones.objetivos_completos("mision_secuencial")
	print("Secuencial: tras cumplir la fase 1, la fase 2 sí acredita (esperado true): %s" % _secuencial_fase2_avanza_tras_fase1_ok)

	# Control: una misión NO secuencial con la misma forma no debe bloquear
	# nada — ambos objetivos progresan en paralelo, como siempre.
	var obj_par1 := DatosObjetivoMision.new()
	obj_par1.id = "par1"
	obj_par1.tipo = Enums.Mision.TipoObjetivo.MATAR
	obj_par1.id_meta = _datos_enemigo.obtener_id()
	obj_par1.cantidad_meta = 5

	var obj_par2 := DatosObjetivoMision.new()
	obj_par2.id = "par2"
	obj_par2.tipo = Enums.Mision.TipoObjetivo.MATAR
	obj_par2.id_meta = datos_enemigo_fase2.obtener_id()
	obj_par2.cantidad_meta = 1

	var mision_paralela := DatosMision.new()
	mision_paralela.id = "mision_paralela"
	mision_paralela.secuencial = false
	mision_paralela.objetivos = [obj_par1, obj_par2]
	mision_paralela.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision_paralela)

	_misiones.aceptar_mision(mision_paralela)
	_misiones.notificar_matar(datos_enemigo_fase2)
	_secuencial_no_secuencial_no_se_bloquea_ok = _misiones.progreso_objetivo("mision_paralela", "par2") == 1
	print("No secuencial: el segundo objetivo acredita sin esperar al primero (esperado true): %s" % _secuencial_no_secuencial_no_se_bloquea_ok)


func _informar() -> bool:
	var exito := _aceptar_ok and _matar_una_vez_no_completa_ok and _matar_dos_veces_completa_objetivo_ok \
		and _recolectar_completa_objetivo_ok and _completar_antes_de_tiempo_rechaza_ok \
		and _completar_con_todo_listo_ok and _recompensas_otorgadas_ok and _abandonar_borra_progreso_ok \
		and _objetivos_completos_false_antes_ok and _objetivos_completos_true_despues_ok \
		and _repetible_resetea_a_disponible_ok and _repetible_se_puede_reaceptar_ok \
		and _reparar_resetea_completada_vieja_repetible_ok and _reparar_no_toca_completada_no_repetible_ok \
		and _secuencial_fase2_no_avanza_antes_ok and _secuencial_fase1_no_bloqueada_ok \
		and _secuencial_fase2_avanza_tras_fase1_ok and _secuencial_no_secuencial_no_se_bloquea_ok
	print("PRUEBA MISIONES PROGRESO MATAR RECOLECTAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
