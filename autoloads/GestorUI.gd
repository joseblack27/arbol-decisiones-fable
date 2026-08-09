extends Node

enum Modo { JUEGO, OS, DIALOGO }

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

## Diálogo con un NPC — GestorUI.Modo.DIALOGO desactiva la capa de juego
## igual que OS (ver ControlJuego.gd, reacciona genérico a "modo != JUEGO"),
## para que el jugador no pueda moverse ni pelear en medio de una
## conversación.
func abrir_dialogo() -> void:
	if modo_actual == Modo.DIALOGO:
		return
	modo_actual = Modo.DIALOGO
	modo_cambiado.emit(Modo.DIALOGO)

func cerrar_dialogo() -> void:
	if modo_actual != Modo.DIALOGO:
		return
	modo_actual = Modo.JUEGO
	modo_cambiado.emit(Modo.JUEGO)

func es_juego() -> bool:
	return modo_actual == Modo.JUEGO
