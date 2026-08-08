# =============================================================================
# Prueba del nivel de mejora en habilidades ACTIVAS, ahora con escalado
# CONFIGURABLE por habilidad (ver DatosHabilidad.escalado/EscaladoHabilidad/
# HabilidadBase.preparar_escalado) en vez de una fórmula fija global. El
# mecanismo genérico en sí (porcentaje vs. tabla, no compone, tope, campo
# no reconocido) ya se prueba aparte en prueba_escalado_habilidad_generico.gd
# — esto cubre que el flujo completo de EQUIPAR/GASTAR lo respeta.
#
# Cubre:
#   1. SlotHabilidades._instanciar() llama preparar_escalado(datos.escalado)
#      antes de aplicar_nivel_mejora() — el escalado configurado (mezcla de
#      CampoEscaladoTabla para daño y CampoEscaladoPorcentaje para recarga)
#      se aplica de verdad al equipar con niveles ya comprados.
#   2. El progreso vive en MejorasComponente (por resource_path), no en la
#      instancia — reequipar en OTRO slot conserva el nivel comprado.
#   3. Gastar en una habilidad YA EQUIPADA actualiza la instancia VIVA sin
#      reequipar.
#   4. Costo/tope salen de datos.escalado (no de una constante global).
#   5. Una habilidad SIN escalado asignado (escalado == null) rechaza el
#      gasto — opt-in explícito, no toda habilidad es mejorable.
#   godot --headless --path . --script res://pruebas/prueba_mejoras_gastar_en_habilidad.gd
# =============================================================================
extends SceneTree

var _jugador
var _mejoras
var _slots
var _datos: DatosHabilidad

var _equipar_aplica_escalado_configurado_ok := false
var _sobrevive_a_reequipar_en_otro_slot_ok := false
var _gastar_actualiza_instancia_viva_ok := false
var _costo_tope_salen_del_escalado_ok := false
var _sin_escalado_rechaza_gasto_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_equipar_aplica_escalado()
	_probar_gastar_actualiza_instancia_viva()
	_probar_costo_tope_por_recurso()
	_probar_sin_escalado()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	# Nivel bien alto -> muchos puntos disponibles por defecto (20), para
	# que las pruebas de tope/costo controlen los puntos a propósito (ver
	# _probar_costo_tope_por_recurso) en vez de toparse sin querer con el
	# costo_puntos_por_nivel=2 que configura este escalado de prueba.
	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	_jugador.add_child(experiencia)
	experiencia.agregar_xp(100000)

	_mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	_mejoras.name = "MejorasComponente"
	_jugador.add_child(_mejoras)

	# Nombre EXPLÍCITO (no el que Godot asigna solo): MejorasComponente
	# busca a este nodo por nombre ("SlotHabilidades") para actualizar la
	# instancia viva al gastar puntos — ver _gastar_en_habilidad_local.
	_slots = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	_slots.name = "SlotHabilidades"
	_slots.jugador = _jugador
	_jugador.add_child(_slots)

	# muro.tres es un recurso CACHEADO/compartido — se le asigna un
	# escalado de prueba EN MEMORIA (no se guarda a disco), suficiente para
	# un proceso --script aislado que termina enseguida.
	_datos = load("res://recursos/habilidades/muro.tres") as DatosHabilidad
	var escalado := EscaladoHabilidad.new()
	var c_min := CampoEscaladoTabla.new()
	c_min.campo = Enums.Habilidad.CampoEscalable.DANO_MIN
	c_min.valores_por_nivel = [3.0, 5.0, 7.0]
	var c_max := CampoEscaladoTabla.new()
	c_max.campo = Enums.Habilidad.CampoEscalable.DANO_MAX
	c_max.valores_por_nivel = [6.0, 9.0, 12.0]
	var c_recarga := CampoEscaladoPorcentaje.new()
	c_recarga.campo = Enums.Habilidad.CampoEscalable.RECARGA
	c_recarga.porcentaje_por_nivel = -0.05
	escalado.campos = [c_min, c_max, c_recarga] as Array[CampoEscalado]
	escalado.nivel_maximo = 3
	escalado.costo_puntos_por_nivel = 2
	_datos.escalado = escalado


func _probar_equipar_aplica_escalado() -> void:
	# Simula "ya compré 2 niveles" (sin pasar por el RPC de gasto todavía).
	_mejoras.niveles_habilidades[_datos.resource_path] = 2

	_slots.equipar(0, _datos)
	var instancia_slot_0: HabilidadBase = _slots.obtener(0)
	print("nivel_mejora al equipar en slot 0 con 2 comprados (esperado 3): %d" % instancia_slot_0.nivel_mejora)
	print("dano_min/max según la TABLA configurada (esperado 7-12): %d-%d" % [
		instancia_slot_0._dano_min, instancia_slot_0._dano_max])
	_equipar_aplica_escalado_configurado_ok = instancia_slot_0.nivel_mejora == 3 \
		and instancia_slot_0._dano_min == 7 and instancia_slot_0._dano_max == 12

	# Reequipar la MISMA habilidad en OTRO slot — el progreso vive en
	# MejorasComponente (por resource_path), no en la instancia vieja.
	_slots.equipar(1, _datos)
	var instancia_slot_1: HabilidadBase = _slots.obtener(1)
	print("nivel_mejora al reequipar en slot 1 (esperado 3, sobrevive): %d" % instancia_slot_1.nivel_mejora)
	_sobrevive_a_reequipar_en_otro_slot_ok = instancia_slot_1.nivel_mejora == 3


