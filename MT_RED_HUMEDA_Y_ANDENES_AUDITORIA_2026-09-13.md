# Auditoría de redes húmedas y andenes — 2026-09-13

## Trazabilidad

- Agente: Codex
- Equipo: BOG085CD119BDQN
- Fecha: 2026-09-13 (America/Bogota)
- Versión del motor instalada: 5.0.6
- Commit: `f5ec2dc` (`v5.0.6: acelerar franjas guia y toperol`)
- DWG original: `C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\Memorias\URB_MASTER_GENERAL.dwg`
- Copia analizada, solo lectura: `C:\Users\juanbusper\Documents\URBANISMO\work\mt_pozos505\MASTER_test.dwg`
- SHA-256 de la copia analizada: `D8750A207511E01FC7D6E54B1785625ECC0E28FBA63E89D1AE498C9FF0ECEB98`
- SHA-256 del LSP fuente e instalado: `07C383961D69BF7EC6A9688A14FE86CCB6978F6DAAFC8319516E0D097938B56D`

No se modificó el DWG original ni la copia de auditoría.

## Hallazgos de redes húmedas

### 1. DOM41 es el inflador principal

El bloque `MP_PUNTO_POZO_SAN`, handle `4B951`, ID `DOM41`, subetapa `4E`, contiene:

| Atributo | Valor | Observación |
|---|---:|---|
| `PROFUNDIDAD` | 2559.65 m | No es una profundidad de diseño válida |
| `COTA_CLAVE_INI` | 2.00 m | Cota inconsistente con la superficie 2561.295 |
| Diferencia implícita | 2557.65 m | Explica la magnitud anómala |

El tramo `MP_TRAMO_SAN_7_26`, handle `9761C`, DOM41–55, mide 6.06 m y quedó persistido con:

- `EXCAVACION_M3 = 9317.00`
- `RELLENO_M3 = 9316.16`
- `ENTIBADO_GT3_M2 = 15528.33`
- perfil XDATA con profundidad máxima aproximada de 2559.55 m
- equivalentes aproximados: 1,537.46 m³/ml de excavación, 1,537.32 m³/ml de lleno y 2,562.43 m²/ml de entibado total (1,281.22 m de profundidad por cada cara)

Conclusión: DOM41–55 sí es un dato contaminado y explica por sí solo la inflación extrema. Debe corregirse la cota/profundidad de DOM41 y regenerarse el tramo y sus cantidades; no se intercambiaron cotas automáticamente.

### 2. La subetapa 4E queda dominada por ese tramo

Los 10 tramos de 4E suman 236.73 ml, 9,979.94 m³ de excavación, 9,946.56 m³ de llenos y 16,745.35 m² de entibado. DOM41–55 representa aproximadamente 93.36% de la excavación, 93.66% del lleno y 92.73% del entibado de 4E.

Excluyendo DOM41–55, los otros 9 tramos de 4E quedan en 230.67 ml, 662.94 m³ de excavación, 630.40 m³ de lleno y 1,217.01 m² de entibado, valores sin la anomalía de miles de metros.

### 3. Duplicados de tramos que también pueden inflar cantidades

Se encontraron 15 grupos de insertos sanitarios duplicados: misma subetapa, pozos inicial/final, longitud y punto de inserción. Hay 15 filas extra que no deben sumarse dos veces si representan copias accidentales. En conjunto aportan aproximadamente:

- 833.32 m³ de excavación
- 805.63 m³ de lleno
- 1,443.37 m² de entibado

El caso más importante es DOM53–67, duplicado en handles `97955` y `97881`, ambos en la misma coordenada. Debe confirmarse en Civil 3D cuál copia es válida antes de eliminar o excluir una.

### 4. Otros datos de pozos pendientes

Además de DOM41, el auditor encontró cuatro profundidades negativas y cuatro vacías:

- Negativas: `4BB13` DOM02 (-1.08), `4B861` TRAT-01 (-2548.12), `4B825` TRAT-05 (-2547.51), `4B7F8` TRAT-08 (-2547.24).
- Vacías: `4A141` LM21, `49D45` BO01, `49CC1` 33 y `49CB2` 32.

El motor 5.0.6 ya tiene `urb:audit-pozo-depths`/`urb:ppto-check-pozo-depths`: los datos no positivos o mayores a 30 m bloquean la exportación; los vacíos quedan pendientes y se informan. La solución correcta es confirmar cotas con `EDITAR`, recalcular los tramos conectados y volver a auditar.

## Verificación de andenes

Validado en los fixtures de Civil 3D disponibles antes de esta auditoría:

- El patrón curvo no deja círculos de obra; guía y toperol llegan al final del tramo.
- El andén queda empacado como bloque, sin entidades sueltas, cuando el comando termina normalmente.
- El sobreancho de 1.00 m por lado y las cantidades de área con/sin sobreancho están guardados en atributos.
- La versión instalada y la fuente son idénticas por SHA-256.

La optimización 5.0.6 sustituyó la generación de franjas guía/toperol por regiones y hatches continuos, reduciendo el número de booleanos/hatches. Sin embargo, el ensayo automatizado de esta sesión con `accoreconsole.exe` no es una validación funcional del motor: CoreConsole no expuso correctamente los objetos VLA/ActiveDocument (`bad argument type: VLA-OBJECT nil`), por lo que no se debe usar ese tiempo como medición de Civil 3D. Queda pendiente una corrida limpia dentro de Civil 3D abierto para medir el tiempo final y verificar visualmente un andén curvo real.

## Próximo orden de corrección

1. Confirmar la cota clave/profundidad correcta de DOM41.
2. Recalcular DOM41–55 y auditar nuevamente excavación, llenos y entibado.
3. Confirmar/eliminar la copia duplicada de DOM53–67 y revisar los otros 14 grupos duplicados.
4. Resolver las cuatro profundidades negativas y cuatro vacías.
5. Ejecutar una prueba final en Civil 3D 2023/2024 con un andén curvo y otro de 188 ml; registrar tiempo, bloque, círculos, guía/toperol y cantidades.

