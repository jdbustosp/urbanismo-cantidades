# Andenes 5.5.3: bloque plano y rendimiento

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha: 2026-09-14 America/Bogota. Base ea5d740 (motor5.5.2).

**Cierre08:45: fuente553 verificada e INSTALADA en estePC.**
50OK/0fallos en comparacion plana188/800 y50OK/0fallos en fuente final.
El ensayo independiente de alternativas tuvo54OK/1fallo: el hatch con origen
alterado fue rechazado y NO forma parte de la entrega.

Repeticion con fuente final sin instrumentacion:188m base23.110s ->22.297s
sin guardar (generar12.984->14.203s, empaquetar9.969->7.953s,REGEN.157->.141s).
La mejora TOTAL fue solo3.5% en esta repeticion; no prometer un11.6% uniforme
ni que el motor completo genere siempre en12s. El beneficio confirmado es
el bloque plano y menor tiempo de empaquetado; la lentitud global NO queda
agotada por esta entrega. Sigue pendiente perfilar el caso del maestro.

Fuente final: hatches conservanDXF/capas/angulos/origen; guia4702geometrias
exactas; modos sinGUIA/TOP, soloTOP20cm y soloGUIA40cm ladoopuesto pasan
BUILD/FLAT/0sueltas/orden. Contenedor:AREA658.35->656.91m2, GUIA188.1ML y
TOP188.01ML conservados, patronSI,0fallos. El hueco no cruzaba esas franjas:
el test detecta la amputacion previa, no certifica todos los recortes tactiles.
Rechazo de bloque interno inesperado deja referencias/conteo intactos.

Instalador553 ejecutado, fuente y ambosDLL coinciden con bundle local:
- LSP SHA256:C4332C5F4D83BAA82EF6BF0D12F07B51E34E011A5AF887DECA73BFB363A13B16
- NET2023:374C65FC933331FD215D112907729868894F8F97DA320C94BA625541891B108F
- NET2025:05EDC79D123D969AB5FAC25A34971E34FCA8E301480C0333141EC8E43736B3DE

Cerrar/reabrirCivil para cargar la entrega; no reconstruye andenes existentes.
En otroPC ejecutarINSTALAR.bat una vez por los nuevosDLL. NET8 compilado,
no ejecutado2025/2026. Se cerraron soloPIDpropios8040/18748/29240/9692.

## Cambio implementado

El motor sigue calculando curvas, offsets, recortes y cantidades en AutoLISP.
El modulo UrbAndenFast copia mediante una transaccion.NET las entidades
LINE/LWPOLYLINE de los bloques internos URB_GUIA al bloque final del anden,
elimina esas referencias internas y ordena todos los roles en una pasada.
Conserva coordenadas, bulges, capas, colores y XDATA; no sustituye simbolos
por texturas aproximadas. No reduce detalle, tolerancias ni controles anticirculos.
Las definiciones auxiliares sin referencias pueden permanecer en la tabla
de bloques: no son INSERT anidados ni piezas sueltas. No se hace PURGE global.

La transaccion rechaza bloques internos inesperados o transformados; no
intenta enderezarlos silenciosamente. El preflight comprueba el acelerador
ANTES de comenzar a dibujar y antes de empaquetar. Si un segundo PC no tiene
los DLL nuevos, pide ejecutar INSTALAR.bat: sincronizar solo elLSP no basta
para esta entrega. Los DLL tienen variantes.NETFramework y.NET8.

## Comparacion nativa Civil3D2023, curvaS3.5m de ancho

| Longitud / motor | Generar | Empaquetar | REGEN | Guardar | Total sin guardar |
|---|---:|---:|---:|---:|---:|
|188m base552|8.078s|5.953s|0.094s|0.406s|14.125s|
|188m plano553|7.406s|5.000s|0.078s|0.297s|12.484s|
|800m base552|29.031s|53.515s|0.406s|0.687s|82.952s|
|800m plano553|31.594s|29.344s|0.578s|0.984s|61.516s|

Reduccion medida del total sin guardar:11.6% y25.8%, respectivamente.
NO es generacion instantanea. La medicion se hizo en dibujo de laboratorio,
no sobre el maestro: no explica por si sola los cinco minutos del usuario.
Hay variacion respecto a corridas anteriores; no comparar solo los mejores
tiempos ni descontar dos veces el ahorro del orden.

