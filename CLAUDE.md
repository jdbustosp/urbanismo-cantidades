# Proyecto: URBANISMO EXTERNO (AutoLISP / Civil 3D + Presupuesto de obra)

Plugin de cantidades de urbanismo para Civil 3D: `urbanismo_cantidades.lsp` (motor AutoLISP)
+ `bundle\` (ribbon .NET, manifiesto, iconos). Repo git: `jdbustosp/urbanismo-cantidades` (GitHub).

## Migración 2026-08-14
Este proyecto vivía en `VARIOS\BLOQUES PPTOS\CANTIDADES\` con el `.git` separado en
`REPOSITORIO CODIGOS\urbanismo-cantidades\`. Ahora TODO vive aquí, con `.git` normal dentro.
El LSP legado `MAIPORE_BLOQUES_REDES_ELECT_...lsp` sigue en `VARIOS\BLOQUES PPTOS\` (no es de este repo).

## Cómo carga Civil 3D (importante)
- Civil 3D NO carga desde esta carpeta: carga el bundle instalado en
  `%AppData%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle` (local por máquina).
- Tras editar el lsp/DLL: correr `INSTALAR.bat` (o `instalar_bundle.ps1`) y reiniciar Civil 3D.
- En un PC nuevo o tras esta migración: correr `INSTALAR.bat` una vez; si el Startup Suite
  apuntaba a la ruta vieja de BLOQUES PPTOS, quitarlo y depender solo del bundle.

## Documentos clave
- `PROGRESS.md` — bitácora completa del desarrollo (leerla antes de retomar).
- `TESTING_CIVIL3D.md` — metodología de verificación headless (work/<tema>/, invariantes de
  área, peor caso, PDFs solo a carpeta temporal, nunca a Drive).

## Convenciones
- Namespaces `urb:` / `mp:`. Releer el `.lsp` antes de editar (puede haber cambios externos).
- Integrar funciones nuevas en comandos existentes, no crear comandos nuevos.
- No bloquear Civil 3D en primer plano al verificar.
- Versionar: bump de `*urb-version*` en cada entrega + commit con mensaje `vX.Y.Z: descripción`.

## Flujos de trabajo del proyecto
1. **LSP / Civil 3D**: el desarrollo del plugin (este repo).
2. **Presupuesto de obra (Excel)**: se trabaja en chats separados dentro de este mismo
   proyecto; sus archivos van en `presupuesto\`. Contexto en la memoria
   `diseno-ppto-detallado-ejecutado-detallado`.

## Esquema CLAUDE (multi-PC)
- Memoria compartida: `..\..\memoria\URBANISMO EXTERNO\` (junction por PC; bloque de
  conexión en `..\..\README.md`).
- Handoff entre computadores: `..\..\handoffs\urbanismo-externo.md` — es el ÚNICO archivo
  de continuidad del proyecto (estado actual, qué se consiguió, pendientes, cómo retomar
  en otro PC). **Actualizarlo EN CADA momento en que se consiga o implemente algo** (una
  versión nueva, un hallazgo, un cambio de rumbo) — no esperar al cierre de la sesión ni
  acumular varios logros para documentarlos juntos al final. Si la sesión se corta a medio
  camino, el handoff debe reflejar hasta dónde se llegó igual. No fragmentar esta bitácora
  en otros archivos de memoria — todo el resumen de continuidad vive ahí; `PROGRESS.md`
  sigue aparte como el changelog técnico git-tracked (un commit por versión), pero no
  reemplaza al handoff para retomar el hilo.
