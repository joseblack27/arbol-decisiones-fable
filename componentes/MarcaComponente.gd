extends Node
class_name MarcaComponente
## MARCA DETONABLE, colgada del enemigo marcado: durante unos segundos anota
## TODO el daño que ese enemigo recibe y, al vencer (o al morir él), estalla
## en área devolviendo un porcentaje de lo acumulado a todo lo que tenga cerca.
##
## Es la única habilidad del juego en DOS ETAPAS: el resto es instantáneo o
## continuo. Premia concentrar el daño en un objetivo en vez de repartirlo, y
## combina fuerte con Vórtice (juntás al grupo, marcás al del medio, pegás).
##
## Detona también si el marcado MUERE antes de tiempo: si no, matarlo rápido
## —que es lo que uno hace naturalmente— desperdiciaría la marca justo cuando
## más daño acumuló, y la habilidad castigaría jugar bien.
##
## El daño se cuenta escuchando BusEventos.daño_aplicado en vez de meterse en
## VidaComponente: así entra CUALQUIER fuente (golpe, proyectil, DoT, aura,
## área) sin tocar ninguna de ellas.

signal marca_puesta(duracion: float)
signal marca_detonada(daño: float, alcanzados: int)

## Capa de física donde viven los cuerpos golpeables (misma que usan las
## demás habilidades de área para su consulta).
const MASCARA_OBJETIVOS := 0xFFFFFFFF

var _tiempo_restante: float = 0.0
var _acumulado: float = 0.0
var _porcentaje: float = 0.5
var _radio: float = 120.0
## FÍSICO. Escrito como número y no como Enums.Habilidad.TipoDano.FISICO a
## propósito: un autoload en el inicializador de una variable de clase impide
## que el script compile en contextos donde los autoloads todavía no están
## resueltos, y ahí .new() deja de existir.
var _tipo_dano: int = 2
var _fuente: Node = null
var _detonando := false
## Piso garantizado para la detonación, aparte de lo acumulado — pensado
## para un jefe que sea la única fuente de daño del encuentro: si nadie más
## golpea al marcado durante la ventana, _acumulado queda en 0 y la marca no
## haría nada. 0.0 (default) no cambia el comportamiento de siempre (Marca
## del jugador, donde siempre hay otra fuente de daño de por medio).
var _dano_base_detonacion: float = 0.0

## Sello que se dibuja SOBRE el marcado mientras dura la marca. Sin esto la
## habilidad era invisible: el impacto se veía 0,4 s y después no había forma
## de saber a quién marcaste ni cuánto le quedaba (reportado: "la marca no se
## ve"). Lo maneja este componente y no la zona de impacto porque la marca es
## un estado del ENEMIGO, con su propia cuenta atrás.
const _TEXTURA_SELLO := "res://assets/sello_marca_48x48.png"
var _sello: Sprite2D = null
var _duracion_total: float = 0.0


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_aplicar_daño)
	var vida := get_parent().get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.muerte.connect(_al_morir_el_marcado)


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante -= delta
	_animar_sello()
	if _tiempo_restante <= 0.0:
		_tiempo_restante = 0.0
		_detonar()


## El sello late cada vez más rápido cuanto menos le queda: así se lee de un
## vistazo si conviene seguir pegándole o si está por estallar.
func _animar_sello() -> void:
	if _sello == null or _duracion_total <= 0.0:
		return
	var avance := 1.0 - (_tiempo_restante / _duracion_total)
	var velocidad := 3.0 + avance * 9.0
	var pulso := 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() / 1000.0 * velocidad))
	_sello.modulate.a = pulso
	_sello.scale = Vector2.ONE * (0.9 + 0.15 * pulso)


