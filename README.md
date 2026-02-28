# TheBackrooms

Proyecto en Godot.

## Requisitos

- Godot 4.x (detectado en este proyecto: 4.6.1)
- Git
- (Opcional) Python 3.14+ para usar `godot-mcp`

## Arranque rápido

1. Clona el repositorio y entra a la carpeta.
2. Abre el proyecto con Godot (`project.godot`).
3. Ejecuta la escena principal desde el editor.

## MCP de Godot (opcional)

Este proyecto ya incluye configuración MCP en `.vscode/mcp.json` para usar el servidor `godot-mcp` con VS Code.

Si necesitas reinstalarlo:

1. Crea/activa `.venv`.
2. Instala `godot-mcp`:
   - `python -m pip install godot-mcp`
3. Verifica el ejecutable de Godot:
   - `which godot`

## Flujo de ramas

- Rama por defecto: `dev`
- Rama protegida: `main`
- Todo cambio debe entrar por Pull Request (PR) hacia `main`

## Flujo recomendado

1. Actualiza `dev`:
   - `git checkout dev`
   - `git pull`
2. Crea una rama de trabajo desde `dev`:
   - `git checkout -b feature/nombre-cambio`
3. Haz commits y sube tu rama:
   - `git add .`
   - `git commit -m "Descripción corta"`
   - `git push -u origin feature/nombre-cambio`
4. Abre PR de `feature/*` hacia `main`.

## Comandos útiles

- Ver ramas: `git branch -a`
- Ver estado: `git status`
- Traer cambios remotos: `git fetch --all --prune`
- Ejecutar MCP manualmente: `.venv/bin/python -m godot_mcp.server`

## Estructura base

- `scenes/`: escenas de juego
- `scripts/`: lógica de gameplay y sistemas
- `autoloads/`: singletons globales
- `assets/`: materiales, sonidos y texturas
- `.github/`: plantillas de colaboración
