# =============================================================================
# Accion.gd  (Hoja — base abstracta)
# Clase base para nodos de Acción.
#
# Las acciones MODIFICAN el estado del juego (mover, atacar, animar, etc.).
# Pueden retornar EN_EJECUCION si la acción tarda varios ticks en completarse.
#
# CÓMO CREAR UNA ACCIÓN PROPIA:
# ─────────────────────────────────────────────────────────────────────────────
#   extends Accion
#
#   @export var velocidad: float = 3.0
#
#   func _on_entrar() -> void:
#       super._on_entrar()
#       # Preparar la acción (animaciones, inicializar variables, etc.)
#
#   func _on_ejecutar() -> Estado:
#       var agente: CharacterBody2D = _memoria.obtener("agente")
#       var objetivo: Vector2 = _memoria.obtener("posicion_objetivo")
#       if not agente:
#           return Estado.FALLIDO
#       if agente.global_position.distance_to(objetivo) < 1.0:
#           return Estado.EXITOSO
#       var direccion = (objetivo - agente.global_position).normalized()
#       agente.velocity = direccion * velocidad
#       agente.move_and_slide()
#       return Estado.EN_EJECUCION
#
#   func _on_salir(estado: Estado) -> void:
#       super._on_salir(estado)
#       # Limpiar después de la acción (detener animaciones, etc.)
# =============================================================================
class_name Accion
extends NodoHoja
