extends Node

enum Modo { JUEGO, OS, DIALOGO, CHAT }

signal modo_cambiado(modo: int)

var modo_actual: int = Modo.JUEGO

## A qué modo volver al cerrar OS o DIALOGO: normalmente JUEGO, pero si el
## chat ya estaba abierto (CHAT) antes de que lo taparan, hay que volver a
## CHAT; si no, el joystick de atrás volvía a recibir los toques con el chat
## todavía encima. Se guarda al ABRIR (nunca con OS/DIALOGO mismos, por si se
## anidaran) y se restaura al CERRAR.
var _modo_de_fondo: int = Modo.JUEGO

func abrir_os() -> void:
	if modo_actual == Modo.OS:
		return
	if modo_actual != Modo.OS and modo_actual != Modo.DIALOGO:
		_modo_de_fondo = modo_actual
	modo_actual = Modo.OS
	modo_cambiado.emit(Modo.OS)

func cerrar_os() -> void:
	if modo_actual == Modo.JUEGO:
		return
	modo_actual = _modo_de_fondo
	modo_cambiado.emit(modo_actual)

## Diálogo con un NPC — GestorUI.Modo.DIALOGO desactiva la capa de juego
## igual que OS (ver ControlJuego.gd, reacciona genérico a "modo != JUEGO"),
## para que el jugador no pueda moverse ni pelear en medio de una
## conversación.
func abrir_dialogo() -> void:
	if modo_actual == Modo.DIALOGO:
		return
	if modo_actual != Modo.OS and modo_actual != Modo.DIALOGO:
		_modo_de_fondo = modo_actual
	modo_actual = Modo.DIALOGO
	modo_cambiado.emit(Modo.DIALOGO)

func cerrar_dialogo() -> void:
	if modo_actual != Modo.DIALOGO:
		return
	modo_actual = _modo_de_fondo
	modo_cambiado.emit(modo_actual)

## Chat expandido (PanelChat). ComponenteToque escucha _input() global sin
## filtrar qué UI está encima, así que el único freno es este modo +
## ControlJuego (desactiva el joystick y los slots de habilidad mientras el
## modo no sea JUEGO), como con Diálogo y OS. Sin esto, tocar el cuadro de
## texto del chat también movía al jugador.
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
