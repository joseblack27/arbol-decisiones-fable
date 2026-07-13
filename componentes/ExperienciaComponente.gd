extends Node
class_name ExperienciaComponente
## ExperienciaComponente — la XP de ESTE jugador (Fase 1 del plan de
## migración a multijugador). Antes vivía en el autoload GestorExperiencia;
## ver ese archivo, que ahora es una fachada de compatibilidad.

## Emitida cada vez que xp_total cruza el umbral de un nivel nuevo (ver
## TablaNiveles) — nivel_nuevo, no cuánto subió, así un salto de varios
## niveles de una sola vez (XP grande de golpe) emite una vez por nivel.
signal subio_de_nivel(nivel_nuevo: int)

var xp_total: int = 0
## Caché de TablaNiveles.nivel_desde_xp(xp_total) — NUNCA la fuente de
## verdad (esa es xp_total); se recalcula acá para no tener que llamar
## TablaNiveles desde cada lugar que solo quiere mostrar el nivel.
var nivel: int = 1


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
	var nivel_real := TablaNiveles.nivel_desde_xp(xp_total)
	while nivel < nivel_real:
		nivel += 1
		_aplicar_crecimiento_nivel()


## Bono automático al subir de nivel — nada de asignar puntos a mano, sube
## solo. Vive acá (no en Jugador.gd) porque Vida/Energia/Atributos son
## hermanos directos del mismo jugador dueño de este componente, mismo
## patrón que ya usa VidaComponente para leer AtributosComponente.
func _aplicar_crecimiento_nivel() -> void:
	var padre := get_parent()
	if padre == null:
		return
	var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.salud_maxima += 10.0
		vida.agregar_vida(10.0)  # el incremento también cura, se siente como un mini-heal
	var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		energia.energia_maxima += 5.0
		energia.agregar_energia(5.0)
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos:
		# agregar_crecimiento_permanente() (no "atributos.base.danos += 1.0"
		# directo): un bono aplicado solo a "base" desaparecía la próxima vez
		# que el equipo cambiaba — recalcular_con_equipo() sobreescribe
		# "base" entero desde la copia de fábrica, sin saber nada de niveles.
		atributos.agregar_crecimiento_permanente(1.0)
