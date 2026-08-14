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

## Emitida cuando cambia el total de bonos de daño TEMPORALES (se agrega
## uno nuevo, o vence uno existente) — para que la UI (PanelTablero) se
## entere al toque sin tener que sondear a cada rato (antes revisaba cada
## 0.5s aunque nada hubiera cambiado; con la señal solo se refresca
## cuando de verdad hay algo nuevo que mostrar).
signal bono_dano_cambiado(nuevo_total: float)

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


## Bonos TEMPORALES (buffs de tiempo limitado, p. ej. HabilidadBuffEquipo o
## HabilidadSacrificio) — a propósito NO viven en "base": recalcular_con_
## equipo() sobreescribe "base" entero desde _base_sin_equipo cada vez que
## cambia el equipo (ver ese método), así que cualquier bono temporal
## sumado ahí se perdía apenas alguien reequipaba algo mientras el buff
## seguía activo. Viven aparte, se evalúan al calcular daño (ver
## calcular_dano_saliente) y se quitan solos al vencer — nunca hace falta
## "restar" nada a mano.
## Generalizado desde la versión original (solo "danos", para Grito de
## Guerra) — pedido del usuario para Sacrificio, que además de daño
## temporal necesita potencia/crítico temporales, y por el mismo motivo de
## arriba NINGUNO de los tres puede vivir en "base".
class BonoTemporal:
	var danos: float = 0.0
	var potencia: float = 0.0
	var probabilidad_critico: float = 0.0
	var dano_critico: float = 0.0
	var tiempo_restante: float = 0.0

var _bonos_temporales: Dictionary[String, BonoTemporal] = {}


func _ready() -> void:
	if base:
		_base_sin_equipo = base.duplicate() as AtributosBase


func _process(delta: float) -> void:
	if _bonos_temporales.is_empty():
		return
	var vencio_alguno := false
	for id in _bonos_temporales.keys():
		var bono: BonoTemporal = _bonos_temporales[id]
		bono.tiempo_restante -= delta
		if bono.tiempo_restante <= 0.0:
			_bonos_temporales.erase(id)
			vencio_alguno = true
	if vencio_alguno:
		bono_dano_cambiado.emit(obtener_bono_dano_temporal())


## Agrega (o renueva) un bono TEMPORAL identificado por "id" a cualquier
## combinación de danos/potencia/probabilidad_critico/dano_critico —
## reactivar el mismo buff antes de que venza el anterior renueva la
## duración en vez de sumarse dos veces (mismo criterio que BuffsComponente
## .agregar()). Antes se llamaba agregar_bono_dano_temporal() y solo
## aceptaba "danos" (para Grito de Guerra) — generalizado para Sacrificio.
func agregar_bono_temporal(id: String, danos: float = 0.0, potencia: float = 0.0,
		probabilidad_critico: float = 0.0, dano_critico: float = 0.0, duracion: float = 0.0) -> void:
	var bono: BonoTemporal = _bonos_temporales.get(id, BonoTemporal.new())
	bono.danos                = danos
	bono.potencia              = potencia
	bono.probabilidad_critico  = probabilidad_critico
	bono.dano_critico          = dano_critico
	bono.tiempo_restante       = duracion
	_bonos_temporales[id] = bono
	bono_dano_cambiado.emit(obtener_bono_dano_temporal())


## Público (no solo uso interno de calcular_dano_saliente): PanelTablero lo
## necesita para sumar el bono al Daño mostrado en las estadísticas del
## jugador, así en pleno combate se ve el número YA efectivo, sin que el
## jugador tenga que sumar a mano un buff aparte (pedido del usuario).
func obtener_bono_dano_temporal() -> float:
	var total := 0.0
	for bono in _bonos_temporales.values():
		total += (bono as BonoTemporal).danos
	return total


## Mismo criterio que obtener_bono_dano_temporal(), para potencia — usado
## por calcular_dano_saliente()/vista_previa() y PanelTablero.
func obtener_bono_potencia_temporal() -> float:
	var total := 0.0
	for bono in _bonos_temporales.values():
		total += (bono as BonoTemporal).potencia
	return total


## Ídem, para probabilidad de crítico.
func obtener_bono_probabilidad_critico_temporal() -> float:
	var total := 0.0
	for bono in _bonos_temporales.values():
		total += (bono as BonoTemporal).probabilidad_critico
	return total


## Ídem, para daño crítico.
func obtener_bono_dano_critico_temporal() -> float:
	var total := 0.0
	for bono in _bonos_temporales.values():
		total += (bono as BonoTemporal).dano_critico
	return total


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


## Aplica un crecimiento PERMANENTE (p. ej. al subir de nivel, o al
## desbloquear una pasiva de estadística — ver ExperienciaComponente
## ._aplicar_crecimiento_nivel) a la línea de base "de fábrica" — NO
## alcanza con tocar "base" directo: recalcular_con_equipo() SOBREESCRIBE
## base entero desde _base_sin_equipo cada vez que el equipo cambia, así
## que un bono aplicado solo a "base" desaparecía en cuanto se
## equipaba/desequipaba algo — incluido el propio flujo de carga de
## partida, que restaura el equipo justo después de la XP (bug reportado:
## "al cargar la partida las estadísticas no se reflejan en el daño").
## Tocar ambos a la vez da efecto inmediato Y sobrevive al próximo recálculo.
## Recibe un AtributosBase completo (no solo daños) para que las pasivas de
## estadística puedan sumar cualquier campo — reusa _sumar_bonos, que ya
## itera los 17 campos, en vez de repetir esa lista acá.
func agregar_crecimiento_permanente(bono: AtributosBase) -> void:
	if not bono:
		return
	if _base_sin_equipo:
		_sumar_bonos(_base_sin_equipo, bono)
	if base:
		_sumar_bonos(base, bono)


