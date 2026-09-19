# =============================================================================
# Prueba de "Puesta de Huevos" (ver HabilidadPuestaHuevos.gd), la habilidad
# temática pedida por el usuario: la Reina pone huevos y se queda en reposo
# (+20% de daño recibido) un tiempo fijo. Los huevos que sigan vivos al
# terminar eclosionan en hormigas guardianas que le dan -20% de daño
# recibido CADA UNA mientras sigan vivas, mostrando un ícono de escudo
# tanto en ellas como en la propia Reina; matar a una guardiana le quita esa
# resistencia de a una.
#
# Los chequeos SINCRÓNICOS (justo tras activar/matar, sin dejar correr
# ningún fotograma de por medio) evitan depender de cuánto dura un
# fotograma real en este entorno headless -- el primero tras armar una
# escena así de pesada (Reina + 3 componentes nuevos) puede valer bastante
# más que 1/60s (visto en la práctica: ~0.14s), así que "esperar 1
# fotograma" para un timer corto NO es un margen confiable (ver el mismo
# criterio en prueba_pisoton_reina.gd/prueba_marca_colonia.gd).
#   1. Al activarse: 2 huevos vivos, Reina en reposo (BT apagado) y
#      vulnerable (+20% de daño, verificado con un golpe real).
#   2. Se mata UN huevo ahí mismo, antes de que termine el reposo.
#   3. Con margen de sobra sobre la duración del reposo: el huevo muerto NO
#      eclosiona; el que sobrevivió SÍ, como guardiana -- la Reina queda con
#      -20% de daño recibido y su propio ícono de escudo puesto; la
#      guardiana también lo muestra.
#   4. Al matar a esa guardiana (mismo instante): la Reina pierde la
#      resistencia y el ícono.
#   godot --headless --path . --script res://pruebas/prueba_puesta_huevos_reina.gd
# =============================================================================
extends SceneTree

const DURACION_DESCANSO_PRUEBA := 1.0

var _fotogramas := 0
var _reina
var _habilidad
var _contenedor: Node2D

var _dos_huevos_vivos_ok := false
var _bt_congelado_ok := false
var _vulnerabilidad_ok := false
var _amplifica_dano_real_ok := false

var _huevo_muerto_no_eclosiona_ok := false
var _un_guardian_nuevo_ok := false
var _resistencia_20_ok := false
var _buff_reina_ok := false
var _buff_guardian_ok := false

var _resistencia_baja_a_0_tras_matar_ok := false
var _buff_reina_desaparece_ok := false

var _guardian: Node = null
var _huevo_referencia_muerta_estaba_muerta := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_activar_y_verificar_estado_inicial()
			_matar_primer_huevo()
		60:  # Margen de sobra sobre DURACION_DESCANSO_PRUEBA: ya eclosionó.
			_verificar_eclosion()
			_matar_guardian_y_verificar()
			return _informar()
	return false


func _montar() -> void:
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO
	_reina.get_node("ArbolComportamiento").activo = true  # Confirmar que _ejecutar() lo apaga.

	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")
	_habilidad.cantidad_huevos = 2
	_habilidad.duracion_descanso = DURACION_DESCANSO_PRUEBA


func _vida(entidad: Node) -> float:
	var v := entidad.get_node_or_null("VidaComponente") as VidaComponente
	return v.obtener_vida() if v else 0.0


func _activar_y_verificar_estado_inicial() -> void:
	_habilidad.activar(Vector2.ZERO, 1.0)

	_dos_huevos_vivos_ok = _habilidad._huevos_activos.size() == 2 \
		and _habilidad._huevos_activos.all(func(h): return is_instance_valid(h) and not h.esta_muerto())
	print("Pone 2 huevos vivos (esperado true): %s" % _dos_huevos_vivos_ok)

	_bt_congelado_ok = not _reina.get_node("ArbolComportamiento").activo
	print("La Reina queda en reposo, BT apagado (esperado true): %s" % _bt_congelado_ok)

	var vulnerabilidad = _reina.get_node_or_null("VulnerabilidadComponente")
	_vulnerabilidad_ok = vulnerabilidad != null and vulnerabilidad.esta_activo()
	print("Queda vulnerable durante el reposo (esperado true): %s" % _vulnerabilidad_ok)

	var vida_antes := _vida(_reina)
	_reina.get_node("VidaComponente").quitar_vida(100.0)
	var perdio := vida_antes - _vida(_reina)
	# +20% de daño real: 100 de base debería quitar ~120 (con margen por
	# redondeo/otros componentes que puedan tocar el número).
	_amplifica_dano_real_ok = perdio > 105.0
	print("Un golpe de 100 quita más de 100 de verdad (esperado true, perdió %.1f): %s" % [
		perdio, _amplifica_dano_real_ok])


