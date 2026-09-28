extends Node
## Log de conexión visible EN PANTALLA (celular): un botón en el HUD muestra u
## oculta un panel con este registro (ver PanelLogRed), para diagnosticar la
## conexión sin cable USB ni logcat.
##
## Autoload (no vive en Mundo.tscn): sobrevive el cambio de escena de
## MenuInicio a Mundo, así la primera línea ("intentando conectar a...") ya
## está cuando se abre el panel.
##
## También junta el log de daño recibido, para tener un solo registro de
## diagnóstico (red + combate).

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
## imprimir_consola en false deja la línea en el panel EN PANTALLA pero se
## salta el print(): usado por _registrar_dano para no inundar de una línea
## por golpe la consola del servidor (Docker) salvo que se pida ver eso.
func registrar(texto: String, imprimir_consola: bool = true) -> void:
	var hora := Time.get_time_string_from_system()
	var linea := "[%s] %s" % [hora, texto]
	lineas.append(linea)
	if lineas.size() > MAX_LINEAS:
		lineas.pop_front()
	if imprimir_consola:
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
	# Mismo criterio que la visibilidad del panel (ver
	# Mundo._aplicar_visibilidad_depuracion): con los datos de desarrollo
	# apagados, la línea queda en el historial pero no se imprime, para no
	# llenar los logs del contenedor con un "X hizo N daño a Y" por golpe.
	registrar("%s hizo %d daño a %s" % [nombre_fuente, int(cantidad), Utils.nombre_visible(objetivo)],
		Utils.mostrar_depuracion)
