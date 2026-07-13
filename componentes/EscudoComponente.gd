extends Node
class_name EscudoComponente
## Guarda y aplica un escudo TEMPORAL de reducción de daño. No decide cuándo
## activarse — eso lo hace una habilidad (ver HabilidadEscudo); este
## componente solo lleva la cuenta del tiempo restante y hace la cuenta.
##
## VidaComponente.quitar_vida() lo consulta como sibling ("EscudoComponente"
## bajo el mismo padre) ANTES de aplicar el daño real — mismo punto central
## por el que pasa TODO el daño (proyectil, arañazo, golpe, carga, área),
## así que un escudo activo protege sin importar qué tipo de ataque llegue,
## sin tener que tocar cada habilidad de ataque por separado.
##
## Genérico a propósito: se puede colgar de CUALQUIER entidad (jugador o
## mob) que quiera tener esta defensa disponible más adelante.

signal escudo_activado(duracion: float, reduccion: float)
signal escudo_terminado()

var _tiempo_restante: float = 0.0
## 1.0 = bloquea el 100% del daño entrante; 0.5 = lo reduce a la mitad.
var _reduccion: float = 1.0


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = 0.0
		escudo_terminado.emit()


## Activa (o renueva, si ya estaba activo) el escudo por "duracion" segundos.
func activar(duracion: float, reduccion: float = 1.0) -> void:
	_tiempo_restante = maxf(0.0, duracion)
	_reduccion = clampf(reduccion, 0.0, 1.0)
	escudo_activado.emit(_tiempo_restante, _reduccion)


func esta_activo() -> bool:
	return _tiempo_restante > 0.0


func tiempo_restante() -> float:
	return maxf(0.0, _tiempo_restante)


## Aplica la reducción al daño entrante. Llamar SIEMPRE (aunque no esté
## activo: en ese caso devuelve "dano" sin tocar) en vez de chequear
## esta_activo() aparte — un solo punto de verdad para la fórmula.
func aplicar(dano: float) -> float:
	if not esta_activo():
		return dano
	return dano * (1.0 - _reduccion)