## Copia congelada de "_base_sin_equipo" tal como está AHORA MISMO. Usado
## por ExperienciaComponente para capturar el punto de partida de nivel 1
## antes de aplicar ningún crecimiento, y más tarde poder volver exacto a
## él (ver restablecer_linea_base) sin importar cuántos campos distintos
## haya tocado agregar_crecimiento_permanente() desde entonces — antes solo
## "danos" crecía; con las pasivas de estadística cualquier campo puede
## hacerlo, y resetear solo "danos" dejaría los demás acumulándose de
## nuevo en cada reconexión (restaurar_xp() reaplica todo el crecimiento
## desde nivel 1 cada vez que se llama).
func capturar_linea_base() -> AtributosBase:
	if not _base_sin_equipo:
		return null
	return _base_sin_equipo.duplicate() as AtributosBase


## Inverso de agregar_crecimiento_permanente(): vuelve _base_sin_equipo (y
## "base") al snapshot de capturar_linea_base(). Si se pasan
## items_equipados, "base" se reconstruye vía recalcular_con_equipo (fábrica
## + equipo actual); si no, se copia el snapshot directo a "base".
func restablecer_linea_base(linea_base: AtributosBase, items_equipados: Array[DatosItem] = []) -> void:
	if not linea_base or not _base_sin_equipo:
		return
	_copiar_bonos(_base_sin_equipo, linea_base)
	if items_equipados.is_empty():
		if base:
			_copiar_bonos(base, linea_base)
	else:
		recalcular_con_equipo(items_equipados)


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

	# 1. Multiplicador de potencia (base + cualquier buff temporal, ej.
	# HabilidadSacrificio) — SOLO sobre el daño base de la habilidad, no
	# sobre el bonus plano (ver punto 3): antes "danos" entraba acá también
	# y terminaba amplificado por potencia Y por crítico a la vez, así que
	# equipar daño plano + potencia escalaba multiplicativamente entre sí y
	# desbalanceaba rápido. Ahora el plano se suma fijo al final, sin que
	# ningún multiplicador lo toque.
	var total: float = dano_base
	total *= 1.0 + (base.potencia + obtener_bono_potencia_temporal()) / 100.0

	# 2. Crítico: base x1.2 SIEMPRE que acierta (ver MULTIPLICADOR_CRITICO_
	# BASE) + el dano_critico visible del personaje encima (ambos, base +
	# cualquier buff temporal) — ídem, solo sobre el daño base ya potenciado.
	ultimo_golpe_critico = false
	var prob_critico_total: float = base.probabilidad_critico + obtener_bono_probabilidad_critico_temporal()
	if prob_critico_total > 0.0 and randf() * 100.0 < prob_critico_total:
		ultimo_golpe_critico = true
		total *= MULTIPLICADOR_CRITICO_BASE + (base.dano_critico + obtener_bono_dano_critico_temporal()) / 100.0

	# 3. Bonus plano (base de fábrica+equipo, más cualquier buff temporal
	# activo — ver obtener_bono_dano_temporal): se suma AL FINAL, sin
	# multiplicar por potencia ni por crítico.
	total += base.danos + obtener_bono_dano_temporal()

	return maxf(0.0, total)


## Igual que calcular_dano_saliente() pero SIN el roll de crítico (ese paso
## es aleatorio y no tiene sentido en un número mostrado en pantalla, p. ej.
## la descripción de una habilidad en el panel). Solo potencia + bonus plano,
## mismo orden que la versión real (ver ahí).
func calcular_dano_saliente_vista_previa(dano_base: float) -> float:
	if not base:
		return dano_base
	var total: float = dano_base
	total *= 1.0 + base.potencia / 100.0
	total += base.danos
	return maxf(0.0, total)


## Rango de "Daño Calculado": dano_min/max pasados por calcular_dano_
## saliente_vista_previa (o tal cual si no hay atributos disponibles) y
## RECIÉN ahí escalados por "factor" — el multiplicador_dano_tick propio
## de habilidades que reparten el golpe en varios ticks (Lanzallamas,
## Aura). Compartido por PanelDetalleHabilidad ("Daño Calculado" del
## detalle) y HabilidadAura (descripción del buff activo) para que los
## dos muestren siempre el mismo número sin duplicar la fórmula en cada
## lugar que la necesite — antes vivía escrita dos veces y se desincronizó
## (reportado: "el daño que se muestra no es el calculado para el aura").
static func calcular_rango_con_factor(
		atributos: AtributosComponente, dano_min: float, dano_max: float, factor: float = 1.0) -> Vector2i:
	var final_min := dano_min
	var final_max := dano_max
	if atributos:
		final_min = atributos.calcular_dano_saliente_vista_previa(dano_min)
		final_max = atributos.calcular_dano_saliente_vista_previa(dano_max)
	return Vector2i(int(final_min * factor), int(final_max * factor))


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
