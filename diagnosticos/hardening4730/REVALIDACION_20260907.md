# Revalidacion en segundo plano — 2026-09-07

Motor: 4.73.0; revision del motor: 5d95c03408c6429b4c9bcd888003c914e654fc40.

## Resultados ejecutados

- Suite ejecutar.ps1 sobre copia local de plantilla Civil 3D 2026: 50 OK / 0 FALLOS, DONE, salida 0.
- Instalador -ValidateOnly: entrega valida, cuatro referencias de componentes.
- Pruebas aisladas del instalador: 4/4; acepta entrega valida y rechaza version distinta, XML invalido y componente ausente.
- Analisis estructural del LSP: sin parentesis abiertos ni cierres sobrantes. Este analisis no certifica semantica AutoLISP.
- SHA256 del motor del repositorio y del instalado identico: 5A7D53C2AA6A2CA0AD857B8EB9982613A5A56FB922A43ED4DFAA4BA49554C893.
- git diff --check sin incidencias antes de guardar el informe.

La suite usa adaptadores ActiveX/DCL. No acredita COM nativo, interfaz visual, superficies Civil 3D ni exportacion Excel completa. No se ha intervenido la interfaz de trabajo del usuario.

## Mejoras pendientes por prioridad

1. **Integridad del cambio de etapa/subetapa.** urb:apply-etapa-subetapa asigna categoria despues de llamar al escritor XDATA sin comprobar su retorno. Revisar tambien escritura de atributos; implementar lectura posterior y rollback por entidad antes de contabilizar exito. Es un riesgo detectado por lectura, todavia sin reproduccion de fallo real. Probar cancelacion y UNDO del lote con ActiveX nativo.
2. **Validacion de extremo a extremo.** Usar copias de DWG y Excel para comparar memorias, cantidades, unidades, etapas, campos ocultos y presupuesto exportado; incluir superficies, bloques dinamicos y capas bloqueadas. Es la mayor brecha de validacion actual.
3. **Consulta de un elemento.** urb:q-trace-command llama a q-collect-readonly para todo el dibujo y luego filtra por handle. Permitir a los colectores recibir una entidad o seleccion acotada, conservando las mismas reglas de calculo. Medir tiempos y equivalencia antes/despues.
4. **Agrupacion de cantidades.** urb:q-aggregate busca con assoc y sustituye con subst en una lista creciente. Puede crecer cuadraticamente cuando aumentan los grupos. Comparar agrupacion ordenada o un indice, verificando suma, conteo, estado y orden de salida. Aun no hay benchmark que cuantifique la mejora.
5. **Actualizacion de redes.** q-refresh-network-segments recorre INSERT y actualiza tramos elegibles. Medir costes de COM y estudiar invalidacion por cambios de geometria, datos y superficie antes de introducir cache; URB_DATA_AUDIT solo indica ultima escritura y no basta para decidir vigencia de calculo.
6. **Compatibilidad de interfaz.** Recompilar y probar DLL 2019–2024 con referencias compatibles para retirar el boton Sendero heredado. No afirmar soporte probado sin ejecutar esa version.

## Harness nativo preparado

verify_real.lsp queda conservado como experimental, NO ejecutado ni certificado. Requiere una fixture llamada validacion_real.dwg y URB_TEST_LAB configurado; no usar sobre un dibujo de trabajo. No sustituye las pruebas manuales del README ni tiene runner nativo validado.

En esta revalidacion no cambia el motor ni su numero de version: se guardan evidencia y pendientes.
