extends Resource
class_name PasivaStatDesbloqueo
## Una pasiva de ESTADÍSTICA: se desbloquea sola al alcanzar nivel_requerido
## (ver ExperienciaComponente.pasivas_stat / _aplicar_crecimiento_nivel) y
## aplica "bono" como crecimiento PERMANENTE — mismo mecanismo que el
## crecimiento normal de daños por nivel, ver AtributosComponente
## .agregar_crecimiento_permanente(). Siempre activa, sin equipar/desequipar.

## Nivel de personaje en el que se desbloquea.
@export var nivel_requerido: int = 1
@export var nombre: String = ""
@export var descripcion: String = ""
## Para la UI de solo lectura (ver PanelHabilidades) y la notificación de
## desbloqueo. Opcional — null = sin ícono.
@export var icono: Texture2D = null
## Se suma PERMANENTEMENTE a los atributos del personaje al alcanzar
## nivel_requerido — puede tener cualquier combinación de campos. El
## desbloqueo automático da UN tier gratis; ver costo_puntos_por_nivel/
## max_niveles para los tiers ADICIONALES que se compran con puntos de
## mejora (ver MejorasComponente), otra copia entera de este mismo bono
## por cada tier comprado.
@export var bono: AtributosBase = null

## Puntos de mejora que cuesta cada tier ADICIONAL más allá del gratis.
@export var costo_puntos_por_nivel: int = 1
## Tope de tiers comprables con puntos (sin contar el gratis del desbloqueo).
@export var max_niveles: int = 5
