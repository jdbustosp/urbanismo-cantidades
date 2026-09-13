# Entrega 5.0.7 — andenes curvos y guardado de cotas

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-13 17:56 America/Bogota.
El historial de Git identifica el commit de entrega. Base al retomar: cd09304;
se preservaron los cambios de presupuesto de Claude.

## Resultado

Pruebas con Civil 3D 2023 REAL y ActiveX, sobre una copia local del maestro.
No se controlaron ventanas del usuario ni se modificaron DWG/Excel originales.

| Caso | Generar | Empaquetar | Total | Resultado |
|---|---:|---:|---:|---|
| Curva188 m, version final |19.500 s|26.000 s|45.500 s|Un bloque,6065 entidades internas,0 piezas sueltas|
| S80 m, dos arcos opuestos, ronda geometrica |7.187 s|11.328 s|18.515 s|Un bloque,2622 internas,0 piezas sueltas|

El mismo caso188 en la ronda anterior tardaba77.344 s SOLO en generar; ahora
esa fase tarda19.500 s, una reduccion medida del74.8%. No se presenta como
comparacion completa antes/despues: el empaquetado anterior abortaba.
No se promete45.5 s para cualquier dibujo/equipo. Los tiempos excluyen abrir
Civil, cargar/migrar el archivo y ejecutar las comprobaciones adicionales.

Version final: coincidencia exacta de los conjuntos de6040 HANDLE obtenidos
por busqueda rapida y por busqueda completa. El ensayo preliminar exigia tambien
el mismo ORDEN y marco FAIL; era una exigencia incorrecta del test, corregida
sin reducirlo a comparar solo cantidades.

En188m:0 HATCH/REGION fuera de los limites del contorno; atributos de acabados
suman el area sin sobreancho con tolerancia3e-6 m2. El motor ademas conserva su
control geométrico previo, sin relajar tolerancias. Guia189.07ML y toperol187.38ML
son equivalentes de area/ancho medidos, no la longitud nominal del eje188m.
La pruebaS da guia79.98ML y toperol79.80ML. Estos datos no sustituyen una revision
visual de cada tableta en la interfaz.

## Causas y correcciones

1. `(car (last chain))` convertia el ultimo punto en un numero. AutoLISP LAST
   devuelve directamente el ultimo elemento. Reproducido82806.4 con5.0.6;
   corregido tambien en dos accesos similares de rasante.
2. Los0.183601 m2 faltantes eran dos cunas en los REMATES. El limite perpendicular
   a la primera/ultima cuerda cortaba antes de llegar a la tapa real. Se extienden
   esos extremos y se recorta con el contorno exacto; las bisectrices interiores
   conservan las juntas. No se rellenaron cantidades artificialmente.
3. SELECT global consumia21.359 s; UNION de224 regiones solo0.547 s. Durante
   BUILD/PACKAGE se limita la busqueda al rango creado por esa operacion; fuera
   de ella sigue disponible la busqueda completa para dibujos existentes.
4. LINE usa sus2 extremos en vez de17 muestras redundantes; curvas conservan
   su muestreo. XDATA se lee una sola vez de forma filtrada y protegida.
5. Se conserva la region tactil continua, necesaria para medir y empaquetar;
   GUIA usa una posicion longitudinal por tableta y contraste visible, sin cuatro
   capsulas superpuestas. Uniones de cantidades equilibradas por pares.
6. Loseta lisa y adoquin se guardan con6 decimales para no romper la suma de
   areas por redondearlos prematuramente a2 decimales.
7. EDITAR ya conserva la clave propia del tramo en XDATA vinculada al ID del
   pozo. Vacio restaura herencia; cambiar de pozo invalida la excepcion anterior.

## Otras validaciones y limites

- Ocho regresiones focales pasan con la lectura XDATA final.
- Tramo9761C: guarda, reabre y resincroniza conservando la cota de prueba2559.00.
  Excavacion19.619 m3 en COPIA. Ese numero es sintetico, NO la cota aprobada.
- DOM41/4B951 sigue pendiente de confirmar su cota real; no se intercambio
  automaticamente PROFUNDIDAD2559.65 con COTA_CLAVE2.00.
- No se validaron todas las versiones de Civil3D, todos los contornos posibles,
  ni los clics/DCL/ribbon en la sesion del usuario. No hay promesa universal.
- Instalacion local507: motor/manifiesto coherentes; SHA256 repo=instalado:
  `42C16A041DFE55B938BCE8571392C0BF1E101AA3F6163B5EC33C158EE459EEFE`.
  En el otro computador hay que sincronizar y ejecutar INSTALAR.bat.

Evidencia local: `Documents/URBANISMO/work/fix507/diagnose.txt`, `accept.txt`,
`accept2.txt`, `package.txt` y `final.dwg`. Bloque188 final:BE0CC. El test
`native.lsp` conserva los dos casos y la comparacion correcta por conjuntos;
requiere adaptar las rutas y disponer del fixtureB490B indicado en el README.
