# Verificacion v5.7.6 — lado elegido y guia recta

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-21.

## Defectos reproducidos

1. La v5.7.5 ajustaba la separacion de la guia cada 0,25 m segun el ancho
   disponible. Aunque evitaba salir del contorno, convertia una franja que
   debia ser paralela al toperol en una linea serpenteante.
2. El costado tactil se elegia por distancia a los vertices. Un lado recto
   largo con vertices solo en los extremos podia perder contra el lado opuesto
   si este tenia un vertice intermedio, aunque el clic estuviera junto al
   primero.
3. `getpoint` devuelve UCS y la geometria ActiveX esta en WCS. Con UCS girado
   se conservaba un punto de referencia en el sistema equivocado.

## Correcciones

- La guia usa un unico offset para toda la cadena, limitado por el menor
  espacio disponible del corredor. En sectores estrechos se acerca completa
  al toperol, sin cambiar de separacion estacion por estacion.
- La seleccion de costado mide la distancia exacta a todos los segmentos de
  la cadena, no solo a sus vertices.
- El punto marcado se transforma de UCS a WCS al capturarlo.

## Evidencia en Civil 3D 2023 real

Fixture local: copia de 42 MB en
`Documents/URBANISMO/work/verify573_20260920/fixture.dwg`. El maestro no se
abrio, modifico ni guardo.

- Caso controlado que hacia fallar el metodo viejo: lado seleccionado de
  100 m con solo dos vertices, lado contrario con vertice central. Distancias
  exactas: 1,00 m frente a 5,00 m; se eligio el lado marcado.
- Corredor trapezoidal: la guia adopto un unico offset de 2,14006 m; su curva
  resultante permanecio recta.
- Anden real de aproximadamente 188 m: la cadena productiva coincidio con el
  lado largo mas cercano al clic (`3,659645 m`). La generacion termino, se
  empaqueto en una sola referencia de bloque y quedaron cero piezas generadas
  sueltas.
- Medicion directa de las curvas sobre el mismo contorno real:
  - borde cercano de guia: variacion 0,006690 m;
  - borde lejano de guia: variacion 0,007508 m;
  - borde lejano de toperol: variacion 0,000818 m;
  - el toperol quedo a 0,20 m del lado seleccionado;
  - ambos bordes de guia quedaron al mismo costado que el toperol y paralelos
    al recorrido completo.
- Revision visual localizada de `actual_tactile576.png`: lado seleccionado
  rojo, toperol naranja y guia azul siguen los mismos dos quiebres sin el
  serpenteo reportado.

## Limites

La captura del usuario no contenia el DWG ni el contorno editable; por eso no
se pudo regenerar exactamente esa entidad. Se verifico la misma rama de codigo
contra el caso largo real disponible y contra casos controlados que reproducen
las dos causas. Los andenes existentes no se redibujan solos: hay que recrear
o editar el afectado despues de reiniciar Civil 3D y cargar la 5.7.6.
