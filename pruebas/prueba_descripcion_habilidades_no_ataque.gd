# =============================================================================
# Prueba de que las habilidades que NO atacan muestran su magnitud y
# duración por PARÁMETRO en la descripción ({valor1}/{duracion}), leídos
# del export real de la escena — no un número pegado a mano en el texto,
# que quedaba desincronizado apenas alguien tocaba el valor real (pedido
# del usuario). Carga los recursos .tres REALES (no sintéticos) para que
# la prueba se rompa sola si alguna vez el .tres y el export del script
# se desincronizan.
#   godot --headless --path . --script res://pruebas/prueba_descripcion_habilidades_no_ataque.gd
# =============================================================================
extends SceneTree

var _panel
var _fotogramas := 0
var _resultados: Dictionary[String, bool] = {}
var _textos: Dictionary[String, String] = {}


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar("escudo", "res://recursos/habilidades/escudo.tres", "Bloquea 100% del daño entrante durante 3 segundos")
		3:
			_probar("curacion", "res://recursos/habilidades/curacion.tres", "Restaura 50 de vida repartidos a lo largo de 5 segundos")
		4:
			_probar("grito_guerra", "res://recursos/habilidades/grito_guerra.tres", "Aumenta en 15 el daño tuyo y el de tus aliados cercanos durante 10 segundos")
		5:
			_probar("gancho", "res://recursos/habilidades/gancho.tres", "un tirón (0.5s)")
		6:
			_probar("inmovilizar", "res://recursos/habilidades/inmovilizar.tres", "durante 2.5 segundos")
		7:
			# Reportado por el usuario: "la invocación, no puedo ver el daño
			# que hace" — dano_ataque del aliado (HabilidadInvocacion.tscn)
			# ahora sale por {valor1}, igual que el resto de estas habilidades.
			_probar("invocacion", "res://recursos/habilidades/invocacion.tres", "golpeando por 10")
		8:
			# Reportado por el usuario: la marca vive dos escenas más adentro
			# (HabilidadMarca.escena_proyectil -> ProyectilMarca.escena_al_
			# impactar -> EfectoMarcar) y esa escena tiene un "duracion"
			# heredado de EfectoAreaBase (0.4s, la vida de la zona de
			# impacto) que NO es duracion_marca (5s, la cuenta atrás real) —
			# {duracion} y {valor1} se quedaban sin resolver / mal resueltos.
			_probar("marca_detonable", "res://recursos/habilidades/marca_detonable.tres",
				"durante 5 segundos", "repartiendo 50%")
		9:
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	var raiz := escena.instantiate()
	root.add_child(raiz)
	_panel = raiz.get_node("MarginContainer/VBoxContainer/TabContainer/TabActivas/HBoxContainer/PanelDetalle")


func _probar(id: String, ruta: String, esperado_contenido: String, esperado_contenido2: String = "") -> void:
	var datos := load(ruta) as DatosHabilidad
	_panel.show_skill(datos)
	var texto: String = _panel.description_label.text
	_textos[id] = texto
	var sin_placeholders_sin_resolver := not texto.contains("{") and not texto.contains("}")
	var contiene_lo_esperado := texto.contains(esperado_contenido) \
		and (esperado_contenido2 == "" or texto.contains(esperado_contenido2))
	_resultados[id] = sin_placeholders_sin_resolver and contiene_lo_esperado
	print("%s -> \"%s\" (esperado que contenga \"%s\" y \"%s\"): %s" % [
		id, texto, esperado_contenido, esperado_contenido2, _resultados[id]])


func _informar() -> bool:
	var exito := true
	for id in _resultados.keys():
		exito = exito and _resultados[id]
	print("PRUEBA DESCRIPCION HABILIDADES NO ATAQUE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
