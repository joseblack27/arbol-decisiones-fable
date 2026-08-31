extends Control
## Tira de HUD con la vida de los compañeros de grupo — Feature C del plan
## MMO ("ver la vida de tus compañeros sin abrir el menú"). Ver PanelGrupo
## (pestaña del OS) para invitar/salir/expulsar — esto es solo lectura
## rápida durante el combate.
##
## Dos niveles de visibilidad, no confundir: el CONTROL RAÍZ (botón +
## contenido) se oculta entero sin grupo — no tiene sentido mostrar un
## botón para desplegar una lista vacía. Ya en grupo, el botón queda visible
## siempre y el jugador decide con él si quiere ver el contenido o
## colapsarlo (pedido explícito: "que este panel se pueda ocultar y
## mostrar") — mismo patrón de "botón + panel desplegable" que ya usan
## PanelChat y PanelLogRed.

@onready var _boton_toggle: Button = $BotonToggle
@onready var _panel: PanelContainer = $Panel
@onready var _lista: VBoxContainer = $Panel/Lista


func _ready() -> void:
	_boton_toggle.pressed.connect(_alternar)
	GestorGrupos.grupo_actualizado.connect(_actualizar)
	_actualizar()


func _alternar() -> void:
	_panel.visible = not _panel.visible


func _actualizar() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()

	var grupo: Dictionary = GestorGrupos.mi_grupo
	var en_grupo := not grupo.is_empty()
	visible = en_grupo
	if not en_grupo:
		return

	for miembro: Dictionary in (grupo.get("miembros", []) as Array):
		_lista.add_child(_fila(miembro))


func _fila(miembro: Dictionary) -> Control:
	var fila := HBoxContainer.new()

	var nombre := Label.new()
	nombre.text = str(miembro.get("nombre", ""))
	nombre.custom_minimum_size = Vector2(64, 0)
	nombre.add_theme_font_size_override("font_size", 10)
	fila.add_child(nombre)

	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = maxf(1.0, float(miembro.get("vida_maxima", 1.0)))
	barra.value = float(miembro.get("vida", 0.0))
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(70, 10)
	fila.add_child(barra)

	return fila
