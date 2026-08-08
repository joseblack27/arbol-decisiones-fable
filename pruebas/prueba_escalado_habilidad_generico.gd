# =============================================================================
# Prueba del mecanismo GENÉRICO de escalado por nivel de mejora (ver
# HabilidadBase.preparar_escalado/aplicar_nivel_mejora, EscaladoHabilidad,
# CampoEscaladoPorcentaje, CampoEscaladoTabla) — sin pasar por
# MejorasComponente/SlotHabilidades todavía, solo la mecánica de escalado
# en sí sobre una HabilidadBase directa.
#
# Cubre:
#   1. CampoEscaladoPorcentaje: crece según la fórmula, NO compone en
#      llamadas sucesivas (recalcula siempre desde el valor de fábrica).
#   2. Un porcentaje NEGATIVO reduce el campo (caso recarga).
#   3. CampoEscaladoTabla: valores EXACTOS por nivel, se queda en el
#      último si se pide un nivel más allá de lo definido en la lista.
#   4. escalado == null no hace nada (nivel_mejora vuelve a 1).
#   5. Un campo que esta habilidad no reconoce (_nombre_campo_escalable
#      devuelve "") se ignora sin explotar.
#   godot --headless --path . --script res://pruebas/prueba_escalado_habilidad_generico.gd
# =============================================================================
extends SceneTree

var _porcentaje_no_compone_ok := false
var _porcentaje_negativo_reduce_ok := false
var _tabla_valores_exactos_ok := false
var _tabla_se_queda_en_ultimo_ok := false
var _sin_escalado_no_hace_nada_ok := false
var _campo_no_reconocido_no_explota_ok := false


func _process(_delta: float) -> bool:
	_probar_porcentaje()
	_probar_tabla()
	_probar_sin_escalado()
	_probar_campo_no_reconocido()
	return _informar()


func _crear_habilidad(dano_min: int, dano_max: int, recarga: float) -> HabilidadBase:
	var hab: HabilidadBase = (load("res://escenas/habilidades/base/HabilidadBase.gd") as GDScript).new()
	var datos := DatosHabilidad.new()
	datos.dano_base_min = dano_min
	datos.dano_base_max = dano_max
	datos.enfriamiento = recarga
	hab.aplicar_datos(datos)
	return hab


func _probar_porcentaje() -> void:
	var hab := _crear_habilidad(10, 20, 1.0)
	var escalado := EscaladoHabilidad.new()
	var c_dano := CampoEscaladoPorcentaje.new()
	c_dano.campo = Enums.Habilidad.CampoEscalable.DANO_MIN
	c_dano.porcentaje_por_nivel = 0.10
	var c_recarga := CampoEscaladoPorcentaje.new()
	c_recarga.campo = Enums.Habilidad.CampoEscalable.RECARGA
	c_recarga.porcentaje_por_nivel = -0.05  # negativo: la recarga BAJA
	escalado.campos = [c_dano, c_recarga] as Array[CampoEscalado]
	escalado.nivel_maximo = 5
	hab.preparar_escalado(escalado)

	hab.aplicar_nivel_mejora(3)  # 2 pasos: +20% dano_min, -10% recarga
	print("dano_min nivel 3 (esperado 12 = 10*1.2): %d" % hab._dano_min)
	print("duracion_recarga nivel 3 (esperado 0.90 = 1.00*0.9): %.2f" % hab.duracion_recarga)
	var nivel_3_ok := hab._dano_min == 12 and is_equal_approx(hab.duracion_recarga, 0.9)
	_porcentaje_negativo_reduce_ok = is_equal_approx(hab.duracion_recarga, 0.9)

	# Bajar de nivel 3 a 2 no debe quedar compuesto sobre el 12 anterior.
	hab.aplicar_nivel_mejora(2)  # 1 paso: +10%
	print("dano_min nivel 2 tras haber estado en nivel 3 (esperado 11 = 10*1.1, NO 12*1.1): %d" % hab._dano_min)
	_porcentaje_no_compone_ok = nivel_3_ok and hab._dano_min == 11


