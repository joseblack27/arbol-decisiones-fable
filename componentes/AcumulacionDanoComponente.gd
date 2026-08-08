extends Node
class_name AcumulacionDanoComponente
## "Acumulación", colgado del jugador: mientras está activa, anota TODO el
## daño que el portador RECIBE (sin reducirlo — a diferencia de Escudo, no
## bloquea nada) durante hasta "duracion" segundos, y al vencer —o si la
## habilidad la corta antes, ver detonar_ahora()— estalla devolviendo un
## porcentaje de lo acumulado en área alrededor suyo.
##
## Mismo patrón que MarcaComponente (acumula por BusEventos.daño_aplicado,
## detona con un intersect_shape) pero mirado al revés: Marca cuenta el
## daño que un ENEMIGO recibe; esto cuenta el daño que el PROPIO PORTADOR
## recibe.

signal acumulacion_iniciada(duracion: float)
signal acumulacion_detonada(dano: float, alcanzados: int)

## Misma capa que usan las demás habilidades de área para su consulta.
const MASCARA_OBJETIVOS := 0xFFFFFFFF

var _tiempo_restante: float = 0.0
var _acumulado: float = 0.0
var _porcentaje: float = 0.3
var _radio: float = 60.0
## FÍSICO por defecto. Escrito como número y no como Enums.Habilidad.TipoDano.FISICO
## a propósito: un autoload en el inicializador de una variable de clase
## impide que el script compile en contextos donde los autoloads todavía no
## están resueltos (mismo criterio que MarcaComponente._tipo_dano).
var _tipo_dano: int = 2
var _detonando := false


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_recibir_daño)


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = 0.0
		_detonar()


## Arranca (o reinicia) la acumulación. Llamarla mientras ya está activa
## la reinicia desde cero a propósito — la decisión de "si ya está activa,
## detonar antes" vive en HabilidadAcumulacion, no acá.
func activar(duracion: float, porcentaje: float, radio: float, tipo_dano: int) -> void:
	if duracion <= 0.0:
		return
	_tiempo_restante = duracion
	_acumulado = 0.0
	_porcentaje = porcentaje
	_radio = radio
	_tipo_dano = tipo_dano
	_detonando = false
	acumulacion_iniciada.emit(duracion)


func esta_activa() -> bool:
	return _tiempo_restante > 0.0


func acumulado() -> float:
	return _acumulado


## Corta la acumulación YA, antes de que venza sola — dispara la misma
## explosión que el vencimiento natural.
func detonar_ahora() -> void:
	if not esta_activa():
		return
	_detonar()


func _al_recibir_daño(objetivo: Node, cantidad: float, _fuente: Node, _tipo: int = 2, _critico: bool = false) -> void:
	if not esta_activa() or objetivo != get_parent():
		return
	_acumulado += maxf(0.0, cantidad)


func _detonar() -> void:
	if _detonando:
		return
	_detonando = true
	_tiempo_restante = 0.0
	var dano := _acumulado * _porcentaje
	_acumulado = 0.0
	var portador := get_parent() as Node2D
	if portador == null:
		acumulacion_detonada.emit(0.0, 0)
		return

	# Feedback visual del radio real, SIEMPRE que detona (aunque no hubiera
	# nada acumulado) — pedido del usuario: sin esto, la detonación pasaba
	# en silencio y no había forma de saber si de verdad hizo algo.
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = _radio
	indicador.color_relleno = Color(1.0, 0.5, 0.2, 0.35)
	indicador.color_borde = Color(1.0, 0.6, 0.25, 0.9)
	portador.get_tree().current_scene.add_child(indicador)
	indicador.global_position = portador.global_position

	if dano <= 0.0:
		acumulacion_detonada.emit(0.0, 0)
		return

	var espacio := portador.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = _radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, portador.global_position)
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var alcanzados := 0
	for resultado in espacio.intersect_shape(consulta, 32):
		var cuerpo = resultado.get("collider")
		if not (cuerpo is Node) or cuerpo == portador:
			continue
		if Combate.mismo_equipo(portador, cuerpo):
			continue
		var vida := (cuerpo as Node).get_node_or_null("VidaComponente") as VidaComponente
		if vida == null:
			continue
		var final := AtributosComponente.calcular_pipeline(portador, cuerpo, dano, _tipo_dano)
		var critico := AtributosComponente.ultimo_pipeline_critico
		vida.quitar_vida(final, portador, _tipo_dano, critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(cuerpo, final, portador, _tipo_dano, critico)
		alcanzados += 1
	acumulacion_detonada.emit(dano, alcanzados)
