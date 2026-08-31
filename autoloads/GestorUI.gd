extends Node

enum Modo { JUEGO, OS, DIALOGO, CHAT }

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

## Chat expandido (PanelChat) — sin esto, tocar el cuadro de texto/botón
## Enviar del chat también le llegaba al joystick de atrás: ComponenteToque
## escucha _input() global sin ningún filtro de qué UI está encima (ver ese
## script), así que el único freno real del proyecto es este modo +
## ControlJuego (desactiva el subárbol del joystick/slots de habilidad
## mientras el modo no sea JUEGO) — mismo mecanismo que ya usan Diálogo/OS,
## reportado por el usuario: "al abrir el chat, el joystick de atrás
## también recibe el click".
func abrir_chat() -> void:
	if modo_actual == Modo.CHAT:
		return
	modo_actual = Modo.CHAT
	modo_cambiado.emit(Modo.CHAT)

func cerrar_chat() -> void:
	if modo_actual != Modo.CHAT:
		return
	modo_actual = Modo.JUEGO
	modo_cambiado.emit(Modo.JUEGO)

func es_juego() -> bool:
	return modo_actual == Modo.JUEGO
