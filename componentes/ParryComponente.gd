extends Node
class_name ParryComponente
## Ventana de inmunidad DIRECCIONAL a daño de ÁREA — el efecto único de
## HabilidadCorte (ver ese archivo). Pedido del usuario: "el jugador se
## vuelve inmune al daño de habilidades de tipo área mientras realiza el
## ataque y siempre y cuando el jugador se encuentre encima de un ataque
## como este o lo vaya a recibir desde el ángulo en que lanzó Corte".
##
## Componente SIBLING (no hijo de VidaComponente), consultado desde
## VidaComponente.quitar_vida() — mismo patrón que EscudoComponente
## (reducción de daño) e InmunidadDebuffsComponente (efectos pegados): el
## chequeo vive en el ÚNICO punto por el que pasa todo el daño real, así
## cubre cualquier fuente (proyectil, arañazo, AoE, DoT, muro, aura) sin
## tocar cada habilidad por separado.
##
## A propósito NO reusa VidaComponente.activar_invulnerabilidad(): esa es
## todo-o-nada y arrastra dos efectos colaterales que acá estorban — el
## destello amarillo de "recién aparecido" (Jugador._actualizar_visual_
## invulnerable) y, peor, que VisionComponente deja de registrarte como
## objetivo (los mobs te sueltan de la mira). Un parry de 1 segundo no
## debería hacer que el jefe se olvide de vos.
##
## Se crea al vuelo si no existe (ver HabilidadCorte._componente_parry),
## mismo criterio que HabilidadPurga con InmunidadDebuffsComponente.

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
## es_area — solo el daño de ÁREA se para con Corte (pedido del usuario).
##   Un proyectil NO se bloquea acá: Corte lo destruye en el aire cuando
##   cae dentro del rectángulo (ver HabilidadCorte._cortar_ataques), que es
##   la forma correcta de "contrarrestarlo" — si igual te llega, entra.
## origen — de DÓNDE salió el golpe (la posición del atacante para un AoE,
##   la del charco para un DoT). Vector2.INF = desconocido; ahí se bloquea
##   igual (es daño de área durante la ventana activa, y no poder ubicarlo
##   no debería castigar al jugador que acertó el timing).
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
