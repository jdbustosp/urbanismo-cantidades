# Verificación 5.7.5 — continuidad táctil y tierras de vías variables

Fecha: 2026-09-21 (America/Bogota)
Agente/equipo: Codex / BOG085CD119BDQN
Entorno: Civil 3D 2023, copia local `fixture.dwg`; el maestro no se abrió ni modificó.

## Andén real de 374,333717 m²

- Dos ejecuciones completas: 35,282 s y 54,062 s. El primer resultado se
  descompone en 23,828 s de acabado, 10,829 s de empaque y 0,625 s de regen.
  El segundo se ejecutó con mayor carga del equipo. Antes el usuario reportaba
  cerca de cinco minutos; no se declara generación instantánea.
- Una referencia de bloque, cero piezas generadas sueltas y cero bloques
  anidados. Contenido: 4.785 entidades; 3.574 de guía y 618 de toperol.
- Área neta 374,333717 m²; suma de lisa/adoquín/guía/toperol 374,333718 m².
  Diferencia 0,000001 m².
- Guía 142,91 m y toperol 141,04 m. El trazado adaptativo acerca la guía en
  estrechamientos en vez de cortarla por conservar un offset fijo.
- Se aisló el bloque nuevo `144407`, se ocultó el resto del modelo y se
  plotearon la vista completa y cuatro ampliaciones. Guía roja y toperol azul
  permanecen continuos en todo el recorrido, curvas y estrechamientos; no se
  observaron círculos grandes. PNG locales: `overview575_final.png` y
  `tactile575_full.png`/`tactile575_1..4.png`.

## Movimiento de tierras vial

`verify575.lsp` valida la implementación productiva y un resultado calculado
independientemente a paso más fino.

- Caso analítico de ancho variable: calzada trapezoidal de 30 m² y 0,50 m de
  sobreancho perpendicular por costado. Huella exacta esperada y obtenida:
  40,04987562 m². Primer momento esperado y obtenido: 216,91604477; el modelo
  antiguo de ancho promedio daba 200.
- VIA-17: huella 1.468,127293 m². Producción: corte 814,142 m³, relleno
  126,332 m³. Auditoría a 0,125 m: 814,144 / 126,335 m³ (diferencia <0,003 %).
- VIA-08: huella 1.155,927680 m². Producción y auditoría a 0,125 m:
  1.106,46 m³ de corte y 0,00 m³ de relleno.
- En ambas vías: cero celdas sin `SUP_TN`, convergencia dentro de 0,5 %, área
  de huella almacenada igual a la geometría, atributos de área total y
  sobreancho exclusivo iguales a esa huella, metadatos conservados al empacar
  y objetos originales sin cambios.
- Los remates de costados oblicuos se recortan contra las tapas; el guardián
  admite el miter geométrico hasta 1,5× el sobreancho y sigue rechazando picos.

## Apertura

La reparación histórica de hatches ya no se sella con cada versión del motor.
Usa `HATCH_RENDER_V1`; un DWG con el sello anterior migra sin volver a censar
todos los bloques. Se evita repetir el barrido pesado en cada entrega menor.

## Límites honestos

- Civil 3D 2025/2026 no se ejecutó; el LSP común y el manifiesto se entregan
  para `R20.0–R25.1`, pero la geometría nativa se comprobó en Civil 3D 2023.
- No se guardó ni regeneró el maestro. Los andenes/vías ya creados requieren
  `EDITAR` para reconstruir su geometría o recalcular sus tierras.
- La auditoría de 0,125 m es deliberadamente costosa y no forma parte del
  tiempo normal de creación del andén.

## Instalación

Instalador validado y ejecutado con Civil cerrado. Motor y manifiesto 5.7.5
coinciden entre repo e instalación:

- Motor SHA-256: `D9F771824A51D624148FF76E3908D3B7EF9B479A7F9D433E5817C50BB8F7868F`.
- Manifiesto SHA-256: `256F5D9A2DE08BD5562AE7E70B7D594AD58200561485B0F9A54AF3F4A2B56532`.
