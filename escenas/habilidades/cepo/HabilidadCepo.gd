class_name HabilidadCepo
extends HabilidadBase
## Coloca un Cepo oculto a cierta distancia (dirección + poder, igual que
## HabilidadTrampa) que espera a que un enemigo pise su radio de detección
## — recién ahí lo inmoviliza y le hace daño por tick durante
## duracion_aturdimiento segundos (ver Cepo.gd/EfectoCepo.gd). Mismo
## criterio "preparar y esperar" que Trampa: NO congela el movimiento del
## jugador al colocarlo (ver congela_movimiento_en_red más abajo).

@export var escena_cepo: PackedScene = preload("res://escenas/habilidades/cepo/Cepo.tscn")

@export_group("Colocación")
## Distancia máxima a la que se coloca; poder (0..1) la escala, igual que
## AreaEfecto.desplazamiento_maximo/HabilidadTrampa.alcance_maximo.
var alcance_maximo: float = 150.0

@export_group("Cepo")
@export var radio_deteccion: float         = 15.0
@export var dano_por_tick: float           = 10.0
@export var intervalo_tick: float          = 0.5
## Nombre elegido a propósito igual al de HabilidadSacudida: PanelDetalle
## Habilidad.gd busca esta propiedad por NOMBRE (duck typing) para llenar
## el {duracion} de la descripción — ver ese script, sección "duracion_X".
@export var duracion_aturdimiento: float   = 3.0
@export var duracion_maxima: float         = 20.0

## Mismo ícono que la habilidad, para que BuffsComponente lo muestre igual
## que en el botón — mismo criterio que HabilidadSacudida._icono_debuff.
var _icono_debuff: Texture2D = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Cepo"
	tipo_habilidad   = "cepo"
	requiere_direccion = true
	congela_movimiento_en_red = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		alcance_maximo = float(d.alcance_metros) * ESCALA_METROS_PIXEL
	if d.icono:
		_icono_debuff = d.icono


func _ejecutar(direccion: Vector2, poder: float) -> void:
	var desplazamiento := Vector2.ZERO
	if direccion.length() > 0.1:
		desplazamiento = direccion.normalized() * alcance_maximo * clampf(poder, 0.0, 1.0)

	# Reutiliza un cepo ya creado en vez de instanciar uno nuevo cada vez
	# (object pooling: ver GestorPiscinas).
	var cepo := GestorPiscinas.obtener(escena_cepo) as Cepo
	cepo.global_position = (entidad_dueña as Node2D).global_position + desplazamiento
	cepo.configurar(
		_calcular_dano(int(dano_por_tick)),
		intervalo_tick,
		duracion_aturdimiento,
		radio_deteccion,
		entidad_dueña,
		duracion_maxima,
		tipo_dano,
		_icono_debuff,
	)
