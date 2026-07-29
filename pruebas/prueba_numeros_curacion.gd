# =============================================================================
# Prueba de GestorNumerosCuracion: número flotante verde "+N" al curarse,
# sea con habilidades, ítems o cualquier otro llamador de VidaComponente.
# agregar_vida() — pedido del usuario: "numero flotantes en verde y un signo
# + por delante del numero cuando te curas... para cuando pierdes daño no
# quiero que agregues nada extra" (no se toca GestorNumerosDano).
#
# Verifica:
#   1. VidaComponente.agregar_vida() emite BusEventos.curacion_aplicada con
#      el delta REAL aplicado.
#   2. El delta se recorta al máximo real (pedir de más cerca del tope
#      muestra lo que de verdad se ganó, no lo pedido).
#   3. NO emite nada si ya está al máximo (ganancia real = 0 -> sin "+0").
#   4. quitar_vida() (daño) NO dispara curacion_aplicada — no se mezclan
#      los dos sistemas.
#   5. GestorNumerosCuracion solo muestra el número para MI jugador (mismo
#      criterio que GestorNumerosDano, ver prueba_numeros_dano_solo_mios).
#   godot --headless --path . --script res://pruebas/prueba_numeros_curacion.gd
# =============================================================================
extends SceneTree

var _mi_jugador
var _otro_jugador
var _vida_mi_jugador
var _gestor
var _piscinas
var _fotogramas := 0

var _delta_correcto_al_curar := false
var _delta_correcto_recortado_al_maximo := false
var _sin_señal_si_ya_esta_al_maximo := false
var _dano_no_dispara_curacion := false
var _muestra_numero_para_mi_jugador := false
var _no_muestra_numero_ajeno := false

var _ultima_curacion_objetivo: Node = null
var _ultima_curacion_cantidad: float = -1.0
var _veces_curacion_emitida := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_vida_mi_jugador.quitar_vida(40.0)  # vida: 100 -> 60.
		3:
			_vida_mi_jugador.agregar_vida(15.0)  # 60 -> 75.
			_delta_correcto_al_curar = _ultima_curacion_objetivo == _mi_jugador \
				and is_equal_approx(_ultima_curacion_cantidad, 15.0)
			print("Emite curacion_aplicada con el delta correcto (esperado true, +15, real +%.0f): %s" % [
				_ultima_curacion_cantidad, _delta_correcto_al_curar])
		4:
			_ultima_curacion_cantidad = -1.0
			_vida_mi_jugador.agregar_vida(50.0)  # 75 -> 100 (tope): pide 50, gana 25.
			_delta_correcto_recortado_al_maximo = is_equal_approx(_ultima_curacion_cantidad, 25.0)
			print("Recorta el delta al máximo real (esperado true, +25 no +50, real +%.0f): %s" % [
				_ultima_curacion_cantidad, _delta_correcto_recortado_al_maximo])
		5:
			var veces_antes := _veces_curacion_emitida
			_vida_mi_jugador.agregar_vida(20.0)  # ya al tope: ganancia real = 0.
			_sin_señal_si_ya_esta_al_maximo = _veces_curacion_emitida == veces_antes
			print("No emite nada si ya está al máximo (esperado true, sin +0): %s" % _sin_señal_si_ya_esta_al_maximo)

			veces_antes = _veces_curacion_emitida
			_vida_mi_jugador.quitar_vida(10.0)
			_dano_no_dispara_curacion = _veces_curacion_emitida == veces_antes
			print("quitar_vida() no dispara curacion_aplicada (esperado true): %s" % _dano_no_dispara_curacion)
		6:
			var antes: int = _piscinas._activos.size()
			_gestor._al_curar(_mi_jugador, 10.0)
			_muestra_numero_para_mi_jugador = _piscinas._activos.size() > antes
			print("Muestra el número para MI jugador (esperado true): %s" % _muestra_numero_para_mi_jugador)
		7:
			var antes: int = _piscinas._activos.size()
			_gestor._al_curar(_otro_jugador, 10.0)
			_no_muestra_numero_ajeno = _piscinas._activos.size() == antes
			print("NO muestra el número de una curación ajena (esperado true): %s" % _no_muestra_numero_ajeno)
			return _informar()
	return false


func _al_curar(objetivo: Node, cantidad: float) -> void:
	_ultima_curacion_objetivo = objetivo
	_ultima_curacion_cantidad = cantidad
	_veces_curacion_emitida += 1


func _montar() -> void:
	_gestor = root.get_node("/root/GestorNumerosCuracion")
	_piscinas = root.get_node("/root/GestorPiscinas")

	_mi_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_mi_jugador)
	_vida_mi_jugador = _mi_jugador.get_node("VidaComponente")
	_vida_mi_jugador.salud_maxima = 100.0
	_vida_mi_jugador.restaurar_vida(100.0)
	# Un jugador recién aparecido es invulnerable un rato (ver Jugador.
	# TIEMPO_INVULNERABILIDAD_APARICION) — acá se prueba el número flotante
	# de curación, y el daño se usa solo para bajar la vida y poder curarla.
	_vida_mi_jugador.cancelar_invulnerabilidad()

	_otro_jugador = Node2D.new()
	root.add_child(_otro_jugador)

	root.get_node("/root/BusEventos").curacion_aplicada.connect(_al_curar)


func _informar() -> bool:
	var exito := _delta_correcto_al_curar and _delta_correcto_recortado_al_maximo \
		and _sin_señal_si_ya_esta_al_maximo and _dano_no_dispara_curacion \
		and _muestra_numero_para_mi_jugador and _no_muestra_numero_ajeno
	print("PRUEBA NUMEROS CURACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
