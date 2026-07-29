# =============================================================================
# Prueba de los escudos con resistencias MEZCLADAS (pedido del usuario: cada
# escudo fuerte contra unos elementos y DÉBIL contra otro, para que cambiar
# de escudo según a dónde vas sea una decisión real y no "el que tiene más
# números").
#
# Lo que se prueba es el efecto REAL en combate (AtributosComponente.
# calcular_dano_entrante), no solo que los .tres tengan los campos cargados:
#   1. Los 5 escudos cargan y su id_recurso apunta a su propia ruta.
#   2. Equipar un escudo REDUCE el daño del elemento contra el que es fuerte.
#   3. Una resistencia NEGATIVA amplifica el daño de forma NOTORIA (al menos
#      un 15% más que sin escudo). El umbral importa: la defensa plana se
#      resta ANTES del porcentaje, así que amortigua la amplificación — con
#      -25 de resistencia y 14 de defensa, el escudo de Roca recibía apenas
#      un 3% más de daño de aire mientras reducía el físico un 35%, o sea
#      que seguía siendo el mejor en todo y la debilidad era decorativa.
#   4. Ningún escudo es dominante: el de Roca, el más defensivo del set,
#      recibe MÁS daño de aire que alguien sin escudo.
#   5. Quitar el escudo devuelve los valores a la línea de base (no quedan
#      bonos pegados).
#   godot --headless --path . --script res://pruebas/prueba_escudos_resistencias.gd
# =============================================================================
extends SceneTree

const RUTAS := [
	"res://recursos/items/equipables/escudo.tres",
	"res://recursos/items/equipables/escudo_brasas.tres",
	"res://recursos/items/equipables/escudo_marea.tres",
	"res://recursos/items/equipables/escudo_roca.tres",
	"res://recursos/items/equipables/escudo_tormenta.tres",
]

# Enums.Habilidad.TipoDano
const TIERRA := 0
const FUEGO  := 1
const FISICO := 2
const AGUA   := 3
const AIRE   := 4

var _todos_cargan := false
var _id_recurso_correcto := false
var _brasas_reduce_fuego := false
var _brasas_amplifica_agua := false
var _roca_reduce_fisico := false
var _roca_amplifica_aire := false
var _tormenta_amplifica_fisico := false
var _quitar_vuelve_a_la_base := false


func _process(_d: float) -> bool:
	var atributos := AtributosComponente.new()
	atributos.base = AtributosBase.new()
	root.add_child(atributos)
	# _base_sin_equipo se arma en _ready(): sin él recalcular_con_equipo() no
	# hace nada (ver ese método).
	atributos._base_sin_equipo = AtributosBase.new()

	var items := {}
	_todos_cargan = true
	_id_recurso_correcto = true
	for ruta in RUTAS:
		var it := load(ruta) as DatosItem
		if it == null or it.bonos == null:
			_todos_cargan = false
			print("NO CARGA: %s" % ruta)
			continue
		if it.id_recurso != ruta:
			_id_recurso_correcto = false
			print("id_recurso incorrecto en %s: '%s'" % [ruta, it.id_recurso])
		items[ruta.get_file().get_basename()] = it
	print("Los 5 escudos cargan con bonos (esperado true): %s" % _todos_cargan)
	print("Cada id_recurso apunta a su propia ruta (esperado true): %s" % _id_recurso_correcto)

	const GOLPE := 100.0
	# Cuánto peor debe ir un escudo contra su elemento débil para considerar
	# que la contrapartida existe de verdad (ver el punto 3 de la cabecera).
	const PENALIZACION_MINIMA := 1.15
	var sin_escudo_fuego := atributos.calcular_dano_entrante(GOLPE, FUEGO)
	var sin_escudo_agua  := atributos.calcular_dano_entrante(GOLPE, AGUA)
	var sin_escudo_fis   := atributos.calcular_dano_entrante(GOLPE, FISICO)
	var sin_escudo_aire  := atributos.calcular_dano_entrante(GOLPE, AIRE)

	# --- Escudo de Brasas: fuerte al fuego, DÉBIL al agua ---
	_equipar(atributos, items["escudo_brasas"])
	var brasas_fuego := atributos.calcular_dano_entrante(GOLPE, FUEGO)
	var brasas_agua  := atributos.calcular_dano_entrante(GOLPE, AGUA)
	_brasas_reduce_fuego = brasas_fuego < sin_escudo_fuego
	_brasas_amplifica_agua = brasas_agua >= sin_escudo_agua * PENALIZACION_MINIMA
	print("Brasas reduce el daño de FUEGO (esperado true, %.0f -> %.0f): %s" % [
		sin_escudo_fuego, brasas_fuego, _brasas_reduce_fuego])
	print("Brasas AMPLIFICA el daño de AGUA >=15%% (esperado true, %.0f -> %.0f): %s" % [
		sin_escudo_agua, brasas_agua, _brasas_amplifica_agua])

	# --- Escudo de Roca: el más defensivo, pero DÉBIL al aire ---
	_equipar(atributos, items["escudo_roca"])
	var roca_fis  := atributos.calcular_dano_entrante(GOLPE, FISICO)
	var roca_aire := atributos.calcular_dano_entrante(GOLPE, AIRE)
	_roca_reduce_fisico = roca_fis < sin_escudo_fis
	_roca_amplifica_aire = roca_aire >= sin_escudo_aire * PENALIZACION_MINIMA
	print("Roca reduce mucho el daño FÍSICO (esperado true, %.0f -> %.0f): %s" % [
		sin_escudo_fis, roca_fis, _roca_reduce_fisico])
	print("Roca recibe >=15%% más daño de AIRE, no es dominante (esperado true, %.0f -> %.0f): %s" % [
		sin_escudo_aire, roca_aire, _roca_amplifica_aire])

	# --- Escudo Tormenta: débil al físico, que es lo más común hoy ---
	_equipar(atributos, items["escudo_tormenta"])
	var tormenta_fis := atributos.calcular_dano_entrante(GOLPE, FISICO)
	_tormenta_amplifica_fisico = tormenta_fis >= sin_escudo_fis * PENALIZACION_MINIMA
	print("Tormenta AMPLIFICA el daño FÍSICO >=15%% (esperado true, %.0f -> %.0f): %s" % [
		sin_escudo_fis, tormenta_fis, _tormenta_amplifica_fisico])

	# --- Quitar el escudo: vuelve a la línea de base ---
	var vacio: Array[DatosItem] = []
	atributos.recalcular_con_equipo(vacio)
	_quitar_vuelve_a_la_base = is_equal_approx(atributos.calcular_dano_entrante(GOLPE, FISICO), sin_escudo_fis) \
		and is_equal_approx(atributos.calcular_dano_entrante(GOLPE, AIRE), sin_escudo_aire)
	print("Quitar el escudo devuelve todo a la base (esperado true): %s" % _quitar_vuelve_a_la_base)

	atributos.free()
	return _informar()


func _equipar(atributos: AtributosComponente, item: DatosItem) -> void:
	var lista: Array[DatosItem] = [item]
	atributos.recalcular_con_equipo(lista)


func _informar() -> bool:
	var exito := _todos_cargan and _id_recurso_correcto \
		and _brasas_reduce_fuego and _brasas_amplifica_agua \
		and _roca_reduce_fisico and _roca_amplifica_aire \
		and _tormenta_amplifica_fisico and _quitar_vuelve_a_la_base
	print("PRUEBA ESCUDOS RESISTENCIAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
