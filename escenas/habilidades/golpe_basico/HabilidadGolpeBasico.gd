class_name HabilidadGolpeBasico
extends HabilidadBase
## Golpe cuerpo a cuerpo instantáneo en la dirección que mira el agente.
## Crea un hitbox de corta duración frente a la entidad.

## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var daño: float          = 15.0
var alcance_golpe: float = 48.0
## Sin equivalente en DatosHabilidad — configurable manualmente. Subido de
## 30 a 70 (pedido del usuario) junto con el freno de aproximación de
## AccionAtacar/AccionPerseguir (ver distancia_minima_acercamiento): antes,
## el mob caminaba hasta quedar pegado al jugador y el golpe (que se coloca
## alcance_golpe px POR DELANTE del propio mob) terminaba pasándose de
## largo de un radio chico casi siempre.
@export var radio_golpe: float    = 70.0
@export var duracion_golpe: float = 0.15
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_basico/GolpeBasico.tscn")

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Golpe Básico"
	tipo_habilidad   = "golpe"

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_golpe = d.alcance_metros * ESCALA_METROS_PIXEL
	if d.radio_golpe > 0.0:
		radio_golpe = d.radio_golpe

func _ejecutar(direccion: Vector2, _poder: float) -> void:
	# Reutiliza un golpe ya creado en vez de instanciar uno nuevo cada vez
	# (object pooling: ver GestorPiscinas).
	var golpe  := GestorPiscinas.obtener(escena_golpe) as GolpeBasico
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + frente * alcance_golpe
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)
	_mostrar_indicador_golpe(posicion)
	_reproducir_sonido()

## Feedback visual de la zona real de golpe — pedido del usuario ("colocales
## un indicador de la zona de golpe"), mismo patrón ya usado por Sacudida/
## Acumulación/Marca (ver IndicadorZonaEfecto): un flash puro, sin física,
## en la posición y radio reales del golpe. No toca la animación de ataque
## ni el timing (sigue siendo instantáneo como siempre) — es una capa
## visual encima, nada más. HabilidadArañazo hereda esto y lo llama igual.
func _mostrar_indicador_golpe(posicion: Vector2) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio_golpe
	# Mismo naranja "esto es daño" que ya usa AcumulacionDanoComponente —
	# distinto del azul de Sacudida (control) para que se lea distinto.
	indicador.color_relleno = Color(1.0, 0.5, 0.2, 0.35)
	indicador.color_borde   = Color(1.0, 0.6, 0.25, 0.9)
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(indicador)
	indicador.global_position = posicion
