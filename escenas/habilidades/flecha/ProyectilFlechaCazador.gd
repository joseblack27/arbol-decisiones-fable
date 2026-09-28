extends Proyectil
class_name ProyectilFlechaCazador
## Variante de Proyectil.gd solo para el NPC Cazador (ver
## escenas/npc/cazador/Cazador.gd): sus flechas no dañan jugadores. El Cazador
## no está en los grupos "jugadores"/"enemigos" (ver Cazador.gd), así que
## Combate.mismo_equipo() nunca da true, y sin este filtro una flecha que
## tocara a un jugador en la línea de tiro le haría daño real.
##
## Escena PROPIA (no reusa ProyectilFlecha.tscn) aunque el arte y la colisión
## sean iguales: GestorPiscinas.obtener() indexa la piscina por resource_path,
## y compartirla con HabilidadFlechaArquero (que SÍ daña jugadores) mezclaría
## las instancias recicladas de ambos tiradores.

func _debe_ignorar_objetivo(defensor: Node) -> bool:
	return defensor.is_in_group("jugadores")
