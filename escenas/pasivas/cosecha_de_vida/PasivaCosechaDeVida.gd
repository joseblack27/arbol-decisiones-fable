extends PasivaBase
class_name PasivaCosechaDeVida
## Pasiva de gatillo: al matar a un enemigo de un golpe propio, cura un
## porcentaje de la vida máxima.
##
## No existe ningún evento de "maté a X" (ver BusEventos: solo daño_aplicado
## y curacion_aplicada son señales de combate reales) — se detecta
## escuchando daño_aplicado con fuente == entidad_dueña y comprobando si la
## vida del objetivo quedó en 0 justo después: quitar_vida() (ver
## VidaComponente/Combate.gd) ya actualiza salud_actual ANTES de emitir
## daño_aplicado, así que para cuando este listener corre, la vida
## resultante del objetivo ya refleja el golpe real.
##
## Sin gate de red propio: VidaComponente.agregar_vida() ya se autolimita al
## servidor/single-player (no-op en un cliente puro), mismo criterio que
## InventarioComponente._curar_local() con las pociones.

@export_range(0.0, 1.0) var porcentaje_curacion: float = 0.05


func _ready() -> void:
	BusEventos.daño_aplicado.connect(_al_daño_aplicado)


func _al_daño_aplicado(objetivo: Node, _cantidad: float, fuente: Node, _tipo: int, _critico: bool) -> void:
	if fuente != entidad_dueña or not is_instance_valid(objetivo):
		return
	var vida_objetivo := objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if vida_objetivo == null or vida_objetivo.obtener_vida() > 0.0:
		return
	if not is_instance_valid(entidad_dueña):
		return
	var vida_propia := entidad_dueña.get_node_or_null("VidaComponente") as VidaComponente
	if vida_propia:
		vida_propia.agregar_vida(vida_propia.obtener_vida_maxima() * porcentaje_curacion)
