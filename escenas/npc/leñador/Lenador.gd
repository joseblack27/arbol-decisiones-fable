extends "res://escenas/npc/NpcErrante.gd"
class_name Lenador
## NPC autónomo: sale de la Ciudad, camina hasta la Pradera, corta el árbol
## disponible más cercano, vuelve a la Ciudad y deposita la madera en el
## almacén compartido (ver GestorLenador.gd). Los mobs no lo atacan y las
## habilidades no chocan con él (ver NpcAutonomo.gd).
##
## Cruza entre la Ciudad y la Pradera como un jugador (ver NpcErrante.gd).
## Ciudad y Pradera además se mantienen siempre activas (ver
## GestorNiveles.mantener_siempre_activo, llamado desde GestorLenador).

const _ESPERA_EN_CASA := 4.0
const _ESPERA_SIN_ARBOL := 3.0

const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"

enum Estado {
	ESPERANDO_CASA,          # en Ciudad: quieto un rato antes de salir
	YENDO_AL_PORTAL_CIUDAD,  # en Ciudad: caminando al portal para cruzar a Pradera
	BUSCANDO_ARBOL,          # en Pradera: eligiendo el árbol más cercano disponible
	ESPERANDO_ARBOL,         # en Pradera: no hay ninguno disponible, reintenta
	YENDO_AL_ARBOL,          # en Pradera: caminando al árbol elegido
	CORTANDO,                # en Pradera: acción instantánea de tala
	YENDO_AL_PORTAL_PRADERA, # en Pradera: caminando al portal para volver a Ciudad
	YENDO_AL_ALMACEN,        # en Ciudad: caminando al almacén a depositar
	DEPOSITANDO,             # en Ciudad: acción instantánea de depósito
}

var _estado: int = Estado.ESPERANDO_CASA
var _espera_restante: float = 0.0
var _arbol_objetivo: ObjetoRecolectable = null
var _carga_actual: DatosItem = null

## Resueltos una sola vez en el servidor (ver _preparar_servidor): esta
## instancia vive fuera de los dos niveles, así que ninguno puede
## referenciarla con una ruta fijada en el editor.
var _nivel_ciudad: NivelBase
var _nivel_pradera: NivelBase
var _portal_ciudad: Node2D    # PortalAPradera, adentro de NivelCiudad
var _portal_pradera: Node2D   # PortalACiudad, adentro de NivelPradera
var _almacen_punto: AlmacenLenador
var _contenedor_arboles: Node


func _preparar_servidor() -> void:
	_nivel_ciudad = GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	_nivel_pradera = GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_PRADERA)
	if _nivel_ciudad:
		_portal_ciudad = _nivel_ciudad.get_node_or_null("PortalAPradera")
		_almacen_punto = _nivel_ciudad.get_node_or_null("Decoraciones/AlmacenLenador1")
	if _nivel_pradera:
		_portal_pradera = _nivel_pradera.get_node_or_null("PortalACiudad")
		_contenedor_arboles = _nivel_pradera.get_node_or_null("Decoraciones")

	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_CIUDAD)
	_estado = Estado.ESPERANDO_CASA
	_espera_restante = _ESPERA_EN_CASA


func _procesar_estado(delta: float) -> void:
	match _estado:
		Estado.ESPERANDO_CASA:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.YENDO_AL_PORTAL_CIUDAD

		Estado.YENDO_AL_PORTAL_CIUDAD:
			if _portal_ciudad == null:
				return
			movimiento.comandar_destino(_portal_ciudad.global_position)
			if movimiento.llego_al_destino(MARGEN_LLEGADA):
				_cruzar_a_pradera()
				_estado = Estado.BUSCANDO_ARBOL

		Estado.BUSCANDO_ARBOL:
			_arbol_objetivo = _recolectable_mas_cercano(_contenedor_arboles)
			if _arbol_objetivo == null:
				_espera_restante = _ESPERA_SIN_ARBOL
				_estado = Estado.ESPERANDO_ARBOL
			else:
				_estado = Estado.YENDO_AL_ARBOL

		Estado.ESPERANDO_ARBOL:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.BUSCANDO_ARBOL

		Estado.YENDO_AL_ARBOL:
			if _arbol_objetivo == null or not is_instance_valid(_arbol_objetivo) \
					or _arbol_objetivo.esta_agotado():
				_estado = Estado.BUSCANDO_ARBOL
				return
			movimiento.comandar_destino(_punto_de_interaccion(_arbol_objetivo))
			# El margen de llegada es el radio de interacción REAL del árbol (el
			# mismo con que el servidor acepta la recolección de un jugador, ver
			# ObjetoRecolectable._pedir_recolectar_red), y se usa
			# movimiento.llego_al_destino() en vez de comparar distancias: el centro
			# del área de interacción puede quedar pegado al tronco (no navegable) y
			# el agente nunca se acerca tanto; sin esto el leñador se quedaba
			# caminando en el lugar.
			if movimiento.llego_al_destino(_arbol_objetivo.radio_interaccion_servidor):
				movimiento.detener()
				_estado = Estado.CORTANDO

		Estado.CORTANDO:
			if _arbol_objetivo != null and is_instance_valid(_arbol_objetivo):
				_carga_actual = _arbol_objetivo.recolectar_para_npc()
			_arbol_objetivo = null
			_estado = Estado.YENDO_AL_PORTAL_PRADERA

		Estado.YENDO_AL_PORTAL_PRADERA:
			if _portal_pradera == null:
				return
			movimiento.comandar_destino(_portal_pradera.global_position)
			if movimiento.llego_al_destino(MARGEN_LLEGADA):
				_cruzar_a_ciudad()
				_estado = Estado.YENDO_AL_ALMACEN

		Estado.YENDO_AL_ALMACEN:
			if _almacen_punto == null:
				return
			movimiento.comandar_destino(_punto_de_interaccion(_almacen_punto))
			# Mismo motivo que YENDO_AL_ARBOL: el origen exacto del mueble
			# puede quedar pegado a su colisión sólida.
			if movimiento.llego_al_destino(_almacen_punto.radio_interaccion):
				movimiento.detener()
				_estado = Estado.DEPOSITANDO

		Estado.DEPOSITANDO:
			if _carga_actual != null:
				GestorLenador.depositar_servidor(_carga_actual)
				_carga_actual = null
			_espera_restante = _ESPERA_EN_CASA
			_estado = Estado.ESPERANDO_CASA


func _cruzar_a_pradera() -> void:
	_cruzar_a(_portal_pradera, _RUTA_PRADERA)


func _cruzar_a_ciudad() -> void:
	_cruzar_a(_portal_ciudad, _RUTA_CIUDAD)
