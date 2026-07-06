extends Node

enum Modo { JUEGO, OS }

signal modo_cambiado(modo: int)

var modo_actual: int = Modo.JUEGO

func abrir_os() -> void:
	if modo_actual == Modo.OS:
		return
	modo_actual = Modo.OS
	modo_cambiado.emit(Modo.OS)

func cerrar_os() -> void:
	if modo_actual == Modo.JUEGO:
		return
	modo_actual = Modo.JUEGO
	modo_cambiado.emit(Modo.JUEGO)

func es_juego() -> bool:
	return modo_actual == Modo.JUEGO
