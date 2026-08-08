extends EfectoAreaBase
class_name EfectoMarcar
## Cuelga una MARCA DETONABLE (ver MarcaComponente) de cada enemigo alcanzado.
##
## A diferencia de Inmovilizar —que es una ZONA: te frena mientras estés
## dentro— esto se PEGA al objetivo: una vez marcado, la marca vive su propia
## cuenta atrás aunque salga de la zona, igual que el veneno. Por eso
## _quitar_efecto() no hace nada.

@export_group("Marca")
## Segundos que la marca acumula daño antes de estallar.
@export var duracion_marca: float = 5.0
## Qué fracción del daño acumulado se devuelve en la explosión.
@export_range(0.0, 2.0) var porcentaje_detonacion: float = 0.5
## Radio (px) de la explosión.
@export var radio_detonacion: float = 130.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FUEGO
## Ícono que muestra el objetivo mientras está marcado.
@export var icono_debuff: Texture2D = null
## Piso garantizado de la detonación aparte de lo acumulado — pensado para un
## jefe que sea la única fuente de daño del encuentro (ver MarcaComponente).
## 0.0 (default) no cambia el uso normal de la Marca del jugador.
@export var dano_base_detonacion: float = 0.0

## Se la asigna Proyectil si tiene la propiedad "fuente" — quién puso la marca.
var fuente: Node = null


func _aplicar_efecto(objetivo: Node) -> void:
	if not is_instance_valid(objetivo):
		return
	var marca := objetivo.get_node_or_null("MarcaComponente") as MarcaComponente
	if marca == null:
		marca = MarcaComponente.new()
		marca.name = "MarcaComponente"
		objetivo.add_child(marca)
	var fuente_valida: Node = fuente if is_instance_valid(fuente) else null
	marca.activar(duracion_marca, porcentaje_detonacion, radio_detonacion,
		fuente_valida, tipo_dano, dano_base_detonacion)
	_anotar_icono(objetivo)


## La marca sobrevive a salirse de la zona: es un estado del objetivo, no de
## la zona. Se deja vacío a propósito (ver la nota de clase).
func _quitar_efecto(_objetivo: Node) -> void:
	pass


func _anotar_icono(objetivo: Node) -> void:
	if icono_debuff == null:
		return
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar("marca", icono_debuff, duracion_marca, true, "Marcado")
