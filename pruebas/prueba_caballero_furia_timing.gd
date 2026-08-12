# =============================================================================
# Prueba de EnemigoCaballeroEsqueleto._actualizar_chequeo_furia(): reglas de
# timing EXACTAS pedidas por el usuario para cuándo se tira la moneda de
# Furia (10% de probabilidad, ver _PROBABILIDAD_FURIA):
#   1. Sin objetivo válido, la cuenta regresiva NO avanza (no se evalúa).
#   2. Con objetivo, la cuenta regresiva baja con delta.
#   3. Mientras la furia está activa, NO se vuelve a evaluar — ni siquiera
#      se descuenta el temporizador (HabilidadFuriaGuerrero.esta_activa()
#      corta la función entera antes de tocar el contador).
#   4. Al terminar la furia (furia_terminada), la ventana se reinicia
#      COMPLETA a _INTERVALO_CHEQUEO_FURIA (10s) — no resume desde donde
#      había quedado.
#   5. El camino de la moneda en sí SÍ puede activar la furia: se llama
#      _actualizar_chequeo_furia() muchas veces independientes (reseteando
#      el contador a 0 cada vez, sin esperar tiempo real) — con 300
#      intentos al 10% cada uno, la chance de que NINGUNO acierte es
#      ~7e-10, así que no hace falta fijar semilla ni contar fotogramas
#      hasta una tirada puntual (mismo criterio que ya usa
#      prueba_esqueleto_arquero_reaccion_cercania.gd para no depender de
#      una tirada frágil).
#
# Llama _actualizar_chequeo_furia(delta) DIRECTO con deltas grandes para las
# partes 1/2/5 (no hace falta tiempo real: son deterministas o de muchos
# intentos instantáneos); las partes 3/4 sí esperan fotogramas reales
# porque HabilidadFuriaGuerrero.esta_activa() se basa en
# Time.get_ticks_msec(), no en el delta que se le pase a mano — por eso se
# acorta duracion a 0.3s para la prueba (el real, en el .tscn, es 15.0s).
#
# activar() en sí (recarga interna, costo de energía) es genérico de
# HabilidadBase y no es lo que prueba este archivo — se resetea
# _recarga_restante a mano antes de la parte 5 para no depender de esperar
# duracion_recarga real de sobra, algo ajeno a esta prueba.
#   godot --headless --path . --script res://pruebas/prueba_caballero_furia_timing.gd
# =============================================================================
extends SceneTree

var _mob
var _jugador
var _fase := 0
var _contador := 0
var _contador_asentamiento := 0
var _valor_antes_furia: float = -1.0

var _ok_sin_objetivo := false
var _ok_cuenta_baja := false
var _ok_furia_activa_no_reevalua := false
var _ok_reinicio_tras_furia := false
var _ok_moneda_activa_furia := false


func _process(_delta: float) -> bool:
	if _fase > 0 and (_mob == null or _mob._habilidad_furia == null):
		# Falla rápido y con mensaje claro en vez de quedarse llamando a
		# null cada fotograma para siempre — ver memoria del proyecto
		# sobre class_name nuevos sin reimportar.
		push_error("_mob o _habilidad_furia es null — ¿faltó reimportar (--headless --import)?")
		quit(1)
		return true
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			_probar_sin_objetivo()
			_fase = 2
		2:
			_probar_cuenta_baja()
			_fase = 3
		3:
			_iniciar_prueba_furia_activa()
			_fase = 4
		4:
			_contador += 1
			if _contador < 12:  # ~0.2s: furia activa de sobra (duracion=0.3s).
				return false
			_verificar_furia_activa_no_reevalua()
			_contador = 0
			_fase = 5
		5:
			_contador += 1
			if _mob._habilidad_furia.esta_activa() and _contador < 60:  # ~1s tope.
				return false
			_contador_asentamiento += 1
			if _contador_asentamiento < 6:
				# _mob es un nodo real en el árbol: su _physics_process()
				# automático (no solo mis llamadas manuales) también corre
				# _actualizar_chequeo_furia() en paralelo. Justo en el
				# fotograma exacto en que esta_activa() pasa a false, ese
				# llamado automático puede alcanzar a restarle un delta al
				# centinela ANTES de que _on_furia_terminada() (disparado
				# por el _process() de la habilidad al notar la transición)
				# lo pise con el reinicio a 10.0 — un roce de ~1 fotograma
				# sin consecuencia real (en el juego real la cuenta ya
				# arranca la ventana de furia en 10.0 limpio, no en un
				# centinela chico como acá). Unos fotogramas de margen antes
				# de leer evitan esa carrera ajena a lo que se quiere probar.
				return false
			_verificar_reinicio_tras_furia()
			_fase = 6
		6:
			_probar_moneda_activa_furia()
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(300, 0)
	if _mob._habilidad_furia == null:
		return  # el guard de _process() corta acá, con mensaje, en el próximo fotograma.
	_mob._habilidad_furia.duracion = 0.3


