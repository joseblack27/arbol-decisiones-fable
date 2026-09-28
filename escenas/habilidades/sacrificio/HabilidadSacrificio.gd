class_name HabilidadSacrificio
extends HabilidadBase
## Auto-buff de alto riesgo y alto beneficio: paga el 20% de tu vida ACTUAL
## (no la máxima) a cambio de +100 de potencia, +20% de probabilidad de
## crítico y +10% de daño crítico durante 30 s, todos temporales (ver
## AtributosComponente.agregar_bono_temporal).
##
## Nunca puede matar de un solo uso: el costo es un PORCENTAJE de la vida
## actual, así que siempre queda el 80%; no hace falta chequear si "alcanza".
##
## A diferencia de Furia y Fervor, que necesitan un _process() para revertir
## algo que pisan cada frame, acá no hace falta: el bono de
## AtributosComponente y el ícono de BuffsComponente vencen solos, así que
## alcanza con un disparo en _ejecutar(), como HabilidadBuffEquipo.

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


## Escalado por nivel de mejora (ver DatosHabilidad.escalado y
## recursos/habilidades/sacrificio.tres): usa CampoEscalado.campo_atributo
## (POTENCIA, PROBABILIDAD_CRITICO, DANO_CRITICO), que HabilidadBase ya
## resuelve a bono_potencia/bono_probabilidad_critico/bono_dano_critico sin
## ningún override acá.


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
