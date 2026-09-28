extends "res://escenas/npc/NpcErrante.gd"
class_name Minero
## NPC autónomo: pica el mineral disponible más cercano dentro de la mina y lo
## deposita en el almacén compartido (ver GestorMinero.gd). Mismo diseño que
## Lenador.gd, pero nunca cruza de nivel: mina y almacén viven los dos dentro
## de NivelMina.

const _ESPERA_ANTES_DE_PICAR := 2.0
const _ESPERA_SIN_VETA := 3.0

const _RUTA_MINA := "res://escenas/niveles/NivelMina.tscn"

enum Estado {
	BUSCANDO_VETA,       # eligiendo la veta más cercana disponible
	ESPERANDO_VETA,      # no hay ninguna disponible, reintenta
	YENDO_A_LA_VETA,     # caminando a la veta elegida
	PICANDO,             # acción instantánea de picar
	YENDO_AL_ALMACEN,    # caminando al almacén a depositar
	DEPOSITANDO,         # acción instantánea de depósito
}

var _estado: int = Estado.BUSCANDO_VETA
var _espera_restante: float = 0.0
var _veta_objetivo: ObjetoRecolectable = null
var _carga_actual: DatosItem = null

## Resueltos una sola vez en el servidor (ver _preparar_servidor).
var _almacen_punto: AlmacenMinero
var _contenedor_vetas: Node


func _preparar_servidor() -> void:
	var nivel_mina := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_MINA)
	if nivel_mina:
		_almacen_punto = nivel_mina.get_node_or_null("Decoraciones/AlmacenMinero1")
		_contenedor_vetas = nivel_mina.get_node_or_null("Decoraciones")

	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_MINA)
	_estado = Estado.BUSCANDO_VETA


func _procesar_estado(delta: float) -> void:
	match _estado:
		Estado.BUSCANDO_VETA:
			_veta_objetivo = _recolectable_mas_cercano(_contenedor_vetas)
			if _veta_objetivo == null:
				_espera_restante = _ESPERA_SIN_VETA
				_estado = Estado.ESPERANDO_VETA
			else:
				_estado = Estado.YENDO_A_LA_VETA

		Estado.ESPERANDO_VETA:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.BUSCANDO_VETA

		Estado.YENDO_A_LA_VETA:
			if _veta_objetivo == null or not is_instance_valid(_veta_objetivo) \
					or _veta_objetivo.esta_agotado():
				_estado = Estado.BUSCANDO_VETA
				return
			movimiento.comandar_destino(_punto_de_interaccion(_veta_objetivo))
			# Mismo motivo que Lenador.YENDO_AL_ARBOL: el radio de interacción
			# REAL de la veta, no una comparación de distancia a secas; el centro
			# exacto puede caer sobre el cuerpo sólido no navegable.
			if movimiento.llego_al_destino(_veta_objetivo.radio_interaccion_servidor):
				movimiento.detener()
				_estado = Estado.PICANDO

		Estado.PICANDO:
			if _veta_objetivo != null and is_instance_valid(_veta_objetivo):
				_carga_actual = _veta_objetivo.recolectar_para_npc()
			_veta_objetivo = null
			_estado = Estado.YENDO_AL_ALMACEN

		Estado.YENDO_AL_ALMACEN:
			if _almacen_punto == null:
				return
			movimiento.comandar_destino(_punto_de_interaccion(_almacen_punto))
			if movimiento.llego_al_destino(_almacen_punto.radio_interaccion):
				movimiento.detener()
				_estado = Estado.DEPOSITANDO

		Estado.DEPOSITANDO:
			if _carga_actual != null:
				GestorMinero.depositar_servidor(_carga_actual)
				_carga_actual = null
			_estado = Estado.BUSCANDO_VETA