Prueba plana: geometriaGUIA4702/20001entidades exacta1e-9, atributos de
cantidades iguales,0sueltas,0INSERTanidados candidato y orden real correcto.
La comprobacion fue contra version instrumentada completa de552. La prueba
adicional de la FUENTE FINAL esta registrada en result.txt (50OK/0fallos).

## Las tres opciones ensayadas

1. Orden.NET:5313ms ->47ms en bloque plano188m. Integrado junto con
   aplanamiento seguro; no extrapolar ese factor al tiempo total.
2. Cache de candidatos/cajas durante una creacion:101obstaculos,203aciertos
   y405consultas no almacenadas (la caja de region modificable se recalcula).
   Geometrias/hatches/cantidades coinciden, pero NO mejoro el tiempo global:
   10.547s ->68.640s sin guardar. Las cajas solo15ms ->30ms y busquedas31ms
   ->16ms; la gran variacion esta fuera de esas funciones y no se atribuye
   causalmente a la cache. NO integrada ni vendida como optimizacion.
3. Hatches material.NET:300hatches de100regiones,594msCOM vs78ms.NET+
   328ms de los mismos controles de seguridad. RECHAZADO:200hatchesUSER
   cambiaron origenDXF43/44 a0,0, aunque el angulo permanecio correcto.
   No se incorpora una mejora que corra las juntas. Contornos.NET se basan
   en [AppendLoop de Autodesk](https://help.autodesk.com/cloudhelp/2019/ENU/OARX-ManagedRefGuide/files/OREFNET-Autodesk_AutoCAD_DatabaseServices_Hatch_AppendLoop_HatchLoopTypes_ObjectIdCollection.html).

## Tiempo de guia y toperol

En la primera corrida instrumentada188m: GUIA1078ms (incluye375ms emision
de su lote); TOPEROL94ms creando el patron y157ms en simbolos/juntas de su
franja. Accesibilidad completa2296ms (incluye esas fases: NO sumarlas otra vez).
PatronTOPEROL=SI,0fallos. Esos valores no prueban que no pueda degradarse
en un contorno diferente; el estado se mide por caso.

## Hallazgo de continuidad junto a contenedores

El ensayo con contenedor1.44m2 expuso una rama anterior: la mera cercania
del contenedor anulaba driving-chain incluso en un anden con arcos. El
generador sustituia el eje curvo por una franja recta global y terminaba
conGUIA126.85ML yTOP18.37ML frente a188m. La igualdad entre variantes NO
habria detectado el defecto preexistente.

La fuente553 conserva el eje si la polilinea contiene bulges/arcos y sigue
recortando contra la region neta. Para contornos rectilineos entrantes se
mantiene el respaldo anterior. La prueba final exige area neta menos1.44m2,
perdida tactil no mayor al hueco, patronTOPactivo y ningun fallo de pieza.
No confundir esta prueba con cobertura de todos los contornos entrantes.

## Limites y reproduccion

No se modificaron DWG/Excel originales. No se tomo la pantalla. Pruebas en
Civil3D2023 completo oculto, coordenadas82800/102400, fixtures locales.
Sin nueva imagen renderizada: la preservacion de apariencia se sustenta en
DXF y orden; la correccion junto al contenedor requiere revision visual local.
DLL.NET8 compila, pero NO se ejecutoCivil2025/2026 ni el otroPC.

Lab: Documents/URBANISMO/work/anden_three_options. prepare.ps1 genera
instantaneas instrumentadas desde git ea5d740; wrappers.lsp mide funciones
renombradas, no alias SUBR. helpers/native prueban tres opciones; flat-test
compara188/800; release-check usa release-engine.lsp, copia completa del
motor553. Compilar con ribbon-net/compilar_anden.ps1. No lanzar en maestro.
Los scripts guardan la ruta exacta del fixture; adaptar la ruta al otroPC.

Incidencias de infraestructura conservadas: snapshots iniciales estaban
truncados por transportar el archivo grande en salida de herramienta; se
regeneraron completos conPowerShell. Se corrigio un parentesis del harness
y una copia de fixture intentada antes de terminar el proceso anterior;
ahora se espera WaitForExit antes de copiar. Ninguna cuenta como prueba pasada.
