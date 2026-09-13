# Auditoría de movimiento de tierras y pozos

Agente: Codex. Equipo: BOG085CD119BDQN. Modelo: Luna. Fecha: 2026-09-13.
DWG revisado: `MASTER_test.dwg`, copia local de `URB_MASTER_GENERAL.dwg`; el DWG principal no se modificó.

## Resultado verificable

- Civil 3D cargó el motor en la copia y encontró la superficie `SUP_TN`.
- La prueba con una huella de 50 m² pasó el invariante de rasante: subir la rasante 1 m cambió el balance corte–relleno exactamente 50 m³.
- La prueba de huella curva (área neta 123,603 m²; sobreancho 1 m por cada lado 194,234 m²) pasó y conservó la diferencia de volumen igual al área ampliada.
- La lectura de una huella empaquetada, girada y escalada pasó: se corrigió la conversión OCS de entidades dentro de una definición de bloque.
- Los entibados ahora se integran por segmento y se dividen en los cruces de 2 y 3 m. Prueba de 10 m entre 1 y 4 m: 16,6667 m² en 0–2, 23,3333 m² en 2–3 y 10,0000 m² sobre 3; total 50 m². La prueba inversa da el mismo resultado.

## Pozos: datos que deben confirmarse

El barrido encontró 83 pozos sanitarios. La suma de las 75 profundidades positivas es **2.829,86 ML**, de los cuales **2.582,83 ML** están en la subetapa 4E (10 pozos). Esto confirma la concentración indicada, pero no confirma que las profundidades sean correctas.

El caso crítico es el pozo **DOM41**, handle `4B951`, subetapa 4E: `PROFUNDIDAD=2559.65`, `COTA_TN_INI=2561.295`, `COTA_CLAVE_INI=2.00`. No se intercambiaron esos campos automáticamente porque faltaría saber la cota de diseño aprobada. Esa inconsistencia también contamina el tramo `DOM41–55`, handle `9761C`, de 6,06 m: el DWG guarda 9.317 m³ de excavación y 15.528 m² de entibado.

También hay cuatro valores negativos (`DOM02`, `TRAT-01`, `TRAT-05`, `TRAT-08`) y cuatro pozos sin profundidad (`LM21`, `BO01`, `33`, `32`). Los pozos pluviales sin anillo se informan como faltantes, no se inventan metros.

El comando de exportación queda bloqueado antes de escribir Excel si encuentra valores no positivos o que exceden el umbral de revisión de 30 m. Los faltantes quedan como pendientes. El diagnóstico interno es de solo lectura: no cambia cotas del DWG.

## Pendiente antes de instalar

Confirmar las cotas de diseño de los 9 registros indicados, editar DOM41 y sus tramos conectados, y volver a ejecutar el barrido. Después se debe hacer una exportación de prueba al libro de trabajo, verificar que el total de anillo deje de ser 2.829,86 ML mientras esos datos estén pendientes, y recién entonces subir versión e instalar el bundle.
