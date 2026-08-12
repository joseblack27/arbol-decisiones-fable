extends Node


class Inventario:
	enum TipoItem {
		NINGUNO,
		TODOS,
		CONSUMIBLE,
		EQUIPABLE,
		RECURSO,
		MISION,
		ARMA,
		## Ítem especial que desbloquea una pasiva de GATILLO al usarse (ver
		## DatosItem.escena_pasiva / PasivasComponente). Tipo propio, no
		## CONSUMIBLE: así no se puede "apilar como poción" por error si
		## can_use queda mal configurado.
		PASIVA
	}

	enum TipoItemEquipable {
		NINGUNO,
		CASCO,
		CUERPO,
		PANTALON,
		BOTAS,
		AMULETO,
		ANILLO,
		CINTURON,
		ARMA,
		ESCUDO
	}

class Habilidad:
	enum TipoDano {
		TIERRA,
		FUEGO,
		FISICO,
		AGUA,
		AIRE
	}

	## Rol de la habilidad — usado por PanelDetalleHabilidad.gd para mostrar
	## solo la información relevante (daño/tipo/rango no significan nada en
	## una habilidad que no ataca, p. ej. un buff o un muro que solo bloquea:
	## mostraban "Daño: 0-0" sin sentido, reportado por el usuario).
	enum Categoria {
		ATAQUE,       ## Inflige daño real — muestra daño/tipo/rango.
		DEFENSA,      ## Protege (escudo, parpadeo para escapar...).
		POTENCIADOR,  ## Buff propio o de aliados (curación, grito de guerra...).
		CONTROL,      ## Inmoviliza/arrastra sin dañar (red, gancho...).
	}

	## Campos "conceptuales" que una habilidad puede tener configurados para
	## crecer con el nivel de mejora (ver HabilidadBase._nombre_campo_escalable
	## / MejorasComponente / EscaladoHabilidad) — el enum evita errores de
	## tipeo al elegir qué escalar; la traducción al nombre REAL de la
	## propiedad vive en cada script de habilidad, porque distintas
	## habilidades usan distintos nombres para "lo mismo" (alcance_maximo,
	## alcance_golpe, distancia_parpadeo... todas son "rango").
	enum CampoEscalable {
		DANO_MIN,
		DANO_MAX,
		RECARGA,
		COSTO_ENERGIA,
		RANGO,
		RADIO,
		DURACION_EFECTO,
		PORCENTAJE_EFECTO,
	}

	## Bonos de combate escalables por nivel de mejora (ver CampoEscalado.
	## campo_atributo/HabilidadBase._nombre_campo_atributo) — a diferencia de
	## CampoEscalable de arriba, ACÁ el nombre real de la propiedad es FIJO
	## y GLOBAL (no hace falta un override por habilidad): cualquier
	## habilidad que quiera escalar uno de estos tiene que nombrar su propio
	## campo EXACTO así (bono_potencia, bono_probabilidad_critico,
	## bono_dano_critico, bono_dano — este último ya es el nombre real que
	## usa HabilidadBuffEquipo). NINGUNO=0 a propósito: es el default de
	## cualquier CampoEscalado que no lo use, y tiene que significar
	## "no aplica" para no pisar por accidente el CampoEscalable viejo.
	enum AtributoEscalable {
		NINGUNO,
		DANOS,
		POTENCIA,
		PROBABILIDAD_CRITICO,
		DANO_CRITICO,
	}

	## Color (nombre CSS o hex) para mostrar el daño de cada elemento en la
	## descripción de una habilidad — ver PanelDetalleHabilidad.gd. Un solo
	## enum de elemento (TipoDano) para gameplay Y color: antes había un
	## ColorDano aparte con el MISMO elemento en un ORDEN distinto (FISICO
	## en la posición 4 acá, 2 en TipoDano) — un enum totalmente redundante,
	# sin usarse en ningún otro lado, que solo invitaba a mezclar los
	## índices de uno con el otro por error.
	const valor_color_dano := {
		TipoDano.TIERRA: "#905010",
		TipoDano.FUEGO: "red",
		TipoDano.AGUA: "#00c4ff",
		TipoDano.AIRE: "#008f39",
		TipoDano.FISICO: "ghostwhite"
	}

class Evento:
	enum Tipo {
		JEFE_MUNDIAL,
		MAZMORRA,
		INVASION,
		CAMBIO_MUNDIAL,
		FACCION
	}

	enum Estado {
		PROXIMO,
		ACTIVO,
		COMPLETADO,
		FALLIDO,
		CANCELADO
	}

