extends Node
class_name ExperienciaComponente
## ExperienciaComponente — la XP de ESTE jugador (Fase 1 del plan de
## migración a multijugador). Antes vivía en el autoload GestorExperiencia;
## ver ese archivo, que ahora es una fachada de compatibilidad.

## Emitida cada vez que xp_total cruza el umbral de un nivel nuevo (ver
## TablaNiveles) — nivel_nuevo, no cuánto subió, así un salto de varios
## niveles de una sola vez (XP grande de golpe) emite una vez por nivel.
signal subio_de_nivel(nivel_nuevo: int)

## Cuánto crece cada estadística POR NIVEL (ver _aplicar_crecimiento_nivel).
## Los máximos no se guardan en la partida: se derivan de la XP reaplicando
## esto una vez por nivel alcanzado, así que cambiar estos números
## RECALCULA a todos los personajes existentes la próxima vez que carguen.
const CRECIMIENTO_VIDA := 10.0
const CRECIMIENTO_ENERGIA := 5.0
const CRECIMIENTO_DANOS := 1.0

## Pasivas de ESTADÍSTICA que se desbloquean solas al alcanzar cierto nivel
## (ver PasivaStatDesbloqueo) — a diferencia de las pasivas de gatillo (por
## ítem especial, ver PasivasComponente), estas no necesitan persistencia
## propia: restaurar_xp() las re-deriva desde cero reaplicando el
## crecimiento nivel por nivel, mismo criterio que vida/energía máxima.
@export var pasivas_stat: Array[PasivaStatDesbloqueo] = []

var xp_total: int = 0
## Caché de TablaNiveles.nivel_desde_xp(xp_total) — NUNCA la fuente de
## verdad (esa es xp_total); se recalcula acá para no tener que llamar
## TablaNiveles desde cada lugar que solo quiere mostrar el nivel.
var nivel: int = 1

## Valores de fábrica (nivel 1, sin ningún crecimiento) de las estadísticas
## que _aplicar_crecimiento_nivel() incrementa — capturados UNA sola vez en
## _ready(), antes de que este nodo haya subido de nivel jamás. Existen para
## que restaurar_xp() pueda RESETEAR a un punto de partida conocido antes de
## reaplicar el crecimiento, en vez de sumarlo encima de lo que ya hubiera.
var _vida_maxima_base: float = 0.0
var _energia_maxima_base: float = 0.0
## Snapshot completo (los 17 campos, no solo daños) de AtributosComponente
## ._base_sin_equipo en el nivel 1 — ver AtributosComponente
## .capturar_linea_base(). Necesario desde que las pasivas de estadística
## pueden hacer crecer permanentemente cualquier campo, no solo daños.
var _atributos_linea_base: AtributosBase = null
var _base_capturada := false


func _ready() -> void:
	_capturar_baseline()


## Sin esto, cada reconexión del jugador volvía a sumar +10 vida_maxima /
## +5 energia_maxima / +1 daños POR CADA NIVEL YA ALCANZADO encima de las
## estadísticas que ya tenía — restaurar_xp() nunca partía de cero, así que
## el crecimiento se acumulaba sin límite con cada reconexión (bug grave
## reportado: una Bola de Fuego con daño base 10-12 llegó a hacer 400 de
## daño tras varias reconexiones). Este componente vive en el mismo nodo
## Jugador que persiste en el servidor entre reconexiones — _ready() solo
## corre una vez en la vida de ese nodo, así que esto captura el nivel 1
## real una sola vez, antes de que cualquier crecimiento se haya aplicado.
func _capturar_baseline() -> void:
	if _base_capturada:
		return
	var padre := get_parent()
	if padre == null:
		return
	var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		_vida_maxima_base = vida.salud_maxima
	var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		_energia_maxima_base = energia.energia_maxima
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos:
		_atributos_linea_base = atributos.capturar_linea_base()
	_base_capturada = true


## Vuelve vida_maxima/energia_maxima/daños al valor de fábrica capturado en
## _capturar_baseline() — el punto de partida limpio desde el que
## restaurar_xp() reaplica el crecimiento, para que llamarlo varias veces
## (una por reconexión) dé siempre el mismo resultado en vez de acumular.
func _resetear_a_baseline() -> void:
	var padre := get_parent()
	if padre == null:
		return
	var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.salud_maxima = _vida_maxima_base
	var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		energia.energia_maxima = _energia_maxima_base
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos and _atributos_linea_base:
		# "base" NO se pisa a pelo con la fábrica: se reconstruye como
		# fábrica + bonos del equipo ACTUAL. Al reconectar, el equipo suele
		# aplicarse ANTES de que llegue la restauración de XP — pisar base
		# directo borraba el bono de daños de la espada (la potencia
		# sobrevivía porque este reseteo solo tocaba daños), y el servidor
		# quedaba pegando más flojo de lo que el panel del cliente mostraba
		# (reportado: "parece que tuviera +10 de resistencia en vez de -10"
		# — la debilidad sí multiplicaba, pero sobre una base ya recortada).
		var equipo := padre.get_node_or_null("EquipoComponente")
		if equipo:
			atributos.restablecer_linea_base(_atributos_linea_base, equipo.equipados)
		else:
			atributos.restablecer_linea_base(_atributos_linea_base)


