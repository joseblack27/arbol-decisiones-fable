extends Node
class_name ParryComponente
## Ventana de inmunidad DIRECCIONAL a daño de ÁREA: el efecto único de
## HabilidadCorte. Mientras dura, el jugador no recibe daño de área que venga
## desde el ángulo en que lanzó Corte (o que le caiga encima).
##
## Componente hermano (no hijo de VidaComponente), consultado desde
## VidaComponente.quitar_vida(), como EscudoComponente e
## InmunidadDebuffsComponente: el chequeo vive en el ÚNICO punto por el que
## pasa todo el daño real, así cubre cualquier fuente sin tocar cada
## habilidad.
##
## A propósito NO reusa VidaComponente.activar_invulnerabilidad(): es todo o
## nada y trae dos efectos que acá estorban, el destello amarillo
## (Jugador._actualizar_visual_invulnerable) y, peor, que VisionComponente te
## suelte como objetivo. Un parry de 1 segundo no debería hacer que el jefe se
## olvide de vos.
##
## Se crea al vuelo si no existe (ver HabilidadCorte._componente_parry), como
## HabilidadPurga con InmunidadDebuffsComponente.

## Semiángulo (grados) de la "guardia": un golpe de área cuyo origen caiga
## dentro de este cono, centrado en la dirección del corte, se bloquea.
## 90° = todo el semiplano de adelante (bloquea cualquier cosa que venga
## del lado hacia el que cortaste, no solo lo que viene de frente exacto).
const SEMIANGULO_GUARDIA := 90.0
## Si el origen del daño está MÁS CERCA que esto, se toma como "el jugador
## está parado ENCIMA del ataque" (el charco de fuego a los pies, ver
## EfectoDoT) y se bloquea sin mirar el ángulo — ahí no hay una dirección
## de la cual venga el golpe, te está quemando desde abajo.
const RADIO_ENCIMA := 48.0

var _restante: float = 0.0
var _direccion: Vector2 = Vector2.RIGHT


func _process(delta: float) -> void:
	if _restante > 0.0:
		_restante = maxf(0.0, _restante - delta)


## Abre la ventana. Nunca acorta una ya en curso más larga (maxf, mismo
## criterio que VidaComponente.activar_invulnerabilidad): dos cortes
## encadenados no deben pisarse entre sí.
func activar(segundos: float, direccion: Vector2) -> void:
	if segundos <= 0.0:
		return
	_restante = maxf(_restante, segundos)
	if direccion != Vector2.ZERO:
		_direccion = direccion.normalized()


func esta_activo() -> bool:
	return _restante > 0.0


func tiempo_restante() -> float:
	return _restante


## ¿Este golpe puntual queda bloqueado por el parry en curso?
## es_area: solo el daño de ÁREA se para. Un proyectil NO se bloquea acá: Corte
##   lo destruye en el aire si cae dentro del rectángulo (ver
##   HabilidadCorte._cortar_ataques); si igual llega, entra.
## origen: de DÓNDE salió el golpe (el atacante en un área, el charco en un
##   DoT). Vector2.INF = desconocido; ahí se bloquea igual, para no castigar a
##   quien acertó el timing.
func bloquea(es_area: bool, origen: Vector2) -> bool:
	if not esta_activo() or not es_area:
		return false
	var padre := get_parent()
	if not (padre is Node2D) or origen == Vector2.INF:
		return true
	var posicion: Vector2 = (padre as Node2D).global_position
	# "Encima": sin dirección de la cual venir, el ángulo no aplica.
	if posicion.distance_to(origen) <= RADIO_ENCIMA:
		return true
	var hacia_el_golpe := posicion.direction_to(origen)
	return rad_to_deg(absf(_direccion.angle_to(hacia_el_golpe))) <= SEMIANGULO_GUARDIA
