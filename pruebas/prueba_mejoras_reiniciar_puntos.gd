# =============================================================================
# Prueba de MejorasComponente.reiniciar_puntos() — respec completo, pedido
# del usuario: "un botón al lado de los puntos de habilidad disponibles
# para reiniciarlos".
#
# Cubre:
#   1. Con puntos gastados en una pasiva de estadística Y una habilidad
#      activa equipada, reiniciar_puntos() vacía los dos registros y
#      devuelve puntos_gastados a 0 (puntos_disponibles() vuelve al total).
#   2. El bono de la pasiva (agregar_crecimiento_permanente, puramente
#      ADITIVO) desaparece de AtributosComponente — no alcanza con vaciar
#      niveles_pasivas, hay que deshacerlo de verdad.
#   3. La instancia VIVA de la habilidad equipada vuelve a nivel_mejora=1 al
#      instante, sin tener que reequiparla.
#   4. El crecimiento por NIVEL (vida/energía/daño de XP, no de puntos
#      gastados) sobrevive intacto — el reinicio no debe tocarlo.
#   5. Sin nada gastado, reiniciar_puntos() no hace nada (false, ningún
#      efecto secundario).
#   godot --headless --path . --script res://pruebas/prueba_mejoras_reiniciar_puntos.gd
# =============================================================================
extends SceneTree

var _jugador
var _mejoras
var _slots
var _experiencia
var _atributos
var _pasiva: PasivaStatDesbloqueo
var _datos_muro: DatosHabilidad

var _vacia_los_dos_registros_ok := false
var _puntos_disponibles_completos_ok := false
var _deshace_bono_pasiva_ok := false
var _instancia_viva_vuelve_a_nivel_1_ok := false
var _crecimiento_por_nivel_sobrevive_ok := false
var _sin_nada_gastado_no_hace_nada_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_gastar_en_pasiva_y_habilidad()
	_probar_reinicio()
	_probar_sin_nada_gastado()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	# AtributosComponente/VidaComponente ANTES que ExperienciaComponente: su
	# _ready() (que corre apenas se agrega al árbol, ver
	# ExperienciaComponente._capturar_baseline) necesita encontrarlos YA
	# como hermanos para capturar la línea de base de verdad — si no
	# existen todavía, _atributos_linea_base se queda en null para
	# siempre (el guard _base_capturada evita cualquier reintento
	# posterior), y restaurar_xp() nunca puede deshacer nada.
	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	_atributos.name = "AtributosComponente"
	_atributos.base = AtributosBase.new()
	_jugador.add_child(_atributos)
	_atributos._ready()

	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	_jugador.add_child(vida)

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_pasiva = PasivaStatDesbloqueo.new()
	_pasiva.resource_path = "res://pruebas/fixtures/PasivaStatReinicioDePrueba.tres"
	_pasiva.nivel_requerido = 1
	_pasiva.max_niveles = 5
	_pasiva.costo_puntos_por_nivel = 1
	_pasiva.bono = AtributosBase.new()
	_pasiva.bono.defensa = 3.0
	_experiencia.pasivas_stat = [_pasiva] as Array[PasivaStatDesbloqueo]
	_jugador.add_child(_experiencia)
	_experiencia.agregar_xp(100000)  # nivel alto -> muchos puntos y buen colchón de vida/energía

	_mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	_mejoras.name = "MejorasComponente"
	_jugador.add_child(_mejoras)

	_slots = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	_slots.name = "SlotHabilidades"
	_slots.jugador = _jugador
	_jugador.add_child(_slots)

	# muro.tres es un recurso CACHEADO/compartido — escalado de prueba EN
	# MEMORIA, mismo criterio que prueba_mejoras_gastar_en_habilidad.gd.
	_datos_muro = load("res://recursos/habilidades/muro.tres") as DatosHabilidad
	var escalado := EscaladoHabilidad.new()
	var c_min := CampoEscaladoTabla.new()
	c_min.campo = Enums.Habilidad.CampoEscalable.DANO_MIN
	c_min.valores_por_nivel = [3.0, 5.0, 7.0]
	var c_max := CampoEscaladoTabla.new()
	c_max.campo = Enums.Habilidad.CampoEscalable.DANO_MAX
	c_max.valores_por_nivel = [6.0, 9.0, 12.0]
	escalado.campos = [c_min, c_max] as Array[CampoEscalado]
	escalado.nivel_maximo = 3
	escalado.costo_puntos_por_nivel = 1
	_datos_muro.escalado = escalado
	_slots.equipar(0, _datos_muro)


