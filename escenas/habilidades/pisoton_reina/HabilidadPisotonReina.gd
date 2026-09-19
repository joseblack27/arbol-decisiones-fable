class_name HabilidadPisotonReina
extends HabilidadBase
## Pisotón Sísmico: golpe de área centrado en la propia Reina, telegrafiado
## (se prepara "duracion_preparacion" segundos, con el radio real visible en
## el piso vía IndicadorZonaEfecto todo ese tiempo) antes de golpear fuerte a
## quien siga adentro. Pensado para castigar quedarse pegado a ella en melee
## durante todo el combate — totalmente esquivable retrocediendo durante la
## preparación, así que sigue siendo justo jugando solo.
##
## Mismo esqueleto FASE por FASE que HabilidadCarga (PREPARACION → GOLPE, con
## _process acumulando delta) en vez de un único golpe instantáneo como
## HabilidadOndaChoque/HabilidadSacudida — acá la preparación ES la mecánica
## (dar tiempo real a alejarse), no un mero efecto visual de 0.35s.

enum Fase { INACTIVO, PREPARACION, GOLPE }

## Emitida al entrar en preparación (la Reina se detiene y muestra el radio).
signal preparacion_iniciada()
## Emitida cuando el golpe real se aplica.
signal golpe_aplicado()
## Emitida al terminar el ciclo completo.
signal pisoton_terminado()

@export_group("Pisotón")
@export var daño: float = 40.0
@export var radio: float = 110.0
@export var duracion_preparacion: float = 1.2

var _fase: Fase = Fase.INACTIVO
var _timer_preparacion: float = 0.0


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Pisotón Sísmico"
	tipo_habilidad   = "pisoton_reina"
	requiere_direccion = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.radio_golpe > 0.0:
		radio = d.radio_golpe


func _process(delta: float) -> void:
	super._process(delta)
	if _fase != Fase.PREPARACION:
		return
	_timer_preparacion += delta
	if _timer_preparacion >= duracion_preparacion:
		_golpear()


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_reproducir_sonido()

	_timer_preparacion = 0.0
	_fase = Fase.PREPARACION
	if entidad_dueña and "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)
	preparacion_iniciada.emit()

	# Radio visible durante TODA la preparación (no el flash de 0.35s por
	# defecto) — es la advertencia real de "alejate antes de que caiga".
	var origen := entidad_dueña as Node2D
	if origen and origen.is_inside_tree():
		var indicador := IndicadorZonaEfecto.new()
		indicador.radio = radio
		indicador.duracion = duracion_preparacion
		indicador.color_relleno = Color(0.55, 0.35, 0.15, 0.35)
		indicador.color_borde = Color(0.75, 0.5, 0.2, 0.9)
		origen.get_tree().current_scene.add_child(indicador)
		indicador.global_position = origen.global_position


func esta_preparando() -> bool:
	return _fase == Fase.PREPARACION


## Solo golpea de verdad del lado con autoridad (servidor o un solo
## jugador): VidaComponente.quitar_vida() ya se auto-bloquea en un cliente
## puro, pero sin este corte cada cliente haría su PROPIA consulta de
## física y podría alcanzar objetivos ligeramente distintos según su propia
## posición interpolada — más limpio no calcular nada ahí.
func _golpear() -> void:
	_fase = Fase.GOLPE
	if is_instance_valid(entidad_dueña) and not (Utils.en_red() and not multiplayer.is_server()):
		var origen := entidad_dueña as Node2D
		if origen:
			var forma := CircleShape2D.new()
			forma.radius = radio
			Combate.golpear_area(origen, forma, _calcular_dano(int(daño)), entidad_dueña,
				tipo_dano, tipo_habilidad)
	golpe_aplicado.emit()
	_terminar()


func _terminar() -> void:
	_fase = Fase.INACTIVO
	if entidad_dueña and "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", false)
	pisoton_terminado.emit()
