extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoGuardianQuebrado
## Jefe de 4 fases pensado para poner a prueba la habilidad "Corte" del
## jugador (parry direccional de área, corta ataques, daño verdadero, se lanza
## aturdido) sin que sea un botón de "gano automático". Mecánica de fases
## común en EnemigoJefe.gd:
##   Fase 1 "Guardia": combo, barrido, amague.
##   Fase 2 "Cazador": lluvia de lanzas, francotirador, charco en golpes de área.
##   Fase 3 "Corrupción": golpe corrupto, muro, escudo reflectante, castigo por
##     cooldown de Corte.
##   Fase 4 "Quiebre": arremetida de daño verdadero, miedo/empujón, refuerzos.
## Cada fase tiene su prueba (pruebas/prueba_guardian_*.gd), y
## prueba_guardian_4_fases_completas.gd las recorre de punta a punta.

@export_group("Fase 2 - Cazador")
@export var habilidad_lluvia_lanzas_bt: HabilidadBT
@export var habilidad_francotirador_bt: HabilidadBT

@export_group("Fase 3 - Corrupción")
@export var habilidad_golpe_corrupto_bt: HabilidadBT
@export var habilidad_muro_bt: HabilidadBT
@export var habilidad_escudo_reflectante_bt: HabilidadBT
## La rama "CastigoCorte" (ArbolComportamiento/Selector/CastigoCorte) está en
## el árbol DESDE EL INICIO, igual que CastigoIndefenso en EnemigoArañaReina,
## pero su SelectorHabilidades empieza vacío: siempre da FALLIDO y cae a
## "Atacar" hasta que esto se agrega en fase 3.
@export var habilidad_castigo_bt: HabilidadBT

@export_group("Fase 4 - Quiebre")
@export var habilidad_arremetida_bt: HabilidadBT
@export var habilidad_miedo_bt: HabilidadBT

const _RUTA_SELECTOR_CASTIGO := "ArbolComportamiento/Selector/CastigoCorte/AtacarCastigo/SelectorCastigo"

var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]


func _ready() -> void:
	super._ready()
	# HabilidadLluviaLanzasGuardian.tscn es una instancia PELADA de
	# HabilidadProyectilAbanico.gd, cuyo _ready() pisa nombre_habilidad con el
	# genérico "Proyectil en abanico" después de cualquier override del .tscn.
	# La única forma de que la etiqueta muestre un nombre propio es fijarlo
	# acá, en el _ready() del jefe, que corre DESPUÉS del de sus hijos.
	var lluvia_lanzas := get_node_or_null("Habilidades/HabilidadLluviaLanzasGuardian")
	if lluvia_lanzas:
		lluvia_lanzas.nombre_habilidad = "Lluvia de Lanzas"


## HabilidadArremetidaGuardian hereda las señales de HabilidadCarga; usa la
## pose CARGANDO por defecto de EnemigoJefe.
func _ruta_embestida() -> String:
	return "Habilidades/HabilidadArremetidaGuardian"


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidades_ataque([habilidad_lluvia_lanzas_bt, habilidad_francotirador_bt])
			# Los golpes de área ya no se van sin dejar rastro: el piso se va
			# llenando de charcos y empuja a moverse en vez de plantarse.
			var combo := get_node_or_null("Habilidades/HabilidadComboGuardian")
			if combo:
				combo.deja_charco = true
			var barrido := get_node_or_null("Habilidades/HabilidadBarridoGuardian")
			if barrido:
				barrido.deja_charco = true
		3:
			_agregar_habilidades_ataque([habilidad_golpe_corrupto_bt, habilidad_muro_bt,
				habilidad_escudo_reflectante_bt])
			_agregar_habilidad_bt(_RUTA_SELECTOR_CASTIGO, habilidad_castigo_bt)
		4:
			_agregar_habilidades_ataque([habilidad_arremetida_bt, habilidad_miedo_bt])
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()