func _probar_tabla() -> void:
	var hab := _crear_habilidad(10, 12, 1.0)
	var escalado := EscaladoHabilidad.new()
	var c_min := CampoEscaladoTabla.new()
	c_min.campo = Enums.Habilidad.CampoEscalable.DANO_MIN
	c_min.valores_por_nivel = [10.0, 14.0, 18.0]
	var c_max := CampoEscaladoTabla.new()
	c_max.campo = Enums.Habilidad.CampoEscalable.DANO_MAX
	c_max.valores_por_nivel = [12.0, 17.0, 22.0]
	escalado.campos = [c_min, c_max] as Array[CampoEscalado]
	escalado.nivel_maximo = 5  # más alto que la tabla a propósito
	hab.preparar_escalado(escalado)

	hab.aplicar_nivel_mejora(2)
	print("dano_min/max nivel 2 (esperado 14-17): %d-%d" % [hab._dano_min, hab._dano_max])
	var nivel_2_ok := hab._dano_min == 14 and hab._dano_max == 17

	hab.aplicar_nivel_mejora(5)  # más allá de lo definido en la tabla (solo hay 3 entradas)
	print("dano_min/max nivel 5, tabla de solo 3 (esperado se queda en 18-22): %d-%d" % [hab._dano_min, hab._dano_max])
	_tabla_se_queda_en_ultimo_ok = hab._dano_min == 18 and hab._dano_max == 22
	_tabla_valores_exactos_ok = nivel_2_ok


func _probar_sin_escalado() -> void:
	var hab := _crear_habilidad(10, 12, 1.0)
	hab.preparar_escalado(null)
	hab.aplicar_nivel_mejora(3)
	print("Sin escalado, dano_min no cambia (esperado 10): %d" % hab._dano_min)
	print("Sin escalado, nivel_mejora vuelve a 1 (esperado 1): %d" % hab.nivel_mejora)
	_sin_escalado_no_hace_nada_ok = hab._dano_min == 10 and hab.nivel_mejora == 1


func _probar_campo_no_reconocido() -> void:
	var hab := _crear_habilidad(10, 12, 1.0)
	var escalado := EscaladoHabilidad.new()
	var c := CampoEscaladoPorcentaje.new()
	c.campo = Enums.Habilidad.CampoEscalable.DURACION_EFECTO  # HabilidadBase no lo reconoce
	c.porcentaje_por_nivel = 0.50
	escalado.campos = [c] as Array[CampoEscalado]
	hab.preparar_escalado(escalado)
	hab.aplicar_nivel_mejora(3)  # no debe explotar
	print("Campo no reconocido no cambia nada, dano_min sigue en 10: %d" % hab._dano_min)
	_campo_no_reconocido_no_explota_ok = hab._dano_min == 10 and hab.nivel_mejora == 3


func _informar() -> bool:
	var exito := _porcentaje_no_compone_ok and _porcentaje_negativo_reduce_ok \
		and _tabla_valores_exactos_ok and _tabla_se_queda_en_ultimo_ok \
		and _sin_escalado_no_hace_nada_ok and _campo_no_reconocido_no_explota_ok
	print("  porcentaje no compone en llamadas sucesivas: %s" % _porcentaje_no_compone_ok)
	print("  porcentaje negativo reduce el campo: %s" % _porcentaje_negativo_reduce_ok)
	print("  tabla da valores exactos por nivel: %s" % _tabla_valores_exactos_ok)
	print("  tabla se queda en el último valor: %s" % _tabla_se_queda_en_ultimo_ok)
	print("  sin escalado no hace nada: %s" % _sin_escalado_no_hace_nada_ok)
	print("  campo no reconocido no explota: %s" % _campo_no_reconocido_no_explota_ok)
	print("PRUEBA ESCALADO HABILIDAD GENERICO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
