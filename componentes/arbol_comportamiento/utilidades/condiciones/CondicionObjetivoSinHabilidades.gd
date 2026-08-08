# =============================================================================
# CondicionObjetivoSinHabilidades.gd  (Condición utilitaria)
#
# Éxito solo si el objetivo está a distancia melee Y NINGUNA de sus
# habilidades equipadas está lista para usarse — pensado para que un jefe
# "castigue" al jugador que se quedó pegado sin ninguna carta para responder
# (pedido del usuario: "un ataque para cuando el jugador esté cerca y no
# tenga habilidades disponible en el momento").
# =============================================================================
class_name CondicionObjetivoSinHabilidades
extends Condicion

@export_group("Configuración")
## Rango melee — coherente con el radio del golpe que dispara esta condición.
@export var umbral_melee: float = 90.0
@export var clave_objetivo: String = "objetivo"


func _on_ejecutar() -> Estado:
	# Mismo criterio que CondicionDistanciaObjetivo: validar ANTES de castear,
	# el objetivo puede haberse liberado (desconexión a mitad de combate).
	var agente_raw = _memoria.obtener("agente")
	var objetivo_raw = _memoria.obtener(clave_objetivo)
	if not is_instance_valid(agente_raw) or not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO
	var agente := agente_raw as Node2D
	var objetivo := objetivo_raw as Node2D
	if not agente or not objetivo:
		return Estado.FALLIDO

	if agente.global_position.distance_to(objetivo.global_position) > umbral_melee:
		return Estado.FALLIDO

	var slots := objetivo.get_node_or_null("SlotHabilidades") as SlotHabilidades
	if slots == null:
		return Estado.FALLIDO
	for i in slots.total_slots:
		var hab := slots.obtener(i)
		if hab != null and hab.puede_usarse():
			return Estado.FALLIDO  # tiene al menos una libre

	return Estado.EXITOSO
