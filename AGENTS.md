# Instrucciones compartidas para este repositorio

Antes de trabajar, leer `CLAUDE.md`, `TESTING_CIVIL3D.md` y
`../../handoffs/urbanismo-externo.md`. Este ultimo es el unico resumen de
continuidad entre agentes y computadores; actualizarlo con avances verificables.

El usuario pide mantener el motor en `urbanismo_cantidades.lsp` y los cambios
en este repositorio. Revisar Git y releer el archivo antes de editar. No modificar
DWG/Excel vigentes como parte de una prueba. Usar fixtures locales en work/.
Documentar limites de validacion: un adaptador de prueba no equivale a ActiveX
real, ni la carga del LSP prueba los dialogos o los calculos contra terreno real.
Antes de entregar: comprobar version/manifiesto, pruebas pertinentes, commit
y push conforme al flujo existente. No sobrescribir trabajo externo.
