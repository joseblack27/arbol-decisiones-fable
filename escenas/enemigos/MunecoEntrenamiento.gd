extends Enemigo
class_name MunecoEntrenamiento
## Blanco de práctica: recibe golpes (vida real, números de daño, barra)
## y responde a empuje/atracción igual que cualquier mob —eso ya lo da
## gratis Enemigo/MovimientoComponente, no hace falta nada especial—, pero
## nunca completa Enemigo._procesar_muerte() (sin botín, sin XP, sin
## despawn): al llegar a 0 de vida se cura de vuelta al máximo en vez de
## morir. Sin árbol de comportamiento ni memoria en uso: nunca ataca ni
## persigue, así que solo se mueve cuando algo externo lo empuja/atrae.
##
## En reposo queda quieto en el frame 0 (sin loop de reposo, a pedido del
## usuario). _on_daño_aplicado ya viene de Enemigo —se llama por CADA golpe
## confirmado, propio o ajeno, y dispara el parpadeo rojo ya heredado—: acá
## se suma reproducir la animación "golpe" (frames 9-12, el muñeco se
## tambalea y se endereza) sin pisar nada de lo que ya hace la base.
##
## Vuelta a casa: cada golpe reinicia _tiempo_restante a
## DURACION_VUELTA_A_CASA (10s); mientras la bandera _en_combate esté
## activa, ese contador baja solo en _process(). Si llega a 0 (10s seguidos
## sin ningún golpe nuevo) el muñeco vuelve teletransportado a donde
## apareció y la bandera se apaga — empujarlo/atraerlo lejos de su sitio
## (Onda de Choque, Vórtice...) no debería dejarlo perdido para siempre.
const DURACION_VUELTA_A_CASA := 10.0

var _en_combate := false
var _tiempo_restante := 0.0
var _posicion_original := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_posicion_original = global_position


## Autoritativo: SOLO corre en el servidor (o en local sin red). En un
## cliente puro, hacer esto también teletransportaría la copia LOCAL en un
## instante ligeramente distinto al del servidor y generaría un tirón
## visible en cuanto llegue la próxima réplica de posición real — mismo
## criterio que todo el resto del combate (el servidor decide, el cliente
## solo refleja, ver VidaComponente.quitar_vida).
func _process(delta: float) -> void:
	super._process(delta)
	if not _en_combate:
		return
	if Utils.en_red() and not multiplayer.is_server():
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_en_combate = false
		global_position = _posicion_original


func _on_daño_aplicado(objetivo: Node, cantidad: float, fuente: Node,
		tipo: int = 2, critico: bool = false) -> void:
	super._on_daño_aplicado(objetivo, cantidad, fuente, tipo, critico)
	if objetivo == self:
		_en_combate = true
		_tiempo_restante = DURACION_VUELTA_A_CASA
		var reproductor := get_node_or_null("AnimationPlayer") as AnimationPlayer
		if reproductor:
			reproductor.play("golpe")


func _on_muerte(_valor: float) -> void:
	# restaurar_vida() no puede llamarse ACÁ mismo: quitar_vida() todavía
	# tiene pendiente "salud_actual = 0.0" justo después de emitir esta
	# señal, y esa línea pisaría la curación. Diferido, corre después.
	call_deferred("_revivir_instantaneo")


func _revivir_instantaneo() -> void:
	if componente_vida:
		componente_vida.restaurar_vida(componente_vida.obtener_vida_maxima())
