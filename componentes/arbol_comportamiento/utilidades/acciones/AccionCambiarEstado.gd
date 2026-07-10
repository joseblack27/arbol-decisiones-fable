class_name AccionCambiarEstado
extends Accion

@export var nuevo_estado: String
## Si el estado actual está en esta lista, la acción no hace nada y retorna EXITOSO.
## Útil para evitar interrumpir ciclos naturales como idle↔deambular.
@export var estados_a_ignorar: Array[String] = []

func _on_ejecutar() -> Estado:
	if not _memoria:
		push_warning("AccionEstablecerMemoria '%s': Sin acceso a MemoriaBT." % nombre_nodo)
		return Estado.FALLIDO

	if nuevo_estado.is_empty():
		push_warning(
			"AccionEstablecerMemoria '%s': 'nombre_variable' está vacío." % nombre_nodo
		)
		return Estado.FALLIDO

	var mde: MaquinaDeEstadosComponente = _memoria.obtener("componente_maquina_estados")
	if not mde:
		return Estado.FALLIDO

	if mde.estado_actual in estados_a_ignorar:
		return Estado.EXITOSO

	mde.cambiar_estado(nuevo_estado)
	return Estado.EXITOSO
