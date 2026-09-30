# URBANISMO EXTERNO — manual del proyecto (Claude, Codex, Gemini)

Plugin de cantidades de urbanismo para Civil 3D (`urbanismo_cantidades.lsp` = motor AutoLISP;
`bundle\` = cinta .NET, manifiesto, iconos) + presupuesto de obra en Excel (`presupuesto\`).
Repo git: `jdbustosp/urbanismo-cantidades`. Instrucciones generales: `hub\INSTRUCCIONES-IA.md`.

## Qué leer (y qué NO)
- Continuidad: `..\..\handoffs\urbanismo-externo.md` (entradas nuevas arriba). El resumen de inicio ya
  muestra la última; NO leer el archivo completo. Histórico: `urbanismo-externo-archivo.md` (buscar, no leer).
- `PROGRESS.md` = changelog técnico (un commit por versión). Consultar por búsqueda (`Select-String`), nunca completo.
- `TESTING_CIVIL3D.md`: antes de verificar/ajustar leer solo su sección 0 y la 3e (protocolo vigente).
  Pasar un test no significa haber visto todo el modelo.

## Cómo carga Civil 3D
- Civil 3D carga el bundle local `%AppData%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle`;
  su `acaddoc.lsp` carga el motor desde ESTA carpeta (repo en Drive) y solo cae a la copia del bundle si no está.
  Cambios del `.lsp` → basta reiniciar Civil 3D. Al arrancar imprime `urbcant <version> (repo|bundle local)`.
- Desde v5.7.2 el manifiesto carga `bundle/urbcant_cargador.lsp` (motor una sola vez; `*urb-load-count*` = 1).
- `INSTALAR.bat` solo cuando cambian el DLL de la cinta, `PackageContents.xml` o iconos, o en un PC nuevo.
- El LSP legado `MAIPORE_BLOQUES_REDES_ELECT_...lsp` vive en `VARIOS\BLOQUES PPTOS\` (no es de este repo).

## Convenciones
- Namespaces `urb:` / `mp:`. Revisar git y releer el `.lsp` antes de editar (puede haber cambios externos).
- Integrar funciones nuevas en comandos existentes, no crear comandos nuevos.
- Versionar: bump de `*urb-version*` en cada entrega + commit `vX.Y.Z: descripción` + push según el flujo existente.
- No modificar DWG/Excel vigentes como prueba: usar copias y fixtures en `work\`. No sobrescribir trabajo externo.

## Verificación
- Protocolo en `TESTING_CIVIL3D.md` §0 y §3e: Civil 3D en segundo plano, nunca bloquear en primer plano;
  separar evidencia numérica, visual e instalada; no afirmar haber visto el DWG completo por consultarlo vía COM.
- Documentar límites: un adaptador de prueba no equivale a ActiveX real; cargar el LSP no prueba diálogos ni
  cálculos contra terreno real.
- Verificación lenta o repetida → mejorar el lanzador/script, con tiempo máximo; si se pasa, parar y diagnosticar.

## Registro (trazabilidad multiagente / multi-PC)
- Al lograr algo verificable: entrada NUEVA arriba en el handoff, máx. ~6 líneas, con `Agente` (Claude|Codex|Gemini),
  `Equipo` (COMPUTERNAME), fecha/hora local y commit. El detalle técnico va en `PROGRESS.md`/commit.
- No atribuir cambios ajenos ni usar `Co-authored-by` sin coautoría real.

## Flujos de trabajo
1. LSP / Civil 3D (este repo). 2. Presupuesto de obra (Excel) en `presupuesto\`: contexto en la memoria
   `diseno-ppto-detallado-ejecutado-detallado`.
