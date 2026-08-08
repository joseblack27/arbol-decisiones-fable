extends Node
## Cuentas por nombre+PIN — separado de GestorGuardado.gd (la PERSISTENCIA
## en sí, guardar/cargar datos) porque resolver QUIÉN es un jugador es un
## concepto distinto de guardar SUS datos, aunque los dos compartan la
## misma conexión SQLite del servidor (ver GestorGuardado._bd_red()).

var _tabla_lista := false


## Crea la tabla "cuentas" la primera vez que hace falta — separada de la
## tabla "partidas" (esa la crea GestorGuardado._bd_red(), que es quien
## abre la conexión).
func _asegurar_tabla(bd) -> void:
	if _tabla_lista:
		return
	_tabla_lista = true
	# Cuentas por nombre+PIN: mapean un nombre a un id_unico FIJO, para que
	# la partida siga al NOMBRE y no al dispositivo (cambiar de celular o
	# reinstalar ya no pierde el progreso — ver resolver_cuenta). El PIN
	# nunca se guarda en claro, solo su hash.
	bd.query("""
		CREATE TABLE IF NOT EXISTS cuentas (
			nombre TEXT PRIMARY KEY,
			pin_hash TEXT NOT NULL,
			id_unico TEXT NOT NULL,
			creada TEXT NOT NULL
		);
	""")


## SERVIDOR: resuelve qué id_unico le corresponde a un jugador que se
## presenta con nombre+PIN (ver Jugador._registrar_identidad_red):
##   - Nombre nuevo  → crea la cuenta ligada al id del DISPOSITIVO actual
##     (así el progreso que ya tenía en este aparato queda adoptado por la
##     cuenta) y devuelve ese id.
##   - Nombre existente + PIN correcto → devuelve el id_unico de la cuenta:
##     la partida sigue al nombre, venga del dispositivo que venga.
##   - Nombre existente + PIN incorrecto → devuelve "" (rechazo).
## Con PIN vacío no se llama a esto — comportamiento clásico por
## dispositivo, sin cuenta (ver Jugador._registrar_identidad_red).
func resolver_cuenta(nombre: String, pin: String, id_dispositivo: String) -> String:
	var bd = GestorGuardado._bd_red()
	if bd == null:
		return id_dispositivo  # sin BD no hay cuentas: caer al modo clásico.
	_asegurar_tabla(bd)
	var clave := _normalizar_nombre_cuenta(nombre)
	if clave == "":
		return id_dispositivo
	var hash_pin := _hash_pin(clave, pin)
	bd.query_with_bindings("SELECT pin_hash, id_unico FROM cuentas WHERE nombre = ?;", [clave])
	if bd.query_result.is_empty():
		bd.query_with_bindings(
			"INSERT INTO cuentas (nombre, pin_hash, id_unico, creada) VALUES (?, ?, ?, ?);",
			[clave, hash_pin, id_dispositivo, Time.get_datetime_string_from_system(true)]
		)
		print("[CUENTAS] creada '%s' -> %s" % [clave, id_dispositivo])
		return id_dispositivo
	var fila: Dictionary = bd.query_result[0]
	if str(fila["pin_hash"]) != hash_pin:
		print("[CUENTAS] PIN incorrecto para '%s'" % clave)
		return ""
	return str(fila["id_unico"])


func _normalizar_nombre_cuenta(nombre: String) -> String:
	var limpio := ""
	for c in nombre.strip_edges().to_lower():
		var seguro: bool = (c >= "a" and c <= "z") or (c >= "0" and c <= "9") \
			or c == "_" or c == "-"
		if seguro:
			limpio += c
	return limpio.substr(0, 24)


func _hash_pin(nombre: String, pin: String) -> String:
	# Sal fija + nombre en el hash: el mismo PIN en dos cuentas distintas
	# produce hashes distintos (no delata PINs repetidos entre filas).
	return ("gorpg|%s|%s" % [nombre, pin]).sha256_text()
