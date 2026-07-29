class_name GanchoProyectil
extends Proyectil
## Proyectil del Gancho: no aplica daño real (ver HabilidadGancho.daño_
## proyectil, en 0 — es una habilidad de puro control, mismo criterio que
## HabilidadProyectilInmovilizador). Al resolverse (enganchó a alguien, o
## se quedó sin alcance sin tocar nada), avisa a la habilidad dueña para
## que sepa cuándo soltar al jugador que lo lanzó — que queda bloqueado
## desde el instante del disparo (ver HabilidadGancho._ejecutar()) hasta
## que se sepa si enganchó o no.

var habilidad_dueña: HabilidadGancho = null


func _al_liberar_a_piscina() -> void:
	super._al_liberar_a_piscina()
	if is_instance_valid(habilidad_dueña):
		habilidad_dueña._al_resolver_gancho(_ya_impacto, _ultimo_defensor_impactado)
	habilidad_dueña = null