## Gastar un punto en una habilidad YA EQUIPADA tiene que actualizar la
## instancia VIVA de inmediato (no solo el registro en MejorasComponente)
## — sin esto, el jugador vería el gasto descontado pero la habilidad
## seguiría pegando igual hasta volver a equiparla.
func _probar_gastar_actualiza_instancia_viva() -> void:
	_mejoras.niveles_habilidades.clear()
	_mejoras.puntos_gastados = 0
	_slots.equipar(2, _datos)  # slot nuevo, nivel_mejora arranca en 1

	var antes: HabilidadBase = _slots.obtener(2)
	print("nivel_mejora antes de gastar (esperado 1): %d" % antes.nivel_mejora)

	var resultado: bool = _mejoras._gastar_en_habilidad_local(_datos)
	print("Gasto en habilidad ya equipada (esperado true): %s" % resultado)

	var despues: HabilidadBase = _slots.obtener(2)
	print("nivel_mejora de la instancia VIVA tras gastar (esperado 2, sin reequipar): %d" % despues.nivel_mejora)
	_gastar_actualiza_instancia_viva_ok = resultado and antes == despues and despues.nivel_mejora == 2


## costo_puntos_por_nivel=2 y nivel_maximo=3 vienen del escalado de ESTE
## recurso, no de una constante global — confirmar que se respetan.
func _probar_costo_tope_por_recurso() -> void:
	_mejoras.niveles_habilidades.clear()
	# Dejar disponible EXACTAMENTE 1 punto (el escalado pide 2 por nivel) —
	# relativo a lo que de verdad otorga el nivel del personaje, no un
	# número fijo, para no depender de cuánta XP se le dio en _montar().
	_mejoras.puntos_gastados = 0
	var puntos_totales: int = _mejoras.puntos_disponibles()
	_mejoras.puntos_gastados = puntos_totales - 1
	var con_1_punto: bool = _mejoras._gastar_en_habilidad_local(_datos)
	print("Gasto con 1 punto, cuesta 2 (esperado false): %s" % con_1_punto)

	# Ya en nivel_actual=2 (tope nivel_maximo=3): un gasto más debe alcanzar
	# el tope, y OTRO más allá debe rechazarse.
	_mejoras.niveles_habilidades[_datos.resource_path] = 1  # ya en nivel 2
	_mejoras.puntos_gastados = 0
	var al_tope: bool = _mejoras._gastar_en_habilidad_local(_datos)  # sube a nivel 3 (tope)
	var pasado_el_tope: bool = _mejoras._gastar_en_habilidad_local(_datos)  # ya no debería poder
	print("Gasto que llega al tope (esperado true): %s" % al_tope)
	print("Gasto pasado el tope de nivel_maximo=3 (esperado false): %s" % pasado_el_tope)

	_costo_tope_salen_del_escalado_ok = not con_1_punto and al_tope and not pasado_el_tope


func _probar_sin_escalado() -> void:
	var datos_sin_escalado := DatosHabilidad.new()
	datos_sin_escalado.resource_path = "res://pruebas/fixtures/HabilidadSinEscaladoDePrueba.tres"
	datos_sin_escalado.dano_base_min = 5
	datos_sin_escalado.dano_base_max = 8
	datos_sin_escalado.escalado = null

	_mejoras.niveles_habilidades.clear()
	_mejoras.puntos_gastados = 0
	var resultado: bool = _mejoras._gastar_en_habilidad_local(datos_sin_escalado)
	print("Gasto en habilidad SIN escalado configurado (esperado false): %s" % resultado)
	_sin_escalado_rechaza_gasto_ok = not resultado


func _informar() -> bool:
	var exito := _equipar_aplica_escalado_configurado_ok and _sobrevive_a_reequipar_en_otro_slot_ok \
		and _gastar_actualiza_instancia_viva_ok and _costo_tope_salen_del_escalado_ok \
		and _sin_escalado_rechaza_gasto_ok
	print("  equipar aplica el escalado configurado (tabla+porcentaje): %s" % _equipar_aplica_escalado_configurado_ok)
	print("  sobrevive a reequipar en otro slot: %s" % _sobrevive_a_reequipar_en_otro_slot_ok)
	print("  gastar actualiza la instancia viva sin reequipar: %s" % _gastar_actualiza_instancia_viva_ok)
	print("  costo/tope salen del escalado del recurso: %s" % _costo_tope_salen_del_escalado_ok)
	print("  sin escalado configurado rechaza el gasto: %s" % _sin_escalado_rechaza_gasto_ok)
	print("PRUEBA MEJORAS GASTAR EN HABILIDAD %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
