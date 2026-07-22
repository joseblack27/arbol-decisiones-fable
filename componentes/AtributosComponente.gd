extends Node
class_name AtributosComponente
## Componente de atributos de combate.
## Adjuntar al nodo raíz del personaje (jugador o enemigo).
## Expone dos métodos principales:
##   - calcular_dano_saliente()  → daño que ESTE personaje inflige
##   - calcular_dano_entrante()  → daño que ESTE personaje recibe
##
## Para aplicar atributos ofensivos del atacante al calcular daño entrante,
## pasar su AtributosComponente como argumento.

## Valores base del personaje. Asignar en el Inspector.
@export var base: AtributosBase

## Multiplicador BASE de todo golpe crítico (+20%), aplicado siempre que el
## crítico acierta — dano_critico (el atributo visible) se SUMA encima de
## esto. A propósito NO se muestra en ningún panel de atributos: es parte
## de la fórmula, no una estadística del personaje. Sin esta base, un
## personaje con probabilidad de crítico pero 0 de dano_critico acertaba
## críticos que multiplicaban por 1.0 — no hacían absolutamente nada.
const MULTIPLICADOR_CRITICO_BASE := 1.2

## true si el ÚLTIMO calcular_dano_saliente() de esta instancia acertó el
## crítico — el pipeline lo lee justo después para propagarlo hasta el
## número flotante (amarillo). Ver ultimo_pipeline_critico.
var ultimo_golpe_critico := false

## Copia estática del flag de crítico del último calcular_pipeline() — los
## que aplican daño (Proyectil, Combate, DoT, cargas, muro) lo leen JUSTO
## después de llamar al pipeline, en el mismo hilo y sin nada en el medio,
## para pasarlo a quitar_vida()/daño_aplicado. Estado mutable compartido a
## propósito acotado a ese patrón "llamar y leer de inmediato".
static var ultimo_pipeline_critico := false

## Copia congelada de los atributos "de fábrica" (los del Inspector, sin
## ningún bono de equipo). Se toma UNA vez en _ready() y nunca se toca — es
## la referencia desde la que se recalcula cada vez que el equipo cambia
## (para no ir acumulando bonos sobre bonos).
var _base_sin_equipo: AtributosBase


func _ready() -> void:
	if base:
		_base_sin_equipo = base.duplicate() as AtributosBase


## Recalcula los campos de "base" = atributos de fábrica + la suma de los
## bonos de todos los ítems actualmente equipados (DatosItem.bonos).
## Llamarlo cada vez que el equipo cambia (ver BusEventos.equipo_cambiado /
## GestorEquipo). Importante: MUTA el mismo recurso "base" en su sitio en
## vez de reemplazarlo por uno nuevo — cualquiera que ya tenga una
## referencia guardada a él (p. ej. PanelTablero, que la cachea al abrirse)
## ve los cambios reflejados sin tener que volver a pedirla.
func recalcular_con_equipo(items_equipados: Array[DatosItem]) -> void:
	if not _base_sin_equipo or not base:
		return
	_copiar_bonos(base, _base_sin_equipo)
	for item in items_equipados:
		if item and item.bonos:
			_sumar_bonos(base, item.bonos)


## Aplica un crecimiento PERMANENTE (p. ej. al subir de nivel — ver
## ExperienciaComponente._aplicar_crecimiento_nivel) a la línea de base "de
## fábrica" — NO alcanza con tocar "base" directo: recalcular_con_equipo()
## SOBREESCRIBE base entero desde _base_sin_equipo cada vez que el equipo
## cambia, así que un bono aplicado solo a "base" desaparecía en cuanto se
## equipaba/desequipaba algo — incluido el propio flujo de carga de
## partida, que restaura el equipo justo después de la XP (bug reportado:
## "al cargar la partida las estadísticas no se reflejan en el daño").
## Tocar ambos a la vez da efecto inmediato Y sobrevive al próximo recálculo.
func agregar_crecimiento_permanente(danos_extra: float = 0.0) -> void:
	if _base_sin_equipo:
		_base_sin_equipo.danos += danos_extra
	if base:
		base.danos += danos_extra


func _copiar_bonos(destino: AtributosBase, origen: AtributosBase) -> void:
	destino.danos                 = origen.danos
	destino.potencia               = origen.potencia
	destino.impacto                = origen.impacto
	destino.afliccion              = origen.afliccion
	destino.impulso                = origen.impulso
	destino.probabilidad_critico    = origen.probabilidad_critico
	destino.dano_critico            = origen.dano_critico
	destino.regeneracion_vida       = origen.regeneracion_vida
	destino.regeneracion_vida_plana = origen.regeneracion_vida_plana
	destino.regeneracion_energia    = origen.regeneracion_energia
	destino.defensa                 = origen.defensa
	destino.tenacidad               = origen.tenacidad
	destino.fortaleza               = origen.fortaleza
	destino.resistencia_fisica      = origen.resistencia_fisica
	destino.resistencia_aire        = origen.resistencia_aire
	destino.resistencia_agua        = origen.resistencia_agua
	destino.resistencia_fuego       = origen.resistencia_fuego
	destino.resistencia_tierra      = origen.resistencia_tierra