func _probar_sin_objetivo() -> void:
	_mob.memoria.establecer("objetivo", null)
	_mob._tiempo_restante_chequeo_furia = _mob._INTERVALO_CHEQUEO_FURIA
	_mob._actualizar_chequeo_furia(5.0)
	_ok_sin_objetivo = absf(_mob._tiempo_restante_chequeo_furia - _mob._INTERVALO_CHEQUEO_FURIA) < 0.001 \
		and not _mob._habilidad_furia.esta_activa()
	print("Sin objetivo: la cuenta regresiva no se mueve (esperado true): %s (quedó en %.2f)" % [
		_ok_sin_objetivo, _mob._tiempo_restante_chequeo_furia
	])


func _probar_cuenta_baja() -> void:
	_mob.memoria.establecer("objetivo", _jugador)
	_mob._tiempo_restante_chequeo_furia = _mob._INTERVALO_CHEQUEO_FURIA
	_mob._actualizar_chequeo_furia(3.0)
	var esperado: float = _mob._INTERVALO_CHEQUEO_FURIA - 3.0
	_ok_cuenta_baja = absf(_mob._tiempo_restante_chequeo_furia - esperado) < 0.001
	print("Con objetivo: la cuenta regresiva baja con delta (esperado %.2f): %.2f -> %s" % [
		esperado, _mob._tiempo_restante_chequeo_furia, _ok_cuenta_baja
	])


func _iniciar_prueba_furia_activa() -> void:
	_mob._habilidad_furia.activar()  # fuerza la furia sin pasar por la moneda.
	_mob._tiempo_restante_chequeo_furia = 0.05  # centinela: si se llegara a tocar, cambiaría.
	_valor_antes_furia = _mob._tiempo_restante_chequeo_furia


func _verificar_furia_activa_no_reevalua() -> void:
	_mob._actualizar_chequeo_furia(0.2)
	_ok_furia_activa_no_reevalua = _mob._habilidad_furia.esta_activa() \
		and absf(_mob._tiempo_restante_chequeo_furia - _valor_antes_furia) < 0.001
	print("Furia activa: NO se reevalúa ni se descuenta (esperado true): %s (contador quedó en %.3f, activa=%s)" % [
		_ok_furia_activa_no_reevalua, _mob._tiempo_restante_chequeo_furia, _mob._habilidad_furia.esta_activa()
	])


func _verificar_reinicio_tras_furia() -> void:
	var ok_vencio: bool = not _mob._habilidad_furia.esta_activa()
	# Tolerancia holgada (no absf(...) < 0.001 como en el resto): tras el
	# reinicio a 10.0, la cuenta nueva arranca a descontarse de inmediato de
	# forma normal (es la ventana siguiente, ya en marcha) durante los
	# fotogramas de margen que esperó esta fase — lo que hay que distinguir
	# es "reinició a ~10" de "se quedó pegada cerca del centinela (0.05)",
	# no pedir un instante exacto que ninguna ejecución real va a dar.
	var ok_reinicio: bool = _mob._tiempo_restante_chequeo_furia > 9.0
	_ok_reinicio_tras_furia = ok_vencio and ok_reinicio
	print("Tras terminar la furia: ventana reinicia completa a %.1f, no resume (esperado true): %s (venció=%s, quedó en %.2f)" % [
		_mob._INTERVALO_CHEQUEO_FURIA, _ok_reinicio_tras_furia, ok_vencio, _mob._tiempo_restante_chequeo_furia
	])


func _probar_moneda_activa_furia() -> void:
	_mob._habilidad_furia._recarga_restante = 0.0  # recarga genérica de HabilidadBase, ajena a esta prueba.
	for intento in range(300):
		_mob._tiempo_restante_chequeo_furia = 0.0
		_mob._actualizar_chequeo_furia(0.0)
		if _mob._habilidad_furia.esta_activa():
			_ok_moneda_activa_furia = true
			print("El camino de la moneda (10%%) activó la furia en el intento %d de 300" % (intento + 1))
			return
	_ok_moneda_activa_furia = false
	print("El camino de la moneda (10%%) NUNCA activó la furia en 300 intentos independientes — sospechoso")


func _informar() -> bool:
	var exito := _ok_sin_objetivo and _ok_cuenta_baja and _ok_furia_activa_no_reevalua \
		and _ok_reinicio_tras_furia and _ok_moneda_activa_furia
	print("PRUEBA CABALLERO FURIA TIMING %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
