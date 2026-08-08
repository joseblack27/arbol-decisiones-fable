extends Node
class_name CamuflajeComponente
## Estado temporal de OCULTO: mientras dure, los mobs no pueden tomar a esta
## entidad como objetivo, y los que ya la tenían fichada la pierden.
##
## No decide cuándo activarse — eso lo hace una habilidad (ver
## HabilidadCamuflaje); acá sólo vive la cuenta atrás y el estado que todos
## los demás consultan.
##
## Quién lo consulta:
##   • VisionComponente — ni registra ni conserva a un objetivo oculto.
##   • AccionPerseguir / AccionAtacar — sueltan al objetivo si se oculta, en
##     vez de perseguir su última posición conocida durante unos segundos.
##   • Jugador — lo dibuja translúcido.
##
## Se rompe al ATACAR (ver _al_aplicar_daño): si no, sería sencillamente una
## invulnerabilidad con golpes gratis encima. Así queda como lo que se buscó:
## una herramienta para despegarse de una pelea y reposicionarse, no para
## pegar sin consecuencias.
##
## Genérico a propósito: se puede colgar de cualquier entidad, igual que
## EscudoComponente.

signal camuflaje_activado(duracion: float)
signal camuflaje_terminado()

var _tiempo_restante: float = 0.0


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_aplicar_daño)


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = 0.0
		camuflaje_terminado.emit()


## Activa (o renueva) el camuflaje por "duracion" segundos.
func activar(duracion: float) -> void:
	if duracion <= 0.0:
		return
	_tiempo_restante = maxf(_tiempo_restante, duracion)
	camuflaje_activado.emit(_tiempo_restante)


## Lo corta ya mismo (atacar, o cualquier otro motivo de diseño futuro).
func cancelar() -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante = 0.0
	camuflaje_terminado.emit()


func esta_activo() -> bool:
	return _tiempo_restante > 0.0


func tiempo_restante() -> float:
	return maxf(0.0, _tiempo_restante)


## Atajo para el resto del código: "¿esta entidad está oculta ahora mismo?".
## Estático y tolerante a null para poder llamarlo desde cualquier lado sin
## andar buscando el nodo ni chequeando dos veces.
static func esta_oculta(entidad: Node) -> bool:
	if entidad == null or not is_instance_valid(entidad):
		return false
	var componente := entidad.get_node_or_null("CamuflajeComponente") as CamuflajeComponente
	return componente != null and componente.esta_activo()


## Atacar rompe el camuflaje. Se escucha el daño REAL aplicado (y no el
## lanzamiento de la habilidad) para no tener que enumerar cuáles hacen daño:
## cualquier golpe que salga de esta entidad la delata, venga de donde venga.
func _al_aplicar_daño(_objetivo: Node, _cantidad: float, fuente: Node,
		_tipo: int = 2, _critico: bool = false) -> void:
	if fuente != null and fuente == get_parent():
		cancelar()
