# =============================================================================
# Prueba de HabilidadBase.datos (DatosHabilidad aplicado a habilidades de
# MOBS, no solo del jugador vía SlotHabilidades) + el indicador visual de
# zona de golpe en HabilidadArañazo/HabilidadGolpeBasico (IndicadorZonaEfecto,
# mismo patrón que ya usan Sacudida/Acumulación/Marca).
#
# Contexto del bug real que esto arregla: HabilidadGolpeBasico.daño es una
# var PLANA (no @export) — un override daño=47.0 en el .tscn de un mob
# nunca se aplicaba de verdad (Godot ignora overrides de instancia sobre
# variables no exportadas en nodos de sub-escena instanciada), y el
# Caballero Esqueleto (y Araña/Lobo/LoboFeroz/Jefe Esqueleto) venían
# pegando 15 en vez de su daño real desde siempre. Ahora cada uno trae su
# propio DatosHabilidad.tres (ver arañazo_caballero.tres) asignado al nuevo
# campo HabilidadBase.datos, aplicado automáticamente en _ready() — fija
# dano_base_min=dano_base_max al valor real, y _calcular_dano() (ver
# HabilidadBase.gd) prioriza ese rango sobre el daño de fallback.
#
# Usa el Caballero Esqueleto (arañazo_caballero.tres: daño=50, costo de
# energía=10, alcance 1 metro = 40px, sin recarga especial) como caso
# concreto — mismo criterio que ya usa prueba_habilidad_furia_guerrero.gd.
#   godot --headless --path . --script res://pruebas/prueba_habilidad_datos_mob_indicador_golpe.gd
# =============================================================================
extends SceneTree

var _escena: Node2D
var _mob
var _arañazo
var _fase := 0
var _resultados: Array[bool] = []


func _process(_delta: float) -> bool:
	if _fase > 0 and (_mob == null or _arañazo == null):
		push_error("_mob o _arañazo es null — ¿faltó reimportar (--headless --import)?")
		quit(1)
		return true
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			_verificar_datos_aplicados()
			_fase = 2
		2:
			_verificar_indicador()
			return _informar()
	return false


func _montar() -> void:
	# El indicador (_mostrar_indicador_golpe) hace get_tree().current_scene.
	# add_child(...) — hace falta una current_scene real, no solo colgar
	# nodos de root directo (mismo montaje que ya usa prueba_sacudida.gd).
	_escena = Node2D.new()
	root.add_child(_escena)
	current_scene = _escena

	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_escena.add_child(jugador)
	jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn") as PackedScene).instantiate()
	_escena.add_child(_mob)
	_mob.global_position = Vector2(300, 0)
	_arañazo = _mob.get_node_or_null("Habilidades/HabilidadArañazo")


func _verificar_datos_aplicados() -> void:
	# _dano_min/_dano_max son de HabilidadBase (guión bajo, sin getter) —
	# se leen directo, mismo criterio que el resto de las pruebas del
	# proyecto para campos internos.
	var dano_ok: bool = _arañazo._dano_min == 50 and _arañazo._dano_max == 50
	var costo_ok: bool = absf(_arañazo.costo_energia - 10.0) < 0.001
	var recarga_ok: bool = absf(_arañazo.duracion_recarga - 1.0) < 0.001
	var alcance_ok: bool = absf(_arañazo.alcance_golpe - 40.0) < 0.001
	var ok: bool = dano_ok and costo_ok and recarga_ok and alcance_ok
	_resultados.append(ok)
	print("datos (DatosHabilidad) aplicado en _ready() del mob (esperado true): %s (dano_min=%s dano_max=%s costo=%s recarga=%s alcance=%s)" % [
		ok, _arañazo._dano_min, _arañazo._dano_max, _arañazo.costo_energia,
		_arañazo.duracion_recarga, _arañazo.alcance_golpe
	])


func _verificar_indicador() -> void:
	var posicion_esperada: Vector2 = _mob.global_position + Vector2.RIGHT * _arañazo.alcance_golpe
	_arañazo._ejecutar(Vector2.RIGHT, 1.0)

	var indicador: Node = null
	for hijo in _escena.get_children():
		if hijo.get_script() == load("res://escenas/efectos/IndicadorZonaEfecto.gd"):
			indicador = hijo
			break

	var ok: bool = indicador != null \
		and indicador.global_position.distance_to(posicion_esperada) < 0.01 \
		and is_equal_approx(indicador.radio, _arañazo.radio_golpe)
	_resultados.append(ok)
	print("Aparece el indicador de zona de golpe, en la posición y radio reales (esperado true): %s" % ok)


const _CHEQUEOS_ESPERADOS := 2

func _informar() -> bool:
	# Si un chequeo revienta ANTES de llegar a _resultados.append(ok) (ej.
	# un error de compilación en cascada), _resultados queda más corto de
	# lo esperado — sin este chequeo de tamaño, el for de abajo no tiene
	# nada que reprobar y la prueba reporta OK por una lista vacía, un
	# falso positivo real que pasó armando esta prueba.
	var exito := _resultados.size() == _CHEQUEOS_ESPERADOS
	if not exito:
		print("Faltan chequeos: se esperaban %d resultados, llegaron %d (revisar SCRIPT ERROR arriba)" % [
			_CHEQUEOS_ESPERADOS, _resultados.size()
		])
	for r in _resultados:
		exito = exito and r
	print("PRUEBA HABILIDAD DATOS MOB + INDICADOR GOLPE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
