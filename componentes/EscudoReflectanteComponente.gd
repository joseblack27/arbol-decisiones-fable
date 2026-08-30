extends EscudoComponente
class_name EscudoReflectanteComponente
## Igual que EscudoComponente (reduce/bloquea daño entrante), pero además
## devuelve la porción bloqueada contra quien atacó — pensado para la fase
## "Corrupción" del Guardián Quebrado, para castigar pegarle a distancia
## mientras el escudo está activo. Sigue llamándose "EscudoComponente" como
## nodo (ver comentario de HabilidadEscudoReflectanteGuardian), así que
## VidaComponente.quitar_vida() lo sigue encontrando y usando sin cambios.
##
## Daño reflejado siempre FISICO y sin crítico: el escudo no conoce el tipo
## real del golpe bloqueado (EscudoComponente.aplicar() nunca lo recibió),
## así que devolver algo aproximado es preferible a inventar información
## que no existe.

func aplicar(dano: float, fuente: Node = null) -> float:
	var restante := super.aplicar(dano)
	if not esta_activo() or fuente == null or not is_instance_valid(fuente):
		return restante
	var dueño := get_parent()
	if fuente == dueño:
		return restante
	var vida_fuente := fuente.get_node_or_null("VidaComponente") as VidaComponente
	if vida_fuente:
		var reflejado := dano - restante
		if reflejado > 0.0:
			vida_fuente.quitar_vida(reflejado, dueño)
	return restante
