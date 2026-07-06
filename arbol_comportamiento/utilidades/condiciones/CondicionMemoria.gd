# =============================================================================
# CondicionMemoria.gd  (Utilidad — listo para usar en escena)
# Condición que compara el valor de una variable de la MemoriaBT
# contra un valor de referencia configurable desde el Inspector.
#
# USO: Añade este nodo en la escena y configura sus @export desde el Inspector.
# No requiere código adicional para casos simples.
# =============================================================================
class_name CondicionMemoria
extends Condicion

enum TipoComparacion {
	ES_VERDADERO,  ## valor != null && valor != false && valor != 0
	ES_FALSO,      ## valor == null || valor == false || valor == 0
	NO_ES_NULO,    ## valor != null
	IGUAL_NUMERO,  ## valor == valor_numerico
	MAYOR_QUE,     ## valor > valor_numerico
	MENOR_QUE,     ## valor < valor_numerico
	MAYOR_IGUAL,   ## valor >= valor_numerico
	MENOR_IGUAL,   ## valor <= valor_numerico
	IGUAL_TEXTO,   ## str(valor) == valor_texto
}

@export_group("Configuración Condición")
## Nombre de la variable en la MemoriaBT que se va a evaluar.
@export var nombre_variable: String = ""
## Tipo de comparación a realizar.
@export var tipo_comparacion: TipoComparacion = TipoComparacion.ES_VERDADERO
## Valor numérico de referencia (para comparaciones numéricas).
@export var valor_numerico: float = 0.0
## Valor de texto de referencia (para IGUAL_TEXTO).
@export var valor_texto: String = ""


func _on_ejecutar() -> Estado:
	if not _memoria:
		push_warning("CondicionMemoria '%s': Sin acceso a MemoriaBT." % nombre_nodo)
		return Estado.FALLIDO

	if nombre_variable.is_empty():
		push_warning("CondicionMemoria '%s': 'nombre_variable' está vacío." % nombre_nodo)
		return Estado.FALLIDO

	if not _memoria.existe(nombre_variable):
		if debug_activo:
			print_rich(
				"[color=orange][BT ?][/color] CondicionMemoria [b]%s[/b]: variable '%s' no existe → FALLIDO"
				% [nombre_nodo, nombre_variable]
			)
		return Estado.FALLIDO

	var valor: Variant = _memoria.obtener(nombre_variable)
	var resultado: bool = _evaluar(valor)

	if debug_activo:
		print_rich(
			"[color=yellow][BT ?][/color] CondicionMemoria [b]%s[/b]: [i]%s[/i] = %s → %s"
			% [nombre_nodo, nombre_variable, str(valor), "EXITOSO" if resultado else "FALLIDO"]
		)

	return Estado.EXITOSO if resultado else Estado.FALLIDO


func _evaluar(valor: Variant) -> bool:
	match tipo_comparacion:
		TipoComparacion.ES_VERDADERO:
			return bool(valor)
		TipoComparacion.ES_FALSO:
			return not bool(valor)
		TipoComparacion.NO_ES_NULO:
			return valor != null
		TipoComparacion.IGUAL_NUMERO:
			return float(valor) == valor_numerico
		TipoComparacion.MAYOR_QUE:
			return float(valor) > valor_numerico
		TipoComparacion.MENOR_QUE:
			return float(valor) < valor_numerico
		TipoComparacion.MAYOR_IGUAL:
			return float(valor) >= valor_numerico
		TipoComparacion.MENOR_IGUAL:
			return float(valor) <= valor_numerico
		TipoComparacion.IGUAL_TEXTO:
			return str(valor) == valor_texto
	return false
