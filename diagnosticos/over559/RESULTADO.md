# Sobreancho con pico y rendimiento — Civil 3D 2023

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-14, America/Bogota.
Base: c1b4fd6 (5.5.8). Laboratorio local: `work/over559` en el workspace Codex.
No se modificaron DWG/Excel originales.

## Reproduccion real

Copia de URB_MASTER_GENERAL.dwg, guardado 18:16:04, 36.140.836 bytes.
Bloque E239A / contorno original DFA56: 367.586328 m2, 537 vertices,
perimetro 212.771 m. No confundir perimetro con longitud del corredor.
Su bloque SI existe; ANDEN_CORTE_M3 y ANDEN_RELLENO_M3 estaban vacios.
Sobreancho guardado: 770.048540 m2.

La huella anterior reproduce un vertice a **189.509 m** del contorno.
No hay autointerseccion: ese chequeo y area mayor que el acabado no bastan.
La prolongacion de segmentos con OFFSETGAPTYPE=0 produce el pico.
OFFSETGAPTYPE=1 en ActiveX real crea uniones de radio1m y lo elimina.
La variable se restaura tambien cuando el calculo falla; solo cambia tierras,
no geometria de losetas/guia/toperol/prefabricados.

Huella corregida: **582.155230774 m2**. Se verifica distancia de cada vertice y
punto medio exacto <=1m+0.1mm, ausencia de cruces y contencion del acabado
por sustraccion de regiones. No es una demostracion universal de todo arco.
Comparacion visual localizada de coordenadas extraidas: `comparacion.png`
LOCAL, no captura de la pantalla ni revision visual completa del maestro.

## Rendimiento y controles

- Intersecciones: barrido de cajas por X, mismos cruces estrictos, sin NTH
  repetido sobre listas largas. 506 casos de equivalencia, cero diferencias.
- Huella anterior39.422s; prototipo con redondeo+barrido2.688s; con control
  adicional de distancia4.953s. No son tiempos totales de generacion.
- Construccion con esta primera correccion: acabado80.781s + paquete42.797s
  =123.578s. Bloque unico; cantidades de acabados identicas a E239A.
- La malla de tierras convierte esa huella en4110puntos. Su triangulacion
  anterior supero5min; se interrumpio SOLO el PID8800 de laboratorio, tras
  guardar el bloque. No se obtuvo tiempo final ni equivalencia completa de
  esa malla anterior. No presentar una corrida interrumpida como exito.
- Se prueba optimizacion de triangulacion: recorrido de listas y cajas
  conservadoras que incluyen la tolerancia baricentrica existente. No se
  simplifica el contorno ni se aumenta el paso de muestras2.5m.

## Muestreo de tierras: segundo defecto encontrado y corregido

La primera optimizacion de triangulos dio240/240casos EXACTAMENTE iguales al
algoritmo anterior, pero la prueba real fallo el cierre de area:204.359s,
873670muestras, area582.3465m2 en vez de582.1552m2. Se conserva este fallo en log.
El origen fue el muestreo de microarcos mediante un centro/radio enorme y
cancelacion numerica en coordenadas WCS. No se relajo la tolerancia de areas.

Ahora se evalua el arco en coordenadas locales con seno de medio angulo y
flecha maxima0.00001m (0.01mm), sin minimo artificial de8segmentos por microarco.
Arcos originales del DWG no se simplifican.20checks contra puntos/areas nativos
de Civil pasaron con bulges positivos/negativos desde1e-9 hasta2 (arcos>180grados).
Caso real:1927puntos, malla28.609s,251831muestras, diferencia de area0.000615344m2:
PASA el control anterior, sin inflar la tolerancia.

LIMITACION DE RENDIMIENTO ABIERTA:251831muestras siguen siendo muchas llamadas
potenciales a SUP_TN. No se hizo el calculo real contra terreno ni puede
prometerse rapidez del proceso completo. La subdivision de triangulos finos
por lado2.5m sigue siendo candidata para una mejora separada con validacion
espacial; no cambiarla por un umbral de area que pierda detalle longitudinal.

## Cierre 18:59 — motor5.5.9

Ultima generacion real: acabado70.406s + paquete34.984s = **105.390s**.
Un INSERT final, cero INSERT anidados; censo por tipo/capa/rol identico al
primer bloque de ensayo. Seis areas de atributos identicas; fallo final0.
No es una promesa para otros andenes ni incluye SUP_TN. Se conserva separado
del ensayo anterior123.578s: no se atribuye todo el ahorro a un unico cambio.
Fuente/probada SHA256:
`C9FE52DB547207E178F5BAFD609D34A2F80B654C51B186084B47710E2E8148FF`.
Manifiesto5.5.9, instalador ValidateOnly OK, diff --check sin errores.
Sesion propia37032 cerrada tras QSAVE. Instalacion y commit/push al cierre.

## Zona verde alrededor del area azul

La resta de REGIONES coplanares es la operacion geometrica apropiada. No
aplicar SUBTRACT al bloque cuantificado: el comando de zona verde existente
acepta una polilinea cerrada y sus areas/tierras salen del contorno exterior.
Un hatch con isla por si solo NO descuenta el hueco de las cantidades.
Solucion compatible hoy: zonas cerradas simples alrededor del area excluida,
sin superposicion, seleccionadas en el comando de zona verde. Para una sola
zona con huecos se necesita desarrollar exclusiones tanto en acabado como en
area neta, tierra negra, cortes/rellenos y posterior edicion. No implementado.

## Limites

No calculo final de volumen contra SUP_TN/cotas del usuario en esta prueba;
el fixture geometrico no contiene la superficie. Los ceros de tierras del
bloque de ensayo se crearon con calcular=No, no representan el volumen real.
No pruebas nativas2025/2026. Rehacer/actualizar el anden con el motor nuevo y
volver a calcular tierras; instalar no repara automaticamente DWG existentes.
