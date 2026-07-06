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

# ── API pública ───────────────────────────────────────────────────────────────

## Aplica los atributos ofensivos de ESTE personaje a [dano_base].
## Suma bonus plano, aplica potencia y evalúa crítico.
## Devuelve el daño final como float (el caller decide si lo trunca).
func calcular_dano_saliente(
	dano_base: float, 
	_tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> float:
	if not base:
		return dano_base

	# 1. Bonus plano
	var total: float = dano_base + base.danos

	# 2. Multiplicador de potencia
	total *= 1.0 + base.potencia / 100.0

	# 3. Crítico
	if base.probabilidad_critico > 0.0 and randf() * 100.0 < base.probabilidad_critico:
		total *= 1.0 + base.dano_critico / 100.0

	return maxf(0.0, total)


## Aplica los atributos defensivos de ESTE personaje al daño entrante.
## [atacante] es el AtributosComponente de quien inflige el daño (puede ser null).
## El Impacto del atacante reduce la Defensa del receptor.
func calcular_dano_entrante(
		dano: float,
		tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC,
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
		Enums.Skill.TypeDamage.PHYSIC: reduccion += base.resistencia_fisica / 100.0
		Enums.Skill.TypeDamage.WIND:   reduccion += base.resistencia_aire   / 100.0
		Enums.Skill.TypeDamage.WATER:   reduccion += base.resistencia_agua   / 100.0
		Enums.Skill.TypeDamage.FIRE:  reduccion += base.resistencia_fuego  / 100.0
		Enums.Skill.TypeDamage.EARTH: reduccion += base.resistencia_tierra / 100.0

	# Máximo 95 % de reducción para evitar inmunidad total
	reduccion = clampf(reduccion, 0.0, 0.95)
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
		tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> float:

	# Lado ofensivo
	# is_instance_valid() (no "if fuente:") porque un efecto persistente
	# (p. ej. la telaraña de la araña, un DoT) puede seguir vivo después de
	# que quien lo creó ya haya muerto y sido liberado: una referencia a un
	# nodo liberado no es null, así que "if fuente:" no lo detecta.
	var atrib_at: AtributosComponente = null
	if is_instance_valid(fuente):
		atrib_at = fuente.get_node_or_null("AtributosComponente") as AtributosComponente
	var dano := atrib_at.calcular_dano_saliente(cantidad, tipo) if atrib_at else cantidad

	# Lado defensivo
	var atrib_def: AtributosComponente = null
	if is_instance_valid(defensor):
		atrib_def = defensor.get_node_or_null("AtributosComponente") as AtributosComponente
	dano = atrib_def.calcular_dano_entrante(dano, tipo, atrib_at) if atrib_def else dano

	return dano
