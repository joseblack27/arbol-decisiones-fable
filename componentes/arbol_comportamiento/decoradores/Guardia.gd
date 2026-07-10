# =============================================================================
# Guardia.gd  (Decorador — Guard / Gate)
#
# Comprueba una variable en la MemoriaBT ANTES de ceder el paso al hijo.
# Si la condición no se cumple, retorna FALLIDO sin ejecutar al hijo.
# Si se cumple, ejecuta al hijo y retorna su resultado sin modificarlo.
#
# Es un decorador "portero": deja pasar o no, según el estado de la memoria.
# Más expresivo que una Secuencia con una CondicionMemoria cuando la intención
# es explícitamente "proteger" un subárbol complejo con una sola condición.
#
# Casos de uso:
#   • Solo ejecutar un subárbol de ataque si "tiene_arma" está en true.
#   • Bloquear toda la rama de patrulla si "alarma_activa" es true.
#   • Reemplazar Secuencia(Condicion + Accion) cuando la condición es simple.
#
# USO EN ESCENA: Añade UN único nodo NodoBT como hijo de Guardia.
# =============================================================================
class_name Guardia
extends NodoDecorador

enum TipoGuardia {
	ES_VERDADERO,  ## Pasa si el valor es truthy (no null, no false, no 0).
	ES_FALSO,      ## Pasa si el valor es falsy.
	NO_ES_NULO,    ## Pasa si la variable existe y no es null.
	MAYOR_QUE,     ## Pasa si el valor numérico > umbral.
	MENOR_QUE,     ## Pasa si el valor numérico < umbral.
	MAYOR_IGUAL,   ## Pasa si el valor numérico >= umbral.
	MENOR_IGUAL,   ## Pasa si el valor numérico <= umbral.
	IGUAL_NUMERO,  ## Pasa si el valor numérico == umbral.
}

@export_group("Configuración Guardia")
## Variable de la MemoriaBT que se evalúa como condición de paso.
@export var nombre_variable: String = ""
## Tipo de evaluación a realizar sobre el valor.
@export var tipo_guardia: TipoGuardia = TipoGuardia.ES_VERDADERO
## Umbral numérico de referencia (para comparaciones numéricas).
@export var umbral: float = 0.0


func _on_ejecutar() -> Estado:
	if not _hijo:
		push_warning("Guardia '%s': No tiene hijo NodoBT." % nombre_nodo)
		return Estado.FALLIDO

	if not _memoria:
		return Estado.FALLIDO

	if nombre_variable.is_empty():
		push_warning("Guardia '%s': 'nombre_variable' está vacío." % nombre_nodo)
		return Estado.FALLIDO

	if not _memoria.existe(nombre_variable):
		if debug_activo:
			print_rich(
				"[color=red][BT 🚧][/color] Guardia [b]%s[/b]: '%s' no existe → bloqueado"
				% [nombre_nodo, nombre_variable]
			)
		return Estado.FALLIDO

	var valor: Variant = _memoria.obtener(nombre_variable)
	var pasa: bool = _evaluar(valor)

	if debug_activo:
		var icono := "🟢 abierto" if pasa else "🔴 bloqueado"
		print_rich(
			"[color=cyan][BT 🚧][/color] Guardia [b]%s[/b]: [i]%s[/i]=%s → %s"
			% [nombre_nodo, nombre_variable, str(valor), icono]
		)

	if not pasa:
		return Estado.FALLIDO

	return _hijo.ejecutar()


func _evaluar(valor: Variant) -> bool:
	match tipo_guardia:
		TipoGuardia.ES_VERDADERO:  return bool(valor)
		TipoGuardia.ES_FALSO:      return not bool(valor)
		TipoGuardia.NO_ES_NULO:    return valor != null
		TipoGuardia.MAYOR_QUE:     return float(valor) > umbral
		TipoGuardia.MENOR_QUE:     return float(valor) < umbral
		TipoGuardia.MAYOR_IGUAL:   return float(valor) >= umbral
		TipoGuardia.MENOR_IGUAL:   return float(valor) <= umbral
		TipoGuardia.IGUAL_NUMERO:  return float(valor) == umbral
	return false