func _sumar_bonos(destino: AtributosBase, bonos: AtributosBase) -> void:
	destino.danos                 += bonos.danos
	destino.potencia               += bonos.potencia
	destino.impacto                += bonos.impacto
	destino.afliccion              += bonos.afliccion
	destino.impulso                += bonos.impulso
	destino.probabilidad_critico    += bonos.probabilidad_critico
	destino.dano_critico            += bonos.dano_critico
	destino.regeneracion_vida       += bonos.regeneracion_vida
	destino.regeneracion_vida_plana += bonos.regeneracion_vida_plana
	destino.regeneracion_energia    += bonos.regeneracion_energia
	destino.defensa                 += bonos.defensa
	destino.tenacidad               += bonos.tenacidad
	destino.fortaleza               += bonos.fortaleza
	destino.resistencia_fisica      += bonos.resistencia_fisica
	destino.resistencia_aire        += bonos.resistencia_aire
	destino.resistencia_agua        += bonos.resistencia_agua
	destino.resistencia_fuego       += bonos.resistencia_fuego
	destino.resistencia_tierra      += bonos.resistencia_tierra


# ── API pública ───────────────────────────────────────────────────────────────

## Aplica los atributos ofensivos de ESTE personaje a [dano_base].
## Suma bonus plano, aplica potencia y evalúa crítico.
## Devuelve el daño final como float (el caller decide si lo trunca).
func calcular_dano_saliente(
	dano_base: float, 
	_tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> float:
	if not base:
		return dano_base

	# 1. Bonus plano
	var total: float = dano_base + base.danos

	# 2. Multiplicador de potencia
	total *= 1.0 + base.potencia / 100.0

	# 3. Crítico: base x1.2 SIEMPRE que acierta (ver MULTIPLICADOR_CRITICO_
	# BASE) + el dano_critico visible del personaje encima.
	ultimo_golpe_critico = false
	if base.probabilidad_critico > 0.0 and randf() * 100.0 < base.probabilidad_critico:
		ultimo_golpe_critico = true
		total *= MULTIPLICADOR_CRITICO_BASE + base.dano_critico / 100.0

	return maxf(0.0, total)


## Igual que calcular_dano_saliente() pero SIN el roll de crítico (ese paso
## es aleatorio y no tiene sentido en un número mostrado en pantalla, p. ej.
## la descripción de una habilidad en el panel). Solo bonus plano + potencia.
func calcular_dano_saliente_vista_previa(dano_base: float) -> float:
	if not base:
		return dano_base
	var total: float = dano_base + base.danos
	total *= 1.0 + base.potencia / 100.0
	return maxf(0.0, total)


## Aplica los atributos defensivos de ESTE personaje al daño entrante.
## [atacante] es el AtributosComponente de quien inflige el daño (puede ser null).
## El Impacto del atacante reduce la Defensa del receptor.
func calcular_dano_entrante(
		dano: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		atacante: AtributosComponente = null) -> float:

	if not base:
		return dano

	# 1. Defensa plana menos la penetración del atacante
	var penetracion: float = atacante.base.impacto if (atacante and atacante.base) else 0.0
	var defensa_efectiva: float = maxf(0.0, base.defensa - penetracion)
	var resultado: float = maxf(0.0, dano - defensa_efectiva)

	# 2. Reducción porcentual acumulada (fortaleza + resistencia elemental)
	var reduccion: float = base.fortaleza / 100.0
	match tipo:
		Enums.Habilidad.TipoDano.FISICO: reduccion += base.resistencia_fisica / 100.0
		Enums.Habilidad.TipoDano.AIRE:   reduccion += base.resistencia_aire   / 100.0
		Enums.Habilidad.TipoDano.AGUA:   reduccion += base.resistencia_agua   / 100.0
		Enums.Habilidad.TipoDano.FUEGO:  reduccion += base.resistencia_fuego  / 100.0
		Enums.Habilidad.TipoDano.TIERRA: reduccion += base.resistencia_tierra / 100.0

	# Máximo 95 % de reducción para evitar inmunidad total. Piso en -100 %
	# (no 0): una resistencia NEGATIVA es una DEBILIDAD elemental — debe
	# amplificar el daño, no quedarse en "no hace nada". Con piso en 0 antes,
	# ponerle -25 de resistencia al fuego a un mob no tenía ningún efecto
	# (clampf cortaba a 0 igual que sin nada) — el sistema de debilidades
	# nunca podía funcionar. -1.0 tope: como mucho el doble de daño, para
	# que una debilidad marcada sea notoria sin volverse un one-shot.
	reduccion = clampf(reduccion, -1.0, 0.95)
	resultado *= 1.0 - reduccion

	# Mínimo 1 de daño siempre pasa
	return maxf(1.0, resultado)


## Pipeline completo atacante → defensor.
## Llámalo desde launchers (Proyectil, AreaEfecto, etc.) antes de quitar_vida().
## Si alguno de los dos nodos no tiene AtributosComponente, el daño pasa sin cambios.
static func calcular_pipeline(
		fuente: Node,
		defensor: Node,
		cantidad: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> float:

	# Lado ofensivo
	# is_instance_valid() (no "if fuente:") porque un efecto persistente
	# (p. ej. la telaraña de la araña, un DoT) puede seguir vivo después de
	# que quien lo creó ya haya muerto y sido liberado: una referencia a un
	# nodo liberado no es null, así que "if fuente:" no lo detecta.
	var atrib_at: AtributosComponente = null
	if is_instance_valid(fuente):
		atrib_at = fuente.get_node_or_null("AtributosComponente") as AtributosComponente
	var dano := atrib_at.calcular_dano_saliente(cantidad, tipo) if atrib_at else cantidad
	ultimo_pipeline_critico = atrib_at.ultimo_golpe_critico if atrib_at else false

	# Lado defensivo
	var atrib_def: AtributosComponente = null
	if is_instance_valid(defensor):
		atrib_def = defensor.get_node_or_null("AtributosComponente") as AtributosComponente
	dano = atrib_def.calcular_dano_entrante(dano, tipo, atrib_at) if atrib_def else dano

	return dano
