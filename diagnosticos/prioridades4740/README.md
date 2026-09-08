# Verificación v4.74.0–v4.76.0 — prioridades del 2026-09-08

## Adición v4.76.0 — recorte físico de andenes

- **65 OK / 0 fallos** en Core Console 2023; duración total 40,21 s.
- Caso puro agregado: reconoce un entrante de contenedor como polígono cóncavo
  y conserva el rectángulo normal como convexo.
- El acabado resta regiones de prefabricados/contenedores antes de generar
  material y accesibilidad. Esta parte usa ActiveX real: queda pendiente la
  confirmación visual del usuario; no se simula como si fuera prueba gráfica.
- Instalación 4.76.0 y hash del LSP instalado idéntico al repositorio.

Trazabilidad: **Agente: Codex | Equipo: BOG085CD119BDQN | Fecha local:
2026-09-08**.

## Archivos de prueba

- Excel: copia local `Documents/URBANISMO/work/codex_20260908_prioridades/urbanismo_maipore_copia.xlsx`.
- DWG: copia local `Documents/URBANISMO/work/codex_20260908_prioridades/URB_MASTER_GENERAL_copia.dwg`.
- Los archivos vigentes del proyecto no se modificaron durante las pruebas.

## Resultados verificables

- v4.75.0: **64 OK / 0 fallos** con Core Console 2023 sobre una copia del
  maestro; tiempo total 33,99 s. Se añadieron checks de las tres tipologías de
  áreas y de recorte de caja/pozo.
- Instalación v4.75.0: manifiesto XML válido, hash del LSP instalado idéntico
  al repositorio y cargador `acaddoc.lsp` presente en Civil 3D 2023.
- La validación con Civil 3D completo oculto no llegó al harness por avisos
  modales del DWG. Se abandonó sin tocar originales; no equivale a fallo del
  motor ni permite declarar validación visual.

- Suite Core Console: **61 OK / 0 fallos**. Incluye carga del motor,
  regresiones anteriores, destino de prefabricados, tipologías de rampa y
  transacción de etapa/subetapa con restauración ante escritura parcial.
- Consulta en la copia del master: 3.234 INSERT y 1.166 tramos candidatos.
  Recolección completa: 610–640 ms; recolección limitada al handle 90908:
  16–32 ms (aprox. 20–38 veces menos en estas corridas).
- Handle 90908: el atributo `DIAMETRO` está vacío. Por eso el cabezal debe
  seguir visible como `SIN MATCH`; no se asignó por suposición a uno de los
  rangos 8–10, 12–16 o 18–24.
- Apariencia objetivo del motor: ancho 0,20 m y altura de texto 0,60 m para
  todos los tramos húmedos y secos. La normalización del dibujo completo
  requiere Civil 3D/AutoCAD con ActiveX completo.

## Excel (solo lectura)

- El presupuesto contiene capítulos distintos para `RAMPA VEHICULAR`,
  `RAMPA PEATONAL` y `PASO PEATONAL SEGURO`; el motor ahora conserva esa
  tipología y dirige cada elemento al capítulo correspondiente.
- `MEMORIA_CALCULO_RANGO` apunta a `#REF!` y solo aparece en
  `xl/workbook.xml` como nombre definido; no se hallaron fórmulas, conexiones
  ni consultas que lo consuman. Es un nombre obsoleto, pero no se eliminó del
  libro vigente en esta entrega.
- La ampliación de capítulos indirectos de etapa 6/GENERAL tiene impacto
  contractual aproximado de **$783.253.493**. No se aplicó sin decisión del
  responsable del presupuesto.

## Limitaciones

- AutoCAD Core Console 2024 no expone el objeto COM completo en este equipo:
  no pudo ejecutar la regeneración masiva de bloques ni validar visualmente
  DCL/Civil 3D. La suite usa un adaptador ActiveX para la lógica transaccional.
- La copia aislada del master abre XREF relativas como descargadas; por eso no
  se volvió a censar el pendiente histórico de 313 accesorios de acueducto sin
  tramo. Ese pendiente es de modelación/conectividad, no un espesor visual.

## Ejecución

```powershell
.\diagnosticos\prioridades4740\ejecutar.ps1 `
  -CoreConsole 'C:\Program Files\Autodesk\AutoCAD 2024\accoreconsole.exe' `
  -Template 'C:\Program Files\Autodesk\AutoCAD 2024\Sample\ActiveX\SheetSetVBA\IRD.dwt' `
  -Lab "$env:USERPROFILE\Documents\URBANISMO\work\codex_20260908_prioridades\hardening4740"
```