## Pone (o renueva) la marca. Renovar REINICIA lo acumulado a propósito: si
## no, se podrían encadenar marcas para acumular sin techo.
func activar(duracion: float, porcentaje: float, radio: float,
		fuente: Node, tipo_dano: int, dano_base_detonacion: float = 0.0) -> void:
	if duracion <= 0.0:
		return
	_tiempo_restante = duracion
	_acumulado = 0.0
	_porcentaje = maxf(0.0, porcentaje)
	_radio = maxf(1.0, radio)
	_fuente = fuente
	_tipo_dano = tipo_dano
	_duracion_total = duracion
	_dano_base_detonacion = maxf(0.0, dano_base_detonacion)
	_detonando = false
	_crear_sello()
	marca_puesta.emit(duracion)


func _crear_sello() -> void:
	if _sello != null and is_instance_valid(_sello):
		return
	var portador := get_parent()
	if portador == null or not (portador is Node2D):
		return
	var textura := load(_TEXTURA_SELLO) as Texture2D
	if textura == null:
		return
	_sello = Sprite2D.new()
	_sello.name = "SelloMarca"
	_sello.texture = textura
	_sello.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Por encima del mob y un poco arriba, para que no lo tape.
	_sello.z_index = 5
	_sello.position = Vector2(0, -34)
	portador.add_child(_sello)


func _borrar_sello() -> void:
	if _sello != null and is_instance_valid(_sello):
		_sello.queue_free()
	_sello = null


func esta_activa() -> bool:
	return _tiempo_restante > 0.0


func acumulado() -> float:
	return _acumulado


func tiempo_restante() -> float:
	return maxf(0.0, _tiempo_restante)


func _al_aplicar_daño(objetivo: Node, cantidad: float, _fuente_golpe: Node,
		_tipo: int = 2, _critico: bool = false) -> void:
	if not esta_activa() or objetivo != get_parent():
		return
	_acumulado += maxf(0.0, cantidad)


## Si el marcado muere antes de que venza la marca, estalla igual — ver la
## nota de arriba sobre por qué.
func _al_morir_el_marcado(_vida: float) -> void:
	if esta_activa():
		_detonar()


## La explosión NO se la aplica al propio marcado: ya se llevó todo ese daño
## en vida, cobrárselo de nuevo sería contarlo dos veces. Va a los de al lado,
## que es lo que le da sentido a juntarlos antes.
func _detonar() -> void:
	if _detonando:
		return
	_detonando = true
	_tiempo_restante = 0.0
	_borrar_sello()
	var daño := _acumulado * _porcentaje + _dano_base_detonacion
	_acumulado = 0.0
	var portador := get_parent() as Node2D
	if portador == null or daño <= 0.0:
		marca_detonada.emit(0.0, 0)
		return

	# Feedback visual del área real de la detonación — sin esto la marca
	# estallaba en silencio, sin nada en pantalla que confirmara dónde ni
	# qué tan lejos llegó (mismo pedido ya cubierto para Sacudida/
	# Acumulación, ver IndicadorZonaEfecto).
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = _radio
	indicador.color_relleno = Color(1.0, 0.2, 0.1, 0.35)
	indicador.color_borde = Color(1.0, 0.3, 0.15, 0.9)
	portador.get_tree().current_scene.add_child(indicador)
	indicador.global_position = portador.global_position

	var espacio := portador.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = _radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, portador.global_position)
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var fuente_valida: Node = _fuente if is_instance_valid(_fuente) else null
	var alcanzados := 0
	for resultado in espacio.intersect_shape(consulta, 32):
		var cuerpo = resultado.get("collider")
		if not (cuerpo is Node) or cuerpo == portador:
			continue
		if Combate.mismo_equipo(fuente_valida, cuerpo):
			continue
		var vida := (cuerpo as Node).get_node_or_null("VidaComponente") as VidaComponente
		if vida == null:
			continue
		var final := AtributosComponente.calcular_pipeline(
			fuente_valida, cuerpo, daño, _tipo_dano)
		var critico := AtributosComponente.ultimo_pipeline_critico
		vida.quitar_vida(final, fuente_valida, _tipo_dano, critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(cuerpo, final, fuente_valida, _tipo_dano, critico)
		alcanzados += 1
	marca_detonada.emit(daño, alcanzados)
