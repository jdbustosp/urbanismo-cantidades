# Auditoria de ejes y movimiento de tierras

Agente: Codex. Equipo: BOG085CD119BDQN. Actualizado: 2026-09-21 06:23, America/Bogota.
Base: f37211b, motor 5.7.3. Candidato: 5.7.4.

## Alcance y evidencia

Civil 3D 2023 completo, ActiveX y funciones AutoLISP reales, sobre una copia
local del maestro. SUP_TN es un objeto IAeccTinSurface real: no un adaptador.
Laboratorio: `Documents/URBANISMO/work/verify573_20260920`.
No se ha modificado ni recalculado el DWG original. No se ha probado Civil 2026.
Las imagenes de geometria extraida no son capturas ni renders completos del DWG.

## Pendiente geometrico identificado

La via que coincide con la forma de la captura es VIA-17, bloque 13BBED,
eje antiguo 13BACC. El generador 5.7.3 produce un nuevo eje que termina en
el centro del borde superior, en lugar del recorrido quebrado antiguo.
El editor, sin embargo, recuperaba siempre el eje guardado: no invocaba
esa correccion para una via existente.

5.7.4 incorpora en EDITAR la eleccion Conservar/Recalcular/Seleccionar.
Conservar es el valor predeterminado. Recalcular usa la previsualizacion
existente. Si cambia el eje, no se reutilizan silenciosamente las cotas
guardadas en abscisas del eje anterior: se pide rasante nueva por puntos,
o se vuelve a proyectar la capa de textos. No borra el eje anterior porque
puede ser una referencia compartida.

La guia y el toperol del anden URB_ANDEN_13D362 ya se verificaron sobre su
contorno de acabado (374.333717 m2), no sobre la huella de tierras
(677.352848 m2). Resultado 5.7.3: generacion tactil T, 8.735 s; evidencia
en RESULTADO.md/comparison.png del laboratorio. Esto NO demuestra tiempo
total de construccion, todos los simbolos anidados ni todas las geometrias.

## Como calcula cada familia

| Familia | Huella | Diseno y estructura | Integracion |
| --- | --- | --- | --- |
| Via | Ancho medio area/longitud. 5.7.3 omitia los sobreanchos al haber area valida; 5.7.4 los suma | Rasante por estaciones, bombeo, espesor del perfil vial | Areas extremas longitudinales (por defecto 2.5 m), 7 ordenadas transversales |
| Anden | Contorno con 1 m por costado, cuando se pudo construir | Referencia longitudinal de via, bombeo, bordillo, pendiente transversal; estructura por defecto 0.60 m | Triangulos con aristas <=2.5 m; >200 vertices: trapecios recortados por niveles de vertices y paso maximo 0.5 m (5.7.4) |
| Sendero | Huella con sobreanchos cuando puede obtener costados; existe respaldo al contorno original | Referencia de via/anden o cotas; estructura segun tipo configurado | Mismo motor superficial que anden |
| Zona verde | Contorno propio, sin sobreancho automatico | Referencia o cotas; descuenta espesor de tierra negra (por defecto 0.20 m) | Mismo motor superficial |

En los cuatro casos se compara TN con subrasante (terminado menos estructura).
La sobreexcavacion configurada es un minimo de excavacion: con h=0.50 m,
delta=TN-subrasante, corte=max(delta,h), relleno=max(0,h-delta). Ejemplo
delta=-1 da corte=0.50 y relleno=1.50 m por m2. No es un error de resta:
se excava material no portante y se repone. Expansion de corte y factor
de material de relleno se aplican aparte; no confundirlos con volumen geometrico.

Seleccionar una VIA del plugin con rasante almacenada permite consultar
la cota a lo largo del eje; no equivale a tomar solamente la altura del clic.
Un texto/punto suelto sin esa referencia si produce otra hipotesis: una cota
horizontal, dos cotas un plano inclinado, tres o mas un plano ajustado.
No equivale a una superficie de proyecto arbitraria. Senderos y zonas verdes
que referencian una via heredan reglas de bordillo/pendiente de anden: revisar
si representan su diseno arquitectonico, especialmente en zonas anchas.

## Mediciones con superficie real, base 5.7.3

Misma rasante persistida, mismo eje antiguo, h=0.50 m y bombeo=2%.
No son nuevas cantidades aprobadas del maestro ni el resultado del eje corregido.

| Caso | Paso longitudinal | Corte m3 | Relleno m3 | Secciones sin TN |
| --- | ---: | ---: | ---: | ---: |
| VIA-17, sin sobreanchos | 2.5 m | 606.989 | 102.923 | 0 |
| VIA-17, sin sobreanchos | 0.625 m | 607.137 | 102.852 | 0 |
| VIA-17, +1 m por lado | 2.5 m | 809.048 | 127.716 | 0 |
| VIA-17, +1 m por lado | 0.625 m | 809.154 | 127.532 | 0 |
| VIA-08, sin sobreanchos | 2.5 m | 868.906 | 0 | 0 |
| VIA-08, sin sobreanchos | 0.625 m | 868.931 | 0 | 0 |
| VIA-08, +1 m por lado | 2.5 m | 1116.000 | 0 | 0 |
| VIA-08, +1 m por lado | 0.625 m | 1116.020 | 0 | 0 |

Refinar estaciones cambia poco estos casos. Eso prueba estabilidad del
muestreo longitudinal, NO exactitud global: no corrige eje, ancho transversal,
rasante, sobreancho ni datos malos de terreno.

VIA-17: area de calzada 1114.676052 m2, longitud 179.552046 m.
La formula publicada de area con sobreancho da 1473.780144 m2; el calculo
5.7.3 utilizaba solo 1114.676052 m2. Defecto de consistencia confirmado.

