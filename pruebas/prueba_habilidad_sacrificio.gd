# =============================================================================
# Prueba de HabilidadSacrificio: self-buff de alto riesgo/alto beneficio del
# JUGADOR — paga 20% de la vida ACTUAL a cambio de +100 potencia, +20%
# probabilidad de crítico y +10% daño crítico por 30s (números exactos
# pedidos por el usuario, que también la pidió como prueba de estrés del
# sistema de bonos temporales generalizado en AtributosComponente — ver ese
# archivo, antes solo cargaba "danos" para Grito de Guerra).
#
# Verifica:
#   1. Cuesta EXACTAMENTE el 20% de la vida ACTUAL (no la máxima) al activarse.
#   2. Nunca puede matar de un solo uso (80% siempre queda).
#   3. Los bonos de potencia/crítico/daño crítico quedan registrados en
#      AtributosComponente — leídos directo de los getters (obtener_bono_*),
#      sin pasar por calcular_dano_saliente(), que tiene un roll de crítico
#      aleatorio de por medio y volvería la prueba no determinística.
#   4. Aparece el ícono en BuffsComponente mientras dura.
#   5. Al vencer (forzado, sin esperar 30s reales — mismo criterio que
#      prueba_buff_equipo.gd), los tres bonos vuelven a 0 y el ícono desaparece.
#   6. Estrés: Sacrificio y un bono al estilo Grito de Guerra (mismo
#      diccionario _bonos_temporales, ids distintos) coexisten sin pisarse,
#      y calcular_dano_saliente_vista_previa() sigue sin verse afectada por
#      NINGUNO de los dos (por diseño, ver ese método — es la vista "de
#      catálogo", no la vista "en combate ahora mismo").
#   7. sacrificio.tres escala potencia/probabilidad de crítico/daño crítico
#      con el nivel de mejora (pedido explícito del usuario) — usa los 3
#      campos "libres" de Enums.Habilidad.CampoEscalable (RADIO/DURACION_
#      EFECTO/PORCENTAJE_EFECTO, ninguno atado a una fila fija del panel de
#      detalle) vía el override en HabilidadSacrificio._nombre_campo_
#      escalable(), mismo criterio que HabilidadEscudo.
#   godot --headless --path . --script res://pruebas/prueba_habilidad_sacrificio.gd
# =============================================================================
extends SceneTree

var _jugador
var _vida
var _atributos
var _buffs
var _habilidad
var _vida_antes: float
var _dano_base_previa_antes: float

var _resultados: Array[bool] = []
const _CHEQUEOS_ESPERADOS := 9


