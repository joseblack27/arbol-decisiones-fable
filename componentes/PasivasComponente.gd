extends Node
class_name PasivasComponente
## Pasivas de GATILLO de ESTE jugador — desbloqueadas al usar un ítem
## especial (ver DatosItem.escena_pasiva, InventarioComponente.usar_item).
## A diferencia de las pasivas de ESTADÍSTICA (ver ExperienciaComponente
## .pasivas_stat, que se re-derivan solas del nivel), estas SÍ necesitan
## persistencia propia — no hay ningún otro dato guardado del que puedan
## reconstruirse (ver GestorGuardado, clave "pasivas").
##
## Siempre activas una vez desbloqueadas: no hay equipar/desequipar ni
## límite de cantidad (pedido del usuario), así que esto es solo una lista
## de "cuáles tengo" + la instancia real de cada una colgando como hijo.

## Rutas (resource_path de la ESCENA, no del ítem) de las pasivas de
## gatillo ya desbloqueadas — nunca se duplican, sirve tanto para no
## volver a instanciar la misma dos veces como para serializar/restaurar.
var gatillo_desbloqueadas: Array[String] = []


## [notificar] = false al restaurar una partida guardada (ver
## GestorGuardado._restaurar_pasivas) — mismo criterio que
## ExperienciaComponente._aplicar_crecimiento_nivel: la pasiva ya era tuya
## de antes, no hace falta repetir el aviso de pantalla.
func desbloquear_gatillo(ruta_escena: String, notificar: bool = true) -> void:
	if ruta_escena == "" or ruta_escena in gatillo_desbloqueadas:
		return
	var escena := load(ruta_escena) as PackedScene
	if escena == null:
		return
	var pasiva := escena.instantiate() as PasivaBase
	if pasiva == null:
		return
	gatillo_desbloqueadas.append(ruta_escena)
	pasiva.entidad_dueña = get_parent()
	add_child(pasiva)
	if notificar:
		BusEventos.pasiva_desbloqueada.emit(get_parent(), pasiva.nombre_pasiva, pasiva.descripcion)
