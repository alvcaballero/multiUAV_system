# CLAUDE.md

Las instrucciones del proyecto están en AGENTS.md (compartidas con otros agentes). Se importan aquí:

@AGENTS.md

## Solo para Claude Code

- El plan vivo es `docs/plans/environments.md`: al retomar, leé "Para retomar" y el estado antes de proponer nada.
  Al cerrar un paso, actualizá ahí el estado, las decisiones nuevas (numeradas, con "Confirmado por el usuario") y las
  trampas que hayas verificado.
- Decisiones que cambian el diseño (versiones de contrato, qué entra en una imagen, cómo se comparte código): preguntá
  al usuario con evidencia y una recomendación; no las tomes solo.
- Comandos largos (builds, `rosdep` real en un contenedor de prueba): en segundo plano, y seguí verificando lo demás.
