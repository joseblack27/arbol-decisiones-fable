class_name TablaNiveles
extends RefCounted
## Tabla de progresión de niveles del jugador. Antes DatosJugador.nivel/
## experiencia_max eran campos fijos que nunca cambiaban en juego: subir de
## nivel no existía, xp_total crecía sin techo contra un "experiencia_max"
## de 1000 que jamás se movía.
##
## El nivel se DERIVA de la XP acumulada total — nunca se guarda como un
## campo aparte (ExperienciaComponente.nivel es una caché, no la fuente de
## verdad), así que jamás puede desincronizarse: dado un xp_total, siempre
## hay un único nivel correcto.
##
## Curva triangular: cada nivel pide 100 XP más que el anterior (nivel 2
## cuesta 100, nivel 3 cuesta 200 más =300 acumulado, nivel 4 cuesta 300
## más =600 acumulado...). Con los mobs actuales (Lobo 25xp, Araña 50xp),
## subir del nivel 1 al 2 toma 2-4 muertes — ritmo cómodo para el
## contenido que ya existe; ajustar XP_POR_TRAMO si se siente lento/rápido.
const XP_POR_TRAMO := 100
const NIVEL_MAXIMO := 50


## XP acumulada TOTAL necesaria para ESTAR en "nivel" (nivel 1 = 0 XP).
static func xp_para_alcanzar(nivel: int) -> int:
	var n := clampi(nivel, 1, NIVEL_MAXIMO)
	return XP_POR_TRAMO * (n - 1) * n / 2


## Nivel correspondiente a una cantidad de XP acumulada total.
static func nivel_desde_xp(xp_total: int) -> int:
	var nivel := 1
	while nivel < NIVEL_MAXIMO and xp_total >= xp_para_alcanzar(nivel + 1):
		nivel += 1
	return nivel


## Progreso DENTRO del nivel actual: x=cuánta XP lleva desde que lo
## alcanzó, y=cuánta hace falta en total para el siguiente. Para mostrar
## "XP: 45 / 100" en vez del acumulado total contra un techo que no se
## movía. En NIVEL_MAXIMO devuelve (0, 0) — no hay "siguiente" nivel.
static func progreso_en_nivel(xp_total: int, nivel: int) -> Vector2i:
	if nivel >= NIVEL_MAXIMO:
		return Vector2i.ZERO
	var base := xp_para_alcanzar(nivel)
	var siguiente := xp_para_alcanzar(nivel + 1)
	return Vector2i(xp_total - base, siguiente - base)
