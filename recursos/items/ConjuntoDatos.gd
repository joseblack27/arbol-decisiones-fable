extends Resource
class_name ConjuntoDatos
## Conjunto de equipo: varias piezas (DatosItem.conjunto apuntando acá, la
## MISMA instancia de este recurso en cada una) que además de sus bonos
## individuales otorgan bonos EXTRA por tener varias equipadas a la vez —
## ver AtributosComponente._sumar_bonos_de_conjuntos(). No reemplaza los
## bonos de cada pieza, se suman encima.
##
## Sin roles (ver memoria del proyecto): cada tramo tiene que servir
## jugando SOLO — nada de "reduce amenaza" ni bonos que solo ayuden a otro
## jugador.

@export var nombre: String = "Conjunto sin nombre"
## Tramos por cantidad de piezas equipadas — no hace falta ordenarlos, se
## evalúan todos independientemente.
@export var tramos: Array[TramoConjunto] = []
