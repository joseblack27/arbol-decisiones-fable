extends Proyectil
class_name ProyectilFlechaCazador
## Variante de Proyectil.gd solo para el NPC Cazador (ver escenas/npc/
## cazador/Cazador.gd) — pedido explícito del usuario: "la flecha del
## cazador no debe hacerle daño al jugador". El Cazador no está en ningún
## grupo "jugadores"/"enemigos" a propósito (inmunidad a todo aggro, ver el
## comentario de Cazador.gd), así que Combate.mismo_equipo() nunca da true
## contra nadie — sin este filtro, una flecha que de casualidad tocara a un
## jugador parado en la línea de tiro (entre el cazador y el ratón) le
## haría daño real.
##
## Escena PROPIA (no reusa ProyectilFlecha.tscn) a propósito, aunque el
## arte/colisión sean idénticos: GestorPiscinas.obtener() indexa la piscina
## por resource_path, así que compartir la escena con HabilidadFlechaArquero
## (que SÍ debe poder dañar jugadores) mezclaría las mismas instancias
## recicladas entre ambos tiradores.

func _debe_ignorar_objetivo(defensor: Node) -> bool:
	return defensor.is_in_group("jugadores")
