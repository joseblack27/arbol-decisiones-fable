extends Node
class_name PasivaBase
## Base para pasivas de GATILLO — desbloqueadas por un ítem especial (ver
## DatosItem.escena_pasiva / PasivasComponente.desbloquear_gatillo), no por
## un slot de acción. A diferencia de HabilidadBase, no tienen activación
## manual, cooldown ni costo de energía: reaccionan solas a lo que pase.
##
## Cada subclase hace su propio _ready(), se conecta a lo que necesite de
## BusEventos, y SIEMPRE filtra por entidad_dueña (mismo criterio que
## GestorNumerosDano/Enemigo._es_mi_propio_golpe: las señales de combate
## son GLOBALES, disparan para cualquier entidad visible en pantalla).
##
## Corre en TODOS los peers (dueño y servidor) para que la predicción del
## dueño no dependa de esperar al servidor, pero cualquier efecto REAL
## (daño, curación, control) tiene que gatear
## "if Utils.en_red() and not multiplayer.is_server(): return" antes de
## aplicarse — mismo criterio que toda habilidad activa del proyecto.

## Jugador dueño de esta pasiva — lo asigna PasivasComponente al
## instanciarla, ANTES de agregarla al árbol (así ya está listo para
## cuando corra _ready()).
var entidad_dueña: Node = null

## Nombre/descripción/ícono para la notificación de desbloqueo y la UI de
## solo lectura (ver BusEventos.pasiva_desbloqueada / PanelHabilidades).
@export var nombre_pasiva: String = ""
@export var descripcion: String = ""
@export var icono: Texture2D = null
