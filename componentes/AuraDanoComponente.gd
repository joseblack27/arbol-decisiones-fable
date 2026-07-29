extends Node2D
class_name AuraDanoComponente
## Aura de daño continuo alrededor de quien la activó — a diferencia de
## una trampa (espera fija) o un veneno (pegado a UN objetivo), esto vive
## pegado al DUEÑO: cualquier enemigo dentro de "radio" recibe daño cada
## "intervalo_tick" segundos mientras dure, sin importar cuántas veces
## entren o salgan del radio (se recalcula de cero en cada tick con
## Combate.golpear_area — no hace falta rastrear quién está "adentro").
##
## El efecto en sí (_aplicar_tick) queda separado a propósito del
## temporizador (pedido del usuario: "el efecto me gustaría que sea
## modificable") — cambiar QUÉ le hace el aura a cada objetivo más
## adelante (otro tipo de daño, un debuff, etc.) no debería tocar nada
## del resto de este archivo.
##
## Mismo patrón que CuracionComponente/EscudoComponente: componente
## genérico, activado por una habilidad (ver HabilidadAura), reusable por
## cualquier entidad futura que quiera este mismo efecto.
##
## Node2D (no Node): así se dibuja el círculo del área SOLO (ver _draw)
## sin necesitar un nodo visual aparte — al ser hijo del dueño, ya sigue
## su posición solo con la herencia de transform normal, sin tocar nada
## en _process. Visible para TODOS los jugadores (pedido del usuario):
## este componente se crea igual en cada peer que corre _ejecutar() (el
## dueño en predicción, el servidor, y cada espectador cercano vía
## HabilidadBase._reproducir_visual_red), así que no hace falta ningún
## filtro "solo local" — ya se replica solo.

@export var radio: float = 25.0
@export var dano_por_tick: float = 6.0
@export var intervalo_tick: float = 1.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## Fracción del daño YA calculado (dano_base + atributos del jugador) que
## de verdad se aplica por tick — mismo criterio que HabilidadLanzallamas
## .multiplicador_dano_tick (pedido del usuario: "que el daño sea el 50%
## del calculado"). Con el MISMO nombre de propiedad, PanelDetalleHabilidad
## ya sabe leerlo solo para mostrar el "Daño Calculado" correcto, sin
## tocar ese panel para nada — ver el comentario ahí.
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


## Círculo del área real, visible para todos mientras el aura está activa
## (pedido del usuario) — se dibuja en espacio LOCAL (0,0 = la posición
## del dueño, ver comentario de clase), así que sigue solo su movimiento
## sin tener que redibujarse cada fotograma.
func _draw() -> void:
	if not _activa:
		return
	draw_circle(Vector2.ZERO, radio, Color(0.9, 0.4, 0.1, 0.15))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, Color(0.9, 0.4, 0.1, 0.6), 1.5)
