extends Control
class_name BarraConsumibles
## Botón junto al HUD que abre/cierra una barra rápida con 4 casillas de
## consumibles — pensada para usarse en pleno combate sin tener que abrir
## el panel de inventario completo. A diferencia de OsPrincipal, NO pasa por
## GestorUI.abrir_os()/cerrar_os(): esa transición bloquea el joystick
## (pensada para menús donde el juego se pausa), y acá el punto es justo lo
## contrario — poder tomar una poción sin dejar de moverse.
##
## Las 4 casillas (SlotConsumibleRapido) no guardan su propio ítem — leen
## GestorBarraRapida.casillas por índice, que es la misma fuente que usa la
## fila equivalente dentro de PanelInventario (ver ese panel): arrastrar acá
## se refleja allá y viceversa.

@onready var boton_toggle: BaseButton = $BotonToggle
@onready var panel_slots: Control = $PanelSlots

## UIHabilidad.gd (el botón de habilidad de abajo a la derecha) escucha
## input crudo con _input(), no _gui_input() — eso corre ANTES del sistema
## de Control/mouse_filter y no le importa qué esté dibujado encima, solo la
## distancia cruda entre el toque y el centro del botón. Por eso ningún
## mouse_filter en las casillas evitaba que un toque sobre la barra abierta
## (que se superpone a esa esquina) también activara la habilidad de abajo.
## UIHabilidad._input() YA revisa este grupo exacto para desactivarse (lo
## tenía preparado el propio código, solo que ningún panel lo usaba nunca)
## — apenas la barra está abierta, se suma acá; al cerrarla, se saca.
const GRUPO_MENU_ABIERTO := "menu_abierto"


func _ready() -> void:
	panel_slots.visible = false
	boton_toggle.pressed.connect(_on_boton_toggle)


## Con el joystick de movimiento sostenido (primer dedo), el "mouse emulado"
## de Android queda pegado a ESE dedo y el Button jamás recibía el toque de
## un segundo dedo — no se podía abrir la barra mientras te movías
## (reportado). Los dedos extra (index > 0) se atienden acá con toque crudo;
## el primer dedo (index 0) sigue el camino normal del Button (clic de
## siempre en escritorio y parado). Mismo criterio que PaginadorHabilidades.
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed or event.index == 0:
		return
	if not boton_toggle.get_global_rect().has_point(event.position):
		return
	get_viewport().set_input_as_handled()
	_on_boton_toggle()


func _on_boton_toggle() -> void:
	panel_slots.visible = not panel_slots.visible
	if panel_slots.visible:
		add_to_group(GRUPO_MENU_ABIERTO)
	else:
		remove_from_group(GRUPO_MENU_ABIERTO)
