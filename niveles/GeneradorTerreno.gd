class_name GeneradorTerreno
extends TileMapLayer
## Genera el terreno del nivel con ruido: suelo variado, decoración, lagunas
## y rocas, con borde de muros. Es la opción "procedural" del contrato de
## nivel: un nivel también puede tener un TileMapLayer pintado a mano con el
## mismo TileSet y todo lo demás funciona igual.
##
## Los índices de tile son la columna X del atlas tiles_mundo.png:
##   0-1 hierba  2 flores  3 tierra  4 agua  5 roca
##   6-7 cueva   8 grava   9 agua cueva  10 muro cueva

@export_group("Dimensiones")
## Tamaño del mapa en tiles (centrado en el origen del nivel).
@export var ancho := 60
@export var alto := 38
## Grosor del borde de muros que encierra el nivel.
@export var grosor_borde := 2

@export_group("Generación")
@export var semilla := 7
@export var frecuencia_ruido := 0.07
## Valores de ruido por debajo de este umbral se vuelven agua.
@export var umbral_agua := -0.42
## Probabilidad de roca suelta en zonas de ruido alto.
@export var densidad_rocas := 0.05
## Probabilidad de tile decorativo (flores/grava).
@export var densidad_decoracion := 0.06

@export_group("Paleta (índice X en el atlas)")
@export var indice_suelo_a := 0
@export var indice_suelo_b := 1
@export var indice_decoracion := 2
@export var indice_agua := 4
@export var indice_muro := 5


func _ready() -> void:
	generar()


func generar() -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = frecuencia_ruido

	var mitad := Vector2i(ancho / 2, alto / 2)
	for x in ancho:
		for y in alto:
			var celda := Vector2i(x, y) - mitad
			var indice: int
			if x < grosor_borde or y < grosor_borde \
					or x >= ancho - grosor_borde or y >= alto - grosor_borde:
				indice = indice_muro
			else:
				indice = _elegir_tile(ruido.get_noise_2d(x, y), rng)
			set_cell(celda, 0, Vector2i(indice, 0))


## Convierte en suelo un círculo de tiles alrededor de una posición global
## (para que aparición, portales y enemigos nunca queden dentro de un sólido).
func despejar_alrededor(posicion_global: Vector2, radio_tiles: int) -> void:
	var centro := local_to_map(to_local(posicion_global))
	for dx in range(-radio_tiles, radio_tiles + 1):
		for dy in range(-radio_tiles, radio_tiles + 1):
			if Vector2(dx, dy).length() > float(radio_tiles):
				continue
			var celda := centro + Vector2i(dx, dy)
			if get_cell_source_id(celda) == -1:
				continue  # Fuera del mapa: no crear suelo flotante.
			var actual := get_cell_atlas_coords(celda)
			if actual.x != indice_muro or _es_borde(celda):
				if actual.x == indice_agua:
					set_cell(celda, 0, Vector2i(indice_suelo_a, 0))
				continue
			set_cell(celda, 0, Vector2i(indice_suelo_a, 0))


func _elegir_tile(valor_ruido: float, rng: RandomNumberGenerator) -> int:
	if valor_ruido < umbral_agua:
		return indice_agua
	if valor_ruido > 0.30 and rng.randf() < densidad_rocas:
		return indice_muro
	if rng.randf() < densidad_decoracion:
		return indice_decoracion
	return indice_suelo_a if valor_ruido > 0.0 else indice_suelo_b


func _es_borde(celda: Vector2i) -> bool:
	var mitad := Vector2i(ancho / 2, alto / 2)
	var local := celda + mitad
	return local.x < grosor_borde or local.y < grosor_borde \
		or local.x >= ancho - grosor_borde or local.y >= alto - grosor_borde
