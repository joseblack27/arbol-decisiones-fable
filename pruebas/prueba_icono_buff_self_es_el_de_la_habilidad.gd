# =============================================================================
# Prueba: para las habilidades de UN SOLO componente (self-buffs y Sacudida,
# sin proyectil de por medio — ver prueba_icono_debuff_es_el_de_la_habilidad
# para el caso con proyectil), aplicar_datos() pisa el ícono de buff/debuff
# con el de la habilidad (DatosHabilidad.icono) — mismo pedido del usuario
# que para Veneno: "quiero que el icono que salga como debuff o buff sea el
# que se usa como habilidad no el del proyectil".
#   godot --headless --path . --script res://pruebas/prueba_icono_buff_self_es_el_de_la_habilidad.gd
# =============================================================================
extends SceneTree

## script, campo del ícono, ruta al .tres real.
const CASOS := [
	["res://escenas/habilidades/camuflaje/HabilidadCamuflaje.gd", "icono_buff", "res://recursos/habilidades/camuflaje.tres"],
	["res://escenas/habilidades/purga/HabilidadPurga.gd", "icono_inmunidad", "res://recursos/habilidades/purga.tres"],
	["res://escenas/habilidades/fervor/HabilidadFervor.gd", "icono_buff", "res://recursos/habilidades/fervor.tres"],
	["res://escenas/habilidades/acumulacion/HabilidadAcumulacion.gd", "icono_buff", "res://recursos/habilidades/acumulacion.tres"],
	["res://escenas/habilidades/sacudida/HabilidadSacudida.gd", "icono_debuff", "res://recursos/habilidades/sacudida.tres"],
]

var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		return _informar()
	return false


func _informar() -> bool:
	var todo_ok := true
	for caso in CASOS:
		var ruta_script: String = caso[0]
		var campo: String = caso[1]
		var ruta_datos: String = caso[2]

		var guion := load(ruta_script) as GDScript
		var hab = guion.new()
		var datos := load(ruta_datos) as DatosHabilidad
		hab.aplicar_datos(datos)

		var coincide: bool = hab.get(campo) == datos.icono
		print("%s.%s coincide con %s.icono (esperado true): %s" % [
			ruta_script.get_file(), campo, ruta_datos.get_file(), coincide])
		todo_ok = todo_ok and coincide
		hab.free()

	print("PRUEBA ICONO BUFF SELF ES EL DE LA HABILIDAD %s" % ("OK" if todo_ok else "FALLIDA"))
	quit(0 if todo_ok else 1)
	return true