func agregar_xp(cantidad: int) -> void:
	if cantidad <= 0:
		return
	xp_total += cantidad

	# Subir de nivel ANTES de avisar la ganancia de XP: xp_agregada dispara
	# a la UI (barra de progreso "X / Y dentro del nivel", ver PanelTablero/
	# HudJugador) — si emitiera con el xp_total nuevo pero "nivel" viejo
	# (sin procesar todavía), la barra mostraba cosas como "105 / 100" justo
	# al cruzar el umbral (bug reportado).
	var nivel_nuevo := TablaNiveles.nivel_desde_xp(xp_total)
	while nivel_nuevo > nivel:
		nivel += 1
		_aplicar_crecimiento_nivel()
		subio_de_nivel.emit(nivel)
		BusEventos.nivel_subido.emit(nivel)

	BusEventos.xp_agregada.emit(cantidad, xp_total)


## Fija xp_total a un valor conocido de una sola vez (al cargar una
## partida guardada — ver GestorGuardado) y re-aplica el crecimiento de
## TODOS los niveles ya alcanzados: vida_maxima/energia_maxima/daños NO se
## guardan por separado en la partida, derivan siempre de la XP, la única
## fuente de verdad real. Sin este resync, un personaje de nivel 10 volvía
## a nacer con las estadísticas de nivel 1 tras reconectar. A diferencia de
## agregar_xp() (incremental, pensado para cada muerte de mob), esto
## siempre recalcula desde cero — no usar para ganancias normales de XP.
func restaurar_xp(valor: int) -> void:
	xp_total = maxi(valor, 0)
	nivel = 1
	_capturar_baseline()
	_resetear_a_baseline()
	var nivel_real := TablaNiveles.nivel_desde_xp(xp_total)
	while nivel < nivel_real:
		nivel += 1
		_aplicar_crecimiento_nivel(false)


## Bono automático al subir de nivel — nada de asignar puntos a mano, sube
## solo. Vive acá (no en Jugador.gd) porque Vida/Energia/Atributos son
## hermanos directos del mismo jugador dueño de este componente, mismo
## patrón que ya usa VidaComponente para leer AtributosComponente.
## [notificar] = false cuando restaurar_xp() reaplica el crecimiento de
## niveles YA alcanzados (reconexión) — evita repetir la notificación de
## pantalla de una pasiva que el jugador desbloqueó hace rato, mismo
## criterio que subio_de_nivel/BusEventos.nivel_subido (restaurar_xp()
## tampoco los emite).
func _aplicar_crecimiento_nivel(notificar: bool = true) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.salud_maxima += CRECIMIENTO_VIDA
		# Vida y energía a TOPE al subir de nivel (pedido del usuario) — no
		# solo el incremento de +10: agregar_vida() ya clampea al máximo
		# nuevo, así que pedir "todo el máximo" garantiza el 100% sin
		# importar cuánta vida tenía antes.
		vida.agregar_vida(vida.salud_maxima)
	var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		energia.energia_maxima += CRECIMIENTO_ENERGIA
		energia.agregar_energia(energia.energia_maxima)
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos:
		# agregar_crecimiento_permanente() (no "atributos.base.danos += 1.0"
		# directo): un bono aplicado solo a "base" desaparecía la próxima vez
		# que el equipo cambiaba — recalcular_con_equipo() sobreescribe
		# "base" entero desde la copia de fábrica, sin saber nada de niveles.
		var crecimiento := AtributosBase.new()
		crecimiento.danos = CRECIMIENTO_DANOS
		atributos.agregar_crecimiento_permanente(crecimiento)

		# Pasivas de estadística: cualquiera cuyo nivel_requerido sea
		# justo el que se acaba de alcanzar se aplica acá, una sola vez —
		# esta función corre una vez POR NIVEL incluso si agregar_xp()
		# cruza varios de un salto (ver el "while" que la llama), así que
		# no hace falta un flag de "ya la di": el nivel en sí es la fuente
		# de verdad, y restaurar_xp() la re-deriva reaplicando este mismo
		# camino desde nivel 1 (con notificar=false — ver más abajo, mismo
		# criterio que subio_de_nivel/nivel_subido, que restaurar_xp()
		# tampoco emite).
		for pasiva in pasivas_stat:
			if pasiva and pasiva.nivel_requerido == nivel and pasiva.bono:
				atributos.agregar_crecimiento_permanente(pasiva.bono)
				if notificar:
					BusEventos.pasiva_desbloqueada.emit(padre, pasiva.nombre, pasiva.descripcion)
