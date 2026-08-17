extends Resource
class_name DatosCofre
## Definición de UN cofre del mundo — plantilla compartida sin estado propio
## (mismo criterio que DatosMision, ver ese comentario): quién ya lo abrió
## vive en CofresComponente, por jugador, indexado por [id]. Reusa LootDrop
## (misma tabla de botín que Enemigo.tabla_botin) — cada entrada se evalúa
## con su propia probabilidad, independiente de las demás.

## Id estable — el que guarda CofresComponente.abiertos y el que usa
## GestorCofres.obtener_por_id() para reasociar esta definición. Debe
## coincidir con el Cofre.id de la instancia en el nivel.
@export var id: String = ""
@export var nombre: String = ""
## Tope de cuántos ítems puede haber a la vez (ver CofresComponente.agregar)
## — no es una grilla de casillas fijas, la lista es densa. -1 = sin
## límite (agregar() nunca rechaza por capacidad).
@export var capacidad: int = 20
## Botín inicial: al abrirlo por PRIMERA VEZ (nunca más), cada entrada tira
## su propia probabilidad independiente y lo que entra se coloca en las
## primeras casillas libres. De ahí en más el contenido es lo que el
## jugador vaya dejando/sacando — esto no se vuelve a tirar.
@export var tabla_botin: Array[LootDrop] = []
