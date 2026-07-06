extends Node
class_name DecisionComponente

## --- Dependencias Externas ---
@export var maquina_de_estados_componente: MaquinaDeEstadosComponente
@export var vision_componente: VisionComponente
@export var vida_componente: VidaComponente
@export var movimiento_componente: MovimientoComponente
@export var entidad: Node2D

#@export var _arbol: ArbolComportamiento


func _ready() -> void:
	# Conectar las señales
	if vision_componente:
		vision_componente.objetivo_detectado.connect(_on_objetivo_detectado)
		vision_componente.objetivo_perdido.connect(_on_objetivo_perdido)
	
	#_arbol = ArbolComportamiento.new()
	#_arbol.agente = entidad
	#vida_componente.arbol_comportamiento = _arbol
	#add_child(_arbol)
	#call_deferred("_construir_arbol")


func _on_objetivo_detectado(_area: Area2D):
	#print("DecisionComponente: Objetivo detectado. Emitiendo señal para transición a Persecución.")
	#_arbol.obtener_pizarra().establecer("objetivo_cercano", _area)
	#_arbol._raiz.buscar_hijo("rama_supervivencia").activo = false
	maquina_de_estados_componente.cambiar_estado("EstadoPersigue")


func _on_objetivo_perdido(_area: Area2D):
	#_arbol.obtener_pizarra().establecer("objetivo_cercano", null)
	#_arbol._raiz.buscar_hijo("rama_supervivencia").activo = true
	#print("DecisionComponente: Objetivo perdido. El estado de IA debe reevaluar su comportamiento.")
	pass


#func _construir_arbol() -> void:
	#
	##region Pizarra
	#var piz: Pizarra = _arbol.obtener_pizarra()
	#
	#piz.establecer("vida_actual", vida_componente.obtener_vida() if vida_componente else 100.0)
	#piz.establecer("vida_maxima", vida_componente.obtener_vida_maxima() if vida_componente else 100.0)
	#piz.establecer("objetivo_cercano", null)
	#piz.establecer("distancia_objetivo", 0)
	##endregion
	#
	## ==============================================================================================
	#
	##region Rama Supervivencia
	### Rama para cuando la vida esta baja
	#var rama_supervivencia: Secuencia = Secuencia.new().agregar_varios([
		#AccEscribirConsola.new("Rama Supervivencia"),
		#CondVidaBaja.new(0.25), # Si vida < 25%
		#AccCambiarEstado.new("EstadoDeambular")
	#])
	#rama_supervivencia.nombre = "rama_supervivencia"
	##endregion
	#
	##region Rama Combate
	### Rama de combate
	#
	## Ataque a distancia (rango 150-300)
	#var rama_validar_ataque_distancia: Secuencia = Secuencia.new().agregar_varios([
		#CondEnRango.new(151.0, 300.0),
		##CondAtaqueDisponible.new(true),
		#Enfriamiento.new(10.0)
			##.decorar(AccAtacarDistancia.new(20.0, 20.0))
			#.decorar(AccEscribirConsola.new("Rama Validar Ataque a Distancia"))
	#])
	#rama_validar_ataque_distancia.nombre = "rama_validar_ataque_distancia"
	#
	## Ataque melee (rango < 150)
	#var rama_validar_ataque_melee: Secuencia = Secuencia.new().agregar_varios([
		#CondEnRango.new(0.0, 150.0),
		##CondAtaqueDisponible.new(true),
		#AccEscribirConsola.new("Rama Validar Ataque a Melee")
		##Enfriamiento.new(10.0)
			###.decorar(AccAtacarMelee.new(10.0,10.0))
			##.decorar(AccEscribirConsola.new("Rama Validar Ataque a Melee"))
	#])
	#rama_validar_ataque_melee.nombre = "rama_validar_ataque_melee"
	#
	## Combate (hay enemigo cerca)
	#var rama_combate: Secuencia = Secuencia.new().agregar_varios([
		#AccEscribirConsola.new("Rama Combate"),
		#CondEnemigoCerca.new(),
		#Selector.new().agregar_varios([
			#AccEscribirConsola.new("Rama Combate"),
			#rama_validar_ataque_distancia,
			#rama_validar_ataque_melee,
			##AccMoverHaciaObjetivo.new(movimiento_componente.velocidad_base, 130.0)
			##AccCambiarEstado.new("EstadoPersigue")
		#])
	#])
	#rama_combate.nombre = "rama_combate"
	##endregion
	#
	##region Rama Monitor Distancia Objetivo
	## Monitor Distancia Objetivo
	#
	#var rama_monitor_distancia_objetivo: Secuencia = Secuencia.new().agregar_varios([
		#AccEscribirConsola.new("Monitor"),
		#CondEnemigoCerca.new(),
		#AccActuDistanciaObjetivo.new()
	#])
	#rama_monitor_distancia_objetivo.nombre = "rama_monitor_distancia_objetivo"
	##endregion
	#
	##region Raiz
	#var raiz: Selector = Selector.new().agregar_varios([
		#rama_monitor_distancia_objetivo,
		#rama_supervivencia,
		#rama_combate
		##AccCambiarEstado.new("EstadoIdle")
	#])
	##endregion
	#
	#_arbol.establecer_raiz(raiz)
