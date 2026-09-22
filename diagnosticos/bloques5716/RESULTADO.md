# v5.7.16 — bloques independientes del movimiento de tierras

Agente: Codex. Equipo: BOG085CD119BDQN. 2026-09-22 06:54 America/Bogota.
Base: e8012e5. Commit final: el commit que incorpora este informe.

## Cambio

En v5.7.15 crear verde/sendero preguntaba y calculaba MT antes de empaquetar.
Una interrupcion dejaba hatch/contorno sin INSERT. Ahora el bloque existe antes
del selector; CREAR y EDITAR usan el mismo calculador y una copia temporal del
contorno. No calcular o fallar MT conserva el bloque, sin volumen validado.
Fallo de empaquetado deja contorno de reintento, elimina hatch incompleto y
no incrementa el contador de senderos creados. No convierte elementos antiguos.

## Evidencia

- Sintaxis: balance 0, sin cadenas abiertas. git diff --check aprobado.
- Manifiesto 5.7.16 y 6 componentes validos.
- Core Console: 26 PASS, 0 FAIL, FINISHED, 8.15 s. Carga del motor,
  conservacion del resultado y manejo de nil/error/exit para ambas familias;
  regresion de interpolacion. Adaptadores sustituyen calculadores/limpieza
  para inyectar resultados: NO equivale a COM ni prueba volumen TIN.
- Civil 2023 completo: 25 PASS, 0 FAIL, FINISHED, 28.28 s. Creacion real de
  dos zonas y dos senderos rectangulares 10x4 m. Sustituye solamente entradas
  (dialogo/contorno/opcion sin prefabricados/selector) e inyecta error del
  selector. COM, empaquetado, atributos, XDATA, copia temporal y limpieza reales.
  Verifica AREA_M2=40, INSERT ya existente al llegar al selector, ausencia de
  contorno/hatch sueltos, MT pendiente al omitir o fallar y bloque conservado.
- La rama de fallo de empaquetado se reviso en codigo; no se indujo fallo COM.
- Fuente=instalado SHA256
  `FF7BC3445B8C272D8E5043947B4A56676984EBD5D59ED125B436291A20124043`.

Fixture/salidas: `C:/Users/juanbusper/Documents/URBANISMO/work/bloques5716/`.
Harness reproducible: run.ps1 (Core), run.ps1 -Native (Civil).
No modifica maestro/Excel. Ninguna inspeccion visual integral del dibujo.

## Pendiente manual

1. Reiniciar Civil y confirmar 5.7.16. Prueba nativa realizada en 2023, no 2026.
2. Crear zona/sendero, elegir Sin en tierras: seleccion debe ser Block Reference
   con AREA_M2 y atributos. EDITAR debe reconocerlo.
3. EDITAR permite reintentar tierras. Hatches viejos siguen sin convertirse;
   recrear desde su contorno conservando sus datos reales. No basta BLOCK manual.

Esta entrega no certifica precision TIN ni resuelve todos los pendientes historicos.
