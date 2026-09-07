# Cobertura actividades del ppto vs PLANOS de redes — 2026-09-07

## REDES HÚMEDAS

### Acueducto (plano 1198 ALCA_ACUEDUCTO, 21 planchas, jul/2021)
- **CUBIERTO**: suministro+instalación PVC Ø1"-Ø12" y HD Ø4"/Ø12" (UN/ML),
  acometidas (plano 15 = tabla oficial), accesorios completos (codos
  11,25/22,5/45/90, tees, reducciones, tapones, uniones — totales plano:
  172/194/54/65/1), válvulas (compuerta, ventosa, purga, VCP — 126),
  hidrantes (74), VRP norte+sur (planos 09-10 = 2.5.1.7), MT con
  entibados E-1A/E-1B/E-2, cárcamo ML, empates/conexiones, pruebas.
- **NO SOBRA NADA**: cada familia del capítulo 2.5.1 tiene respaldo en
  plano. La actividad "Tubería de acero al carbón SCH 40 Ø4"" y "Caja
  estructural para válvula Ø12"" son de detalles VRP (planos 09-10) ✔.
- **PENDIENTE DE MODELAR** (no de ppto): las zonas de tubería sin trazar
  (313 accesorios sin tramo cerca — decisión de alcance).

### Sanitario (plano 1198 ALC_RESIDUAL, 20 planchas)
- **CUBIERTO**: tuberías Ø6"-Ø30" (cantidades oficiales plancha 18:
  Ø8" 2.522,86 ML ... Ø30" 1.284,96 ML), 95 pozos nuevos (base, cañuela,
  anillos, cono, tapa, pasos, cámara de caída), domiciliarias 737,65 m
  (construcción+empate+accesorios), MT con entibados E-1A (≤2m),
  E-1B (≤3m), E-2 (>3m) según planchas 19-20, cárcamo ML, pruebas/CCTV.
- **NO SOBRA NADA** en 2.5.2.

### Pluvial (colectores en plano residual + cartilla bioswales 2013)
- **CUBIERTO**: tuberías NOVAFORT/CCR/CER/CSR por bandas Hex, pozos,
  sumideros, cárcamo ML (nuevo), MT espejo del sanitario (nuevo),
  BIORETENEDORES/BIOSWALES (cartilla D B-5/D B-6: excavación manual +
  cargue y retiro (agregado 4.70.1) + base gravilla permeable + gravilla
  10-15 + gravilla 25-40 + material orgánico + tubería perforada Ø6" +
  rejilla + jardinería — SIN geotextil por nota expresa de cartilla),
  CABEZALES (D B-4: ítem todo-costo con aletas y solado; la zanja de la
  tubería de descarga la cubre el MT del tramo).
- **REVISAR CON EL DISEÑO PLUVIAL DWG** (no hay PDF de ese juego): las
  referencias CER/CSR por banda que hoy están en 0 — depurar cuando se
  modele la red pluvial en lote.

## REDES SECAS (planos = xrefs SERIE 1 / SERIE 6, sin PDF)
- **MT (2.6.1)**: cubierto por el modelado real (220 tramos, cámaras
  CS274/275/276/280 — CS280 ya con precio 7,5M), bancos de ductos,
  cable 3x185, cajas. Sin sobrantes detectados.
- **Alumbrado (2.6.2)**: cubierto (postes 12 m y 14 m — 14 m ya con
  precio 3,5M —, luminarias DECOLED, acometidas 2x12, tubería 2Ф3",
  cable 4x4). La red AP completa vive en los bloques CR T1..T5 de
  SERIE 6 (hallazgo 2026-08-26) — remodelado en lote pendiente.
- **Obras eléctricas (2.6.3)**: transformadores/obras civiles —
  verificar kVA contra plano cuando se haga el lote.
- **Telecomunicaciones (2.6.4)**: SIN soporte de modelado aún (motor
  puede ampliarse igual que MT/AP cuando haya plano/xref de telecom).

## Bioswale/cabezal: ¿excavación, M.O., material?
- **Bioswale: COMPLETO en 4.70.1** — excavación manual (M.O.) + cargue y
  retiro + materiales (gravillas, orgánico, base permeable, tubería,
  rejilla) + jardinería. Las actividades "Suministro y colocación de..."
  incluyen la M.O. de colocación.
- **Cabezal: COMPLETO como ítem todo-costo** ("incluye aletas y solado",
  $8,5M) — no requiere desagregado; su excavación la cubre el MT del
  tramo de descarga.
