extends Button
## Pedido explícito del usuario: en vez de abrir el panel OS directo (en su
## pestaña por defecto), este botón ahora alterna una cuadrícula de accesos
## rápidos (ver MenuAccesosOS.gd) anclada justo debajo — cada ícono ahí
## abre el panel OS directo en una sección puntual (inventario, mapa...).

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	# Sin este guard, el jugador podía abrir el menú ENCIMA de un diálogo
	# activo — GestorUI.modo_actual pisado sin que PanelDialogo se
	# enterara, y el diálogo quedaba huérfano (pedido: el diálogo es
	# obligatorio mientras dura).
	if GestorUI.modo_actual == GestorUI.Modo.DIALOGO:
		return
	var menu = get_tree().get_root().find_child("MenuAccesosOS", true, false)
	if menu:
		menu.alternar()
