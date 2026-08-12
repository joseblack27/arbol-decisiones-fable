class_name HabilidadSacrificio
extends HabilidadBase
## Self-buff de alto riesgo/alto beneficio: paga una porción de tu vida
## ACTUAL (no la máxima) a cambio de pegar mucho más fuerte por un rato —
## potencia, probabilidad de crítico y daño crítico, todos temporales (ver
## AtributosComponente.agregar_bono_temporal, generalizado para esta
## habilidad — antes solo cubría daño plano, para Grito de Guerra).
## Pedido explícito del usuario, con estos números exactos: 20% de la vida
## actual, +100 de potencia, +20% de probabilidad de crítico, +10% de daño
## crítico, 30 segundos de duración.
##
## Nunca puede matar de un solo uso: el costo es un PORCENTAJE de la vida
## ACTUAL (80% siempre queda, nunca llega a 0 por sí solo), no un valor
## fijo — a diferencia de la energía, no hace falta chequear "alcanza"
## antes de aplicar.
##
## A diferencia de Furia/Fervor (que SÍ necesitan un _process() propio para
## revertir algo que ellas mismas pisaron cada frame — velocidad, daño de
## un ataque, multiplicador_recarga de otras habilidades), acá no hace
## falta: tanto el bono de AtributosComponente como el ícono de
## BuffsComponente ya vencen y se quitan solos — un solo disparo en
## _ejecutar() alcanza, como HabilidadBuffEquipo.

@export_group("Sacrificio")
## Fracción (0-1) de la vida ACTUAL que cuesta activarla. 0.2 = 20%.
@export var costo_vida_porcentaje: float = 0.2
@export var bono_potencia: float = 100.0
@export var bono_probabilidad_critico: float = 20.0
@export var bono_dano_critico: float = 10.0
@export var duracion: float = 30.0
## Ícono que muestra BuffsComponente mientras dura. Null = sin ícono en el HUD.
@export var icono_buff: Texture2D = null

const _ID_BUFF := "sacrificio"


## Escalado por nivel de mejora (ver DatosHabilidad.escalado / recursos/
## habilidades/sacrificio.tres): usa CampoEscalado.campo_atributo (POTENCIA/
## PROBABILIDAD_CRITICO/DANO_CRITICO, ver Enums.Habilidad.AtributoEscalable)
## — esos tres YA resuelven a bono_potencia/bono_probabilidad_critico/
## bono_dano_critico de forma fija en HabilidadBase, sin hacer falta ningún
## override acá (antes reutilizaba RADIO/DURACION_EFECTO/PORCENTAJE_EFECTO
## a mano, que obligaba a "descifrar" el override para saber a qué campo
## real correspondía cada uno — pedido del usuario).


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Sacrificio"
	tipo_habilidad   = "sacrificio"
	requiere_direccion = false


## El ícono del buff tiene que ser el mismo que ves en el botón — pedido
## del usuario, ver la nota igual en HabilidadCamuflaje/HabilidadFervor.
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_buff = d.icono


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return

	var vida := entidad_dueña.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		# Costo DIRECTO, sin pasar por AtributosComponente.calcular_pipeline():
		# es un sacrificio propio, no un golpe de combate — la propia
		# defensa/resistencias del jugador no deben poder reducirlo, o
		# "20% de la vida actual" dejaría de ser exacto.
		vida.quitar_vida(vida.obtener_vida() * costo_vida_porcentaje, entidad_dueña)

	var atributos := entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos:
		atributos.agregar_bono_temporal(_ID_BUFF, 0.0, bono_potencia,
			bono_probabilidad_critico, bono_dano_critico, duracion)

	if icono_buff == null:
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		entidad_dueña.add_child(buffs)
	buffs.agregar(_ID_BUFF, icono_buff, duracion, false, nombre_habilidad,
		"+%d potencia, +%d%% probabilidad de crítico, +%d%% daño crítico" % [
			int(bono_potencia), int(bono_probabilidad_critico), int(bono_dano_critico)
		])
