# =============================================================================
# CondicionHabilidadObjetivoEnCooldown.gd  (Condición utilitaria)
#
# Éxito solo si el objetivo tiene equipada la habilidad de "tipo_habilidad_
# objetivo" y esa habilidad está en cooldown (no puede_usarse() ahora mismo).
# Pensada para el Guardián Quebrado (fase "Corrupción"): mientras Corte del
# jugador está gastado, el jefe puede castigar con más golpes single-target
# a propósito, sabiendo que el parry no lo protege en esa ventana.
#
# Sin habilidad equipada de ese tipo, o si YA puede usarse: FALLIDO — mismo
# criterio conservador que CondicionObjetivoSinHabilidades (no asumir nada
# que no se pueda confirmar).
# =============================================================================
class_name CondicionHabilidadObjetivoEnCooldown
extends Condicion

@export_group("Configuración")
@export var tipo_habilidad_objetivo: String = "corte"
@export var clave_objetivo: String = "objetivo"


func _on_ejecutar() -> Estado:
	var objetivo_raw = _memoria.obtener(clave_objetivo)
	if not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO

	var slots := (objetivo_raw as Node).get_node_or_null("SlotHabilidades") as SlotHabilidades
	if slots == null:
		return Estado.FALLIDO

	var hab := slots.obtener_por_tipo(tipo_habilidad_objetivo)
	if hab == null:
		return Estado.FALLIDO

	return Estado.FALLIDO if hab.puede_usarse() else Estado.EXITOSO
