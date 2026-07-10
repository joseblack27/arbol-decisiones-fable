# Servidor dedicado headless del JUEGO REAL (ver escenas/mundo/ServidorDedicado.gd/.tscn).
# Corre el binario del editor de Godot directo contra el código fuente con
# --headless — no hace falta exportar un .pck.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.5.1-stable
ENV GODOT_VERSION=${GODOT_VERSION}

# El binario de Godot (aun en --headless) sigue enlazando dinámicamente
# contra estas libs gráficas/de audio al arrancar, aunque nunca las use de
# verdad — sin ellas falla con "libfontconfig.so.1: cannot open shared
# object file" antes de imprimir nada.
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget unzip ca-certificates \
        libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 \
        libxrandr2 libxrender1 libgl1 libglu1-mesa libasound2 libpulse0 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

WORKDIR /proyecto
COPY . .

# addons/ (godot_ai — el puente MCP de depuración local del editor) NUNCA
# debe correr en el servidor dedicado: .dockerignore ya excluye la carpeta
# entera del build, pero project.godot todavía la referencia como autoload
# GLOBAL (corre en cualquier proceso del juego, no solo en el editor) — sin
# borrar también esa línea, el servidor fallaría buscando un script que no
# está en la imagen. El bloque [editor_plugins] es inofensivo en runtime
# (solo aplica al abrir el editor), pero se borra igual por prolijidad.
RUN sed -i '/_mcp_game_helper=/d' project.godot \
    && sed -i '/\[editor_plugins\]/,+2d' project.godot

# "Calentar" el proyecto: importar TODOS los assets y generar la caché de
# clases globales (.godot/global_script_class_cache.cfg) — sin esto, cada
# class_name (DatosItem, HabilidadBase, NivelBase...) falla con "Could not
# find type", y cada textura/ícono sin importar revienta con "Unable to
# open file: .godot/imported/....ctex". --import espera a que la
# importación completa termine antes de salir solo (a diferencia de
# --editor --quit-after N, que corta a los N fotogramas sin esperar).
RUN godot --headless --import --path /proyecto || true

# Puerto ENet del juego real (ver Utils.PUERTO_JUEGO).
EXPOSE 8920/udp

CMD ["godot", "--headless", "--path", "/proyecto", "res://escenas/mundo/ServidorDedicado.tscn"]
