extends Node

#region Documentación

### Emisor

## - Registrar
#	SignalManager.registrar(str("nombre_señal_",signal_id), signal_id, {"nombre": tipo_variable})

## - Emitir
#	SignalManager.emitir(str("nombre_señal_",signal_id), signal_id, [valor])

### Receptor

## - Conectar
#	SignalManager.conectar(str("nombre_señal",get_instance_id()), self, "funcion_receptor")

## - Función para recibir la señal
#	func funcion_receptor(parametros):

#endregion

var registros = {}

func registrar(nombre: String, id: String, args: Dictionary = {}):
	if not registros.has(nombre):
		registros[nombre] = {
			"args": args,
			"suscriptores": {},
			"id": id
		}
	else:
		printerr("Señal '%s' ya esta registrada" % nombre)

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
		printerr("Señal '%s' no esta registrada" % nombre)

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
