# Regresion de carga 5.0.2

Agente: Codex. Equipo: BOG085CD119BDQN. 2026-09-13 11:02 America/Bogota.

Ejecutar SOLO en un dibujo vacio de laboratorio: el harness sustituye el
creador de anden por un testigo para comprobar el enlace C:ANDEN sin DCL.
No valida geometria, tiempos E2E, ribbon ni terreno.

En SCR fijar URB_LOAD_TEST_PATH al LSP que se quiere verificar (la entrega
INSTALADA, no baseline) y URB_LOAD_TEST_OUT a un resultado local nuevo.
Cargar este verify.lsp y salir sin guardar. Mantener el limite de 60 s de
TESTING_CIVIL3D.md; no usar el documento del usuario.

Resultado reproducido antes: instalado 5.0.1 -> LOAD_ERROR malformed list
on input; ANDEN_TYPE nil y RAMPA_TYPE nil, aunque ENGINE dice 5.0.1.
Despues: instalado 5.0.2, Core Console 2023 y 2024 -> LOAD_OK,
ANDEN_TYPE SUBR, RAMPA_TYPE SUBR, ANDEN_DISPATCH OK, PURGE_EMPTY_DRAWING 0.
2021: File load canceled al cargar harness (seguridad), sin resultado.
2025/2026: no disponibles en esta maquina. No afirmar compatibilidad total.

Logs locales: Documents/URBANISMO/work/carga502. SHA256 motor instalado=repo:
ver hash registrado en PROGRESS/handoff o recalcular sobre ambos archivos.
