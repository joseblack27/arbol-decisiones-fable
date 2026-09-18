extends Enemigo
class_name EnemigoHormigaSoldado
## Hormiga Soldado: la más fuerte de la colonia, ver
## recursos/enemigos/HormigaSoldado.tres. Extiende Enemigo DIRECTO (no
## EnemigoLobo/EnemigoLoboFeroz como al principio): esas clases traen
## @onready fijos a nodos concretos de SU combo (arañazo+carga, +esquiva
## reactiva en el caso de LoboFeroz) que revientan en _ready() si esos
## nodos no existen -- y el kit pedido para las hormigas es otro entero
## (Mordida + Mordida Ácida vía SelectorHabilidades genérico, sin huida),
## así que no hace falta -ni conviene- heredar nada de esa lógica.
