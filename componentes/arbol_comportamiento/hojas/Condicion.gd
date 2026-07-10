# =============================================================================
# Condicion.gd  (Hoja — base abstracta)
# Clase base para nodos de Condición.
#
# Las condiciones EVALÚAN el estado del mundo y retornan EXITOSO o FALLIDO.
# NO deben modificar el estado del juego; solo consultarlo.
# Las condiciones NO deberían retornar EN_EJECUCION (son instantáneas).
#
# CÓMO CREAR UNA CONDICIÓN PROPIA:
# ─────────────────────────────────────────────────────────────────────────────
#   extends Condicion
#
#   @export var distancia_minima: float = 5.0
#
#   func _on_ejecutar() -> Estado:
#       var agente = _memoria.obtener("agente")
#       var objetivo = _memoria.obtener("objetivo")
#       if not agente or not objetivo:
#           return Estado.FALLIDO
#       if agente.global_position.distance_to(objetivo.global_position) <= distancia_minima:
#           return Estado.EXITOSO
#       return Estado.FALLIDO
# =============================================================================
class_name Condicion
extends NodoHoja