## Defectos y limites reproducidos en 5.7.3

1. **Anchos variables:** ancho medio conserva area pero no su distribucion.
   Caso analitico W(x)=2+0.2x, TN=x, x=0..10, diseno=0: resultado 150 m3,
   exacto 166.666667 m3 (-10%). No es un porcentaje aplicable a todo el proyecto.
   Solucion estructural: integrar la huella real de tierras con rasante local,
   o secciones cortadas contra ambos bordes reales, no ancho constante.
2. **Franjas estrechas (corregido 5.7.4):** contorno de 240 vertices, 10 x 0.2 m: el dispatcher
   de produccion escoge barrido; devuelve cero muestras/area, en vez de 2 m2.
   La validacion rechaza el calculo (no guarda un volumen cero como valido).
3. **Barrido normalizado (corregido 5.7.4):** triangulo (0,0),(10,0),(0,1.2), integral de y:
   exacta 2.4; paso 0.5 da 2.46428571 (+2.68%); paso 0.125 da 2.40489130.
   Ahora cada trapecio se divide en triangulos de area/centroide reales,
   sin normalizacion. La integral lineal de esta prueba da exactamente 2.4.
   Queda pendiente un control automatico de convergencia del volumen no lineal.
4. **Cotas colineales (corregido 5.7.4):** (0,100),(5,110),(10,100) sobre una misma recta:
   el ajuste degenerado conserva solo extremos y da 100 donde se marco 110.
   Ahora se ordenan por proyeccion y se interpolan por tramos, conservando110.
5. **Rasante compactada (corregido para nuevos calculos 5.7.4):** se conservaban aproximadamente diez muestras al
   persistir la rasante; pueden perderse quiebres intermedios. Los andenes
   asociados pueden diferir de la rasante usada para calcular la propia via.
   Ahora se incluyen las estaciones de quiebre aunque no coincidan con la
   malla y se guarda perfil completo en URB_VIA_RASANTE_FULL. XDATA mantiene
   copia reducida compatible. Validada consulta por anden y supervivencia
   al empaquetar/extraer para editar. Los perfiles antiguos ya reducidos
   requieren recalculo desde sus fuentes; no se pueden recuperar cotas perdidas.
6. **Cobertura incompleta en vias:** 5.7.3 permitia guardar volumen parcial
   como calculado. 5.7.4 rechaza el resultado y retira cantidades anteriores
   cuando faltan secciones. No sustituye la superficie faltante.
7. **Datos de TN:** una advertencia de cota atipica no corrige ni invalida
   automaticamente los triangulos malos. La precision depende del TIN fuente.

Las redes humedas usan perfiles de zanja y profundidades por elemento;
no se deben equiparar sus volumenes con los de areas urbanas ni inferir
que DOM41 o las profundidades negativas quedaron corregidos por esta prueba.
Esa auditoria completa por tramo no se ha repetido en esta entrega.

## Criterio para aprobar cantidades

No se puede declarar un porcentaje unico de precision. Para aprobar:
corregir datos/ejes, definir una superficie de proyecto compatible con la
arquitectura, conservar sus quiebres, usar la huella exacta, exigir cobertura
completa y comparar contra volumen compuesto TIN de Civil 3D y refinamiento.
El volumen compuesto es exacto respecto de las dos superficies trianguladas
definidas, no respecto de un terreno real no levantado.

Referencia oficial Autodesk:
https://help.autodesk.com/cloudhelp/2024/ENU/Civil3D-UserGuide/files/GUID-A3C76CEC-EE1F-45D4-8D34-E819EB51BD24.htm

## Validacion del candidato

Pruebas Civil2023: final574.txt termina FINISHED; triangulo, rectangulo
estrecho, L concava, coordenadas WCS grandes, sentido inverso, dispatcher
240vertices y contorno real pasan. Rasante82puntos: XDATA<=255caracteres,
perfil completo preservado en bloque, extraccion y consumidor del anden.
Falta TN: production compute rechaza resultado y borra cantidades anteriores.

Motor compartido de areas contra SUP_TN real, rectangulo controlado2m2:
anden espesor0.60: corte1.0/relleno0.6; sendero de prueba espesor0.35:
1.0/1.1; verde espesor0.20:1.0/1.4m3. Coinciden con cuadratura independiente
de0.025m. No equivalen a validar todos los constructores/UI de esas familias.

Prueba completa de acabado del anden real URB_ANDEN_13D362, 21sep06:22:
- area de acabado374.333717m2; tierras677.352848m2;
- build17.922s + empaque9.359s + regen0.844s =28.125s;
- un INSERT, cero piezas generadas sueltas, cero INSERT anidados;
- 3006entidades internas; guia1795, toperol618 (conteo NO son losetas);
- lisa145.268628 + adoquin182.502930 + guia18.354554 + toperol28.207604
  =374.333716m2: diferencia0.000001m2 respecto area neta;
- builder acepto ambas franjas; chain13puntos y rutaOFFSET correcta;
- ML guia91.77 y toperol141.04: no inferir continuidad solo de los totales.
  El caso tiene entrantes/interrupciones: requiere revision visual completa
  para certificar cada interrupcion, simbolo y ausencia de desbordes.

No se incluyo calculo de tierras ni guardado en esos28.125s. No es una
promesa de velocidad para todos los andenes de180m ni render completo.
No se han automatizado los clics del dialogo EDITAR ni probado Civil2026.
Instalacion/commit se registran en PROGRESS y handoff al cerrar la entrega.
