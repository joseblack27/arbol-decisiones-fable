extends Node
## Log de conexión visible EN PANTALLA (celular) — un botón en el HUD
## muestra/oculta un panel con este registro (ver PanelLogRed), para poder
## diagnosticar problemas de conexión sin necesitar cable USB + logcat.
##
## Autoload (no vive dentro de Mundo.tscn): sobrevive el change_scene_to_file
## de MenuInicio -> Mundo, así que el registro ya tiene la primera línea
## ("intentando conectar a...") lista para cuando el panel se abre, en vez
## de perderse por haber ocurrido antes de que el panel existiera.
##
## También junta acá el log de daño recibido (antes vivía aparte, en
## PanelTablero "Actividad Reciente") — pedido del usuario para tener un
## solo registro de diagnóstico (red + combate) en vez de repartido entre
## dos paneles distintos. Ese espacio en PanelTablero ahora muestra los
## buffs/debuffs activos (ver PanelTablero.gd).

signal linea_agregada(linea: String)

var lineas: Array[String] = []
const MAX_LINEAS := 300


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_on_dano_aplicado)
	# En cliente puro el daño real llega por daño_replicado, que trae el
	# nombre del atacante YA resuelto como texto — incluso si su nodo no
	# existe en este peer ("EnemigoAraña@5 [invisible]" en vez de "???").
	# _on_dano_aplicado se salta esos casos (ver el corte servidor/single-
	# player ahí abajo) para no duplicar la línea.
	BusEventos.daño_replicado.connect(_on_dano_replicado)


## Agrega una línea con hora — y de paso la manda a print() (logcat sigue
## funcionando igual que antes para quien tenga cable USB a mano).
func registrar(texto: String) -> void:
	var hora := Time.get_time_string_from_system()
	var linea := "[%s] %s" % [hora, texto]
	lineas.append(linea)
	if lineas.size() > MAX_LINEAS:
		lineas.pop_front()
	print(linea)
	linea_agregada.emit(linea)


func limpiar() -> void:
	lineas.clear()


## Registra "A hizo X daño a B" cada vez que un JUGADOR recibe daño — para
## rastrear el "daño fantasma" (el jugador pierde vida sin ver quién lo
## golpeó). Se registra TODO daño que reciba un jugador, incluso con el
## panel cerrado — al abrirlo se ve el historial completo (mismo criterio
## que tenía antes en PanelTablero).
func _on_dano_aplicado(objetivo: Node, cantidad: float, fuente: Node, _tipo: int = 2, _critico: bool = false) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		return
	var nombre_fuente: String = Utils.nombre_visible(fuente) if is_instance_valid(fuente) else "???"
	_registrar_dano(objetivo, cantidad, nombre_fuente)


func _on_dano_replicado(objetivo: Node, cantidad: float, nombre_fuente: String) -> void:
	_registrar_dano(objetivo, cantidad, nombre_fuente)


func _registrar_dano(objetivo: Node, cantidad: float, nombre_fuente: String) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or not objetivo.is_in_group("jugadores"):
		return
	registrar("%s hizo %d daño a %s" % [nombre_fuente, int(cantidad), Utils.nombre_visible(objetivo)])
