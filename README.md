# TheBackrooms

Proyecto en Godot.

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