func _gastar_en_pasiva_y_habilidad() -> void:
	_mejoras._gastar_en_pasiva_local(_pasiva)
	_mejoras._gastar_en_habilidad_local(_datos_muro)


func _probar_reinicio() -> void:
	var defensa_antes_de_reiniciar: float = _atributos.base.defensa
	var vida_maxima_antes: float = _jugador.get_node("VidaComponente").obtener_vida_maxima()
	print("Defensa CON la pasiva comprada (esperado 3.0): %.1f" % defensa_antes_de_reiniciar)

	var instancia: HabilidadBase = _slots.obtener(0)
	print("nivel_mejora de muro equipado CON 1 nivel comprado (esperado 2): %d" % instancia.nivel_mejora)

	var resultado: bool = _mejoras._reiniciar_puntos_local()
	print("reiniciar_puntos() con algo gastado (esperado true): %s" % resultado)

	_vacia_los_dos_registros_ok = _mejoras.niveles_pasivas.is_empty() \
		and _mejoras.niveles_habilidades.is_empty() and _mejoras.puntos_gastados == 0
	print("Los dos registros quedan vacíos y puntos_gastados=0 (esperado true): %s" % \
		_vacia_los_dos_registros_ok)

	var puntos_totales: int = _experiencia.nivel * _mejoras.PUNTOS_POR_NIVEL
	_puntos_disponibles_completos_ok = _mejoras.puntos_disponibles() == puntos_totales
	print("puntos_disponibles() vuelve al total (esperado %d): %d" % [
		puntos_totales, _mejoras.puntos_disponibles()])

	_deshace_bono_pasiva_ok = is_equal_approx(_atributos.base.defensa, 0.0)
	print("Defensa SIN la pasiva tras reiniciar (esperado 0.0): %.1f" % _atributos.base.defensa)

	var instancia_despues: HabilidadBase = _slots.obtener(0)
	_instancia_viva_vuelve_a_nivel_1_ok = instancia == instancia_despues \
		and instancia_despues.nivel_mejora == 1
	print("nivel_mejora de la instancia VIVA tras reiniciar (esperado 1, sin reequipar): %d" % \
		instancia_despues.nivel_mejora)

	var vida_maxima_despues: float = _jugador.get_node("VidaComponente").obtener_vida_maxima()
	_crecimiento_por_nivel_sobrevive_ok = is_equal_approx(vida_maxima_despues, vida_maxima_antes)
	print("Vida máxima por NIVEL sobrevive al reinicio (esperado %.1f): %.1f" % [
		vida_maxima_antes, vida_maxima_despues])


func _probar_sin_nada_gastado() -> void:
	var resultado: bool = _mejoras._reiniciar_puntos_local()
	print("reiniciar_puntos() sin nada gastado (esperado false): %s" % resultado)
	_sin_nada_gastado_no_hace_nada_ok = not resultado


func _informar() -> bool:
	var exito := _vacia_los_dos_registros_ok and _puntos_disponibles_completos_ok \
		and _deshace_bono_pasiva_ok and _instancia_viva_vuelve_a_nivel_1_ok \
		and _crecimiento_por_nivel_sobrevive_ok and _sin_nada_gastado_no_hace_nada_ok
	print("  vacía los dos registros y puntos_gastados: %s" % _vacia_los_dos_registros_ok)
	print("  puntos_disponibles vuelve al total: %s" % _puntos_disponibles_completos_ok)
	print("  deshace el bono de la pasiva: %s" % _deshace_bono_pasiva_ok)
	print("  instancia viva vuelve a nivel 1: %s" % _instancia_viva_vuelve_a_nivel_1_ok)
	print("  crecimiento por nivel sobrevive: %s" % _crecimiento_por_nivel_sobrevive_ok)
	print("  sin nada gastado no hace nada: %s" % _sin_nada_gastado_no_hace_nada_ok)
	print("PRUEBA MEJORAS REINICIAR PUNTOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
