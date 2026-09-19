extends Node

#region Documentación

### Emisor

## - Registrar
#	SeñalManager.registrar(str("nombre_señal_",signal_id), signal_id, {"nombre": tipo_variable})

## - Emitir
#	SeñalManager.emitir(str("nombre_señal_",signal_id), signal_id, [valor])

### Receptor

## - Conectar
#	SeñalManager.conectar(str("nombre_señal",get_instance_id()), self, "funcion_receptor")

## - Función para recibir la señal
#	func funcion_receptor(parametros):

#endregion

var registros = {}
## Pedidos de conectar() que llegaron ANTES de que su señal existiera
## todavía — nombre -> Array[{suscriptor, metodo}]. Se resuelven solos en
## cuanto llega el registrar() correspondiente (ver ese método). Sin esto,
## el ORDEN en que corre _ready() de cada nodo importaba: un suscriptor
## que intentaba conectarse antes de que alguien más registrara esa señal
## fallaba EN SILENCIO para siempre (printerr nada más) — bug real
## reportado (19 sep 2026, probado en celular): "la segunda página de
## habilidades detectaba el toque pero no lanzaba la habilidad". Jugador/
## IndicadorApunte se conectan a slot_5.._9_lanzar/apunte desde su propio
## _ready() esperando que ALGÚN UIHabilidad ya los haya registrado (ver
## PaginadorHabilidades.registrar_indices_adicionales) — si el Jugador
## corría primero, esa conexión se perdía para siempre y ningún cambio de
## página futuro la reparaba.
var _pendientes: Dictionary = {}

## Sobrescribe en vez de rechazar una segunda registración del mismo
## nombre: cada nombre pertenece a un solo jugador/UI LOCAL a la vez, así
## que si ya había una registración previa, quien la puso ya no existe de
## verdad — es la UI de una partida ANTERIOR liberada al perder la conexión
## (ver Mundo._al_perder_conexion -> reload_current_scene, que crea un
## Joystick/UIHabilidad totalmente nuevo con su propio signal_id). Antes
## esto rechazaba la registración nueva con "ya esta registrada" y dejaba
## el id VIEJO para siempre: emitir() comparaba contra ese id viejo ("no
## coincide con la señal registrada") y silenciaba el joystick y las
## habilidades enteras después de cualquier reconexión (reportado en juego
## real, justo tras varias reconexiones seguidas al servidor).
func registrar(nombre: String, id: String, args: Dictionary = {}):
	registros[nombre] = {
		"args": args,
		"suscriptores": {},
		"id": id
	}
	# Resolver acá cualquier conectar() que haya llegado antes que este
	# registrar() (ver _pendientes) — el orden de _ready() entre el
	# suscriptor y quien registra ya no importa.
	if _pendientes.has(nombre):
		for pedido in _pendientes[nombre]:
			if is_instance_valid(pedido.suscriptor):
				conectar(nombre, pedido.suscriptor, pedido.metodo)
		_pendientes.erase(nombre)

func eliminar(nombre: String):
	if registros.has(nombre):
			registros.erase(nombre)
	else:
		printerr("Señal '%s' no esta registrada" % nombre)

func conectar(nombre: String, suscriptor: Variant, metodo: String):
	if registros.has(nombre):
		if not registros[nombre].suscriptores.has(suscriptor):
			registros[nombre].suscriptores[suscriptor] = metodo
		else:
			printerr("Suscriptor '%s' ya esta conectado a la señal '%s'" % [suscriptor, nombre])
	else:
		# Todavía nadie llamó registrar() para este nombre -- guardar el
		# pedido para cuando llegue (ver _pendientes/registrar()) en vez de
		# perderlo para siempre. Normal al arrancar (el orden entre _ready()
		# de distintas ramas del árbol no está garantizado), no un error.
		var lista: Array = _pendientes.get(nombre, [])
		lista.append({"suscriptor": suscriptor, "metodo": metodo})
		_pendientes[nombre] = lista

func desconectar(nombre: String, suscriptor: Object):
	if registros.has(nombre):
		if registros[nombre].suscriptores.has(suscriptor):
			registros[nombre].suscriptores.erase(suscriptor)
		else:
			printerr("Suscriptores '%s' no estan conectados a la señal '%s'" % [suscriptor, nombre])
	else:
		printerr("Señal '%s' no esta registrada" % nombre)

func emitir(nombre: String, id: String, args: Array = []):
	if registros.has(nombre):

		if id != "" and id != registros[nombre].id:
			printerr("Señal '%s' no coincide con la señal registrada" % nombre)
			return

		var arg_tipos = registros[nombre].args
		if arg_tipos.size()!= args.size():
			printerr("Número de argumentos incorrectos para la señal '%s'" % nombre)
			return

		# Este bus es global (dura toda la partida) y sus suscriptores suelen
		# ser nodos con ciclo de vida propio (p. ej. un Jugador que se
		# desconecta en red) — si alguno se libera sin llamar a
		# desconectar(), quedaba como referencia colgante: llamar a
		# has_method()/callv() sobre un Object ya liberado revienta con
		# "Nonexistent function/base 'null instance'". is_instance_valid()
		# filtra esos casos, y de paso los limpia del registro.
		var muertos := []
		for suscriptor in registros[nombre].suscriptores:
			if not is_instance_valid(suscriptor):
				muertos.append(suscriptor)
				continue
			var metodo = registros[nombre].suscriptores[suscriptor]
			if suscriptor.has_method(metodo):
				suscriptor.callv(metodo, args)
			else:
				printerr("Suscriptor '%s' no tiene el metodo '%s'" % [suscriptor, metodo])
		for suscriptor in muertos:
			registros[nombre].suscriptores.erase(suscriptor)
	else:
		printerr("Señal '%s' no registrada" % nombre)
