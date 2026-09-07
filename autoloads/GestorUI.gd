extends Node

enum Modo { JUEGO, OS, DIALOGO, CHAT }

signal modo_cambiado(modo: int)

var modo_actual: int = Modo.JUEGO

## A qué modo volver al cerrar OS/DIALOGO — normalmente JUEGO, pero si el
## chat ya estaba abierto (modo CHAT) antes de que OS/DIALOGO lo tapara, hay
## que volver a CHAT, no a JUEGO. Sin esto, abrir el chat, después abrir y
## cerrar el panel OS reactivaba el joystick de movimiento aunque el panel
## de chat siguiera visible encima suyo — cerrar_os()/cerrar_dialogo()
## forzaban JUEGO a ciegas, sin saber que venían de CHAT (reportado: "abro
## el chat, abro y cierro OS, y el joystick que queda detrás del chat
## recibe el click otra vez"). Se guarda al ABRIR (nunca se pisa con OS/
## DIALOGO mismos, por si alguna vez se anidaran) y se restaura al CERRAR,
## en vez de forzar JUEGO directo.
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