func _matar_primer_huevo() -> void:
	var huevo: Node = _habilidad._huevos_activos[0]
	huevo.get_node("VidaComponente").quitar_vida(999.0)
	# esta_muerto() ya da true accá mismo (Enemigo._on_muerte() lo fija
	# sincrónico dentro de quitar_vida()) -- guardado ahora porque el nodo
	# se queue_free() solo tras su fundido de 0.4s (Enemigo._desvanecer_y_
	# eliminar()), y para el momento en que se verifica la eclosión (varios
	# fotogramas reales después) ya puede no seguir vivo para consultarlo.
	_huevo_referencia_muerta_estaba_muerta = huevo.esta_muerto()


func _verificar_eclosion() -> void:
	_huevo_muerto_no_eclosiona_ok = _huevo_referencia_muerta_estaba_muerta
	print("El huevo matado antes de tiempo sigue muerto, nunca eclosiona (esperado true): %s" % \
		_huevo_muerto_no_eclosiona_ok)

	var guardianes = _habilidad._guardianes_vivos
	_un_guardian_nuevo_ok = guardianes.size() == 1 and is_instance_valid(guardianes[0])
	print("Eclosiona UNA guardiana del huevo que sobrevivió (esperado true, vivos=%d): %s" % [
		guardianes.size(), _un_guardian_nuevo_ok])
	if _un_guardian_nuevo_ok:
		_guardian = guardianes[0]

	var escudo = _reina.get_node_or_null("EscudoComponente")
	_resistencia_20_ok = escudo != null and escudo.esta_activo() \
		and is_equal_approx(escudo.aplicar(100.0), 80.0)
	print("La Reina queda con -20%% de daño recibido (esperado true): %s" % _resistencia_20_ok)

	var buffs_reina = _reina.get_node_or_null("BuffsComponente")
	_buff_reina_ok = buffs_reina != null and buffs_reina.esta_activo("resistencia_colonia")
	print("La Reina muestra su propio ícono de escudo (esperado true): %s" % _buff_reina_ok)

	if _guardian:
		var buffs_guardian = _guardian.get_node_or_null("BuffsComponente")
		_buff_guardian_ok = buffs_guardian != null and buffs_guardian.esta_activo("guardian_reina")
	print("La guardiana muestra su propio ícono de escudo (esperado true): %s" % _buff_guardian_ok)


func _matar_guardian_y_verificar() -> void:
	if _guardian:
		_guardian.get_node("VidaComponente").quitar_vida(99999.0)

	var escudo = _reina.get_node_or_null("EscudoComponente")
	_resistencia_baja_a_0_tras_matar_ok = escudo == null or not escudo.esta_activo() \
		or is_equal_approx(escudo.aplicar(100.0), 100.0)
	print("Al matar a la única guardiana, la resistencia vuelve a 0 (esperado true): %s" % \
		_resistencia_baja_a_0_tras_matar_ok)

	var buffs_reina = _reina.get_node_or_null("BuffsComponente")
	_buff_reina_desaparece_ok = buffs_reina == null or not buffs_reina.esta_activo("resistencia_colonia")
	print("El ícono de escudo de la Reina desaparece (esperado true): %s" % _buff_reina_desaparece_ok)


func _informar() -> bool:
	var exito := _dos_huevos_vivos_ok and _bt_congelado_ok and _vulnerabilidad_ok \
		and _amplifica_dano_real_ok and _huevo_muerto_no_eclosiona_ok and _un_guardian_nuevo_ok \
		and _resistencia_20_ok and _buff_reina_ok and _buff_guardian_ok \
		and _resistencia_baja_a_0_tras_matar_ok and _buff_reina_desaparece_ok
	print("PRUEBA PUESTA DE HUEVOS REINA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
