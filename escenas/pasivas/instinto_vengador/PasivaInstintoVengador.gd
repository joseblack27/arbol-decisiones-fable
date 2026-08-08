extends PasivaBase
class_name PasivaInstintoVengador
## Pasiva de gatillo: al recibir un golpe CRÍTICO, aturde 1 segundo a quien
## lo dio — castigo automático, sin que el jugador toque nada.
##
## Reusa EfectoAturdir (ver ese archivo, ya usado por HabilidadSacudida.gd —
## mismo patrón exacto de instanciación acá) y SIN gate de red a propósito:
## cada peer que tenga esta pasiva viva (el dueño Y el servidor, ver
## PasivaBase) crea su PROPIA copia local del efecto, igual que hace
## Sacudida — el freeze se siente instantáneo en la pantalla del dueño sin
## esperar una ida y vuelta al servidor, y la copia del SERVIDOR es la que
## de verdad pausa la IA/movimiento del atacante.

const _ESCENA_EFECTO_ATURDIR := "res://escenas/efectos/EfectoAturdir.gd"

@export var duracion_aturdimiento: float = 1.0
## Ícono que muestra BuffsComponente sobre el atacante aturdido.
@export var icono_debuff: Texture2D = null


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_daño_aplicado)


## daño_aplicado es GLOBAL (dispara para cualquier golpe visible en
## pantalla, ver BusEventos) — filtra por objetivo == entidad_dueña (a MÍ
## me tienen que haber pegado) antes de reaccionar.
func _al_daño_aplicado(objetivo: Node, _cantidad: float, fuente: Node, _tipo: int, critico: bool) -> void:
	if not critico or objetivo != entidad_dueña:
		return
	if not is_instance_valid(fuente) or fuente == entidad_dueña:
		return
	var efecto = (load(_ESCENA_EFECTO_ATURDIR) as GDScript).new()
	efecto.objetivo = fuente
	efecto.duracion = duracion_aturdimiento
	efecto.icono_debuff = icono_debuff
	fuente.add_child(efecto)
