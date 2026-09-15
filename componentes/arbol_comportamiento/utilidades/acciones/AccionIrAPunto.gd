# =============================================================================
# AccionIrAPunto.gd  (Acción)
#
# Viaja hacia un PUNTO FIJO guardado en la memoria (no un Node2D como
# AccionPerseguir) — no le importa ningún objetivo ni jugador detectado.
# Nace para "Llamada de Auxilio" de la Reina de las Hormigas (ver
# HabilidadLlamadaAuxilio.gd / Enemigo.responder_llamada_auxilio()): un mob
# alertado abandona lo que esté haciendo y camina directo al punto, sin
# trabarse a pelear con nadie que se cruce en el camino.
#
# RETORNA:
#   EXITOSO → di un paso hacia el punto, O ya llegué (por paso: el Selector
#             raíz re-evalúa prioridades cada tick, mismo criterio que
#             AccionPerseguir — al llegar, limpia la memoria y el próximo
#             tick el árbol cae solo a las ramas normales de combate).
#   FALLIDO → sin agente/movimiento, o la variable de destino no es un Vector2.
#
# MEMORIA:
#   lee "agente", "componente_movimiento", nombre_variable_destino
#   escribe nombre_variable_activa = false al llegar
# =============================================================================
class_name AccionIrAPunto
extends Accion

@export_group("Memoria")
## Variable con el Vector2 destino (posición GLOBAL) al que viajar.
@export var nombre_variable_destino: String = "destino_llamada"
## Variable booleana que esta acción apaga al llegar — es la misma que la
## Condición de la Secuencia que envuelve a esta Acción chequea, así que
## apagarla acá hace que el próximo tick esa rama deje de ganar prioridad.
@export var nombre_variable_activa: String = "en_llamada_auxilio"

@export_group("Configuración")
@export var margen_llegada: float = 100.0
## Multiplicador sobre componente_movimiento.velocidad_base — >1 para que
## la respuesta se sienta urgente, no un paseo.
@export var multiplicador_velocidad: float = 1.3


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	if not agente or not movimiento:
		return Estado.FALLIDO
	var destino_raw = _memoria.obtener(nombre_variable_destino)
	if not (destino_raw is Vector2):
		_memoria.establecer(nombre_variable_activa, false)
		return Estado.FALLIDO
	var destino: Vector2 = destino_raw

	if agente.global_position.distance_to(destino) <= margen_llegada:
		movimiento.detener()
		_memoria.establecer(nombre_variable_activa, false)
		return Estado.EXITOSO

	movimiento.comandar_destino(destino, movimiento.velocidad_base * multiplicador_velocidad)
	return Estado.EXITOSO
