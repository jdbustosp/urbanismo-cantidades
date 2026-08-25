# Lote de redes (2026-08-24) — pluvial, acueducto, MT y alumbrado

Harness del lote masivo ejecutado en el PC secundario (Civil 3D 2025) que
modeló las 4 redes en `URB_MASTER_GENERAL.dwg` leyendo los planos fuente.
**Esta carpeta SÍ sincroniza por Drive** (a diferencia de
`Documents\URBANISMO\work\`, que es local por PC) — desde aquí se puede
reconstruir el laboratorio en cualquier computador.

## Qué se corrió y resultado (corrida v4, aplicada al master 22:53)

- **Pluvial**: 242 pozos + 115 sumideros + 229 tramos (claves 99%,
  diámetro propagado por continuidad; material NOVAFORT).
- **Acueducto** (fuente `02_REDES_HUMEDAS\TOTALES\ACUEDUCTO.dwg` — la
  que referencia el master, NO la de POR EJECUTAR): 704 accesorios +
  337 tramos por segmento (filtro anti-fantasma >130 m; claves =
  terreno − 1.00 m SUPUESTO a confirmar).
- **MT** (SERIE 1): 291 cajas CS-276/280 + 57 trafos/postes/subestaciones
  + 220 tramos (banco de ductos de las etiquetas "d= Xm NØ6" PVC").
- **Alumbrado** (SERIE 6): 603 luminarias + **553 tramos RECONSTRUIDOS**
  encadenando luminarias consecutivas del mismo circuito (el plano no
  tiene la red dibujada — validado: 16.037 ML reconstruidos vs 15.584 ML
  sumados de etiquetas).

Backup previo del master:
`07_MASTER_GENERAL\URB_MASTER_GENERAL_backup_antes_loteredes_20260824.dwg`.

## Archivos

- `lote_redes.lsp` — el constructor (comando `LOTEREDES`). Corre en Civil
  3D COMPLETO headless (usa COM); NO corre en accoreconsole.
- `extract.scr` / `probe.scr` — extracción/sondeo de planos fuente en
  **accoreconsole** (puro entget, sin diálogos). Generan
  `data_<dwg>.txt` / `probe_<dwg>.txt`.
- `correr_probes.ps1`, `correr_lote.scr` — lanzadores.
- `leer_ppto.ps1` — vuelca el presupuesto real a CSV (solo lectura).
- `lote_result.txt` — log de la corrida v4 aplicada.
- `cantidades_modelo.txt` — 167 conceptos con cantidades totales del
  modelo (para cruce con presupuesto).

OJO: las rutas dentro de los scripts apuntan a
`C:\Users\jdbus\Documents\URBANISMO\work\lote_redes\` (el PC secundario).
Para correr en otro PC: copiar esta carpeta ahí (o ajustar `lr:dir` y
las rutas de los .scr/.ps1) y agregar esa carpeta a TRUSTEDPATHS.

## Lecciones técnicas (no repetir)

1. `distof` es ESTRICTO: devuelve nil si hay texto tras el número. Para
   parsear etiquetas usar `atof`/`atoi` o extraer números en orden tras
   limpiar códigos MTEXT (`lr:sin-formato` + `lr:numeros`). Este bug
   apareció DOS veces (etiquetas y posiciones MLD multipunto).
2. Los xrefs del master se insertan en 0,0 rot 0 escala 1 →
   transformación identidad; verificar SIEMPRE la ruta real del xref
   (assoc 1 del bloque): el master usa TOTALES, no POR EJECUTAR.
3. `urb:ppto-tramo-red` espera tokens `Aresidual`/`Alluvias`/`ACUEDUCTO`
   en el atributo RED (no "ALC-PLUVIAL").
4. En TOTALES hay polilíneas en capas de red que NO son tubería
   (perímetro del loteo) → filtrar segmentos >130 m.
5. Los errores de fase se loguean con `lr:fase` — nunca tragar un
   vl-catch-all sin loguear el mensaje.

## Pendientes (detalle completo en el handoff)

- Confirmar recubrimiento 1.00 m acueducto; revisar circuitos AP
  reconstruidos (inferidos, no dibujados); 89 tramos pluviales sin Ø;
  39 con claves descartadas (zona dique); cabezales(67)/captaciones(76)/
  alcantarillas(12)/acometidas(45) como UN manuales; tubería pluvial por
  rangos de profundidad (feature); correr Presupuesto para el match real.