class Mision:
	enum Tipo {
		HISTORIA,
		SECUNDARIA,
		EVENTO,
		DIARIA
	}

	enum Estado {
		BLOQUEADA,
		DISPONIBLE,
		EN_PROGRESO,
		COMPLETADA,
		FALLIDA
	}

	## Qué acredita cada objetivo de una misión (ver DatosObjetivoMision) —
	## MATAR/RECOLECTAR se acreditan solos (Enemigo._notificar_objetivo_
	## matar / InventarioComponente.agregar_item), HABLAR se completa al
	## elegir la opción de diálogo correspondiente (ver Enums.Dialogo.Accion).
	enum TipoObjetivo {
		MATAR,
		RECOLECTAR,
		HABLAR
	}

	## static: antes era un método de instancia de una clase interna, lo
	## que en la práctica lo volvía imposible de llamar (Enums.Mision no
	## es una instancia, es la clase interna misma) — nadie lo usaba.
	static func get_type_text(tipo: Mision.Tipo) -> String:
		match tipo:
			Mision.Tipo.HISTORIA: return "Historia"
			Mision.Tipo.SECUNDARIA: return "Secundaria"
			Mision.Tipo.EVENTO: return "Evento"
			Mision.Tipo.DIARIA: return "Diaria"
		return "-"

class Dialogo:
	## Qué dispara una opción de diálogo (ver OpcionDialogo.accion) — además
	## de avanzar a siguiente_linea, una opción puede abrir la tienda del NPC
	## o aceptar/entregar una de sus misiones ofrecidas. 100% data-driven: no
	## hace falta código propio por NPC para estos casos comunes.
	enum Accion {
		NINGUNA,
		ABRIR_TIENDA,
		ACEPTAR_MISION,
		ENTREGAR_MISION,
		CERRAR
	}

	## Bajo qué estado de una misión se muestra una opción (ver
	## OpcionDialogo.condicion/mision_condicion) — para que un NPC no
	## ofrezca "tengo una misión para vos" si ya la diste, ni "ya me
	## encargué" antes de haber cumplido los objetivos de verdad.
	enum CondicionMision {
		SIEMPRE,               ## Sin condición — no mira ninguna misión.
		NO_ACEPTADA,           ## Nunca se aceptó (ni está en progreso ni completada).
		EN_PROGRESO,           ## Aceptada, pero con objetivos todavía sin cumplir.
		LISTA_PARA_ENTREGAR,   ## Aceptada Y todos los objetivos ya cumplidos.
		COMPLETADA,            ## Ya se completó (no repetible, o repetible recién terminada).
	}

	## Ícono que acompaña el texto de una opción (ver OpcionDialogo.
	## categoria y PanelDialogo._ICONOS_CATEGORIA) — puramente visual, no
	## afecta a condicion/accion. Pedido explícito del usuario para poder
	## reconocer de un vistazo qué tipo de opción es cada botón. Agregar
	## SIEMPRE al final: el valor numérico ya está guardado en los .tres
	## de contenido (ver ejemplo_comerciante.tres), insertar en el medio
	## correría esos índices y cambiaría el ícono de opciones existentes.
	enum CategoriaOpcion {
		NINGUNA,        ## Sin ícono.
		MISION,         ## "!" — ofrece una misión nueva.
		MISION_HABLAR,  ## "?" — hablar sobre una misión ya aceptada (en curso o lista para entregar).
		MERCADO,        ## "$" — abre la tienda.
		HABLAR,         ## Burbuja de chat — diálogo/lore genérico, sin misión de por medio.
		VOLVER,         ## Opción de volver/salir/rechazar (ej. "Ahora no", "Nada, gracias").
		ACEPTAR,        ## Aceptar una misión ofrecida (ej. "Acepto").
	}

class ColorInterfaz:
	enum UI {
		VERDE_FLUORESCENTE,
		BLANCO_FONDO,
		BLANCO_LINEA,

		NEGRO,
		AZUL,
		CIAN,
		VERDE,
		PURPURA,
		ROJO,
		BLANCO,
		AMARILLO,
		NEGRO_BRILLANTE,
		AZUL_BRILLANTE,
		CIAN_BRILLANTE,
		VERDE_BRILLANTE,
		PURPURA_BRILLANTE,
		ROJO_BRILLANTE,
		BLANCO_BRILLANTE,
		AMARILLO_BRILLANTE
	}

	const valor_color_ui := {
		UI.VERDE_FLUORESCENTE: "38ff14",
		UI.BLANCO_FONDO: "f0f0f0",
		UI.BLANCO_LINEA: "eaeaea10",

		UI.NEGRO: "0C0C0C",
		UI.AZUL: "0037DA",
		UI.CIAN: "3A96DD",
		UI.VERDE: "13A10E",
		UI.PURPURA: "881798",
		UI.ROJO: "C50F1F",
		UI.BLANCO: "CCCCCC",
		UI.AMARILLO: "C19C00",
		UI.NEGRO_BRILLANTE: "767676",
		UI.AZUL_BRILLANTE: "3B78FF",
		UI.CIAN_BRILLANTE: "61D6D6",
		UI.VERDE_BRILLANTE: "16C60C",
		UI.PURPURA_BRILLANTE: "B4009E",
		UI.ROJO_BRILLANTE: "E74856",
		UI.BLANCO_BRILLANTE: "F2F2F2",
		UI.AMARILLO_BRILLANTE: "F9F1A5"
	}
