extends Resource
class_name TramoConjunto
## Un escalón de bono de un ConjuntoDatos: se activa cuando el jugador tiene
## equipadas AL MENOS piezas_requeridas piezas de ese conjunto (ver
## AtributosComponente._sumar_bonos_de_conjuntos). Los tramos alcanzados se
## ACUMULAN — con 4 piezas de un set con tramos en 2 y 4, se suman los dos.

@export var piezas_requeridas: int = 2
@export var bonos: AtributosBase
