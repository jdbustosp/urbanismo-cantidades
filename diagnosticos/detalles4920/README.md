# Evidencia leída de los planos (2026-09-10, Claude)

Todo esto se sacó abriendo **copias** de los DWG del proyecto con AutoCAD
headless. **Los originales no se tocaron.** Se guarda aquí, en el repo, porque
el laboratorio local (`Documents\URBANISMO\work\...`) **no viaja entre PCs**.

## Cómo se generó

`run_survey.ps1` del laboratorio copia el DWG al lab, lo abre con
`accoreconsole.exe /i <copia> /s <script>` y corre el `.lsp` correspondiente.
Los `.lsp` de aquí son los que se corrieron; para repetirlo basta con un runner
equivalente (ver `diagnosticos/e2e4920/run.ps1` como plantilla y cambiar el DWG
de origen).

| archivo | qué contiene |
|---|---|
| `survey.txt` | Inventario de `Detalles_Rampas.dwg`: 5.047 entidades, 44 capas, 177 bloques |
| `bloques.txt` | Composición de los bloques de rampa/paso/tableta y sus extensiones |
| `vertices.txt` | **Los vértices reales** de `B-RAMPA VEHICULAR`, `B CEBRA`, `B-Bolardo`, `B-TABLETA 20X20 TÁCTIL ALERTA` y `B-Bordillo A80` |
| `cebra.txt` | Uso de `B CEBRA` (**ninguno**) y conteo de las filas de tableta de la rampa vehicular |
| `senal.txt` | Inventario de `SEÑALIZACION.dwg`: capas, bloques usados y rótulos |

## Medidas que ya están implementadas (v4.91.0 / v4.92.0)

**`B-RAMPA VEHICULAR`** — módulo de 10,00 m de frente:

- aleta trapezoidal: `(0,0) (2.369,1.70) (2.156,1.70) (0,0.20)` y su espejo
- cara de rampa entre aletas, fondo 1,70
- banda de fondo de 0,20 = bordillo **A-80** (bloque de 0,80 × 0,20)
- tableta podotáctil de **ALERTA**: 27 tabletas de 0,20 a lo ancho del fondo,
  8 por cada costado (1,60 m)
- 4 bolardos en (2,40 / 7,60) × (−2,20 / −3,00)
- líneas de proyección de pendiente: `(9.02,-0.20) (5.142,-1.50) (0.98,-0.20)`

**`B-TABLETA 20X20 TÁCTIL ALERTA`** = 0,20 × 0,20 con **3 × 3 = 9 domos de
r = 0,0119** → paso **0,0667** (por eso `URB_TOPEROL.pat` usa ese paso y no 0,05).

**`B-Bordillo A80`** = sección de 0,20 ancho × 0,35 alto, con zarpa hasta −0,60.

**`B CEBRA`** = una franja de **0,30 × 2,80** con relleno sólido, **definida pero
nunca usada** en el plano. Por eso el paso entre franjas de una cebra **no se
puede deducir de aquí**; el usuario decidió que el paso peatonal largo lleve la
textura por bandas del andén, no cebra pintada.

## Señalización (aún sin implementar)

`SEÑALIZACION.dwg`: la señalización del proyecto es casi toda **demarcación
horizontal** en la capa **`SEN_BASE_DEMARCACION`** (1.642 entidades) +
`SEN_BASE_DEM_CPS_2010` (67). Rótulos que se repiten: *"LINEA CONTINUA DE CARRIL
AMARILLA"* y *"LINEA SEGMENTADA BLANCA DE CARRIL"*. De vertical solo el bloque
`SP-20` (×6). Como todo se genera a lo largo del eje, se puede colgar de la
modelación de la vía.
