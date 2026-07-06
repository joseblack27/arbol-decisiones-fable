# =============================================================================
# AccionEstablecerMemoria.gd  (Utilidad — listo para usar en escena)
# Acción que escribe un valor en la MemoriaBT al ejecutarse.
# Siempre retorna EXITOSO si la memoria está disponible.
#
# USO: Añade este nodo en la escena y configura sus @export desde el Inspector.
# Útil para establecer flags, contadores u otros valores sin escribir código.
# =============================================================================
class_name AccionEstablecerMemoria
extends Accion

enum TipoValor {
	BOOLEANO, ## Escribe un bool (true / false).
	NUMERO,   ## Escribe un float.
	TEXTO,    ## Escribe un String.
	NULO,     ## Escribe null (limpia la variable).
}

@export_group("Configuración Acción")
## Nombre de la variable en la MemoriaBT que se va a escribir.
@export var nombre_variable: String = ""
## Tipo del valor a escribir.
@export var tipo_valor: TipoValor = TipoValor.BOOLEANO
## Valor booleano (activo cuando tipo_valor = BOOLEANO).
@export var valor_booleano: bool = true
## Valor numérico (activo cuando tipo_valor = NUMERO).
@export var valor_numerico: float = 0.0
## Valor de texto (activo cuando tipo_valor = TEXTO).
@export var valor_texto: String = ""


func _on_ejecutar() -> Estado:
	if not _memoria:
		push_warning("AccionEstablecerMemoria '%s': Sin acceso a MemoriaBT." % nombre_nodo)
		return Estado.FALLIDO

	if nombre_variable.is_empty():
		push_warning(
			"AccionEstablecerMemoria '%s': 'nombre_variable' está vacío." % nombre_nodo
		)
		return Estado.FALLIDO

	var valor: Variant
	match tipo_valor:
		TipoValor.BOOLEANO: valor = valor_booleano
		TipoValor.NUMERO:   valor = valor_numerico
		TipoValor.TEXTO:    valor = valor_texto
		TipoValor.NULO:     valor = null

	_memoria.establecer(nombre_variable, valor)
	return Estado.EXITOSO