func _process(_delta: float) -> bool:
	_montar()
	# Jugador.tscn arranca con la invulnerabilidad de aparición activa
	# (TIEMPO_INVULNERABILIDAD_APARICION, ver Jugador.gd) — bloquearía el
	# auto-daño que se está por probar. Mismo criterio que prueba_muerte_
	# jugador.gd: cortarla explícitamente antes de golpear.
	_vida.cancelar_invulnerabilidad()
	_vida_antes = _vida.obtener_vida()
	_dano_base_previa_antes = _atributos.calcular_dano_saliente_vista_previa(10.0)
	_habilidad.activar()

	_verificar_costo_vida()
	_verificar_bonos_aplicados()
	_verificar_icono_buff(true)

	_forzar_vencimiento_sacrificio()
	_verificar_bonos_en_cero()
	_verificar_icono_buff(false)

	_verificar_coexistencia_con_otro_bono()
	_verificar_escalado()

	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_vida = _jugador.get_node("VidaComponente")
	_atributos = _jugador.get_node("AtributosComponente")
	_buffs = _jugador.get_node("BuffsComponente")

	var escena := load("res://escenas/habilidades/sacrificio/HabilidadSacrificio.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_jugador.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	# Mismo motivo que en HabilidadBuffEquipo: sin ícono no se anota en
	# BuffsComponente. Acá SÍ importa que haya uno (a diferencia de otras
	# pruebas de habilidad de mob), porque una de las cosas a verificar es
	# justamente que el ícono aparezca y desaparezca.
	_habilidad.icono_buff = PlaceholderTexture2D.new()


func _verificar_costo_vida() -> void:
	var costo_esperado: float = _vida_antes * _habilidad.costo_vida_porcentaje
	var vida_ok: bool = is_equal_approx(_vida.obtener_vida(), _vida_antes - costo_esperado)
	_resultados.append(vida_ok)
	print("Costo exacto %d%% de la vida ACTUAL (esperado true): %s (vida %.1f -> %.1f, esperado %.1f)" % [
		int(_habilidad.costo_vida_porcentaje * 100), vida_ok, _vida_antes, _vida.obtener_vida(),
		_vida_antes - costo_esperado
	])

	var nunca_letal: bool = _vida.obtener_vida() > 0.0
	_resultados.append(nunca_letal)
	print("Nunca letal de un solo uso (esperado true, queda %.1f de vida): %s" % [_vida.obtener_vida(), nunca_letal])


func _verificar_bonos_aplicados() -> void:
	var potencia_ok: bool = is_equal_approx(_atributos.obtener_bono_potencia_temporal(), _habilidad.bono_potencia)
	var critico_ok: bool = is_equal_approx(_atributos.obtener_bono_probabilidad_critico_temporal(), _habilidad.bono_probabilidad_critico)
	var dano_critico_ok: bool = is_equal_approx(_atributos.obtener_bono_dano_critico_temporal(), _habilidad.bono_dano_critico)
	var ok: bool = potencia_ok and critico_ok and dano_critico_ok
	_resultados.append(ok)
	print("Bonos de potencia/crítico/daño crítico aplicados (esperado true): %s (potencia=%.1f, prob_crit=%.1f, dano_crit=%.1f)" % [
		ok, _atributos.obtener_bono_potencia_temporal(), _atributos.obtener_bono_probabilidad_critico_temporal(),
		_atributos.obtener_bono_dano_critico_temporal()
	])


func _verificar_icono_buff(debe_estar_activo: bool) -> void:
	var activo: bool = _buffs.esta_activo("sacrificio")
	var ok: bool = activo == debe_estar_activo
	_resultados.append(ok)
	print("Ícono de buff %s (esperado true): %s" % [
		"activo" if debe_estar_activo else "ausente tras vencer", ok
	])


## Salta directo al vencimiento sin esperar los 30s reales — mismo criterio
## que prueba_buff_equipo.gd, pero acá hay que forzar DOS relojes en paralelo
## (AtributosComponente._bonos_temporales y BuffsComponente._buffs): son dos
## sistemas separados a propósito (ver esos archivos), así que "vencer" de
## verdad significa vencer los dos.
func _forzar_vencimiento_sacrificio() -> void:
	for bono in _atributos._bonos_temporales.values():
		bono.tiempo_restante = 0.001
	_atributos._process(0.01)
	for buff in _buffs._buffs.values():
		buff.tiempo_restante = 0.001
	_buffs._process(0.01)


func _verificar_bonos_en_cero() -> void:
	var ok: bool = is_equal_approx(_atributos.obtener_bono_potencia_temporal(), 0.0) \
		and is_equal_approx(_atributos.obtener_bono_probabilidad_critico_temporal(), 0.0) \
		and is_equal_approx(_atributos.obtener_bono_dano_critico_temporal(), 0.0)
	_resultados.append(ok)
	print("Bonos vuelven a 0 tras vencer (esperado true): %s" % ok)


## Prueba de estrés pedida por el usuario junto con la habilidad: Sacrificio
## y un bono de daño al estilo Grito de Guerra viven en el MISMO diccionario
## _bonos_temporales (ids distintos) — confirma que no se pisan entre sí, y
## que la vista previa (catálogo, sin bonos temporales por diseño) no se
## contamina con ninguno de los dos.
func _verificar_coexistencia_con_otro_bono() -> void:
	_atributos.agregar_bono_temporal("sacrificio", 0.0, _habilidad.bono_potencia,
		_habilidad.bono_probabilidad_critico, _habilidad.bono_dano_critico, 30.0)
	_atributos.agregar_bono_temporal("buff_equipo_dano", 15.0, 0.0, 0.0, 0.0, 10.0)

	var ambos_coexisten: bool = is_equal_approx(_atributos.obtener_bono_potencia_temporal(), _habilidad.bono_potencia) \
		and is_equal_approx(_atributos.obtener_bono_dano_temporal(), 15.0)
	_resultados.append(ambos_coexisten)
	print("Sacrificio + bono de daño ajeno coexisten sin pisarse (esperado true): %s (potencia=%.1f, daño=%.1f)" % [
		ambos_coexisten, _atributos.obtener_bono_potencia_temporal(), _atributos.obtener_bono_dano_temporal()
	])

	var vista_previa_intacta: bool = is_equal_approx(
		_atributos.calcular_dano_saliente_vista_previa(10.0), _dano_base_previa_antes)
	_resultados.append(vista_previa_intacta)
	print("Vista previa (catálogo) sigue sin ver bonos temporales (esperado true): %s" % vista_previa_intacta)


## sacrificio.tres escala potencia/probabilidad de crítico/daño crítico con
## el nivel de mejora — pedido explícito del usuario. Mismo orden que
## SlotHabilidades._instanciar() en el juego real: aplicar_datos() ->
## preparar_escalado() -> aplicar_nivel_mejora().
func _verificar_escalado() -> void:
	var datos := load("res://recursos/habilidades/sacrificio.tres") as DatosHabilidad
	var escena := load("res://escenas/habilidades/sacrificio/HabilidadSacrificio.tscn") as PackedScene
	var hab = escena.instantiate()
	_jugador.add_child(hab)
	hab.entidad_dueña = _jugador
	hab.aplicar_datos(datos)
	hab.preparar_escalado(datos.escalado)

	var potencia_por_nivel: Array[float] = [100.0, 120.0, 140.0, 160.0, 180.0]
	var prob_critico_por_nivel: Array[float] = [20.0, 25.0, 30.0, 35.0, 40.0]
	var dano_critico_por_nivel: Array[float] = [10.0, 15.0, 20.0, 25.0, 30.0]
	var escala_ok := true
	for nivel in range(1, 6):
		hab.aplicar_nivel_mejora(nivel)
		var i := nivel - 1
		var ok_nivel: bool = is_equal_approx(hab.bono_potencia, potencia_por_nivel[i]) \
			and is_equal_approx(hab.bono_probabilidad_critico, prob_critico_por_nivel[i]) \
			and is_equal_approx(hab.bono_dano_critico, dano_critico_por_nivel[i])
		if not ok_nivel:
			escala_ok = false
		print("Nivel %d -> potencia=%.1f prob_crit=%.1f dano_crit=%.1f (esperado %.1f/%.1f/%.1f)" % [
			nivel, hab.bono_potencia, hab.bono_probabilidad_critico, hab.bono_dano_critico,
			potencia_por_nivel[i], prob_critico_por_nivel[i], dano_critico_por_nivel[i]
		])
	_resultados.append(escala_ok)
	print("Potencia/probabilidad de crítico/daño crítico suben con el nivel (esperado true): %s" % escala_ok)


func _informar() -> bool:
	var conteo_ok := _resultados.size() == _CHEQUEOS_ESPERADOS
	if not conteo_ok:
		print("ADVERTENCIA: se esperaban %d chequeos, se registraron %d" % [_CHEQUEOS_ESPERADOS, _resultados.size()])
	var exito := conteo_ok
	for r in _resultados:
		exito = exito and r
	print("PRUEBA HABILIDAD SACRIFICIO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
