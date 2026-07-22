# =============================================================================
# Prueba de la tabla de niveles (TablaNiveles/ExperienciaComponente):
#   1. La curva: xp_para_alcanzar/nivel_desde_xp/progreso_en_nivel dan los
#      valores esperados (nivel 1=0, nivel 2=100, nivel 3=300 acumulados).
#   2. Subir de nivel de verdad (agregar_xp cruzando el umbral) aplica el
#      crecimiento automático: +10 vida_max, +5 energia_max, +1 daños — y
#      emite BusEventos.nivel_subido.
#   3. Un salto grande de XP que cruza VARIOS niveles de una sola vez aplica
#      el crecimiento una vez POR NIVEL, no una sola vez.
#   4. restaurar_xp() (el camino de GestorGuardado al cargar partida) deja
#      el nivel y el crecimiento acumulado correctos de una sola pasada,
#      sin tener que re-jugar los niveles anteriores.
#   5. El bono de daño por nivel SOBREVIVE a un recálculo de equipo
#      (AtributosComponente.recalcular_con_equipo) posterior — bug
#      reportado: "al cargar la partida las estadísticas no se reflejan en
#      el daño", porque recalcular_con_equipo() sobreescribía "base" entero
#      desde la copia de fábrica, sin saber nada de niveles. Este es
#      EXACTAMENTE lo que pasa al cargar una partida: restaurar_xp()
#      corre, y después _restaurar_equipo() dispara un recálculo.
#   6. restaurar_xp() llamado VARIAS veces sobre el mismo nodo (cada
#      reconexión del jugador al servidor dispara _aplicar_estado_red ->
#      restaurar_xp(), ver GestorGuardado) da SIEMPRE el mismo resultado en
#      vez de sumar el crecimiento de nuevo encima de lo que ya había — bug
#      grave reportado: una Bola de Fuego con daño base 10-12 llegó a hacer
#      400 de daño tras varias reconexiones, porque cada una volvía a sumar
#      +10 vida_max/+5 energia_max/+1 daños POR NIVEL YA ALCANZADO.
#   godot --headless --path . --script res://pruebas/prueba_tabla_niveles.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador: CharacterBody2D
# Sin tipar (ExperienciaComponente/VidaComponente/EnergiaComponente/
# AtributosComponente): tipar estos autoload-dependientes fuerza a Godot a
# compilarlos —y sus dependencias (Utils, BusEventos)— ANTES de que los
# autoloads existan, en un .gd pasado por --script (mismo caso ya
# documentado en otras pruebas de este proyecto: "Sin tipar ni precargar
# en el cuerpo de la clase").
var _experiencia
var _vida
var _energia
var _atributos
var _niveles_recibidos: Array[int] = []
var _vida_max_inicial: float
var _energia_max_inicial: float
var _danos_inicial: float


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _verificar_curva()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")

	# load(...).new() en vez de ClassName.new(): en un .gd pasado por
	# --script (este archivo ES el MainLoop) los scripts de componentes que
	# referencian autoloads (Utils, BusEventos) en su propio cuerpo fallan
	# "Identifier not found" si se resuelven a tiempo de compilación —
	# mismo caso ya documentado en otras pruebas de este proyecto.
	_vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	_jugador.add_child(_vida)
	_vida_max_inicial = _vida.salud_maxima

	_energia = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	_energia.name = "EnergiaComponente"
	_energia.energia_maxima = 100.0
	_jugador.add_child(_energia)
	_energia_max_inicial = _energia.energia_maxima

	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	_atributos.name = "AtributosComponente"
	_atributos.base = (load("res://recursos/AtributosBase.gd") as GDScript).new()
	_jugador.add_child(_atributos)
	_danos_inicial = _atributos.base.danos

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_experiencia.subio_de_nivel.connect(func(n): _niveles_recibidos.append(n))
	_jugador.add_child(_experiencia)

	# Para el paso 7: el reseteo de restaurar_xp() reconstruye "base" desde
	# el equipo actual leyendo este componente hermano (como el Jugador real).
	var equipo = (load("res://componentes/EquipoComponente.gd") as GDScript).new()
	equipo.name = "EquipoComponente"
	_jugador.add_child(equipo)

	root.add_child(_jugador)


