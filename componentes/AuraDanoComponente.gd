extends Node2D
class_name AuraDanoComponente
## Aura de daño continuo alrededor de quien la activó. A diferencia de una
## trampa (fija) o un veneno (pegado a UN objetivo), vive pegada al DUEÑO:
## cualquier enemigo dentro de "radio" recibe daño cada "intervalo_tick"
## segundos mientras dure. Se recalcula de cero en cada tick con
## Combate.golpear_area, sin rastrear quién está adentro.
##
## El efecto (_aplicar_tick) queda separado del temporizador a propósito, para
## poder cambiar QUÉ hace el aura (otro tipo de daño, un debuff...) sin tocar
## el resto.
##
## Mismo patrón que CuracionComponente y EscudoComponente: componente genérico
## que activa una habilidad (ver HabilidadAura).
##
## Node2D (no Node): dibuja el círculo del área él mismo (ver _draw) y, como
## hijo del dueño, sigue su posición con la herencia de transform. Se crea en
## cada peer que corre _ejecutar() (dueño, servidor y espectadores vía
## HabilidadBase._reproducir_visual_red), así que todos lo ven sin filtros.

@export var radio: float = 25.0
@export var dano_por_tick: float = 6.0
@export var intervalo_tick: float = 1.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## Fracción del daño YA calculado (dano_base + atributos del jugador) que se
## aplica por tick, como HabilidadLanzallamas.multiplicador_dano_tick. Con el
## MISMO nombre de propiedad, PanelDetalleHabilidad lo lee solo para mostrar
## el "Daño Calculado" correcto.
@export var multiplicador_dano_tick: float = 1.0

var _dueño: Node2D = null
## Quien activó el aura — se necesita para poder recalcular el daño CADA
## tick (no una sola vez al activar): _calcular_dano() vive en
## HabilidadBase y hace un roll aleatorio nuevo cada vez que se llama,
## mismo criterio que ya usa HabilidadLanzallamas._process().
var _habilidad: HabilidadAura = null
var _restante: float = 0.0
var _acumulador_tick: float = 0.0
var _activa := false


## Activa (o renueva) el aura por "duracion" segundos.
func activar(dueño: Node2D, habilidad: HabilidadAura, duracion: float) -> void:
	_dueño = dueño
	_habilidad = habilidad
	_restante = duracion
	_acumulador_tick = 0.0
	_activa = true
	queue_redraw()


func esta_activa() -> bool:
	return _activa


func _process(delta: float) -> void:
	if not _activa:
		return
	_restante -= delta
	_acumulador_tick += delta
	if _acumulador_tick >= intervalo_tick:
		_acumulador_tick -= intervalo_tick
		_aplicar_tick()
	if _restante <= 0.0:
		_activa = false
		queue_redraw()


## Único punto que decide qué le hace el aura a cada objetivo en rango —
## hoy daño, pero aislado para poder cambiarlo sin tocar el temporizador
## de arriba (ver comentario de clase).
func _aplicar_tick() -> void:
	if not is_instance_valid(_dueño) or not is_instance_valid(_habilidad):
		return
	var forma := CircleShape2D.new()
	forma.radius = radio
	# _calcular_dano() (no dano_por_tick directo): respeta el rango de
	# aura.tres (dano_base_min/max) si está seteado, con un roll nuevo en
	# CADA tick — mismo criterio que HabilidadLanzallamas._process().
	var dano_base: float = _habilidad._calcular_dano(int(dano_por_tick))
	Combate.golpear_area(_dueño, forma, dano_base, _dueño, tipo_dano, "aura", true, multiplicador_dano_tick)


## Círculo del área real, visible para todos mientras el aura está activa. Se
## dibuja en espacio LOCAL (0,0 = el dueño), así que sigue su movimiento sin
## redibujarse cada fotograma.
func _draw() -> void:
	if not _activa:
		return
	draw_circle(Vector2.ZERO, radio, Color(0.9, 0.4, 0.1, 0.15))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, Color(0.9, 0.4, 0.1, 0.6), 1.5)
