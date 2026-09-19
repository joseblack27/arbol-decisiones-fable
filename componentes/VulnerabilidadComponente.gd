extends Node
class_name VulnerabilidadComponente
## Espejo de EscudoComponente pero al revés: amplifica (en vez de reducir) el
## daño entrante durante un tiempo. Pensado para la "Puesta de Huevos" de la
## Reina de las Hormigas (ver HabilidadPuestaHuevos.gd) — mientras dura su
## estado de descanso recibe +20% de daño — pero genérico a propósito, igual
## que EscudoComponente: cualquier entidad puede colgarlo si más adelante
## hace falta la misma mecánica.
##
## VidaComponente.quitar_vida() lo consulta como sibling ("Vulnerabilidad
## Componente" bajo el mismo padre), en el mismo punto central por el que
## pasa TODO el daño — mismo criterio que EscudoComponente, ver ese archivo.

signal vulnerabilidad_activada(duracion: float, extra: float)
signal vulnerabilidad_terminada()

var _tiempo_restante: float = 0.0
## 0.2 = +20% de daño entrante mientras dure.
var _extra: float = 0.0


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = 0.0
		vulnerabilidad_terminada.emit()


## Activa (o renueva, si ya estaba activo) la vulnerabilidad por "duracion"
## segundos.
func activar(duracion: float, extra: float = 0.2) -> void:
	_tiempo_restante = maxf(0.0, duracion)
	_extra = maxf(0.0, extra)
	vulnerabilidad_activada.emit(_tiempo_restante, _extra)


## Corta la vulnerabilidad de inmediato (ej.: la Reina sale de su descanso
## antes de tiempo porque ya no queda ningún huevo vivo).
func desactivar() -> void:
	_tiempo_restante = 0.0


func esta_activo() -> bool:
	return _tiempo_restante > 0.0


func tiempo_restante() -> float:
	return maxf(0.0, _tiempo_restante)


## Amplifica el daño entrante. Llamar SIEMPRE (aunque no esté activo: en ese
## caso devuelve "dano" sin tocar) — mismo criterio que EscudoComponente
## .aplicar(), un solo punto de verdad para la fórmula.
func aplicar(dano: float, _fuente: Node = null) -> float:
	if not esta_activo():
		return dano
	return dano * (1.0 + _extra)
