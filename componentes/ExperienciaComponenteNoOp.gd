extends Node
class_name ExperienciaComponenteNoOp
## Hijo nombrado exactamente "ExperienciaComponente" de un NPC no-jugador
## que caza de verdad (ver Cazador.gd) — sin esto, Enemigo._otorgar_xp()
## (busca ese nombre por convención, ver Enemigo.gd) no lo encontraría y
## caería al facade GestorExperiencia.agregar_xp(), pensado para "el único
## jugador local": un mob cazado por el NPC le regalaría XP a cualquier
## jugador que esté de host. Este no-op corta ese fallback sin tocar
## Enemigo.gd.

func agregar_xp(_cantidad: int) -> void:
	pass
