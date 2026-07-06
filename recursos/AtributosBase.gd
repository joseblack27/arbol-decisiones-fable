extends Resource
class_name AtributosBase

@export_group("Características Ofensivas")
## Bonus de daño plano añadido a cada golpe, antes de cualquier multiplicador.
@export var danos: float = 0.0
## Amplifica el daño total en porcentaje. 20 → el daño final es un 20 % mayor.
@export var potencia: float = 0.0
## Penetración de armadura. Resta directamente a la Defensa del objetivo antes de calcular el daño.
@export var impacto: float = 0.0
## Potencia de los efectos negativos aplicados al objetivo (venenos, quemaduras, ralentizaciones). Reservado para uso futuro.
@export var afliccion: float = 0.0
## Fuerza del retroceso aplicado al objetivo al recibir un golpe. Reservado para uso futuro.
@export var impulso: float = 0.0
## Probabilidad de asestar un golpe crítico, en porcentaje (0 – 100).
@export var probabilidad_critico: float = 0.0
## Multiplicador adicional aplicado al daño cuando ocurre un crítico, en porcentaje. 50 → el crítico inflige un 50 % más de daño.
@export var dano_critico: float = 0.0

@export_group("Características Defensivas")
## Reducción de daño plana que se aplica a cada golpe recibido, antes del porcentaje. Puede ser neutralizada por el Impacto del atacante.
@export var defensa: float = 0.0
## Reduce la duración y efectividad de los efectos de control (aturdimientos, ralentizaciones). Reservado para uso futuro.
@export var tenacidad: float = 0.0
## Reducción porcentual de todo el daño recibido, independientemente del tipo. Se aplica después de la Defensa (máximo interno: 95 %).
@export var fortaleza: float = 0.0
## Reducción porcentual del daño de tipo Físico recibido (máximo interno: 95 %).
@export var resistencia_fisica: float = 0.0
## Reducción porcentual del daño de tipo Aire recibido (máximo interno: 95 %).
@export var resistencia_aire: float = 0.0
## Reducción porcentual del daño de tipo Agua recibido (máximo interno: 95 %).
@export var resistencia_agua: float = 0.0
## Reducción porcentual del daño de tipo Fuego recibido (máximo interno: 95 %).
@export var resistencia_fuego: float = 0.0
## Reducción porcentual del daño de tipo Tierra recibido (máximo interno: 95 %).
@export var resistencia_tierra: float = 0.0
