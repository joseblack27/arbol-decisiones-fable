# =============================================================================
# generar_hormigas_reskin.gd — Herramienta de un solo uso: duplica
# EnemigoLobo.tscn/EnemigoLoboFeroz.tscn en EnemigoHormigaObrera.tscn/
# EnemigoHormigaSoldado.tscn para la colonia de hormigas. Mismo combo de
# habilidades y mismo árbol de animación que el original (arañazo+carga) --
# solo cambia el script raíz (subclase vacía, ver EnemigoHormigaObrera.gd/
# EnemigoHormigaSoldado.gd) y el EnemigoDatos (stats + color propios --
# Enemigo._aplicar_datos() ya tiñe el Sprite2D según datos.color, mismo
# mecanismo que ya usa el proyecto para diferenciar reskins como
# EnemigoEsqueletoArquero, así que no hace falta tocar el Sprite2D a mano).
#
# Edición de TEXTO directa sobre el .tscn -- NO PackedScene.instantiate() +
# set_script() + pack(). Reasignarle el script a la raíz DESPUÉS de
# instanciada resetea los @export de tipo nodo (memoria, componente_vida,
# componente_movimiento...) que la escena original resuelve vía node_paths
# al instanciar por primera vez: confirmado en la práctica (quedaban en
# null, "Nonexistent function 'establecer' en base 'Nil'" al correr la
# prueba del mob resultante). Trabajar sobre el texto plano evita el
# problema de raíz -- el archivo de salida es un duplicado exacto del
# original salvo 3 reemplazos puntuales, cada uno verificado como ÚNICO
# antes de aplicarse.
#
# OJO con el ext_resource del script: además del path=, trae un uid=
# (uid://...) que Godot resuelve ANTES que el path si ya existe un archivo
# registrado con ese uid -- confirmado en la práctica (el mob resultante
# cargaba igual el script VIEJO pese a que el .tscn decía el nuevo path).
# Sacar el uid= entero de esa línea fuerza la resolución por path.
#   godot --headless --path . --script res://herramientas/generar_hormigas_reskin.gd
# =============================================================================
extends SceneTree


func _initialize() -> void:
	_reskin(
		"res://escenas/enemigos/EnemigoLobo.tscn",
		"res://escenas/enemigos/EnemigoHormigaObrera.tscn",
		"EnemigoLobo", "EnemigoHormigaObrera",
		"res://escenas/enemigos/EnemigoLobo.gd",
		"res://escenas/enemigos/EnemigoHormigaObrera.gd",
		"res://recursos/enemigos/Lobo.tres",
		"res://recursos/enemigos/HormigaObrera.tres")
	_reskin(
		"res://escenas/enemigos/EnemigoLoboFeroz.tscn",
		"res://escenas/enemigos/EnemigoHormigaSoldado.tscn",
		"EnemigoLoboFeroz", "EnemigoHormigaSoldado",
		"res://escenas/enemigos/EnemigoLoboFeroz.gd",
		"res://escenas/enemigos/EnemigoHormigaSoldado.gd",
		"res://recursos/enemigos/LoboFeroz.tres",
		"res://recursos/enemigos/HormigaSoldado.tres")
	quit(0)


func _reskin(ruta_base: String, ruta_salida: String, nombre_viejo: String, nombre_nuevo: String,
		ruta_script_vieja: String, ruta_script_nueva: String,
		ruta_datos_vieja: String, ruta_datos_nueva: String) -> void:
	var archivo := FileAccess.open(ruta_base, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir %s (error %d)." % [ruta_base, FileAccess.get_open_error()])
		return
	var texto := archivo.get_as_text()
	archivo.close()

	# 1) Script de la raíz -- REGEX porque el uid= tiene un valor variable
	# que no vale la pena hardcodear, y hay que sacarlo entero además de
	# cambiar el path (ver comentario grande de arriba).
	var patron := RegEx.new()
	patron.compile('\\[ext_resource type="Script"( uid="uid://[a-z0-9]+")? path="%s"' % ruta_script_vieja)
	var coincidencias := patron.search_all(texto)
	if coincidencias.size() != 1:
		push_error("%s: esperaba 1 ext_resource de script, encontré %d." % [ruta_base, coincidencias.size()])
		return
	texto = patron.sub(texto, '[ext_resource type="Script" path="%s"' % ruta_script_nueva)

	# 2) EnemigoDatos de la raíz (el ext_resource declarado con id="0_datos"
	# -- las habilidades hijas usan su PROPIO DatosHabilidad con otro id,
	# sin relación con esto). Esta línea no trae uid=, alcanza con el path.
	texto = _reemplazar_unico(texto,
		'path="%s" id="0_datos"' % ruta_datos_vieja, 'path="%s" id="0_datos"' % ruta_datos_nueva, ruta_base)
	if texto == "":
		return

	# 3) Nombre del nodo raíz (cosmético).
	texto = _reemplazar_unico(texto,
		'[node name="%s" type="CharacterBody2D"' % nombre_viejo,
		'[node name="%s" type="CharacterBody2D"' % nombre_nuevo, ruta_base)
	if texto == "":
		return

	var salida := FileAccess.open(ruta_salida, FileAccess.WRITE)
	if salida == null:
		push_error("No se pudo abrir %s para escribir (error %d)." % [ruta_salida, FileAccess.get_open_error()])
		return
	salida.store_string(texto)
	salida.close()
	print("Guardado %s (duplicado de %s con script/datos propios)." % [ruta_salida, ruta_base])


## Reemplaza "buscado" por "nuevo" en "texto" SOLO si aparece EXACTAMENTE
## una vez -- devuelve "" (string vacío, nunca un resultado válido de un
## .tscn real) si no, para que el llamador aborte esa escena en vez de
## arriesgar un reemplazo ambiguo (0 o 2+ ocurrencias).
func _reemplazar_unico(texto: String, buscado: String, nuevo: String, ruta: String) -> String:
	var veces := texto.count(buscado)
	if veces != 1:
		push_error("%s: esperaba 1 ocurrencia de '%s', encontré %d." % [ruta, buscado, veces])
		return ""
	return texto.replace(buscado, nuevo)
