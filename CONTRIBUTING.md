# Contribuir a TheBackrooms

## Flujo de trabajo

1. Parte siempre desde `dev` actualizado:
   - `git checkout dev`
   - `git pull`
2. Crea una rama de trabajo:
   - `git checkout -b feature/tu-cambio`
3. Haz cambios pequeños y commits claros.
4. Sube tu rama:
   - `git push -u origin feature/tu-cambio`
5. Abre PR hacia `main`.

## Convenciones rápidas

- Commits cortos y descriptivos.
- No subir archivos temporales del sistema.
- Mantener cambios enfocados (una idea por PR).
- Si tocas gameplay, deja pasos de prueba en la PR.

## Checklist antes de PR

- El proyecto abre en Godot sin errores nuevos.
- Se probaron los cambios clave en juego.
- La descripción de PR explica qué cambió y cómo probarlo.