func _verificar_curva() -> bool:
	# ── 1. Curva pura ────────────────────────────────────────────────────
	var xp1 := TablaNiveles.xp_para_alcanzar(1)
	var xp2 := TablaNiveles.xp_para_alcanzar(2)
	var xp3 := TablaNiveles.xp_para_alcanzar(3)
	print("xp_para_alcanzar: nivel1=%d(esperado 0) nivel2=%d(esperado 100) nivel3=%d(esperado 300)" % [xp1, xp2, xp3])
	var nivel_en_50 := TablaNiveles.nivel_desde_xp(50)
	var nivel_en_100 := TablaNiveles.nivel_desde_xp(100)
	var nivel_en_299 := TablaNiveles.nivel_desde_xp(299)
	var nivel_en_300 := TablaNiveles.nivel_desde_xp(300)
	print("nivel_desde_xp: 50->%d(esp 1) 100->%d(esp 2) 299->%d(esp 2) 300->%d(esp 3)" % [
		nivel_en_50, nivel_en_100, nivel_en_299, nivel_en_300])
	var curva_ok := xp1 == 0 and xp2 == 100 and xp3 == 300 \
		and nivel_en_50 == 1 and nivel_en_100 == 2 and nivel_en_299 == 2 and nivel_en_300 == 3

	# ── 2. Subir un nivel de verdad (cruza el umbral de 100) ────────────
	_experiencia.agregar_xp(80)   # 80 total, sigue en nivel 1
	var nivel_tras_80: int = _experiencia.nivel
	_experiencia.agregar_xp(30)   # 110 total, cruza a nivel 2
	var nivel_tras_110: int = _experiencia.nivel
	print("nivel tras 80xp=%d(esp 1) tras 110xp=%d(esp 2)" % [nivel_tras_80, nivel_tras_110])
	print("crecimiento tras subir 1 nivel: vida_max=%.0f(esp %.0f) energia_max=%.0f(esp %.0f) danos=%.0f(esp %.0f)" % [
		_vida.salud_maxima, _vida_max_inicial + 10.0,
		_energia.energia_maxima, _energia_max_inicial + 5.0,
		_atributos.base.danos, _danos_inicial + 1.0,
	])
	var un_nivel_ok: bool = nivel_tras_80 == 1 and nivel_tras_110 == 2 \
		and is_equal_approx(_vida.salud_maxima, _vida_max_inicial + 10.0) \
		and is_equal_approx(_energia.energia_maxima, _energia_max_inicial + 5.0) \
		and is_equal_approx(_atributos.base.danos, _danos_inicial + 1.0) \
		and _niveles_recibidos == [2]

	# ── 3. Salto grande: cruza varios niveles de una sola ganancia ──────
	# En 110 (nivel 2). +600 = 710 total. nivel_desde_xp(710): nivel3=300,
	# nivel4=600, nivel5=1000 → nivel 4. Debe pasar por 3 y 4 (una vez c/u).
	_experiencia.agregar_xp(600)
	var nivel_tras_salto: int = _experiencia.nivel
	print("nivel tras salto grande (710 total, esperado 4): %d" % nivel_tras_salto)
	print("niveles recibidos por señal (esperado [2, 3, 4]): %s" % str(_niveles_recibidos))
	# 3 niveles subidos en total (2, 3, 4) → +30 vida_max, +15 energia_max, +3 danos.
	var salto_ok: bool = nivel_tras_salto == 4 and _niveles_recibidos == [2, 3, 4] \
		and is_equal_approx(_vida.salud_maxima, _vida_max_inicial + 30.0) \
		and is_equal_approx(_energia.energia_maxima, _energia_max_inicial + 15.0) \
		and is_equal_approx(_atributos.base.danos, _danos_inicial + 3.0)

	# ── 4. restaurar_xp(): mismo estado final, sin re-jugar los niveles ──
	var vida_max_directo: float = _vida.salud_maxima
	var energia_max_directo: float = _energia.energia_maxima
	var danos_directo: float = _atributos.base.danos
	# NO se resetea nada a mano acá a propósito — restaurar_xp() ahora
	# resetea a la línea de base de fábrica (_capturar_baseline/
	# _resetear_a_baseline) por su cuenta antes de reaplicar el crecimiento,
	# así que llamarlo de nuevo sobre el mismo nodo (nivel/xp_total en
	# cualquier estado previo) tiene que dar el mismo resultado — ver el
	# paso 6 más abajo, que es la prueba real de esto: dos reconexiones
	# seguidas sin resetear nada a mano.
	_experiencia.nivel = 1
	_experiencia.xp_total = 0
	_experiencia.restaurar_xp(710)
	print("restaurar_xp(710): nivel=%d(esp 4) vida_max=%.0f(esp %.0f) energia_max=%.0f(esp %.0f) danos=%.0f(esp %.0f)" % [
		_experiencia.nivel, _vida.salud_maxima, vida_max_directo,
		_energia.energia_maxima, energia_max_directo,
		_atributos.base.danos, danos_directo,
	])
	var restaurar_ok: bool = _experiencia.nivel == 4 \
		and is_equal_approx(_vida.salud_maxima, vida_max_directo) \
		and is_equal_approx(_energia.energia_maxima, energia_max_directo) \
		and is_equal_approx(_atributos.base.danos, danos_directo)

	# ── 5. El bono de daño sobrevive a un recálculo de equipo ────────────
	# Mismo orden que GestorGuardado al cargar partida: XP primero
	# (restaurar_xp ya corrió arriba, quedó en nivel 4 = +3 danos), equipo
	# después. Un recálculo con la lista vacía (equivalente a "sin nada
	# puesto") NO debería borrar el crecimiento de nivel.
	var danos_antes_recalculo: float = _atributos.base.danos
	var sin_equipo: Array[DatosItem] = []
	_atributos.recalcular_con_equipo(sin_equipo)
	print("danos tras recalcular_con_equipo (esperado %.0f, el bug daba %.0f): %.0f" % [
		danos_antes_recalculo, _danos_inicial, _atributos.base.danos])
	var sobrevive_ok: bool = is_equal_approx(_atributos.base.danos, danos_antes_recalculo)

	# ── 6. Reconexiones repetidas: restaurar_xp() NO debe acumular ──────
	# Simula al jugador reconectando dos veces seguidas con la misma XP
	# guardada (710, nivel 4) — igual que el servidor real (ver
	# GestorGuardado._aplicar_estado_red). Nada se resetea a mano: si
	# restaurar_xp() no fuera idempotente, esta segunda llamada volvería a
	# sumar +30 vida_max/+15 energia_max/+3 daños ENCIMA de lo que ya había.
	_experiencia.restaurar_xp(710)
	print("restaurar_xp(710) llamado 2 VECES seguidas (simula reconexión doble) — nivel=%d(esp 4) vida_max=%.0f(esp %.0f) energia_max=%.0f(esp %.0f) danos=%.0f(esp %.0f)" % [
		_experiencia.nivel, _vida.salud_maxima, vida_max_directo,
		_energia.energia_maxima, energia_max_directo,
		_atributos.base.danos, danos_directo,
	])
	var reconexion_doble_ok: bool = _experiencia.nivel == 4 \
		and is_equal_approx(_vida.salud_maxima, vida_max_directo) \
		and is_equal_approx(_energia.energia_maxima, energia_max_directo) \
		and is_equal_approx(_atributos.base.danos, danos_directo)

	# ── 7. Equipo puesto ANTES de restaurar_xp() sobrevive al reseteo ───
	# Orden real al reconectar: el equipo llega y se aplica primero
	# (EquipoComponente._equipar_red), la XP después (GestorGuardado.
	# _aplicar_estado_red -> restaurar_xp). El reseteo a fábrica de
	# restaurar_xp() borraba el bono de daños del equipo — el servidor
	# quedaba pegando más flojo de lo que el panel del cliente mostraba
	# (reportado: "parece resistencia en vez de debilidad al fuego").
	var espada := DatosItem.new()
	espada.name = "Espada de Prueba"
	var bonos_espada = (load("res://recursos/AtributosBase.gd") as GDScript).new()
	bonos_espada.danos = 6.0
	espada.bonos = bonos_espada
	var con_espada: Array[DatosItem] = [espada]
	_jugador.get_node("EquipoComponente").actualizar(con_espada)
	_experiencia.restaurar_xp(710)
	# Esperado: fábrica + 6 de la espada + 3 del crecimiento de niveles.
	var danos_esperado_equipo: float = _danos_inicial + 6.0 + 3.0
	print("restaurar_xp(710) con la espada YA puesta — danos=%.0f(esp %.0f: fábrica + 6 espada + 3 niveles)" % [
		_atributos.base.danos, danos_esperado_equipo])
	var equipo_sobrevive_ok: bool = is_equal_approx(_atributos.base.danos, danos_esperado_equipo)

	var exito: bool = curva_ok and un_nivel_ok and salto_ok and restaurar_ok and sobrevive_ok and reconexion_doble_ok and equipo_sobrevive_ok
	print("PRUEBA TABLA NIVELES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
