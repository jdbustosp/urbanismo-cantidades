# Regresion 5.0.7

Resultado de entrega e instalacion: [RESULTADO.md](RESULTADO.md).
`native.lsp` conserva la prueba integral sobre el contornoB490B del fixture;
no ejecutarlo sobre el maestro. Requiere una copia del fixture y ajustar rutas
en otro computador. La comparacion de entidades es por conjuntos de HANDLE,
no por orden de ssget/entnext. La prueba publica no incluye el DWG privado.

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-13, America/Bogota.

`regression.lsp` contiene pruebas focales de LAST, rasante y las cotas de
conexion persistentes del tramo. Cargar el motor, cargar este archivo y ejecutar
`(test507:run)` SOLO en dibujo descartable. Crea y elimina un POINT de prueba;
no abrirlo sobre el maestro. No sustituye la prueba de geometria/ActiveX.

La prueba integral local de esta entrega vive en
`C:/Users/juanbusper/Documents/URBANISMO/work/fix507/final.lsp`:
copia del maestro, tramo 9761C, DOM41 4B951, corredor curvo de 188 m
(23.8 grados, ancho 3.5 m) y rectangulo de 10 m. Comprueba construccion,
bloque, cero elementos generados sueltos, limites de hatches, circulos,
balance de areas y longitud de franjas tactiles. El resultado y los limites
deben consultarse en el informe de entrega, no inferirse del codigo del test.

Para repetir en otro equipo hay que adaptar rutas, disponer de Civil 3D completo
y de una copia local del fixture. No usar Core Console como sustituto de ActiveX.
El dato 2559.00 del ensayo es sintetico: NO corregir DOM41 con ese numero.

## Ejecucion agil

- Reusar un fixture y un proceso propio cuando haya que investigar un fallo.
- Separar arranque/migracion de la medicion BUILD + PACKAGE. En el laboratorio
  se puede fijar `*urb-suppress-auto-migration*` antes de una recarga focal;
  registrar esa exclusion. No ocultar la migracion si lo probado es el arranque.
- Registrar comienzo/fin de cada fase, el error nativo y el cierre de areas.
- No aceptar un BUILD correcto como prueba de bloque completo. Verificar la
  referencia final y que el handle padre no tenga descendientes en ModelSpace.
- No aceptar solo contar CIRCLE: un disco aparente tambien puede ser un HATCH;
  comprobar sus limites. Esta prueba no demuestra todas las curvas posibles.
- No alterar archivos DWG/Excel vigentes ni cerrar procesos del usuario.
