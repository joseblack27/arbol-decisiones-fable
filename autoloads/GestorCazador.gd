extends Node
## Instancia (una sola vez) el Cazador.tscn — ver Cazador.gd — que caza
## ratones a distancia en la Pradera y deposita el botín automáticamente en
## el almacén compartido del leñador (InventarioRedirectorAlmacen, ver
## Cazador.gd). Mucho más simple que GestorLenador.gd: sin diccionario
## propio, sin persistencia, sin RPC — el botín ya pasa directo por
## GestorLenador.depositar_servidor(), no hace falta ningún estado acá.
##
## Mismo criterio de "NPC errante" que GestorLenador — ver ese archivo para
## el porqué completo. Llama a los mismos métodos de GestorNiveles que ya
## llama GestorLenador (asegurar_nivel_cargado_servidor/mantener_siempre_
## activo) — es seguro/idempotente repetirlos: cada autoload garantiza sus
## propias precondiciones en vez de depender de que el otro haya corrido
## primero.

const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const _ESCENA_CAZADOR := preload("res://escenas/npc/cazador/Cazador.tscn")

var _preparado_servidor := false


## Mismo motivo que GestorLenador._ready(): este autoload arranca antes de
## que ServidorDedicado.gd exista, así que el setup real queda pospuesto
## al primer GestorNiveles.nivel_cargado.
func _ready() -> void:
	GestorNiveles.nivel_cargado.connect(_al_nivel_cargado)


func _al_nivel_cargado(_nivel: NivelBase) -> void:
	if _preparado_servidor or not Utils.en_red() or not multiplayer.is_server():
		return
	_preparado_servidor = true

	var nivel_ciudad := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_PRADERA)
	GestorNiveles.mantener_siempre_activo(_RUTA_CIUDAD)
	GestorNiveles.mantener_siempre_activo(_RUTA_PRADERA)

	var contenedor := GestorNiveles.contenedor_errantes()
	if contenedor and nivel_ciudad:
		var cazador := _ESCENA_CAZADOR.instantiate()
		contenedor.add_child(cazador)
		# "En casa" al arrancar: junto al portal de salida de Ciudad, mismo
		# criterio que GestorLenador con el Leñador.
		var portal := nivel_ciudad.get_node_or_null("PortalAPradera")
		if portal:
			cazador.global_position = portal.global_position
