;;; urbanismo_cantidades.lsp
;;; Herramientas para cuantificar andenes y vias a partir de polilineas cerradas.
;;; Compatible con AutoCAD para Windows (Visual LISP / ActiveX).
;;; 4.23.0: interpola conexiones, incorpora bombeo y memorias con propiedades depuradas.
;;; 4.22.1: simplifica rasantes/propiedades y configura apariencia de tramos.
;;; 4.17.7: evita unidades adicionales por residuos decimales de punto flotante.
;;; 4.17.6: separa giro de 90 grados y cambio del extremo inicial.
;;; 4.17.5: ancla la modulacion al contorno real y evita losetas iniciales cortadas.
;;; 4.17.4: conserva la elevacion y permite invertir la modulacion del anden.
;;; Integra el sentido en la misma XDATA para evitar perdida de metadatos.
;;; 4.17.2: evita confundir los cierres cortos con nuevos brazos del anden.
;;; 4.17.1: orienta andenes irregulares por ejes dominantes locales.
;;; 4.17.0: crea zonas verdes y cuantifica area y tierra negra.
;;; 4.16.6: alinea la cuadrilla al eje largo considerando el UCS del dibujo.
;;; 4.16.4: mantiene franjas transversales y rota correctamente su reticula.
;;; 4.16.3: orienta las franjas de loseta paralelas al eje del anden.
;;; 4.16.2: conserva la correccion grafica aunque las tierras queden pendientes.
;;; 4.16.1: alinea graficamente las losetas con el eje principal del anden.
;;; 4.16.0: calcula y guarda pendientes variables de andenes vinculados a vias.
;;; 4.15.3: simplifica creacion de redes y limpia extremos automaticos huerfanos.
;;; 4.15.2: extrae automaticamente cotas de terreno de redes desde SUP_TN.
;;; 4.15.1: descuenta franjas tactiles del area contractual de adoquin.
;;; 4.15.0: alinea actividades exportadas con los presupuestos de vias y andenes.
;;; 4.14.1: corrige desbordamiento entero al generar el token temporal de sesion.
;;; 4.14.0: controles de integridad, Excel maestro multi-DWG y depuracion general.
;;; 4.13.1: depura el menu principal retirando Mantenimiento e Informacion.
;;; 4.13.0: topologia, geometria 2D/3D, controles y cantidades constructivas de redes.
;;; 4.12.3: corrige exportacion Excel y muestra errores reales sin llamadas invalidas.
;;; 4.12.2: corrige la carga interpretada del recolector de cantidades de redes.
;;; 4.12.1: limpia de la sesion los comandos heredados al recargar.
;;; 4.12.0: interfaz unificada; solo URBANISMO y EDITAR quedan como comandos.
;;; 4.11.3: creacion de redes disponible solo desde el menu URBANISMO.
;;; 4.11.2: funciones Excel disponibles solo desde el menu URBANISMO.
;;; 4.11.1: vinculo compatible con libros XLSX y XLSM sin perder macros.
;;; 4.11.0: tabla Excel unica, vinculo persistente y actualizacion segura.
;;; 4.10.1: exportacion Excel con separadores colombianos y apertura automatica.
;;; 4.10.0: vinculo persistente via-anden y exportacion consolidada a Excel.
;;; Conserva las validaciones y la malla orientada incorporadas en 4.9.0.

(vl-load-com)

(setq *urb-version* "4.23.2")
(setq *urb-memory-reactor-busy* nil)
(setq *urb-memory-pending* nil)
(setq *urb-memory-command-scheduled* nil)
(setq *urb-schema-version* "23")
(setq *urb-prefab-schema-version* "1")
(setq *urb-green-schema-version* "1")
(setq *urb-excel-table-schema* "2")
(setq *mp-terrain-surface-name* "SUP_TN")
(setq *mp-network-construction-enabled* T)
;; Si no es nil, mp:tramo-depth-profile usa min(terreno,subrasante) en vez
;; de solo terreno -- ver mp:select-road-subrasante-reference. Se pone y se
;; quita alrededor de cada llamada a mp:insert-tramo-forced, nunca queda
;; encendido entre comandos.
(setq *mp-tramo-road-ref* nil)
(setq *urb-pattern-scale* 1.0)
(setq *urb-etapa-list* '("1" "2" "3" "4" "5" "6" "7" "8" "9"))
(setq *urb-material-list* '("Loseta"))
(setq *urb-yes-no-list* '("No" "Si"))
(setq *urb-loseta-format-list* '("40 x 40 cm" "20 x 20 cm"))
(setq *urb-anden-grade-source-list*
  '("Via creada" "Cotas seleccionadas" "Alineamiento + cotas"))
(setq *urb-prefab-list* '("Bordillo" "Sardinel" "Canuela"))
(setq *urb-prefab-mode-list* '("Interior" "Exterior"))
(setq *urb-unit-warning-dwg* nil)
(setq *urb-current-tactile-side-point* nil)
;; Distancia de la fila de GUIA al borde de la via (m). U-201 usa 2.50 en
;; los modulos de curva (fila tactil intermedia); antes estaba fijo en
;; 1.20. Configurable en un solo lugar por si otro proyecto usa otra.
(setq *urb-guide-offset* 2.50)
;; Par de cotas (inicial final) seleccionadas en el flujo de via modo
;; "Pendiente"; se limpia al terminar cada creacion de via.
(setq *urb-road-picked-cotas* nil)
;; Punto de insercion de la tabla de verificacion de via, puesto SOLO por
;; urb:road-audit-table-command (Cantidades). Si es nil, el calculo de
;; movimiento de tierras NO crea tabla (2026-08-11: ya no se crea sola).
(setq *urb-road-audit-point* nil)
;; Records (distancia-eje cota) del modo Pendiente con 3+ cotas (pozos
;; sobre la via); se limpia al terminar cada creacion de via.
(setq *urb-road-picked-stations* nil)
;; Bordes extremos (e1 e2) elegidos al calcular el eje automatico; los
;; sardineles los reutilizan sin repreguntar. Se limpia por creacion.
(setq *urb-road-end-edges* nil)
;; Lado elegido para el toperol/guia ("Arriba"/"Abajo"/"Izquierda"/"Derecha").
;; Tiene prioridad sobre *urb-current-tactile-side-point* en
;; urb:reference-v-edge; se resuelve por-anden con el bbox de cada contorno.
(setq *urb-current-tactile-side-choice* nil)
(setq *urb-surface-cache* nil)
(setq *urb-session-token*
  ;; DATE es un real juliano de aproximadamente 2.46e6. Multiplicarlo y
  ;; pasarlo por ITOA excedia el rango de entero de AutoLISP e interrumpia
  ;; APPLOAD con "bad argument type: fixnump". RTOS evita esa conversion.
  (strcat
    (rtos (getvar "MILLISECS") 2 0)
    "_"
    (vl-string-translate ".," "__" (rtos (getvar "DATE") 2 8))))

(defun urb:temp-file (base extension)
  (strcat (getvar "TEMPPREFIX") base "_" *urb-session-token* extension)
)

(defun urb:patterns-folder (/ root base folder)
  ;; Los patrones ya no se publican en %TEMP% ni agregan esa carpeta completa
  ;; al Support Path. Se usa una carpeta estable y exclusiva de la aplicacion.
  (setq root (getenv "LOCALAPPDATA")
        base
          (strcat
            (if (and root (/= root "")) root (getvar "TEMPPREFIX"))
            "\\UrbanismoCantidades")
        folder (strcat base "\\Patterns"))
  (if (not (vl-file-directory-p base))
    (vl-catch-all-apply 'vl-mkdir (list base)))
  (if (not (vl-file-directory-p folder))
    (vl-catch-all-apply 'vl-mkdir (list folder)))
  folder
)

(defun urb:prompt-tactile-side-point (/ result)
  ;; Un solo click del lado de la via/sardinel: el toperol queda pegado al
  ;; borde del anden mas cercano a ese punto, la guia 1.20m hacia adentro.
  ;; (El desplegable Arriba/Abajo/Izquierda/Derecha que existio brevemente
  ;; se quito a pedido del usuario: con andenes diagonales "arriba/abajo"
  ;; es ambiguo; el click sobre el lado real no.)
  (setq result
    (vl-catch-all-apply
      'getpoint
      (list
        "\nMarque un punto del lado de la VIA/sardinel (lado del toperol): ")))
  (if (vl-catch-all-error-p result) nil result)
)

(defun urb:tactile-side-point-from-choice
  (choice points / minx miny maxx maxy pt cx cy diag)
  ;; Traduce una eleccion de lado (Arriba/Abajo/Izquierda/Derecha, en
  ;; coordenadas de mundo/pantalla) a un punto sintetico muy afuera del
  ;; bbox del contorno, del lado pedido. Ya NO esta expuesta en la
  ;; interfaz (el usuario marca un punto con click); se conserva como
  ;; mecanismo interno para las verificaciones headless, que necesitan
  ;; fijar un lado sin emular clicks (global *urb-current-tactile-side-choice*).
  (if (null points)
    nil
    (progn
      (setq minx (car (car points)) maxx minx
            miny (cadr (car points)) maxy miny)
      (foreach pt (cdr points)
        (if (< (car pt) minx) (setq minx (car pt)))
        (if (> (car pt) maxx) (setq maxx (car pt)))
        (if (< (cadr pt) miny) (setq miny (cadr pt)))
        (if (> (cadr pt) maxy) (setq maxy (cadr pt))))
      (setq cx (* 0.5 (+ minx maxx)) cy (* 0.5 (+ miny maxy)))
      (setq diag (max 1.0 (distance (list minx miny) (list maxx maxy))))
      (cond
        ((= choice "Arriba") (list cx (+ maxy diag)))
        ((= choice "Abajo") (list cx (- miny diag)))
        ((= choice "Izquierda") (list (- minx diag) cy))
        ((= choice "Derecha") (list (+ maxx diag) cy))
        (T nil))))
)

;; Marcas de sesion: fuerzan a reescribir los DCL temporales tras recargar el LSP.
(setq *urb-anden-dcl-ok* nil)
(setq *urb-prefab-dcl-ok* nil)
(setq *urb-green-dcl-ok* nil)
(setq *urb-stage-dcl-ok* nil)

(defun urb:safe-string (value default)
  (cond
    ((eq (type value) 'STR) value)
    ((eq value T) "Si")
    ((null value) default)
    (T (vl-princ-to-string value)))
)

(defun urb:string-equal-p (left right)
  (= (strcase (urb:safe-string left ""))
     (strcase (urb:safe-string right "")))
)

(defun urb:yes-p (value)
  (urb:string-equal-p value "Si")
)

;; Normaliza referencias antes de cruzar la frontera ENAME/ActiveX.
;; Nunca acepta T como si fuera una entidad: ese valor produjo el error
;; "unable to get ObjectID: T" durante el calculo de un anden.
(defun urb:valid-ename-p (value / result)
  (if (= (type value) 'ENAME)
    (progn
      (setq result (vl-catch-all-apply 'entget (list value)))
      (and (not (vl-catch-all-error-p result)) result))
    nil)
)

(defun urb:valid-vla-object-p (value / result)
  (if (= (type value) 'VLA-OBJECT)
    (progn
      (setq result (vl-catch-all-apply 'vla-get-Handle (list value)))
      (and (not (vl-catch-all-error-p result)) result))
    nil)
)

(defun urb:as-ename (value / result)
  (cond
    ((urb:valid-ename-p value) value)
    ((urb:valid-vla-object-p value)
      (setq result
        (vl-catch-all-apply 'vlax-vla-object->ename (list value)))
      (if (and (not (vl-catch-all-error-p result))
               (urb:valid-ename-p result))
        result
        nil))
    (T nil))
)

(defun urb:as-vla-object (value / ename result)
  (cond
    ((urb:valid-vla-object-p value) value)
    ((setq ename (urb:as-ename value))
      (setq result
        (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
      (if (and (not (vl-catch-all-error-p result))
               (urb:valid-vla-object-p result))
        result
        nil))
    (T nil))
)

;; Convierte entradas decimales con punto o coma. Tambien reconoce los dos
;; formatos con miles: 1.234,56 (Colombia) y 1,234.56 (internacional).
(defun urb:remove-character (text character)
  (vl-list->string
    (vl-remove (ascii character) (vl-string->list text))))

(defun urb:parse-real (value / text comma-pos dot-pos parsed)
  (setq text (vl-string-trim " " (urb:safe-string value ""))
        comma-pos (vl-string-position 44 text 0 T)
        dot-pos (vl-string-position 46 text 0 T))
  (cond
    ((and comma-pos dot-pos)
      (if (> comma-pos dot-pos)
        (setq text
          (vl-string-translate "," "." (urb:remove-character text ".")))
        (setq text (urb:remove-character text ","))))
    (comma-pos (setq text (vl-string-translate "," "." text))))
  (if (/= text "")
    (progn
      (setq parsed (vl-catch-all-apply 'distof (list text 2)))
      (if (vl-catch-all-error-p parsed) nil parsed))
    nil)
)

;; Todas las cantidades del programa se expresan en m, m2 y m3. No se
;; convierte el dibujo automaticamente: se exige confirmacion una vez por
;; DWG cuando INSUNITS no declara metros.
(defun urb:confirm-meter-units (/ units drawing choice)
  (setq units (getvar "INSUNITS"))
  (setq drawing
    (strcase
      (strcat (urb:safe-string (getvar "DWGPREFIX") "")
              (urb:safe-string (getvar "DWGNAME") ""))))
  (cond
    ((= units 6) T)
    ((= drawing *urb-unit-warning-dwg*) T)
    (T
      (initget "Si No")
      (setq choice
        (getkword
          (strcat
            "\nEl dibujo no tiene INSUNITS en metros (codigo "
            (itoa units)
            "). El programa supone 1 unidad = 1 m."
            " Continuar [Si/No] <No>: ")))
      (if (= choice "Si")
        (progn (setq *urb-unit-warning-dwg* drawing) T)
        nil)))
)

;; Remove public commands left in memory by older versions.
(foreach old-command
  '(c:EDITARANDEN c:UNIFICARANDEN c:LIMPIARANDEN
    c:AGRUPARANDEN c:REPARARANDEN c:AREAANDEN
    c:URBANDEN c:URBLOSETA c:BORDILLO c:SARDINEL c:CANUELA
    c:URBVIA c:URBCANT c:URBAYUDA
    c:AP c:BT c:INS_TRAMO_BT_AP
    c:CAJA_ELECTRICA c:CAJA_ELEC c:INS_ELEM_ELEC
    c:INS_ACC_ACUEDUCTO c:ACC_ACUEDUCTO
    c:AGUAS_LLUVIAS c:INS_TRAMO_RED
    c:SANITARIO c:PLUVIAL c:ACUEDUCTO
    c:MT c:MEDIA_TENSION c:MEDIATENSION c:ALUMBRADO c:INS_TRAMO_MT)
  (vl-catch-all-apply 'vl-acad-undefun (list old-command)))

;; --- Etapas/subetapas EDITABLES y des/habilitables (2026-08-11) ------
;; El catalogo vive en la configuracion del dibujo (URB_ETAPAS_CATALOGO,
;; misma mecanica que los perfiles de via); el interruptor global en
;; URB_ETAPAS_ACTIVO. Se administra desde Ajustes -> Etapas y subetapas
;; (urb:etapas-manager-command). Con etapas DESHABILITADAS, los popups
;; "etapa"/"subetapa" de TODOS los dialogos de creacion quedan grises
;; (centralizado en urb:fill-popup y mp:fill-popup) y los elementos se
;; crean con la etapa por defecto.
(defun urb:default-etapas-catalog ()
  (list
    (list "1" (list "1"))
    (list "2" (list "2"))
    (list "3" (list "3" "3A" "3B"))
    (list "4" (list "4" "4A" "4B" "4C" "4D" "4E"))
    (list "5" (list "5A" "5B" "5C" "5D" "5E"))
    (list "6" (list "6"))
    (list "7" (list "7"))
    (list "8" (list "8A" "8B" "8C"))
    (list "9" (list "9A" "9B" "9C" "9D" "9E"))))
(setq *urb-etapas-catalog* (urb:default-etapas-catalog))

(defun urb:refresh-etapas-catalog (/ raw parsed)
  ;; corre al cargar el lsp (despues de que exista urb:config-read) y
  ;; tras cada edicion del catalogo
  (setq raw (urb:config-read "URB_ETAPAS_CATALOGO"))
  (if (and raw (/= raw ""))
    (progn
      (setq parsed (urb:read-lisp-safe raw))
      (if (and parsed (listp parsed) (listp (car parsed)))
        (setq *urb-etapas-catalog* parsed))))
  (setq *urb-etapa-list* (mapcar 'car *urb-etapas-catalog*))
  (setq *mp-etapa-list* *urb-etapa-list*)
  (princ))

(defun urb:save-etapas-catalog ()
  (urb:config-write "URB_ETAPAS_CATALOGO"
    (urb:serialize-lisp *urb-etapas-catalog*))
  (setq *urb-etapa-list* (mapcar 'car *urb-etapas-catalog*))
  (setq *mp-etapa-list* *urb-etapa-list*))

(defun urb:etapas-enabled-p ()
  (/= (urb:safe-string (urb:config-read "URB_ETAPAS_ACTIVO") "1") "0"))

;; separa "3,3A,3B" (o con ; o espacios) en lista limpia de strings
(defun urb:split-subetapas (text / result token i c)
  (setq text (urb:safe-string text "") result nil token "" i 1)
  (while (<= i (strlen text))
    (setq c (substr text i 1))
    (if (member c '("," ";" " "))
      (progn
        (if (/= token "") (setq result (cons token result)))
        (setq token ""))
      (setq token (strcat token c)))
    (setq i (1+ i)))
  (if (/= token "") (setq result (cons token result)))
  (reverse result))

(defun urb:etapas-print-catalog (/ entry linea)
  (prompt
    (strcat "\nEtapas "
      (if (urb:etapas-enabled-p) "HABILITADAS" "DESHABILITADAS (grises en los dialogos)")
      ":"))
  (foreach entry *urb-etapas-catalog*
    (setq linea "")
    (foreach s (cadr entry)
      (setq linea (strcat linea (if (= linea "") "" ", ") s)))
    (prompt (strcat "\n  Etapa " (car entry) " -> subetapas: " linea)))
  (princ))

;; texto "3A,3B" de las subetapas de una etapa (para el edit_box)
(defun urb:etapas-subs-string (etapa / linea)
  (setq linea "")
  (foreach s (urb:subetapas-for etapa)
    (setq linea (strcat linea (if (= linea "") "" ",") s)))
  linea)

(defun urb:etapas-replace-at (i newentry / k out entry)
  (setq k 0 out nil)
  (foreach entry *urb-etapas-catalog*
    (setq out (cons (if (= k i) newentry entry) out))
    (setq k (1+ k)))
  (setq *urb-etapas-catalog* (reverse out)))

(defun urb:etapas-remove-at (i / k out entry)
  (setq k 0 out nil)
  (foreach entry *urb-etapas-catalog*
    (if (/= k i) (setq out (cons entry out)))
    (setq k (1+ k)))
  (setq *urb-etapas-catalog* (reverse out)))

;; Gestor de Ajustes -> Etapas y subetapas (2026-08-11 v2: CUADRO DE
;; DIALOGO con desplegables, pedido del usuario -- no menu de linea de
;; comandos). El dialogo se reabre tras cada operacion para refrescar la
;; lista; el toggle Habilitadas se persiste en cada salida. Con etapas
;; deshabilitadas, los popups etapa/subetapa de los dialogos de creacion
;; quedan grises (urb:fill-popup / mp:fill-popup).
(defun urb:etapas-manager-command
  (/ filename dcl-id done code idx activo subs nueva nuevasubs lst etapa)
  (urb:refresh-etapas-catalog)
  (setq done nil idx 0)
  (while (not done)
    (setq filename (urb:write-main-menu-dcl))
    (setq dcl-id (if filename (load_dialog filename) -1))
    (if (and dcl-id (> dcl-id 0) (new_dialog "urb_etapas" dcl-id))
      (progn
        (if (>= idx (length *urb-etapa-list*)) (setq idx 0))
        ;; llenado DIRECTO (sin urb:fill-popup: esa pondria gris el popup
        ;; del propio gestor cuando las etapas estan deshabilitadas)
        (start_list "etapa")
        (mapcar 'add_list *urb-etapa-list*)
        (end_list)
        (set_tile "etapa" (itoa idx))
        (set_tile "activo" (if (urb:etapas-enabled-p) "1" "0"))
        (set_tile "subs" (urb:etapas-subs-string (nth idx *urb-etapa-list*)))
        (action_tile "etapa"
          (strcat
            "(setq idx (atoi $value))"
            "(set_tile \"subs\" (urb:etapas-subs-string (nth idx *urb-etapa-list*)))"))
        (action_tile "guardar"
          "(setq activo (get_tile \"activo\") subs (get_tile \"subs\"))(done_dialog 2)")
        (action_tile "quitar"
          "(setq activo (get_tile \"activo\"))(done_dialog 3)")
        (action_tile "agregar"
          "(setq activo (get_tile \"activo\") nueva (get_tile \"nueva\") nuevasubs (get_tile \"nuevasubs\"))(done_dialog 4)")
        (action_tile "restaurar"
          "(setq activo (get_tile \"activo\"))(done_dialog 5)")
        (action_tile "accept"
          "(setq activo (get_tile \"activo\"))(done_dialog 1)")
        (setq code (start_dialog))
        (unload_dialog dcl-id)
        (if activo
          (progn
            (urb:config-write "URB_ETAPAS_ACTIVO" (if (= activo "1") "1" "0"))
            ;; 2026-08-12: los tiles etapa/subetapa se OCULTAN (no se
            ;; emiten en el DCL) cuando las etapas estan deshabilitadas;
            ;; se invalidan los caches para que los dialogos de creacion
            ;; se regeneren con el estado nuevo del toggle.
            (setq *urb-anden-dcl-ok* nil
                  *urb-prefab-dcl-ok* nil
                  *urb-green-dcl-ok* nil
                  *urb-stage-dcl-ok* nil
                  *mp-dcl-listas-ok* nil
                  *mp-dcl-puntos-ok* nil)))
        (cond
          ((= code 2)
            (setq lst (urb:split-subetapas subs))
            (setq etapa (nth idx *urb-etapa-list*))
            (if (and lst etapa)
              (progn
                (urb:etapas-replace-at idx (list etapa lst))
                (urb:save-etapas-catalog))
              (alert "Escriba al menos una subetapa.")))
          ((= code 3)
            (if (<= (length *urb-etapas-catalog*) 1)
              (alert "Debe quedar al menos una etapa.")
              (progn
                (urb:etapas-remove-at idx)
                (urb:save-etapas-catalog)
                (setq idx 0))))
          ((= code 4)
            (setq nueva (vl-string-trim " " (urb:safe-string nueva "")))
            (cond
              ((= nueva "") (alert "Escriba el nombre de la etapa nueva."))
              ((assoc nueva *urb-etapas-catalog*) (alert "Esa etapa ya existe."))
              (T
                (setq lst (urb:split-subetapas nuevasubs))
                (if (null lst) (setq lst (list nueva)))
                (setq *urb-etapas-catalog*
                  (append *urb-etapas-catalog* (list (list nueva lst))))
                (urb:save-etapas-catalog)
                (setq idx (1- (length *urb-etapa-list*))))))
          ((= code 5)
            (setq *urb-etapas-catalog* (urb:default-etapas-catalog))
            (urb:save-etapas-catalog)
            (setq idx 0))
          (T (setq done T))))
      (progn
        (prompt "\nNo se pudo abrir el dialogo de etapas.")
        (setq done T))))
  (princ))

(defun urb:subetapas-for (etapa / entry)
  (setq entry (assoc etapa *urb-etapas-catalog*))
  (if entry (cadr entry) (list (urb:safe-string etapa "1")))
)

(defun urb:index-of (value items / index found)
  (setq value (urb:safe-string value ""))
  (setq index 0)
  (while (and items (null found))
    (if (= (strcase value) (strcase (car items)))
      (setq found index)
      (progn
        (setq index (1+ index))
        (setq items (cdr items))))
  )
  (if found found 0)
)

(defun urb:fill-popup (key items selected)
  (start_list key)
  (mapcar 'add_list items)
  (end_list)
  (set_tile key (itoa selected))
  ;; etapas deshabilitadas -> el popup queda gris en TODOS los dialogos
  (if (and (member key '("etapa" "subetapa"))
           (not (urb:etapas-enabled-p)))
    (mode_tile key 1))
)

(defun urb:dialog-update-subetapa ()
  (setq *urb-dialog-etapa*
    (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
  (urb:fill-popup
    "subetapa"
    (urb:subetapas-for *urb-dialog-etapa*)
    0)
)

(defun urb:write-dialog-dcl (prefix cache-flag lines / filename stream)
  ;; Helper generico compartido por write-anden-dcl/write-prefab-dcl/write-green-dcl:
  ;; cache-flag es un simbolo citado ('*urb-x-dcl-ok*) para leer/escribir el flag
  ;; de cache de cada dialogo sin duplicar la logica de escritura del .dcl.
  (setq filename (urb:temp-file prefix ".dcl"))
  (cond
    ((and (eval cache-flag) (findfile filename)) filename)
    ((setq stream (open filename "w"))
      (foreach line lines (write-line line stream))
      (close stream)
      (set cache-flag T)
      filename)
    (T nil))
)

(defun urb:write-anden-dcl ()
  (urb:write-dialog-dcl
    "urbanismo_anden"
    '*urb-anden-dcl-ok*
    (list
      "urbanismo_anden : dialog { label = \"Datos del anden\";"
      ": boxed_column { label = \"Clasificacion\";"
      ": popup_list { label = \"Material\"; key = \"material\"; }"
      ": popup_list { label = \"Formato de loseta\"; key = \"formato\"; }"
      ;; 2026-08-12: si las etapas estan deshabilitadas los tiles NO se
      ;; emiten (pedido del usuario: ocultar, no engrisar). El gestor de
      ;; etapas resetea *urb-anden-dcl-ok* al cambiar el toggle.
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Etapa\"; key = \"etapa\"; }" "")
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" "")
      "}"
      ": boxed_column { label = \"Accesibilidad\";"
      ": popup_list { label = \"Loseta guia\"; key = \"guia\"; }"
      ": popup_list { label = \"Loseta toperol\"; key = \"toperol\"; }"
      "}"
      ;; 2026-08-12: Modulacion (orientacion/extremo) eliminada del dialogo
      ;; y "Calcular" tambien (el movimiento de tierras SIEMPRE se calcula).
      ": boxed_column { label = \"Movimiento de tierras\";"
      ": popup_list { label = \"Superficie TN\"; key = \"superficie\"; }"
      ": popup_list { label = \"Rasante desde\"; key = \"rasante\"; }"
      "} ok_cancel; }"))
)

(defun urb:dialog-anden
  (current-material current-format current-etapa current-subetapa
   current-guia current-toperol current-calculate current-surface current-grade-source
   current-orientation current-start orientation-list start-list
   / filename dcl-id accepted subetapas result surfaces)
  ;; orientation-list/start-list vienen del llamador porque EDITAR necesita
  ;; la opcion extra "Conservar" (mantener el sentido de cada anden) que en
  ;; la creacion no tiene sentido. El lado de la via/toperol NO va en el
  ;; dialogo: se marca con un click despues de dibujar (urb:prompt-tactile-side-point).
  (setq filename (urb:write-anden-dcl))
  (setq current-material (urb:safe-string current-material "Loseta"))
  (setq current-format (urb:safe-string current-format "40 x 40 cm"))
  (setq current-etapa (urb:safe-string current-etapa "1"))
  (setq current-subetapa (urb:safe-string current-subetapa current-etapa))
  (setq current-guia (urb:safe-string current-guia "No"))
  (setq current-toperol (urb:safe-string current-toperol "No"))
  (setq current-calculate (urb:safe-string current-calculate "Si"))
  (setq current-grade-source (urb:safe-string current-grade-source "Via creada"))
  (setq current-orientation
    (urb:safe-string current-orientation (car orientation-list)))
  (setq current-start (urb:safe-string current-start (car start-list)))
  (setq surfaces (urb:civil-surface-names))
  (setq current-surface
    (urb:safe-string current-surface
      (if surfaces (car surfaces) "Seleccionar en dibujo")))
  (setq surfaces (urb:add-unique-string current-surface surfaces))
  (if (and filename
           (> (setq dcl-id (load_dialog filename)) 0)
           (new_dialog "urbanismo_anden" dcl-id))
    (progn
      (urb:fill-popup
        "material"
        *urb-material-list*
        (urb:index-of current-material *urb-material-list*))
      (urb:fill-popup
        "formato"
        *urb-loseta-format-list*
        (urb:index-of current-format *urb-loseta-format-list*))
      ;; 2026-08-12: etapa/subetapa solo existen en el DCL cuando las
      ;; etapas estan habilitadas -- get_tile sobre un tile ausente truena,
      ;; asi que todo lo relacionado va condicionado.
      (if (urb:etapas-enabled-p)
        (progn
          (urb:fill-popup
            "etapa"
            *urb-etapa-list*
            (urb:index-of current-etapa *urb-etapa-list*))
          (setq *urb-dialog-etapa*
            (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
          (setq subetapas (urb:subetapas-for *urb-dialog-etapa*))
          (urb:fill-popup
            "subetapa"
            subetapas
            (urb:index-of current-subetapa subetapas))
          (action_tile "etapa" "(urb:dialog-update-subetapa)")))
      (urb:fill-popup
        "guia"
        *urb-yes-no-list*
        (urb:index-of current-guia *urb-yes-no-list*))
      (urb:fill-popup
        "toperol"
        *urb-yes-no-list*
        (urb:index-of current-toperol *urb-yes-no-list*))
      (urb:fill-popup
        "superficie" surfaces (urb:index-of current-surface surfaces))
      (urb:fill-popup
        "rasante" *urb-anden-grade-source-list*
        (urb:index-of current-grade-source *urb-anden-grade-source-list*))
      (action_tile
        "accept"
        (strcat
          "(setq *urb-dialog-material-index* (atoi (get_tile \"material\"))"
          " *urb-dialog-format-index* (atoi (get_tile \"formato\"))"
          (if (urb:etapas-enabled-p)
            (strcat
              " *urb-dialog-etapa-index* (atoi (get_tile \"etapa\"))"
              " *urb-dialog-subetapa-index* (atoi (get_tile \"subetapa\"))")
            "")
          " *urb-dialog-guia-index* (atoi (get_tile \"guia\"))"
          " *urb-dialog-toperol-index* (atoi (get_tile \"toperol\"))"
          " *urb-dialog-surface-index* (atoi (get_tile \"superficie\"))"
          " *urb-dialog-grade-index* (atoi (get_tile \"rasante\")))"
          "(done_dialog 1)"))
      (setq accepted (= 1 (start_dialog)))
      (unload_dialog dcl-id)
      (if accepted
        (progn
          (setq current-material
            (nth *urb-dialog-material-index* *urb-material-list*))
          (setq current-format
            (nth *urb-dialog-format-index* *urb-loseta-format-list*))
          (if (urb:etapas-enabled-p)
            (progn
              (setq current-etapa
                (nth *urb-dialog-etapa-index* *urb-etapa-list*))
              (setq subetapas (urb:subetapas-for current-etapa))
              (setq current-subetapa
                (nth *urb-dialog-subetapa-index* subetapas))))
          (setq current-guia
            (nth *urb-dialog-guia-index* *urb-yes-no-list*))
          (setq current-toperol
            (nth *urb-dialog-toperol-index* *urb-yes-no-list*))
          ;; Movimiento de tierras SIEMPRE se calcula (2026-08-12).
          (setq current-calculate "Si")
          (setq current-surface
            (nth *urb-dialog-surface-index* surfaces))
          (setq current-grade-source
            (nth *urb-dialog-grade-index* *urb-anden-grade-source-list*))
          ;; Modulacion eliminada del dialogo: la orientacion y el extremo
          ;; conservan lo que paso el llamador (creacion = "Automatico"/
          ;; "Normal"; EDITAR = "Conservar").
          (setq result
            (list current-material current-format current-etapa current-subetapa
                  current-guia current-toperol current-calculate
                  current-surface current-grade-source
                  current-orientation current-start)))))
  )
  result
)

(defun urb:write-prefab-dcl ()
  (urb:write-dialog-dcl
    "urbanismo_prefabricado"
    '*urb-prefab-dcl-ok*
    (list
      "urbanismo_prefabricado : dialog { label = \"Datos del prefabricado\";"
      ": popup_list { label = \"Tipo\"; key = \"tipo\"; }"
      ": edit_box { label = \"Espesor en metros\"; key = \"espesor\"; edit_width = 12; }"
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Etapa\"; key = \"etapa\"; }" "")
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" "")
      ": popup_list { label = \"Modelado\"; key = \"modo\"; }"
      "ok_cancel; }"))
)

(defun urb:dialog-prefab
  (current-type current-width current-etapa current-subetapa current-mode
   / filename dcl-id accepted subetapas result width-value)
  (setq current-type (urb:safe-string current-type "Bordillo"))
  (setq current-width
    (if (numberp current-width)
      current-width
      (urb:parse-real (urb:safe-string current-width "0.20"))))
  (if (null current-width) (setq current-width 0.20))
  (if (<= current-width 0.0) (setq current-width 0.20))
  (setq current-etapa (urb:safe-string current-etapa "1"))
  (setq current-subetapa
    (urb:safe-string current-subetapa current-etapa))
  (setq current-mode (urb:safe-string current-mode "Interior"))
  (setq filename (urb:write-prefab-dcl))
  (if (and filename
           (> (setq dcl-id (load_dialog filename)) 0)
           (new_dialog "urbanismo_prefabricado" dcl-id))
    (progn
      (urb:fill-popup
        "tipo" *urb-prefab-list*
        (urb:index-of current-type *urb-prefab-list*))
      (set_tile "espesor" (rtos current-width 2 3))
      (if (urb:etapas-enabled-p)
        (progn
          (urb:fill-popup
            "etapa" *urb-etapa-list*
            (urb:index-of current-etapa *urb-etapa-list*))
          (setq *urb-dialog-etapa*
            (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
          (setq subetapas (urb:subetapas-for *urb-dialog-etapa*))
          (urb:fill-popup
            "subetapa" subetapas
            (urb:index-of current-subetapa subetapas))
          (action_tile "etapa" "(urb:dialog-update-subetapa)")))
      (urb:fill-popup
        "modo" *urb-prefab-mode-list*
        (urb:index-of current-mode *urb-prefab-mode-list*))
      (action_tile
        "accept"
        (strcat
          "(setq *urb-dialog-prefab-index* (atoi (get_tile \"tipo\"))"
          (if (urb:etapas-enabled-p)
            (strcat
              " *urb-dialog-etapa-index* (atoi (get_tile \"etapa\"))"
              " *urb-dialog-subetapa-index* (atoi (get_tile \"subetapa\"))")
            "")
          " *urb-dialog-prefab-mode-index* (atoi (get_tile \"modo\"))"
          " *urb-dialog-prefab-width* (get_tile \"espesor\"))"
          "(done_dialog 1)"))
      (setq accepted (= 1 (start_dialog)))
      (unload_dialog dcl-id)
      (if accepted
        (progn
          (setq current-type
            (nth *urb-dialog-prefab-index* *urb-prefab-list*))
          (if (urb:etapas-enabled-p)
            (progn
              (setq current-etapa
                (nth *urb-dialog-etapa-index* *urb-etapa-list*))
              (setq subetapas (urb:subetapas-for current-etapa))
              (setq current-subetapa
                (nth *urb-dialog-subetapa-index* subetapas))))
          (setq current-mode
            (nth *urb-dialog-prefab-mode-index*
              *urb-prefab-mode-list*))
          (setq width-value (urb:parse-real *urb-dialog-prefab-width*))
          (if (or (null width-value) (<= width-value 0.0))
            (setq width-value current-width))
          (setq result
            (list current-type width-value current-etapa
                  current-subetapa current-mode))))))
  result
)

(defun urb:write-green-dcl ()
  (urb:write-dialog-dcl
    "urbanismo_zona_verde"
    '*urb-green-dcl-ok*
    (list
      "urbanismo_zona_verde : dialog { label = \"Datos de la zona verde\";"
      ;; sin etapas habilitadas la Clasificacion completa se omite (solo
      ;; contiene etapa/subetapa)
      (if (urb:etapas-enabled-p)
        ": boxed_column { label = \"Clasificacion\";" "")
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Etapa\"; key = \"etapa\"; }" "")
      (if (urb:etapas-enabled-p)
        ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" "")
      (if (urb:etapas-enabled-p) "}" "")
      ": boxed_column { label = \"Tierra negra\";"
      ": edit_box { label = \"Espesor (m)\"; key = \"espesor\"; edit_width = 12; }"
      "}"
      "ok_cancel; }"))
)

(defun urb:dialog-green
  (current-etapa current-subetapa current-thickness
   / filename dcl-id accepted subetapas result thickness-value)
  (setq current-etapa (urb:safe-string current-etapa "1")
        current-subetapa
          (urb:safe-string current-subetapa current-etapa)
        current-thickness
          (if (numberp current-thickness)
            current-thickness
            (urb:parse-real
              (urb:safe-string current-thickness "0.20"))))
  (if (or (null current-thickness) (<= current-thickness 0.0))
    (setq current-thickness 0.20))
  (setq filename (urb:write-green-dcl))
  (if (and filename
           (> (setq dcl-id (load_dialog filename)) 0)
           (new_dialog "urbanismo_zona_verde" dcl-id))
    (progn
      (if (urb:etapas-enabled-p)
        (progn
          (urb:fill-popup
            "etapa" *urb-etapa-list*
            (urb:index-of current-etapa *urb-etapa-list*))
          (setq *urb-dialog-etapa*
            (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
          (setq subetapas (urb:subetapas-for *urb-dialog-etapa*))
          (urb:fill-popup
            "subetapa" subetapas
            (urb:index-of current-subetapa subetapas))
          (action_tile "etapa" "(urb:dialog-update-subetapa)")))
      (set_tile "espesor" (rtos current-thickness 2 3))
      (action_tile
        "accept"
        (strcat
          "(setq "
          (if (urb:etapas-enabled-p)
            (strcat
              "*urb-dialog-etapa-index* (atoi (get_tile \"etapa\"))"
              " *urb-dialog-subetapa-index* (atoi (get_tile \"subetapa\")) ")
            "")
          "*urb-dialog-green-thickness* (get_tile \"espesor\"))"
          "(done_dialog 1)"))
      (setq accepted (= 1 (start_dialog)))
      (unload_dialog dcl-id)
      (if accepted
        (progn
          (if (urb:etapas-enabled-p)
            (setq current-etapa
              (nth *urb-dialog-etapa-index* *urb-etapa-list*)
                  subetapas (urb:subetapas-for current-etapa)
                  current-subetapa
                    (nth *urb-dialog-subetapa-index* subetapas)))
          (setq thickness-value
            (urb:parse-real *urb-dialog-green-thickness*))
          (if (or (null thickness-value) (<= thickness-value 0.0))
            (progn
              (alert
                "El espesor debe ser un numero mayor que cero.")
              (setq result nil))
            (setq result
              (list current-etapa current-subetapa thickness-value)))))))
  result
)

(defun urb:remove-app-xdata (edata app / result item sections kept section)
  (setq app (urb:safe-string app ""))
  (foreach item edata
    (if (= (car item) -3)
      (progn
        ;; ENTGET puede agrupar en un solo registro -3 las XDATA de varias
        ;; aplicaciones. La version anterior eliminaba el registro completo
        ;; al actualizar una de ellas y, con el, URB_VIA_MOV. Por eso el
        ;; calculo salia bien en la consola pero el bloque recibia ceros.
        (setq sections (cdr item) kept nil)
        (foreach section sections
          (if (not
                (and section
                     (urb:string-equal-p (car section) app)))
            (setq kept (cons section kept))))
        (if kept
          (setq result (cons (cons -3 (reverse kept)) result))))
      (setq result (cons item result)))
  )
  (reverse result)
)

(defun urb:set-xdata-strings
  (ename app values / edata records modified update-result)
  (setq ename (urb:as-ename ename))
  (if (and ename (= (type app) 'STR) (/= app ""))
    (progn
      (if (not (tblsearch "APPID" app))
        (regapp app))
      (setq edata (urb:remove-app-xdata (entget ename '("*")) app))
      (setq records
        (mapcar
          '(lambda (value)
            (cons 1000 (urb:safe-string value "")))
          values))
      (setq modified
        (vl-catch-all-apply
          'entmod
          (list
            (append edata
              (list (list -3 (append (list app) records)))))))
      (if (or (vl-catch-all-error-p modified) (null modified))
        nil
        (progn
          (setq update-result
            (vl-catch-all-apply 'entupd (list ename)))
          (if (vl-catch-all-error-p update-result) nil values))))
    nil)
)

(defun urb:get-xdata-strings (ename app / item section)
  (setq ename (urb:as-ename ename))
  (if ename
    (setq item (assoc -3 (entget ename (list app)))))
  (if item
    (progn
      (setq section (cadr item))
      (mapcar
        '(lambda (record)
          (urb:safe-string (cdr record) ""))
        (cdr section)))
    nil)
)

(defun urb:list-set-extended (values index value / result)
  (setq result values)
  (while (<= (length result) index)
    (setq result (append result (list ""))))
  (urb:replace-nth index value result)
)

(defun urb:clear-xdata-app (ename app / edata modified update-result)
  (setq ename (urb:as-ename ename))
  (if ename
    (progn
      (setq edata
        (urb:remove-app-xdata (entget ename '("*")) app))
      (setq modified
        (vl-catch-all-apply 'entmod (list edata)))
      (if (or (vl-catch-all-error-p modified) (null modified))
        nil
        (progn
          (setq update-result
            (vl-catch-all-apply 'entupd (list ename)))
          (not (vl-catch-all-error-p update-result)))))
    nil)
)

(defun urb:loseta-module (format)
  (if (urb:starts-with (urb:safe-string format "40 x 40 cm") "40") 0.40 0.20)
)

(defun urb:unit-count-ceiling (area unit-area / quotient nearest lower tolerance)
  (if (or (not (numberp area))
          (not (numberp unit-area))
          (<= area 1e-12)
          (<= unit-area 1e-12))
    0
    (progn
      (setq quotient (/ area unit-area)
            nearest (fix (+ quotient 0.5))
            lower (fix quotient)
            tolerance (max 1e-6 (* 1e-9 (abs quotient))))
      ;; Los booleanos REGION pueden devolver 100.0000000003 para una
      ;; cantidad geometricamente exacta de 100 piezas. En ese caso se
      ;; conserva el entero; solo se redondea hacia arriba cuando existe
      ;; una fraccion real mayor que la tolerancia numerica.
      (if (equal quotient nearest tolerance)
        nearest
        (if (> quotient lower) (1+ lower) lower))))
)

;; Devuelve: area lisa, unidades lisas, guia ML, toperol ML,
;; area de adoquin blanco 20x10 y unidades de adoquin.
(defun urb:polygon-band-area
  (triangles umin umax angle-value / triangle piece result)
  (setq result 0.0)
  (foreach triangle triangles
    (setq piece
      (urb:clip-polygon-to-band triangle umin umax angle-value))
    (if piece
      (setq result
        (+ result (abs (urb:polygon-signed-area piece))))))
  result
)

(defun urb:composite-exact-band-areas
  (points angle-value reverse-pattern
   / triangles bounds umin umax cursor next gray phase-state first-band
   band-width gray-area white-area guard band-area)
  ;; Mide las MISMAS franjas 0.80/1.00 que se dibujan. El recorte se hace
  ;; sobre triangulos internos del contorno, por lo que una banda que
  ;; atraviesa dos islas de un anden concavo suma ambas sin aproximarla
  ;; mediante largo x ancho.
  (setq triangles (urb:triangulate-polygon points))
  (if triangles
    (progn
      (setq bounds (urb:project-bounds points angle-value)
            umin (nth 0 bounds)
            umax (nth 1 bounds)
            cursor (if reverse-pattern umax umin)
            phase-state (urb:composite-phase-state 0.0)
            gray (car phase-state)
            first-band T
            gray-area 0.0
            white-area 0.0
            guard 0)
      (while
        (and
          (if reverse-pattern
            (> cursor (+ umin 0.000001))
            (< cursor (- umax 0.000001)))
          (< guard 20000))
        (setq guard (1+ guard)
              band-width
                (if first-band
                  (cdr phase-state)
                  (if gray 0.80 1.00))
              next
                (if reverse-pattern
                  (max umin (- cursor band-width))
                  (min umax (+ cursor band-width)))
              band-area
                (urb:polygon-band-area triangles
                  (if reverse-pattern next cursor)
                  (if reverse-pattern cursor next)
                  angle-value))
        (if gray
          (setq gray-area (+ gray-area band-area))
          (setq white-area (+ white-area band-area)))
        (setq cursor next gray (not gray) first-band nil))
      (list gray-area white-area))
    nil)
)

(defun urb:anden-quantity-pattern-angle
  (ename points pattern-mode / forced-angle clusters result)
  ;; Repite la misma eleccion de eje usada por create-composite-loseta.
  ;; Antes las cantidades ignoraban URB_ANDEN_AXIS y podian repartir las
  ;; bandas con otra orientacion distinta a la que se veia en planta.
  (setq forced-angle
    (urb:parse-real
      (urb:safe-string
        (car (urb:get-xdata-strings ename "URB_ANDEN_AXIS")) "")))
  (if (and (null forced-angle) (urb:lwpoly-has-arcs-p ename))
    (progn
      (setq forced-angle (urb:anden-straight-edges-angle ename))
      (if forced-angle
        (setq forced-angle (+ forced-angle (* 0.5 pi))))))
  (setq clusters (urb:dominant-anden-axis-clusters points))
  (setq result
    (cond
      (forced-angle forced-angle)
      (clusters (car (car clusters)))
      (T (urb:anden-axis-angle points))))
  (urb:anden-pattern-angle result pattern-mode)
)

(defun urb:anden-finish-quantities
  (points area format guia toperol pattern-mode pattern-angle
   / module corridor-angle bounds length-value
   corridor-bounds corridor-length width-value driving-chain
   guide-ml toperol-ml guide-area toperol-area finish-area
   smooth-area smooth-count adoquin-area adoquin-count cursor next gray
   gray-length white-length ratio exact-areas raw-total area-scale)
  (setq module (urb:loseta-module format))
  (setq corridor-angle (urb:anden-axis-angle points)
        pattern-angle
          (if (numberp pattern-angle)
            pattern-angle
            (urb:anden-pattern-angle corridor-angle pattern-mode))
        corridor-bounds
          (urb:project-bounds points corridor-angle)
        bounds (urb:project-bounds points pattern-angle))
  ;; La proyeccion sobre un solo eje (corridor-bounds) subestima la
  ;; longitud real en un tramo curvo -incluso con los puntos del arco ya
  ;; expandidos, proyectar sobre UN eje nunca converge al arco real. Si hay
  ;; una cadena guia con varios segmentos reales (anden curvo), se usa su
  ;; longitud real sumada; si no (anden recto/simple), se conserva la
  ;; proyeccion de siempre -da el mismo resultado ahi de todas formas.
  (setq driving-chain (urb:anden-driving-chain points))
  (setq corridor-length
    (if (and driving-chain (>= (length (urb:open-chain-edges driving-chain)) 2))
      (urb:chain-total-length driving-chain)
      (max 0.0 (- (nth 1 corridor-bounds) (nth 0 corridor-bounds)))))
  (setq length-value (max 0.0 (- (nth 1 bounds) (nth 0 bounds))))
  (setq width-value (max 0.0 (- (nth 3 bounds) (nth 2 bounds))))
  ;; Guia y toperol son franjas longitudinales independientes.
  (setq toperol-ml (if (urb:yes-p toperol) corridor-length 0.0))
  (setq guide-ml
    (if (urb:yes-p guia) corridor-length 0.0))
  (setq guide-area (* guide-ml module))
  (setq toperol-area (* toperol-ml module))
  (setq finish-area (max 0.0 (- area guide-area toperol-area)))
  (if (< module 0.30)
    (progn
      ;; En curvas/codos el ancho interceptado por cada banda cambia. Se
      ;; mide el area real recortada de gris y blanco; luego se normaliza
      ;; contra el area ACIS exacta del contorno y se descuentan las
      ;; franjas tactiles contractuales.
      (setq exact-areas
        (urb:composite-exact-band-areas
          points pattern-angle
          (urb:anden-pattern-reversed-p pattern-mode)))
      (setq raw-total
        (if exact-areas (+ (car exact-areas) (cadr exact-areas)) 0.0))
      (setq ratio
        (if (> raw-total 1e-9)
          (/ (car exact-areas) raw-total)
          (/ 0.80 1.80)))
      (setq smooth-area (* finish-area ratio))
      (setq adoquin-area (- finish-area smooth-area)))
    (setq smooth-area finish-area adoquin-area 0.0))
  (setq smooth-count
    (urb:unit-count-ceiling smooth-area (* module module)))
  (setq adoquin-count
    (urb:unit-count-ceiling adoquin-area 0.02))
  (list smooth-area smooth-count guide-ml toperol-ml
        adoquin-area adoquin-count)
)

;; Para un anden cuyo acabado principal es adoquin, las franjas guia y
;; toperol reemplazan acabado y deben descontarse del area contractual.
;; Devuelve la misma estructura de urb:anden-finish-quantities.
(defun urb:adoquin-finish-quantities
  (points area format guia toperol / tactile module guide-ml toperol-ml
   adoquin-area adoquin-count)
  (setq tactile
    (urb:anden-finish-quantities
      points area format guia toperol "AUTOMATICO" nil)
        module (urb:loseta-module format)
        guide-ml (nth 2 tactile)
        toperol-ml (nth 3 tactile)
        adoquin-area
          (max 0.0
            (- area
              (* module (+ guide-ml toperol-ml))))
        adoquin-count
          (urb:unit-count-ceiling adoquin-area 0.02))
  (list 0.0 0 guide-ml toperol-ml adoquin-area adoquin-count)
)

(defun urb:set-anden-data
  (ename material etapa subetapa guia toperol format calculate surface grade-source
   / object elevation pattern-mode)
  (setq object (urb:as-vla-object ename)
        pattern-mode (urb:anden-pattern-mode ename)
        elevation
          (if (and object
                   (vlax-property-available-p object 'Elevation))
            (vla-get-Elevation object)
            0.0))
  (urb:set-xdata-strings
    ename
    "URB_ANDEN"
    (list "ANDEN"
          (strcase (urb:safe-string material "Loseta"))
          (urb:safe-string etapa "1")
          (urb:safe-string subetapa "1")
          (urb:safe-string guia "No")
          (urb:safe-string toperol "No")
          (urb:safe-string format "40 x 40 cm")
          (urb:safe-string calculate "Si")
          (urb:safe-string surface "Seleccionar en dibujo")
          (urb:safe-string grade-source "Via creada")
          (rtos elevation 2 8)
          pattern-mode))
)

(defun urb:normalize-anden-pattern-mode (mode)
  (setq mode (strcase (urb:safe-string mode "AUTOMATICO")))
  (cond
    ((member mode '("GIRAR90_OPUESTO" "GIRAR90_INVERTIR"))
      "GIRAR90_OPUESTO")
    ((= mode "GIRAR90") "GIRAR90")
    ((member mode '("OPUESTO" "INVERTIR" "INVERTIR_INICIO"))
      "OPUESTO")
    (T "AUTOMATICO"))
)

(defun urb:anden-pattern-rotated-p (mode)
  (member
    (urb:normalize-anden-pattern-mode mode)
    '("GIRAR90" "GIRAR90_OPUESTO"))
)

(defun urb:anden-pattern-reversed-p (mode)
  (member
    (urb:normalize-anden-pattern-mode mode)
    '("OPUESTO" "GIRAR90_OPUESTO"))
)

(defun urb:compose-anden-pattern-mode (rotated reversed)
  (cond
    ((and rotated reversed) "GIRAR90_OPUESTO")
    (rotated "GIRAR90")
    (reversed "OPUESTO")
    (T "AUTOMATICO"))
)

(defun urb:anden-pattern-angle (angle-value mode)
  (urb:normalize-axis-angle
    (if (urb:anden-pattern-rotated-p mode)
      (+ angle-value (/ pi 2.0))
      angle-value))
)

(defun urb:anden-pattern-mode
  (ename / anden-data block-data legacy-data mode object attributes)
  (setq anden-data (urb:get-xdata-strings ename "URB_ANDEN")
        block-data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK")
        legacy-data (urb:get-xdata-strings ename "URB_ANDEN_PATTERN")
        mode
          (cond
            ((> (length anden-data) 11) (nth 11 anden-data))
            ((> (length block-data) 20) (nth 20 block-data))
            (legacy-data (car legacy-data))
            (T
              (setq object (urb:as-vla-object ename))
              (if (and object
                       (urb:string-equal-p
                         (vla-get-ObjectName object)
                         "AcDbBlockReference"))
                (progn
                  (setq attributes
                    (urb:block-attribute-values object))
                  (urb:attribute-alist-value
                    attributes "ANDEN_SENTIDO" "AUTOMATICO"))
                "AUTOMATICO")))
        mode (urb:normalize-anden-pattern-mode mode))
  mode
)

(defun urb:set-anden-pattern-mode
  (ename mode / anden-data block-data object result)
  (setq mode (urb:normalize-anden-pattern-mode mode))
  (setq anden-data (urb:get-xdata-strings ename "URB_ANDEN")
        block-data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
  (cond
    (anden-data
      (setq result
        (urb:set-xdata-strings
          ename "URB_ANDEN"
          (urb:list-set-extended anden-data 11 mode))))
    (block-data
      (setq result
        (urb:set-xdata-strings
          ename "URB_ANDEN_BLOCK"
          (urb:list-set-extended block-data 20 mode)))
      (setq object (urb:as-vla-object ename))
      (if object
        (urb:set-block-attribute object "ANDEN_SENTIDO" mode)))
    (T
      ;; Compatibilidad con contornos antiguos que aun no tienen URB_ANDEN.
      (setq result
        (urb:set-xdata-strings ename "URB_ANDEN_PATTERN" (list mode)))))
  result
)

(defun urb:tag-generated (obj parent-handle / ename)
  (urb:tag-generated-role obj parent-handle "")
)

;; role identifica el papel de la pieza generada, independiente de en que
;; capa quedo. urb:set-block-draw-order y urb:extract-prefab-reference lo
;; usan para decidir orden de dibujo / identificar interior-exterior sin
;; tener que abrir una capa por cada rol (asi se puede consolidar capas).
(defun urb:tag-generated-role (obj parent-handle role / ename)
  (if (and obj (not (vl-catch-all-error-p obj)))
    (progn
      (setq ename
        (vl-catch-all-apply
          'vlax-vla-object->ename
          (list obj)))
      (if (and ename (not (vl-catch-all-error-p ename)))
        (vl-catch-all-apply
          'urb:set-xdata-strings
          (list ename
                "URB_ANDEN_GEN"
                (list parent-handle (urb:safe-string role ""))))))
  )
  obj
)

(defun urb:generated-role (item / ename data)
  (setq ename
    (vl-catch-all-apply 'vlax-vla-object->ename (list item)))
  (if (and ename (not (vl-catch-all-error-p ename)))
    (setq data (urb:get-xdata-strings ename "URB_ANDEN_GEN")))
  (if (> (length data) 1) (nth 1 data) "")
)

(defun urb:delete-generated
  (parent-handle / ss index ename data obj deleted)
  (setq deleted 0)
  ;; Filtra por XData en el ssget: evita recorrer todo el dibujo.
  (if (setq ss (ssget "_X" '((-3 ("URB_ANDEN_GEN")))))
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_ANDEN_GEN"))
        (if (and data (= (car data) parent-handle))
          (progn
            (setq obj (vlax-ename->vla-object ename))
            (if (urb:safe-delete obj)
              (setq deleted (1+ deleted)))))
        (setq index (1+ index)))))
  deleted
)

(defun urb:group-name (parent-handle)
  (strcat "URB_ANDEN_" parent-handle)
)

(defun urb:get-group (group-name / result)
  (setq result
    (vl-catch-all-apply
      'vla-Item
      (list
        (vla-get-Groups (urb:doc))
        group-name)))
  (if (vl-catch-all-error-p result) nil result)
)

(defun urb:remove-anden-group (parent-handle / group)
  (if (setq group
        (urb:get-group (urb:group-name parent-handle)))
    (vl-catch-all-apply 'vla-Delete (list group)))
  T
)

(defun urb:generated-objects
  (parent-handle / ss index ename data objects)
  ;; Filtra por XData en el ssget: evita recorrer todo el dibujo.
  (if (setq ss (ssget "_X" '((-3 ("URB_ANDEN_GEN")))))
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data
          (urb:get-xdata-strings ename "URB_ANDEN_GEN"))
        (if (and data (= (car data) parent-handle))
          (setq objects
            (cons (vlax-ename->vla-object ename) objects)))
        (setq index (1+ index)))))
  (reverse objects)
)

(defun urb:path-ends-with-separator-p (path / last-char)
  (setq last-char (substr path (strlen path) 1))
  (or (= last-char "\\") (= last-char "/"))
)

(defun urb:join-path (folder filename)
  (strcat
    folder
    (if (urb:path-ends-with-separator-p folder) "" "\\")
    filename)
)

(defun urb:path-in-list-p (folder paths / target found)
  (setq target (strcase (vl-string-right-trim "\\/" folder)))
  (while (and paths (not found))
    (if
      (= target
         (strcase
           (vl-string-right-trim "\\/" (car paths))))
      (setq found T)
    )
    (setq paths (cdr paths))
  )
  found
)

(defun urb:ensure-support-path (folder / current paths)
  (setq current (getenv "ACAD"))
  (setq paths
    (if current
      (urb:split-string current ";")
      nil)
  )
  (if (not (urb:path-in-list-p folder paths))
    (setenv "ACAD"
      (if (and current (/= current ""))
        (strcat current ";" folder)
        folder))
  )
)

(defun urb:copy-quantity-scope (source target / data target-ename)
  (setq data
    (if (urb:valid-ename-p source)
      (urb:get-xdata-strings source "URB_Q_SCOPE") nil)
    target-ename (urb:as-ename target))
  (if (and data target-ename)
    (urb:set-xdata-strings target-ename "URB_Q_SCOPE" data))
  target
)

(defun urb:split-string (text separator / position result)
  (while (setq position (vl-string-search separator text))
    (setq result
      (cons (substr text 1 position) result))
    (setq text
      (substr text (+ position (strlen separator) 1)))
  )
  (reverse (cons text result))
)

(defun urb:write-lines (filename lines / stream line)
  (if (setq stream (open filename "w"))
    (progn
      (foreach line lines
        (write-line line stream))
      (close stream)
      T
    )
  )
)

(defun urb:install-patterns
  (/ folder loseta-file adoquin-file guia-file toperol-file)
  (setq folder (urb:patterns-folder))
  (setq loseta-file (urb:join-path folder "URB_LOSETA.pat"))
  (setq adoquin-file (urb:join-path folder "URB_ADOQUIN.pat"))
  (setq guia-file (urb:join-path folder "URB_GUIA.pat"))
  (setq toperol-file (urb:join-path folder "URB_TOPEROL.pat"))
  (if
    (and
      (urb:write-lines
        loseta-file
        '("*URB_LOSETA, Loseta cuadrada modular 0.20 x 0.20"
          "0, 0,0, 0,0.20"
          "90, 0,0, 0.20,0"))
      (urb:write-lines
        adoquin-file
        '("*URB_ADOQUIN, Adoquin rectangular trabado 0.20 x 0.10"
          "0, 0,0, 0,0.10"
          "90, 0,0, 0.20,0.20, 0.10,-0.10"
          "90, 0.10,0.10, 0.20,0.20, 0.10,-0.10"))
      (urb:write-lines
        guia-file
        '("*URB_GUIA, Barras tactiles en loseta guia 0.20 x 0.20"
          "0, 0.02,0.025, 0,0.05, 0.16,-0.04"))
      (urb:write-lines
        toperol-file
        '("*URB_TOPEROL, Puntos tactiles en loseta toperol 0.20 x 0.20"
          "0, 0.025,0.025, 0,0.05, 0,-0.05")))
    (progn
      (urb:ensure-support-path folder)
      T)
    nil
  )
)

(defun urb:doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun urb:space (/ doc)
  (setq doc (urb:doc))
  (if (= 1 (getvar "CVPORT"))
    (vla-get-PaperSpace doc)
    (vla-get-ModelSpace doc)
  )
)

(defun urb:starts-with (text prefix)
  (setq text (urb:safe-string text ""))
  (setq prefix (urb:safe-string prefix ""))
  (= (strcase prefix)
     (substr (strcase text) 1 (strlen prefix)))
)

(defun urb:ends-with (text suffix / text-length suffix-length)
  (setq text (urb:safe-string text ""))
  (setq suffix (urb:safe-string suffix ""))
  (setq text-length (strlen text))
  (setq suffix-length (strlen suffix))
  (and (>= text-length suffix-length)
       (= (strcase suffix)
          (substr
            (strcase text)
            (1+ (- text-length suffix-length))
            suffix-length)))
)

(defun urb:ensure-layer (name color plottable / layers layer)
  (setq layers (vla-get-Layers (urb:doc)))
  (setq layer
    (if (tblsearch "LAYER" name)
      (vla-Item layers name)
      (vla-Add layers name)
    )
  )
  (vla-put-Color layer color)
  (if (vlax-property-available-p layer 'Plottable T)
    (vla-put-Plottable layer
      (if plottable :vlax-true :vlax-false))
  )
  layer
)

(defun urb:closed-poly-p (ename / obj result)
  (setq obj (vlax-ename->vla-object ename))
  (setq result
    (and
      (member (vla-get-ObjectName obj)
        '("AcDbPolyline" "AcDb2dPolyline" "AcDb3dPolyline"))
      (vlax-property-available-p obj 'Closed)
      (= :vlax-true (vla-get-Closed obj))
      (not
        (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-get-Area (list obj))))
    )
  )
  result
)

(defun urb:poly-perimeter (obj / ename endparam)
  (setq ename (vlax-vla-object->ename obj))
  (setq endparam (vlax-curve-getEndParam ename))
  (vlax-curve-getDistAtParam ename endparam)
)

(defun urb:make-loop-array (obj / arr)
  (setq arr (vlax-make-safearray vlax-vbObject '(0 . 0)))
  (vlax-safearray-put-element arr 0 obj)
  (vlax-make-variant arr)
)

(defun urb:add-hatch-raw
  (boundary layer pattern pattern-type scale color / hatch)
  (setq layer (urb:safe-string layer "0"))
  (setq pattern (urb:safe-string pattern "SOLID"))
  (setq hatch
    (vla-AddHatch
      (urb:space)
      pattern-type
      pattern
      :vlax-true
    )
  )
  ;; AutoCAD exige agregar el contorno antes de modificar el hatch.
  (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
  (vla-put-Layer hatch layer)
  (vla-put-Color hatch color)
  (cond
    ((= pattern-type 0)
      (if (vlax-property-available-p hatch 'PatternSpace T)
        (vla-put-PatternSpace hatch scale))
      (if (vlax-property-available-p hatch 'PatternAngle T)
        (vla-put-PatternAngle hatch 0.0))
      (if (vlax-property-available-p hatch 'PatternDouble T)
        (vla-put-PatternDouble hatch :vlax-true)))
    ((and (/= (strcase pattern) "SOLID")
          (vlax-property-available-p hatch 'PatternScale T))
      (vla-put-PatternScale hatch scale))
  )
  (vla-Evaluate hatch)
  hatch
)

(defun urb:object-array-variant (objects / arr index obj)
  (setq arr
    (vlax-make-safearray
      vlax-vbObject
      (cons 0 (1- (length objects)))))
  (setq index 0)
  (foreach obj objects
    (vlax-safearray-put-element arr index obj)
    (setq index (1+ index))
  )
  (vlax-make-variant arr)
)

(defun urb:double-array-variant (values / arr index value)
  (setq arr
    (vlax-make-safearray
      vlax-vbDouble
      (cons 0 (1- (length values)))))
  (setq index 0)
  (foreach value values
    (vlax-safearray-put-element arr index value)
    (setq index (1+ index))
  )
  (vlax-make-variant arr)
)

(defun urb:add-region-from-object (obj / result value)
  (setq result
    (vl-catch-all-apply
      'vla-AddRegion
      (list
        (urb:space)
        (urb:object-array-variant (list obj)))))
  (if (vl-catch-all-error-p result)
    result
    (progn
      (setq value
        (if (= (type result) 'VARIANT)
          (vlax-variant-value result)
          result))
      (car (vlax-safearray->list value))
    )
  )
)

(defun urb:local-to-world (ucoord vcoord angle-value / cosine sine)
  (setq cosine (cos angle-value))
  (setq sine (sin angle-value))
  (list
    (- (* ucoord cosine) (* vcoord sine))
    (+ (* ucoord sine) (* vcoord cosine)))
)

(defun urb:add-rectangle-poly
  (umin umax vmin vmax angle-value elevation / points coords poly)
  (setq points
    (list
      (urb:local-to-world umin vmin angle-value)
      (urb:local-to-world umax vmin angle-value)
      (urb:local-to-world umax vmax angle-value)
      (urb:local-to-world umin vmax angle-value)))
  (setq coords
    (apply 'append
      (mapcar
        '(lambda (point) (list (car point) (cadr point)))
        points)))
  (setq poly
    (vla-AddLightWeightPolyline
      (urb:space)
      (urb:double-array-variant coords)))
  (if (and (numberp elevation)
           (vlax-property-available-p poly 'Elevation T))
    (vla-put-Elevation poly elevation))
  (vla-put-Closed poly :vlax-true)
  poly
)

(defun urb:rectangle-region
  (umin umax vmin vmax angle-value elevation / poly region)
  (setq poly
    (urb:add-rectangle-poly
      umin umax vmin vmax angle-value elevation))
  (setq region (urb:add-region-from-object poly))
  (vla-Delete poly)
  region
)

(defun urb:lwpoly-points (ename / data points item)
  (setq data (entget ename))
  (foreach item data
    (if (= (car item) 10)
      (setq points
        (cons
          (trans
            (list (cadr item) (caddr item) 0.0)
            ename
            0)
          points))
    )
  )
  (reverse points)
)

(defun urb:arc-samples-for (p1 p2 b / theta chord r len)
  ;; Numero de subdivisiones para un segmento con bulge, ~1 muestra por
  ;; metro de arco REAL (antes eran 8 fijas por arco sin importar el
  ;; tamano: un arco de 30m quedaba en cuerdas de casi 4m y la franja de
  ;; guia/toperol salia visiblemente poligonal/zigzag en vez de seguir la
  ;; curva -- visto en el PDF de verificacion del abanico).
  (setq theta (* 4.0 (atan (abs b))))
  (setq chord (distance p1 p2))
  (if (or (< theta 1e-6) (< chord 1e-6))
    8
    (progn
      (setq r (/ chord (* 2.0 (sin (* 0.5 theta)))))
      (setq len (* r theta))
      (max 8 (min 96 (fix (+ 1.0 len))))))
)

(defun urb:arc-bulge-midpoints (ename p1-wcs p2-wcs n / param1 param2 pts j frac tparam pt)
  ;; Puntos intermedios (sin incluir p1 ni p2) a lo largo del arco real
  ;; entre dos vertices con bulge, consultando la curva de verdad
  ;; (vlax-curve) en vez de recalcular la geometria del arco a mano: evita
  ;; arriesgar un error de signo propio en la formula bulge->circulo.
  (setq param1 (vl-catch-all-apply 'vlax-curve-getParamAtPoint (list ename p1-wcs)))
  (setq param2 (vl-catch-all-apply 'vlax-curve-getParamAtPoint (list ename p2-wcs)))
  (if (or (vl-catch-all-error-p param1) (vl-catch-all-error-p param2))
    nil
    (progn
      ;; Segmento de CIERRE con arco (PLINE opcion Arc + CLose): p2 es el
      ;; PRIMER vertice, cuyo parametro es 0 -- interpolar de param1 hacia
      ;; 0 recorre TODA la polilinea hacia atras en vez del arco de
      ;; cierre, sembrando puntos por todo el contorno (el validador veia
      ;; un falso "monio" y rechazaba andenes curvos validos). El extremo
      ;; correcto por el lado del cierre es el parametro FINAL de la
      ;; curva.
      (if (<= param2 param1)
        (progn
          (setq param2 (vl-catch-all-apply 'vlax-curve-getEndParam (list ename)))
          (if (vl-catch-all-error-p param2) (setq param2 param1))))
      (setq pts nil j 1)
      (repeat (1- n)
        (setq frac (/ (float j) (float n)))
        (setq tparam (+ param1 (* frac (- param2 param1))))
        (setq pt (vl-catch-all-apply 'vlax-curve-getPointAtParam (list ename tparam)))
        ;; pt puede ser NIL sin error (parametro fuera de rango): no
        ;; apendear (nil nil)
        (if (and (not (vl-catch-all-error-p pt)) pt)
          (setq pts (cons (list (car pt) (cadr pt)) pts)))
        (setq j (1+ j)))
      (reverse pts))))

(defun urb:lwpoly-points-with-arcs (ename)
  ;; muestreo ESTANDAR (8 por arco): el que usa el material -- con muchas
  ;; cunas delgadas los booleanos de bandas se degradan (verificado
  ;; visualmente en PDF), asi que el material se queda con cuerdas gruesas
  (urb:lwpoly-points-with-arcs-impl ename nil)
)

;; T si la polilinea tiene al menos un segmento en ARCO real (bulge).
;; 2026-08-12 (pantallazo del usuario: bandas diagonales en la curva):
;; las cuerdas en que se subdivide un arco generaban un segundo "eje
;; dominante" y el material se partia en dos zonas con orientaciones
;; distintas (abanico parcial). Un contorno CON arcos es una curva
;; continua -> UN solo eje y la curva solo recorta; la particion en dos
;; ejes queda solo para andenes en L de esquinas rectas (sin bulges).
(defun urb:lwpoly-has-arcs-p (ename / found pair)
  (foreach pair (entget ename)
    (if (and (= (car pair) 42) (> (abs (cdr pair)) 1e-6))
      (setq found T)))
  found
)

;; Angulo dominante usando SOLO los lados RECTOS reales del contorno
;; (los segmentos con bulge -- arcos -- no votan). En un anden curvo las
;; cuerdas del arco elegian un eje diagonal; el eje correcto es el del
;; tramo recto (tapas / lado compartido con el modulo vecino). Devuelve
;; nil si el contorno no tiene ningun lado recto apreciable.
(defun urb:anden-straight-edges-angle
  (ename / data item pts bulges n i p1 p2 b a len bins entry best)
  (setq data (entget ename) pts nil bulges nil)
  (foreach item data
    (cond
      ((= (car item) 10)
        (setq pts (cons (cdr item) pts) bulges (cons 0.0 bulges)))
      ((= (car item) 42)
        (if bulges (setq bulges (cons (cdr item) (cdr bulges)))))))
  (setq pts (reverse pts) bulges (reverse bulges))
  (setq n (length pts) i 0 bins nil)
  (while (< i n)
    (setq p1 (nth i pts)
          p2 (nth (rem (1+ i) n) pts)
          b (nth i bulges))
    (if (<= (abs b) 1e-6)
      (progn
        (setq len (distance p1 p2))
        (if (> len 1e-6)
          (progn
            (setq a (angle p1 p2))
            (if (>= a pi) (setq a (- a pi)))
            (setq entry
              (vl-some
                '(lambda (x)
                   (if (< (urb:axis-angle-distance a (car x))
                          (* pi (/ 10.0 180.0)))
                     x nil))
                bins))
            (if entry
              (setq bins
                (subst (list (car entry) (+ (cadr entry) len)) entry bins))
              (setq bins (cons (list a len) bins)))))))
    (setq i (1+ i)))
  (setq best nil)
  (foreach entry bins
    (if (or (null best) (> (cadr entry) (cadr best))) (setq best entry)))
  (if best (car best) nil)
)

(defun urb:lwpoly-points-with-arcs-fine (ename)
  ;; muestreo ADAPTATIVO (~1 por metro de arco): solo para la cadena de la
  ;; franja tactil, que necesita seguir el arco real (con 8 cuerdas por
  ;; arco la guia salia poligonal/zigzag)
  (urb:lwpoly-points-with-arcs-impl ename T)
)

(defun urb:lwpoly-points-with-arcs-impl
  (ename adaptive / data points item raw-verts current-pt current-bulge n-samples
   i p1 p2 b mids closed-flag wcs-verts end-param j frac tparam pt param1)
  ;; Igual que urb:lwpoly-points, pero si un segmento tiene bulge (arco
  ;; real dibujado con la opcion Arc de PLINE) lo subdivide en varios
  ;; puntos intermedios siguiendo el arco real en vez de tratarlo como una
  ;; sola cuerda recta. Sin esto, un anden con un tramo curvo dibujado como
  ;; un unico arco (no como muchos segmentos rectos cortos) se modula como
  ;; si fuera un solo panel recto de esquina a esquina.
  (setq data (entget ename))
  (setq raw-verts nil current-pt nil current-bulge 0.0 closed-flag nil)
  (foreach item data
    (cond
      ((= (car item) 10)
        (if current-pt
          (setq raw-verts (cons (list current-pt current-bulge) raw-verts)))
        (setq current-pt (list (cadr item) (caddr item)))
        (setq current-bulge 0.0))
      ((= (car item) 42) (setq current-bulge (cdr item)))
      ((= (car item) 70) (setq closed-flag (= 1 (logand (cdr item) 1))))))
  (if current-pt
    (setq raw-verts (cons (list current-pt current-bulge) raw-verts)))
  (setq raw-verts (reverse raw-verts))
  ;; A WCS una sola vez; urb:arc-bulge-midpoints necesita puntos en el
  ;; mismo espacio que entiende vlax-curve.
  (setq wcs-verts
    (mapcar
      '(lambda (v)
        (list (trans (list (car (car v)) (cadr (car v)) 0.0) ename 0) (cadr v)))
      raw-verts))
  (setq n-samples 8)
  (setq points nil i 0)
  (repeat (length wcs-verts)
    (setq p1 (car (nth i wcs-verts)) b (cadr (nth i wcs-verts)))
    (setq points (cons (list (car p1) (cadr p1)) points))
    (if (and (/= b 0.0) (< (1+ i) (length wcs-verts)))
      (progn
        (setq p2 (car (nth (1+ i) wcs-verts)))
        (setq n-samples (if adaptive (urb:arc-samples-for p1 p2 b) 8))
        (setq mids (urb:arc-bulge-midpoints ename p1 p2 n-samples))
        (foreach m mids (setq points (cons m points)))))
    (setq i (1+ i)))
  (setq points (reverse points))
  ;; Cierre: si es cerrada y el ultimo vertice tiene bulge, ese arco cierra
  ;; contra el primer vertice y no queda representado en el bucle anterior.
  ;; El primer vertice esta en el parametro 0 de la curva, pero para
  ;; continuar despues del ultimo vertice hay que usar el parametro final
  ;; real (EndParam), no volver a buscar el punto de partida.
  (if (and closed-flag wcs-verts (> (length wcs-verts) 1))
    (progn
      (setq p1 (car (nth (1- (length wcs-verts)) wcs-verts))
            b (cadr (nth (1- (length wcs-verts)) wcs-verts)))
      (if (/= b 0.0)
        (progn
          (setq end-param (vl-catch-all-apply 'vlax-curve-getEndParam (list ename)))
          (if (not (vl-catch-all-error-p end-param))
            (progn
              (setq param1
                (vl-catch-all-apply 'vlax-curve-getParamAtPoint (list ename p1)))
              (if (not (vl-catch-all-error-p param1))
                (progn
                  ;; mismo criterio de muestreo que los arcos interiores
                  (setq n-samples
                    (if adaptive
                      (urb:arc-samples-for p1 (car (nth 0 wcs-verts)) b)
                      8))
                  (setq j 1)
                  (repeat (1- n-samples)
                    (setq frac (/ (float j) (float n-samples)))
                    (setq tparam (+ param1 (* frac (- end-param param1))))
                    (setq pt
                      (vl-catch-all-apply 'vlax-curve-getPointAtParam (list ename tparam)))
                    ;; getPointAtParam devuelve NIL (sin error) con un
                    ;; parametro fuera de rango: sin este chequeo se
                    ;; apendaba (nil nil) y todo lo aguas abajo reventaba
                    ;; con "bad argument type: 2D/3D point: (nil nil)".
                    (if (and (not (vl-catch-all-error-p pt)) pt)
                      (setq points (append points (list (list (car pt) (cadr pt))))))
                    (setq j (1+ j)))))))))))
  points
)

(defun urb:longest-edge-angle
  (points / closed p1 p2 edge-length best angle-value)
  (setq closed (append points (list (car points))))
  (setq best -1.0)
  (while (cadr closed)
    (setq p1 (car closed))
    (setq p2 (cadr closed))
    (setq edge-length (distance p1 p2))
    (if (> edge-length best)
      (progn
        (setq best edge-length)
        (setq angle-value (angle p1 p2))))
    (setq closed (cdr closed))
  )
  angle-value
)

(defun urb:project-bounds
  (points angle-value / cosine sine first ucoord vcoord
   umin umax vmin vmax point)
  (setq cosine (cos angle-value))
  (setq sine (sin angle-value))
  (setq first T)
  (foreach point points
    (setq ucoord
      (+ (* (car point) cosine) (* (cadr point) sine)))
    (setq vcoord
      (+ (* (- (car point)) sine) (* (cadr point) cosine)))
    (if first
      (progn
        (setq umin ucoord umax ucoord vmin vcoord vmax vcoord)
        (setq first nil))
      (progn
        (setq umin (min umin ucoord))
        (setq umax (max umax ucoord))
        (setq vmin (min vmin vcoord))
        (setq vmax (max vmax vcoord))))
  )
  (list umin umax vmin vmax)
)

(defun urb:normalize-axis-angle (angle-value)
  ;; El eje no tiene sentido de avance: 0 y PI representan la misma
  ;; alineacion. Mantenerlo en [0, PI) evita giros graficos innecesarios.
  (while (< angle-value 0.0)
    (setq angle-value (+ angle-value pi)))
  (while (>= angle-value pi)
    (setq angle-value (- angle-value pi)))
  angle-value
)

(defun urb:normalize-full-angle (angle-value)
  ;; PatternAngle trabaja con una direccion completa, no solo con un eje.
  (while (< angle-value 0.0)
    (setq angle-value (+ angle-value (* 2.0 pi))))
  (while (>= angle-value (* 2.0 pi))
    (setq angle-value (- angle-value (* 2.0 pi))))
  angle-value
)

(defun urb:wcs-angle-to-current-ucs
  (angle-value / ucs-x ucs-angle)
  ;; La geometria del anden y su eje se calculan en WCS. AutoCAD interpreta
  ;; PatternAngle respecto al eje X del UCS actual, por lo que se descuenta
  ;; la rotacion de ese UCS antes de asignar el patron.
  (setq ucs-x (getvar "UCSXDIR"))
  (setq ucs-angle
    (atan (cadr ucs-x) (car ucs-x)))
  (urb:normalize-full-angle (- angle-value ucs-angle))
)

(defun urb:anden-axis-angle
  (points / closed p1 p2 edge-length candidate bounds
   u-length v-length box-area aspect best-area best-aspect best-angle)
  ;; Busca el rectangulo orientado de menor area entre las direcciones de
  ;; todos los bordes. Su lado mayor define el eje longitudinal del anden.
  ;; Es mas estable que usar un unico borde largo en contornos trapezoidales,
  ;; sesgados o con remates diagonales.
  (if (> (length points) 2)
    (progn
      (setq closed (append points (list (car points))))
      (while (cadr closed)
        (setq p1 (car closed)
              p2 (cadr closed)
              edge-length (distance p1 p2))
        (if (> edge-length 1e-8)
          (progn
            (setq candidate (angle p1 p2))
            (setq bounds (urb:project-bounds points candidate))
            (setq u-length (max 0.0 (- (nth 1 bounds) (nth 0 bounds)))
                  v-length (max 0.0 (- (nth 3 bounds) (nth 2 bounds)))
                  box-area (* u-length v-length))
            (if (> v-length u-length)
              (progn
                (setq candidate (+ candidate (/ pi 2.0)))
                (setq aspect
                  (if (> u-length 1e-9) (/ v-length u-length) 1e99)))
              (setq aspect
                (if (> v-length 1e-9) (/ u-length v-length) 1e99)))
            (if (or
                  (null best-area)
                  (< box-area (- best-area 1e-8))
                  (and (equal box-area best-area 1e-8)
                       (> aspect best-aspect)))
              (setq best-area box-area
                    best-aspect aspect
                    best-angle candidate))))
        (setq closed (cdr closed)))
      (urb:normalize-axis-angle
        (if best-angle best-angle (urb:longest-edge-angle points))))
    (urb:longest-edge-angle points))
)

(defun urb:axis-angle-distance (left right / difference)
  (setq left (urb:normalize-axis-angle left)
        right (urb:normalize-axis-angle right)
        difference (abs (- left right)))
  (min difference (- pi difference))
)

(defun urb:polygon-edge-records
  (points / closed p1 p2 edge-length result)
  (if (> (length points) 1)
    (progn
      (setq closed (append points (list (car points))))
      (while (cadr closed)
        (setq p1 (car closed)
              p2 (cadr closed)
              edge-length (distance p1 p2))
        (if (> edge-length 1e-8)
          (setq result
            (cons
              (list p1 p2 edge-length
                (urb:normalize-axis-angle (angle p1 p2)))
              result)))
        (setq closed (cdr closed)))))
  (reverse result)
)

(defun urb:edge-cluster-from-edges
  (edges / edge weight sine-sum cosine-sum angle-value)
  ;; El promedio se calcula sobre 2*angulo porque un eje no tiene sentido:
  ;; 0 y 180 grados representan la misma direccion.
  (setq weight 0.0 sine-sum 0.0 cosine-sum 0.0)
  (foreach edge edges
    (setq weight (+ weight (nth 2 edge))
          sine-sum
            (+ sine-sum
              (* (nth 2 edge) (sin (* 2.0 (nth 3 edge)))))
          cosine-sum
            (+ cosine-sum
              (* (nth 2 edge) (cos (* 2.0 (nth 3 edge)))))))
  (setq angle-value
    (urb:normalize-axis-angle
      (* 0.5 (atan sine-sum cosine-sum))))
  (list angle-value weight edges)
)

(defun urb:edge-axis-clusters
  (points tolerance / edges clusters edge cluster found updated)
  (setq edges (urb:polygon-edge-records points))
  (foreach edge edges
    (setq found nil updated nil)
    (foreach cluster clusters
      (if (and (not found)
               (<=
                 (urb:axis-angle-distance
                   (nth 3 edge) (car cluster))
                 tolerance))
        (progn
          (setq updated
            (cons
              (urb:edge-cluster-from-edges
                (cons edge (nth 2 cluster)))
              updated))
          (setq found T))
        (setq updated (cons cluster updated))))
    (if (not found)
      (setq updated
        (cons (urb:edge-cluster-from-edges (list edge)) updated)))
    (setq clusters (reverse updated)))
  (vl-sort clusters
    '(lambda (left right) (> (nth 1 left) (nth 1 right))))
)

(defun urb:dominant-anden-axis-clusters
  (points / clusters first second)
  ;; Diez grados absorben pequeños quiebres de levantamiento sin mezclar
  ;; brazos realmente diferentes. El segundo eje debe aportar al menos
  ;; 20% de la longitud del principal y separarse como minimo 15 grados.
  (setq clusters
    (urb:edge-axis-clusters points (* pi (/ 10.0 180.0))))
  ;; Un par de lados de cierre puede tener bastante longitud en andenes
  ;; cortos, pero no representa otro brazo. Solo se conservan familias que
  ;; realmente forman un corredor: dos bordes opuestos cuyo desarrollo
  ;; longitudinal supera claramente su separacion transversal.
  (setq clusters
    (vl-remove-if-not 'urb:corridor-axis-cluster-p clusters))
  (if clusters
    (progn
      (setq first (car clusters)
            second (cadr clusters))
      (if (and second
               (>= (nth 1 second) (* 0.20 (nth 1 first)))
               (>=
                 (urb:axis-angle-distance
                   (car first) (car second))
                 (* pi (/ 15.0 180.0))))
        (list first second)
        (list first)))
    nil)
)

(defun urb:axis-descriptor-from-cluster
  (cluster / angle-value edges edge point midpoint ucoord vcoord
   first umin umax vmin vmax width-value length-value aspect)
  (setq angle-value (car cluster)
        edges (urb:cluster-principal-edges cluster)
        first T)
  (foreach edge edges
    (foreach point (list (car edge) (cadr edge))
      (setq ucoord
        (+ (* (car point) (cos angle-value))
           (* (cadr point) (sin angle-value))))
      (if first
        (setq umin ucoord umax ucoord first nil)
        (setq umin (min umin ucoord)
              umax (max umax ucoord))))
    (setq midpoint
      (list
        (/ (+ (car (car edge)) (car (cadr edge))) 2.0)
        (/ (+ (cadr (car edge)) (cadr (cadr edge))) 2.0)
        0.0)
          vcoord (urb:point-v-coordinate midpoint angle-value))
    (if (null vmin)
      (setq vmin vcoord vmax vcoord)
      (setq vmin (min vmin vcoord)
            vmax (max vmax vcoord))))
  (setq width-value (abs (- vmax vmin))
        length-value (max 0.0 (- umax umin))
        aspect
          (if (> width-value 1e-8)
            (/ length-value width-value)
            0.0))
  (list angle-value (/ (+ vmin vmax) 2.0) umin umax
    width-value aspect)
)

(defun urb:corridor-axis-cluster-p (cluster / descriptor)
  (setq descriptor (urb:axis-descriptor-from-cluster cluster))
  (and
    (>= (length (urb:cluster-principal-edges cluster)) 2)
    (> (nth 4 descriptor) 1e-6)
    (>= (nth 5 descriptor) 1.50))
)

(defun urb:cluster-principal-edges
  (cluster / edges maximum edge)
  (setq edges (nth 2 cluster)
        maximum 0.0)
  (foreach edge edges
    (setq maximum (max maximum (nth 2 edge))))
  (vl-remove-if
    '(lambda (item) (< (nth 2 item) (* maximum 0.25)))
    edges)
)

(defun urb:axis-descriptor-intersection
  (left right / a1 a2 v1 v2 n1x n1y n2x n2y determinant x y)
  (setq a1 (nth 0 left)
        v1 (nth 1 left)
        a2 (nth 0 right)
        v2 (nth 1 right)
        n1x (- (sin a1))
        n1y (cos a1)
        n2x (- (sin a2))
        n2y (cos a2)
        determinant (- (* n1x n2y) (* n1y n2x)))
  (if (> (abs determinant) 1e-8)
    (progn
      (setq x
        (/ (- (* v1 n2y) (* n1y v2)) determinant)
            y
        (/ (- (* n1x v2) (* v1 n2x)) determinant))
      (list x y 0.0))
    nil)
)

(defun urb:axis-outward-vector
  (descriptor joint / angle-value joint-u lower upper direction)
  (setq angle-value (nth 0 descriptor)
        joint-u
          (+ (* (car joint) (cos angle-value))
             (* (cadr joint) (sin angle-value)))
        lower (abs (- joint-u (nth 2 descriptor)))
        upper (abs (- (nth 3 descriptor) joint-u))
        direction (if (> upper lower) 1.0 -1.0))
  (list
    (* direction (cos angle-value))
    (* direction (sin angle-value))
    0.0)
)

(defun urb:two-axis-split-data
  (points first-cluster second-cluster
   / first second joint vector1 vector2 bisector split-angle bounds
   span margin split-v rep1 rep1-v)
  (setq first
    (urb:axis-descriptor-from-cluster first-cluster)
        second
    (urb:axis-descriptor-from-cluster second-cluster)
        joint (urb:axis-descriptor-intersection first second))
  (if joint
    (progn
      (setq vector1 (urb:axis-outward-vector first joint)
            vector2 (urb:axis-outward-vector second joint)
            bisector
              (list
                (+ (car vector1) (car vector2))
                (+ (cadr vector1) (cadr vector2))
                0.0))
      (if (< (distance '(0.0 0.0 0.0) bisector) 1e-8)
        (setq bisector
          (list (- (cadr vector1)) (car vector1) 0.0)))
      (setq split-angle (angle '(0.0 0.0 0.0) bisector)
            bounds (urb:project-bounds points split-angle)
            span
              (max
                (- (nth 1 bounds) (nth 0 bounds))
                (- (nth 3 bounds) (nth 2 bounds))
                1.0)
            margin (+ span 10.0)
            split-v (urb:point-v-coordinate joint split-angle)
            rep1
              (list
                (+ (car joint) (* span (car vector1)))
                (+ (cadr joint) (* span (cadr vector1)))
                0.0)
            rep1-v (urb:point-v-coordinate rep1 split-angle))
      (list first second joint split-angle bounds margin split-v
        (< rep1-v split-v)))
    nil)
)

(defun urb:object-box-points
  (object / minimum maximum min-list max-list result)
  (setq result
    (vl-catch-all-apply
      'vla-GetBoundingBox
      (list object 'minimum 'maximum)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq min-list (vlax-safearray->list minimum)
            max-list (vlax-safearray->list maximum))
      (list
        (list (car min-list) (cadr min-list)
          (if (caddr min-list) (caddr min-list) 0.0))
        (list (car max-list) (cadr min-list)
          (if (caddr min-list) (caddr min-list) 0.0))
        (list (car max-list) (cadr max-list)
          (if (caddr max-list) (caddr max-list) 0.0))
        (list (car min-list) (cadr max-list)
          (if (caddr max-list) (caddr max-list) 0.0)))))
)

(defun urb:region-outline-points
  (region / exploded objects object ename start-param end-param
   steps index parameter point points box)
  ;; La caja WCS de una REGION rotada es mayor que su geometria real.
  ;; Usarla para iniciar la modulacion genera franjas parciales en ambos
  ;; extremos. Explotar una copia logica de sus bordes permite calcular
  ;; las proyecciones sobre el contorno verdadero, incluso con arcos.
  (setq exploded
    (vl-catch-all-apply 'vla-Explode (list region)))
  (if (not (vl-catch-all-error-p exploded))
    (progn
      (setq objects (urb:variant-object-list exploded))
      (foreach object objects
        (setq ename
          (vl-catch-all-apply
            'vlax-vla-object->ename
            (list object)))
        (if (not (vl-catch-all-error-p ename))
          (progn
            (setq start-param
              (vl-catch-all-apply
                'vlax-curve-getStartParam
                (list ename))
                  end-param
              (vl-catch-all-apply
                'vlax-curve-getEndParam
                (list ename)))
            (if (and (numberp start-param) (numberp end-param))
              (progn
                (setq steps 16 index 0)
                (repeat (1+ steps)
                  (setq parameter
                    (+ start-param
                      (* (/ (float index) steps)
                        (- end-param start-param))))
                  (setq point
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtParam
                      (list ename parameter)))
                  (if (and point (not (vl-catch-all-error-p point)))
                    (setq points (cons point points)))
                  (setq index (1+ index))))
              (progn
                (setq box (urb:object-box-points object))
                (if box (setq points (append box points)))))))
        (urb:safe-delete object))))
  (reverse points)
)

(defun urb:add-solid-hatch (boundary layer color / hatch)
  (setq layer (urb:safe-string layer "0"))
  (setq hatch
    (vla-AddHatch
      (urb:space)
      1
      "SOLID"
      :vlax-true))
  (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
  (vla-put-Layer hatch layer)
  (vla-put-Color hatch color)
  (vla-Evaluate hatch)
  hatch
)

(defun urb:add-user-hatch-raw
  (boundary layer spacing angle-value double-lines color origin
   / hatch pattern-angle)
  (setq layer (urb:safe-string layer "0"))
  (setq pattern-angle
    (urb:wcs-angle-to-current-ucs angle-value))
  (setq hatch
    (vla-AddHatch
      (urb:space)
      0
      "USER"
      :vlax-true))
  (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
  (vla-put-Layer hatch layer)
  (vla-put-Color hatch color)
  ;; PatternDouble puede regenerar la definicion USER y devolver el angulo
  ;; a cero. Se configura primero y la rotacion se aplica al final.
  (vla-put-PatternDouble hatch
    (if double-lines :vlax-true :vlax-false))
  (vla-put-PatternSpace hatch spacing)
  (vla-put-PatternAngle hatch pattern-angle)
  (vla-Evaluate hatch)
  (if origin
    (urb:set-hatch-origin-dxf hatch origin))
  hatch
)

(defun urb:set-hatch-origin-dxf
  (hatch origin / ename edata item result)
  ;; USER hatches store each pattern-line base in DXF 43/44.
  ;; Updating those codes avoids the global hatch-origin phase.
  (setq ename (vlax-vla-object->ename hatch))
  (setq edata (entget ename))
  (foreach item edata
    (setq result
      (cons
        (cond
          ((= (car item) 43) (cons 43 (car origin)))
          ((= (car item) 44) (cons 44 (cadr origin)))
          (T item))
        result)))
  (if (entmod (reverse result))
    (progn
      (entupd ename)
      T)
    nil)
)

(defun urb:add-user-hatch
  (boundary layer spacing angle-value double-lines color origin
   / result)
  (setq result
    (vl-catch-all-apply
      'urb:add-user-hatch-raw
      (list boundary layer spacing angle-value double-lines color origin)))
  result
)

(defun urb:safe-delete (obj / result)
  (if (urb:valid-vla-object-p obj)
    (progn
      (setq result (vl-catch-all-apply 'vla-Delete (list obj)))
      (if (vl-catch-all-error-p result) nil T))
    nil)
)

(defun urb:region-usable-p (region / area-value)
  ;; Una operacion ACIS puede terminar sin excepcion y aun devolver una
  ;; region vacia/degenerada. Esas regiones fallan despues al crear el
  ;; HATCH y antes se contaban como bandas validas, dejando el fondo negro.
  (setq area-value
    (if (urb:valid-vla-object-p region)
      (vl-catch-all-apply 'vla-get-Area (list region))
      nil))
  (and (numberp area-value) (> area-value 1e-10))
)

(defun urb:stripe-overlaps ()
  ;; Solapes progresivos en metros. Siempre se expanden LOS DOS bordes:
  ;; las bandas vecinas se pisan unas milesimas en vez de separarse.
  '(0.0 0.0005 0.0015 0.004 0.010)
)

(defun urb:clip-stripe-once
  (base-region umin umax vmin vmax angle-value
   / clipped stripe result box elevation)
  (setq clipped (vla-Copy base-region))
  (setq box (urb:object-box-points base-region)
        elevation
          (if (and box (caddr (car box)))
            (caddr (car box))
            0.0))
  (setq stripe
    (urb:rectangle-region
      umin umax vmin vmax angle-value elevation))
  (if (vl-catch-all-error-p stripe)
    (progn
      (urb:safe-delete clipped)
      nil)
    (progn
      (setq result
        (vl-catch-all-apply
          'vla-Boolean
          (list clipped 1 stripe)))
      ;; Boolean consume normalmente la segunda region; si una version de
      ;; AutoCAD la conserva, se limpia de forma defensiva.
      (urb:safe-delete stripe)
      (if (or (vl-catch-all-error-p result)
              (not (urb:region-usable-p clipped)))
        (progn
          (urb:safe-delete clipped)
          nil)
        clipped)
    )
  )
)

;; 2026-08-12 v2: el reintento anterior TRASLADABA toda la banda. Eso
;; rompia la tangencia, pero podia abrir una separacion en el borde que se
;; alejaba de la banda vecina. Ahora la banda se ENSANCHA simetricamente,
;; se valida su area real y el solape queda oculto por el orden de dibujo.
(defun urb:clip-stripe
  (base-region umin umax vmin vmax angle-value / result eps)
  (foreach eps (urb:stripe-overlaps)
    (if (null result)
      (setq result
        (urb:clip-stripe-once
          base-region (- umin eps) (+ umax eps)
          (- vmin eps) (+ vmax eps) angle-value))))
  result
)

(defun urb:grid-phase-shift (global-offset module / m)
  ;; Resto de global-offset sobre "module" en [0, module): cuanto hay que
  ;; correr el origen local de una reticula para que sus juntas caigan
  ;; sobre la reticula GLOBAL de la cadena (juntas cada "module" desde el
  ;; arranque de la cadena completa, no desde cada segmento o banda).
  (setq m (- global-offset (* module (fix (/ global-offset module)))))
  (if (< m 0.0) (+ m module) m)
)

(defun urb:snap-to-row (value vbase module)
  ;; Ajusta un v local a la fila de tabletas mas cercana de la reticula
  ;; anclada en vbase (el mismo anclaje que usa el material), para que la
  ;; franja de guia ocupe filas COMPLETAS de la modulacion en vez de una
  ;; cinta corrida que no respeta las juntas de la loseta.
  (+ vbase (* module (fix (+ (/ (- value vbase) module) (if (< value vbase) -0.5 0.5)))))
)

(defun urb:quad-region (q1 q2 q3 q4 elevation / coords poly region)
  (setq coords
    (apply 'append
      (mapcar '(lambda (p) (list (car p) (cadr p))) (list q1 q2 q3 q4))))
  (setq poly
    (vla-AddLightWeightPolyline
      (urb:space)
      (urb:double-array-variant coords)))
  (if (and (numberp elevation)
           (vlax-property-available-p poly 'Elevation T))
    (vla-put-Elevation poly elevation))
  (vla-put-Closed poly :vlax-true)
  (setq region (urb:add-region-from-object poly))
  (vla-Delete poly)
  region
)

(defun urb:point-near-2d-p (left right tolerance / dx dy)
  (if (and left right)
    (progn
      (setq dx (- (car left) (car right))
            dy (- (cadr left) (cadr right)))
      (<= (+ (* dx dx) (* dy dy)) (* tolerance tolerance)))
    nil)
)

(defun urb:clean-polygon-points (raw-points / result point)
  ;; El muestreo de arcos puede repetir un vertice en una union. Los
  ;; duplicados consecutivos producen triangulos degenerados.
  (foreach point raw-points
    (if (or (null result)
            (not (urb:point-near-2d-p point (car result) 1e-8)))
      (setq result (cons point result))))
  (setq result (reverse result))
  (if (and (> (length result) 2)
           (urb:point-near-2d-p
             (car result) (last result) 1e-8))
    (setq result (reverse (cdr (reverse result)))))
  result
)

(defun urb:polygon-signed-area (points / area i p1 p2 n)
  (setq area 0.0 i 0 n (length points))
  (repeat n
    (setq p1 (nth i points)
          p2 (nth (rem (1+ i) n) points)
          area (+ area (- (* (car p1) (cadr p2))
                          (* (car p2) (cadr p1))))
          i (1+ i)))
  (* 0.5 area)
)

(defun urb:triangle-cross (a b c)
  (- (* (- (car b) (car a)) (- (cadr c) (cadr a)))
     (* (- (cadr b) (cadr a)) (- (car c) (car a))))
)

(defun urb:point-in-triangle-p (p a b c / c1 c2 c3 tol)
  (setq tol 1e-9
        c1 (urb:triangle-cross a b p)
        c2 (urb:triangle-cross b c p)
        c3 (urb:triangle-cross c a p))
  (or (and (>= c1 (- tol)) (>= c2 (- tol)) (>= c3 (- tol)))
      (and (<= c1 tol) (<= c2 tol) (<= c3 tol)))
)

(defun urb:remove-point-once (points target / removed result point)
  (foreach point points
    (if (and (not removed) (urb:point-near-2d-p point target 1e-12))
      (setq removed T)
      (setq result (cons point result))))
  (reverse result)
)

(defun urb:triangulate-polygon
  (points / verts triangles guard n i prev cur nxt test contains ear-found)
  ;; Ear clipping sobre el contorno ordenado de la LWPOLYLINE. Cada
  ;; triangulo es convexo y su interseccion con una banda tambien lo es;
  ;; evita la operacion ACIS multi-isla que falla en curvas concavas.
  (setq verts (urb:clean-polygon-points points))
  (if (< (urb:polygon-signed-area verts) 0.0)
    (setq verts (reverse verts)))
  (setq guard 0 triangles nil)
  (while (and (> (length verts) 3) (< guard 20000))
    (setq n (length verts) i 0 ear-found nil)
    (while (and (< i n) (not ear-found))
      (setq prev (nth (rem (+ i n -1) n) verts)
            cur (nth i verts)
            nxt (nth (rem (1+ i) n) verts))
      (if (> (urb:triangle-cross prev cur nxt) 1e-10)
        (progn
          (setq contains nil)
          (foreach test verts
            (if (and (not contains)
                     (not (urb:point-near-2d-p test prev 1e-12))
                     (not (urb:point-near-2d-p test cur 1e-12))
                     (not (urb:point-near-2d-p test nxt 1e-12))
                     (urb:point-in-triangle-p test prev cur nxt))
              (setq contains T)))
          (if (not contains)
            (progn
              (setq triangles (cons (list prev cur nxt) triangles)
                    verts (urb:remove-point-once verts cur)
                    ear-found T)))))
      (setq i (1+ i)))
    (if (not ear-found) (setq guard 20000))
    (setq guard (1+ guard)))
  (if (= (length verts) 3)
    (reverse (cons verts triangles))
    nil)
)

(defun urb:point-u-coordinate (point angle-value)
  (+ (* (car point) (cos angle-value))
     (* (cadr point) (sin angle-value)))
)

(defun urb:u-boundary-intersection
  (p1 p2 u1 u2 limit / ratio)
  (if (< (abs (- u2 u1)) 1e-12)
    p2
    (progn
      (setq ratio (/ (- limit u1) (- u2 u1)))
      (list
        (+ (car p1) (* ratio (- (car p2) (car p1))))
        (+ (cadr p1) (* ratio (- (cadr p2) (cadr p1)))))))
)

(defun urb:clip-polygon-u-side
  (points limit angle-value keep-greater
   / output previous current previous-u current-u previous-in current-in)
  (if points
    (progn
      (setq previous (last points)
            previous-u (urb:point-u-coordinate previous angle-value)
            previous-in
              (if keep-greater (>= previous-u (- limit 1e-9))
                (<= previous-u (+ limit 1e-9))))
      (foreach current points
        (setq current-u (urb:point-u-coordinate current angle-value)
              current-in
                (if keep-greater (>= current-u (- limit 1e-9))
                  (<= current-u (+ limit 1e-9))))
        (cond
          (current-in
            (if (not previous-in)
              (setq output
                (append output
                  (list (urb:u-boundary-intersection
                          previous current previous-u current-u limit)))))
            (setq output (append output (list current))))
          (previous-in
            (setq output
              (append output
                (list (urb:u-boundary-intersection
                        previous current previous-u current-u limit))))))
        (setq previous current previous-u current-u previous-in current-in))))
  (urb:clean-polygon-points output)
)

(defun urb:clip-polygon-to-band (points umin umax angle-value / clipped)
  (setq clipped (urb:clip-polygon-u-side points umin angle-value T))
  (if clipped
    (setq clipped (urb:clip-polygon-u-side clipped umax angle-value nil)))
  (if (and clipped (> (length clipped) 2)
           (> (abs (urb:polygon-signed-area clipped)) 1e-10))
    clipped
    nil)
)

(defun urb:polygon-region (points elevation / coords poly region)
  (setq coords
    (apply 'append
      (mapcar '(lambda (p) (list (car p) (cadr p))) points)))
  (setq poly
    (vla-AddLightWeightPolyline (urb:space)
      (urb:double-array-variant coords)))
  (if (and (numberp elevation)
           (vlax-property-available-p poly 'Elevation T))
    (vla-put-Elevation poly elevation))
  (vla-put-Closed poly :vlax-true)
  (setq region (urb:add-region-from-object poly))
  (urb:safe-delete poly)
  (if (vl-catch-all-error-p region) nil region)
)

(defun urb:add-solid-hatch-detached-safe
  (boundary layer color / hatch result)
  (setq hatch
    (vl-catch-all-apply 'vla-AddHatch
      (list (urb:space) 1 "SOLID" :vlax-false)))
  (if (vl-catch-all-error-p hatch)
    nil
    (progn
      (setq result
        (vl-catch-all-apply
          '(lambda ()
             (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
             (vla-put-Layer hatch layer)
             (vla-put-Color hatch color)
             (vla-Evaluate hatch)
             hatch)))
      (if (vl-catch-all-error-p result)
        (progn (urb:safe-delete hatch) nil)
        hatch)))
)

(defun urb:add-user-hatch-detached-safe
  (boundary layer spacing angle-value double-lines color origin
   / hatch result pattern-angle)
  (setq pattern-angle (urb:wcs-angle-to-current-ucs angle-value))
  (setq hatch
    (vl-catch-all-apply 'vla-AddHatch
      (list (urb:space) 0 "USER" :vlax-false)))
  (if (vl-catch-all-error-p hatch)
    nil
    (progn
      (setq result
        (vl-catch-all-apply
          '(lambda ()
             (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
             (vla-put-Layer hatch layer)
             (vla-put-Color hatch color)
             (vla-put-PatternDouble hatch
               (if double-lines :vlax-true :vlax-false))
             (vla-put-PatternSpace hatch spacing)
             (vla-put-PatternAngle hatch pattern-angle)
             (vla-Evaluate hatch)
             (if origin (urb:set-hatch-origin-dxf hatch origin))
             hatch)))
      (if (vl-catch-all-error-p result)
        (progn (urb:safe-delete hatch) nil)
        hatch)))
)

(defun urb:decorate-composite-fallback-piece
  (points elevation angle-value origin parent-handle gray
   / region layer color solid joint1 joint2 success)
  (setq region (urb:polygon-region points elevation))
  (if region
    (progn
      (setq layer
        (if gray "URB-ANDEN-LOSETA-GRIS-20X20"
          "URB-ANDEN-BLOQUE-BLANCO-20X10")
            color (if gray 8 7)
            solid (urb:add-solid-hatch-detached-safe region layer color))
      (if solid
        (progn
          (urb:tag-generated-role solid parent-handle "FILL")
          (if gray
            (progn
              (setq joint1
                (urb:add-user-hatch-detached-safe
                  region layer 0.20 angle-value T 9 origin))
              (if joint1
                (urb:tag-generated-role joint1 parent-handle "JOINT")))
            (progn
              (setq joint1
                (urb:add-user-hatch-detached-safe
                  region layer 0.10 angle-value nil 8 origin))
              (setq joint2
                (urb:add-user-hatch-detached-safe
                  region layer 0.20 (+ angle-value (/ pi 2.0)) nil 8 origin))
              (if joint1
                (urb:tag-generated-role joint1 parent-handle "JOINT"))
              (if joint2
                (urb:tag-generated-role joint2 parent-handle "JOINT"))))
          (setq success T)))
      (urb:safe-delete region)))
  success
)

(defun urb:decorate-composite-band-fallback
  (triangles umin umax angle-value origin parent-handle gray elevation
   / triangle piece count)
  ;; Solo se usa para la banda que ACIS no pudo resolver. No pinta un
  ;; fondo general: cada pieza hereda el tono y la fase de ESA banda.
  (setq count 0)
  (foreach triangle triangles
    (setq piece (urb:clip-polygon-to-band triangle umin umax angle-value))
    (if (and piece
             (urb:decorate-composite-fallback-piece
               piece elevation angle-value origin parent-handle gray))
      (setq count (1+ count))))
  (> count 0)
)

(defun urb:clip-edge-wedge
  (base-region p1 p2 bis1 bis2 span
   / d1 d2 q1 q2 q3 q4 clipped wedge result box elevation
   den t1 t2 ix iy s1p s1n s2p s2n)
  ;; Recorta base-region con un cuadrilatero cuyos lados extremos son las
  ;; BISECTRICES en los dos extremos de la arista (junta a inglete): las
  ;; franjas de aristas vecinas empatan exactamente en la bisectriz, sin
  ;; traslaparse ni dejar cunas vacias. Los rectangulos por-arista que se
  ;; usaban antes se pisaban entre si en cada quiebre de la cadena y el
  ;; material o la guia quedaban dibujados DOS veces con angulos distintos
  ;; (la "guia cruzada en diagonal sobre la reticula" que reporto el
  ;; usuario en las transiciones de curva).
  (setq box (urb:object-box-points base-region)
        elevation (if (and box (caddr (car box))) (caddr (car box)) 0.0))
  (setq d1 (list (cos bis1) (sin bis1))
        d2 (list (cos bis2) (sin bis2)))
  ;; En una curva cerrada las dos bisectrices se CRUZAN en el centro de
  ;; curvatura: extender la cuna el span completo hacia ese lado la hace
  ;; atravesar el centro y pintar tambien el lado OPUESTO del anillo (se
  ;; vio como una malla cruzada/zigzag en el medio de un anden en abanico).
  ;; Se recorta la extension de ese lado justo antes del cruce.
  (setq den (- (* (car d1) (cadr d2)) (* (cadr d1) (car d2))))
  (setq t1 nil t2 nil)
  (if (> (abs den) 1e-9)
    (progn
      (setq t1 (/ (- (* (- (car p2) (car p1)) (cadr d2))
                     (* (- (cadr p2) (cadr p1)) (car d2)))
                  den))
      (setq ix (+ (car p1) (* t1 (car d1)))
            iy (+ (cadr p1) (* t1 (cadr d1))))
      (setq t2 (+ (* (- ix (car p2)) (car d2))
                  (* (- iy (cadr p2)) (cadr d2))))))
  (setq s1p span s1n span s2p span s2n span)
  (if (and t1 (> t1 0.0)) (setq s1p (min span (* 0.999 t1))))
  (if (and t1 (< t1 0.0)) (setq s1n (min span (* 0.999 (- t1)))))
  (if (and t2 (> t2 0.0)) (setq s2p (min span (* 0.999 t2))))
  (if (and t2 (< t2 0.0)) (setq s2n (min span (* 0.999 (- t2)))))
  (setq q1 (list (+ (car p1) (* s1p (car d1))) (+ (cadr p1) (* s1p (cadr d1))))
        q2 (list (+ (car p2) (* s2p (car d2))) (+ (cadr p2) (* s2p (cadr d2))))
        q3 (list (- (car p2) (* s2n (car d2))) (- (cadr p2) (* s2n (cadr d2))))
        q4 (list (- (car p1) (* s1n (car d1))) (- (cadr p1) (* s1n (cadr d1)))))
  (setq wedge (vl-catch-all-apply 'urb:quad-region (list q1 q2 q3 q4 elevation)))
  (if (vl-catch-all-error-p wedge)
    nil
    (progn
      (setq clipped (vla-Copy base-region))
      (setq result (vl-catch-all-apply 'vla-Boolean (list clipped 1 wedge)))
      (if (vl-catch-all-error-p result)
        (progn
          (urb:safe-delete clipped)
          (urb:safe-delete wedge)
          nil)
        clipped)))
)

(defun urb:chain-edge-bisectors (edges / n i result prev-dir cur-dir next-dir b1 b2)
  ;; Para cada arista de una cadena ABIERTA: los angulos de las lineas de
  ;; corte en sus dos extremos. En un vertice interior es la bisectriz
  ;; entre las direcciones reales de las dos aristas que se encuentran
  ;; (rotada 90 para ser linea de corte); en los extremos de la cadena es
  ;; la perpendicular a la propia arista. Se recalcula la direccion real
  ;; con (angle p1 p2) porque el (nth 3 edge) viene colapsado a medio giro
  ;; por urb:normalize-axis-angle y perderia el sentido de avance.
  (setq n (length edges) result nil i 0)
  (repeat n
    (setq cur-dir
      (urb:normalize-full-angle
        (angle (nth 0 (nth i edges)) (nth 1 (nth i edges)))))
    (setq prev-dir
      (if (> i 0)
        (urb:normalize-full-angle
          (angle (nth 0 (nth (1- i) edges)) (nth 1 (nth (1- i) edges))))
        nil))
    (setq next-dir
      (if (< i (1- n))
        (urb:normalize-full-angle
          (angle (nth 0 (nth (1+ i) edges)) (nth 1 (nth (1+ i) edges))))
        nil))
    (setq b1
      (+ (if prev-dir
           (+ prev-dir (* 0.5 (urb:turning-angle prev-dir cur-dir)))
           cur-dir)
         (* 0.5 pi)))
    (setq b2
      (+ (if next-dir
           (+ cur-dir (* 0.5 (urb:turning-angle cur-dir next-dir)))
           cur-dir)
         (* 0.5 pi)))
    (setq result (cons (list b1 b2) result))
    (setq i (1+ i)))
  (reverse result)
)

(defun urb:points-span (points / bounds)
  ;; Longitud generosa para extender las cunas de recorte mas alla de todo
  ;; el contorno (diagonal del bbox + margen).
  (setq bounds (urb:project-bounds points 0.0))
  (+ (- (nth 1 bounds) (nth 0 bounds))
     (- (nth 3 bounds) (nth 2 bounds))
     10.0)
)

(defun urb:add-solid-hatch-safe
  (boundary layer color / hatch result)
  ;; Variante transaccional para las bandas del anden. Si AppendOuterLoop,
  ;; propiedades o Evaluate fallan, elimina el HATCH parcial y devuelve nil;
  ;; asi el caller puede volver a recortar y reintentar la banda completa.
  (setq hatch
    (vl-catch-all-apply
      'vla-AddHatch
      (list (urb:space) 1 "SOLID" :vlax-true)))
  (if (vl-catch-all-error-p hatch)
    nil
    (progn
      (setq result
        (vl-catch-all-apply
          '(lambda ()
             (vla-AppendOuterLoop hatch (urb:make-loop-array boundary))
             (vla-put-Layer hatch (urb:safe-string layer "0"))
             (vla-put-Color hatch color)
             (vla-Evaluate hatch)
             hatch)))
      (if (vl-catch-all-error-p result)
        (progn (urb:safe-delete hatch) nil)
        hatch)))
)

(defun urb:decorate-gray-stripe
  (region angle-value origin parent-handle / result joints)
  ;; Antes vivia en la capa auxiliar URB-ANDEN-AUX (no imprimible, separada
  ;; del material). Se fusiono en la capa de material real; el rol FILL
  ;; (xdata) es lo que mantiene el orden de dibujo correcto ahora.
  (vla-put-Layer region "URB-ANDEN-LOSETA-GRIS-20X20")
  (urb:tag-generated-role region parent-handle "FILL")
  (setq result
    (urb:add-solid-hatch-safe
      region "URB-ANDEN-LOSETA-GRIS-20X20" 8))
  (if result
    (progn
      (urb:tag-generated-role result parent-handle "FILL")
      (setq joints
        (urb:add-user-hatch
          region
          "URB-ANDEN-LOSETA-GRIS-20X20"
          0.20
          angle-value
          T
          9
          origin))
      (urb:tag-generated-role joints parent-handle "JOINT")
      T)
    nil)
)

(defun urb:decorate-white-stripe
  (region angle-value origin parent-handle / result joints-u joints-v)
  (vla-put-Layer region "URB-ANDEN-BLOQUE-BLANCO-20X10")
  (urb:tag-generated-role region parent-handle "FILL")
  (setq result
    (urb:add-solid-hatch-safe
      region "URB-ANDEN-BLOQUE-BLANCO-20X10" 7))
  (if result
    (progn
      (urb:tag-generated-role result parent-handle "FILL")
      ;; Bloque blanco de 0.20 x 0.10 m, alineado con el origen comun.
      (setq joints-u
        (urb:add-user-hatch
          region
          "URB-ANDEN-BLOQUE-BLANCO-20X10"
          0.10
          angle-value
          nil
          8
          origin))
      (urb:tag-generated-role joints-u parent-handle "JOINT")
      (setq joints-v
        (urb:add-user-hatch
          region
          "URB-ANDEN-BLOQUE-BLANCO-20X10"
          0.20
          (+ angle-value (/ pi 2.0))
          nil
          8
          origin))
      (urb:tag-generated-role joints-v parent-handle "JOINT")
      T)
    nil)
)

(defun urb:decorate-composite-stripe
  (base-region umin umax vmin vmax angle-value origin parent-handle gray
   / eps region success)
  ;; El exito exige DOS cosas: region con area y relleno SOLID evaluado.
  ;; Si cualquiera falla, elimina la tentativa y repite con mas solape.
  (foreach eps (urb:stripe-overlaps)
    (if (null success)
      (progn
        (setq region
          (urb:clip-stripe-once
            base-region (- umin eps) (+ umax eps)
            (- vmin eps) (+ vmax eps) angle-value))
        (if region
          (progn
            (setq success
              (if gray
                (urb:decorate-gray-stripe
                  region angle-value origin parent-handle)
                (urb:decorate-white-stripe
                  region angle-value origin parent-handle)))
            (if (not success) (urb:safe-delete region)))))))
  success
)

(defun urb:create-two-axis-regions
  (base-region split-data / first second split-angle bounds margin split-v
   first-low umin umax vmin vmax first-region second-region)
  (setq first (nth 0 split-data)
        second (nth 1 split-data)
        split-angle (nth 3 split-data)
        bounds (nth 4 split-data)
        margin (nth 5 split-data)
        split-v (nth 6 split-data)
        first-low (nth 7 split-data)
        umin (- (nth 0 bounds) margin)
        umax (+ (nth 1 bounds) margin)
        vmin (- (nth 2 bounds) margin)
        vmax (+ (nth 3 bounds) margin))
  (if first-low
    (setq first-region
      (urb:clip-stripe
        base-region umin umax vmin split-v split-angle)
          second-region
      (urb:clip-stripe
        base-region umin umax split-v vmax split-angle))
    (setq first-region
      (urb:clip-stripe
        base-region umin umax split-v vmax split-angle)
          second-region
      (urb:clip-stripe
        base-region umin umax vmin split-v split-angle)))
  (if (and first-region second-region)
    (list
      (list first-region (nth 0 first))
      (list second-region (nth 0 second)))
    (progn
      (urb:safe-delete first-region)
      (urb:safe-delete second-region)
      nil))
)

(defun urb:composite-phase-state (phase-offset / gray-w white-w period phase-mod)
  ;; Dado un phase-offset (distancia global acumulada desde el arranque de
  ;; TODO el patron gris/blanco, no solo este segmento), devuelve
  ;; (gris-actual . ancho-restante-de-esa-banda): el color y cuanto falta
  ;; de la banda que ya estaba a medio camino cuando arranca este
  ;; segmento, para continuar el patron 0.80/1.00m sin reiniciar. Sin
  ;; esto, cada segmento de una curva reinicia su propia franja gris en
  ;; u=0 y el patron se ve partido/reducido a una sola hilera en las
  ;; transiciones (aristas cortas del muestreo de arco).
  (setq gray-w 0.80 white-w 1.00)
  (setq period (+ gray-w white-w))
  (setq phase-mod (- phase-offset (* period (fix (/ phase-offset period)))))
  (if (< phase-mod 0.0) (setq phase-mod (+ phase-mod period)))
  (if (< phase-mod gray-w)
    (cons T (- gray-w phase-mod))
    (cons nil (- period (- phase-mod gray-w)))))

(defun urb:decorate-composite-region
  (base-region angle-value format parent-handle reverse-pattern phase-offset
   fallback-points
   / points bounds umin umax actual-vmin actual-vmax vmin vmax
   cursor next gray count origin pattern-v-origin module layer grid
   phase-state first-band band-width iter-guard band-ok fallback-triangles
   elevation box all-bands-ok band-umin band-umax)
  (setq points (urb:region-outline-points base-region))
  (if (null points)
    (setq points (urb:object-box-points base-region)))
  (setq module (urb:loseta-module format))
  (if (null points)
    (progn (urb:safe-delete base-region) nil)
    (progn
      (setq bounds (urb:project-bounds points angle-value)
            umin (nth 0 bounds)
            umax (nth 1 bounds)
            actual-vmin (nth 2 bounds)
            actual-vmax (nth 3 bounds)
            pattern-v-origin actual-vmin)
      ;; Origen UNICO de reticula para toda la zona, corrido para caer
      ;; sobre la reticula GLOBAL de la cadena (phase-offset = distancia
      ;; acumulada desde el arranque). Antes cada banda anclaba su propia
      ;; reticula en su umin local: la primera banda parcial de cada
      ;; segmento quedaba con las juntas corridas respecto al resto del
      ;; corredor, y la franja de guia/toperol (que ancla a esta misma
      ;; reticula global) no coincidia con las juntas del material.
      (setq origin
        (urb:local-to-world
          (if reverse-pattern
            (+ umax (urb:grid-phase-shift (if phase-offset phase-offset 0.0) module))
            (- umin (urb:grid-phase-shift (if phase-offset phase-offset 0.0) module)))
          pattern-v-origin angle-value))
      (if (> module 0.30)
        (progn
          ;; Cada zona conserva su propia reticula, pero sigue perteneciendo
          ;; al mismo bloque y al mismo registro de cantidades.
          (setq layer "URB-ANDEN-LOSETA-LISA-40X40")
          (vla-put-Layer base-region layer)
          (urb:tag-generated-role base-region parent-handle "FILL")
          (setq grid
            (urb:add-user-hatch
              base-region layer module angle-value T 9 origin))
          (if (not (vl-catch-all-error-p grid))
            (urb:tag-generated-role grid parent-handle "JOINT"))
          (and grid (not (vl-catch-all-error-p grid))))
        (progn
          ;; Detalle 20x20: 0.80 m de loseta gris y 1.00 m de adoquin
          ;; blanco, repetidos sobre el eje local de esta zona.
          (setq fallback-triangles
            (if fallback-points
              (urb:triangulate-polygon fallback-points)
              nil))
          (setq box (urb:object-box-points base-region)
                elevation
                  (if (and box (caddr (car box)))
                    (caddr (car box)) 0.0)
                all-bands-ok T)
          (setq vmin (- actual-vmin 1.0)
                vmax (+ actual-vmax 1.0)
                cursor (if reverse-pattern umax umin)
                count 0)
          (setq phase-state (urb:composite-phase-state (if phase-offset phase-offset 0.0)))
          (setq gray (car phase-state) first-band T iter-guard 0)
          (while
            (and
              (if reverse-pattern
                (> cursor (+ umin 0.000001))
                (< cursor (- umax 0.000001)))
              ;; respaldo defensivo: con un phase-offset acumulado de
              ;; punto flotante, el ancho de la primera banda de cada
              ;; segmento podria salir negativo o casi cero por un caso
              ;; extremo no cubierto en urb:composite-phase-state -- sin
              ;; este limite duro de iteraciones, eso puede colgar el
              ;; comando en vez de simplemente fallar (se vio un
              ;; colgado real al agregar la fase continua sin este
              ;; respaldo). 20000 iteraciones alcanza sobrado para
              ;; cualquier anden real (un modulo de 1.8m en un tramo de
              ;; varios kilometros).
              (< iter-guard 20000))
            (setq iter-guard (1+ iter-guard))
            (setq band-width (if first-band (cdr phase-state) (if gray 0.80 1.00)))
            (if (< band-width 0.001) (setq band-width 0.001))
            (setq next
              (if reverse-pattern
                (max umin (- cursor band-width))
                (min umax (+ cursor band-width))))
            ;; todas las bandas comparten el origen global ya alineado.
            ;; La rutina solo devuelve T cuando tambien existe el SOLID.
            (setq band-umin (if reverse-pattern next cursor)
                  band-umax (if reverse-pattern cursor next))
            (setq band-ok
              (urb:decorate-composite-stripe
                base-region band-umin band-umax vmin vmax angle-value
                origin parent-handle gray))
            ;; Una banda que cruza un contorno concavo puede producir dos
            ;; o mas islas. Si ACIS no devuelve una region util, se recorta
            ;; geometricamente contra triangulos internos; el tono y el
            ;; origen de reticula siguen siendo los de la banda original.
            (if (and (not band-ok) fallback-triangles)
              (setq band-ok
                (urb:decorate-composite-band-fallback
                  fallback-triangles band-umin band-umax angle-value
                  origin parent-handle gray elevation)))
            (if band-ok (setq count (1+ count)))
            (if (not band-ok) (setq all-bands-ok nil))
            (setq cursor next
                  gray (not gray)
                  first-band nil))
          ;; La region maestra ya no queda como fondo blanco: ocultaba el
          ;; fallo, pero convertia toda la banda ausente en adoquin blanco.
          (urb:safe-delete base-region)
          (and (> count 0) all-bands-ok)))))
)

(defun urb:turning-angle (a1 a2 / delta two-pi)
  ;; Diferencia angular real (con sentido) entre dos direcciones, normalizada
  ;; al rango -pi a pi. A diferencia de urb:axis-angle-distance (que trata un eje y
  ;; su opuesto como el mismo eje), aqui SI importa el sentido de avance:
  ;; es el angulo que se "gira" al pasar de una arista a la siguiente.
  (setq two-pi (* 2.0 pi))
  (setq delta (- a2 a1))
  (while (> delta pi) (setq delta (- delta two-pi)))
  (while (<= delta (- pi)) (setq delta (+ delta two-pi)))
  delta
)

(defun urb:polygon-corner-indices
  (points threshold / n edges i prev-a next-a delta result prev-edge next-edge)
  ;; Indices de vertices donde el contorno gira mas de "threshold": son las
  ;; esquinas reales (donde un lado largo del anden termina y empieza otro,
  ;; o donde esta la tapa corta de un extremo). Los vertices intermedios de
  ;; un tramo curvo aproximado con muchos segmentos cortos giran poco cada
  ;; uno y no cuentan como esquina.
  (setq n (length points))
  (if (< n 3)
    nil
    (progn
      (setq edges (urb:polygon-edge-records points))
      (setq result nil i 0)
      (repeat n
        ;; OJO: (nth 3 edge) viene de urb:polygon-edge-records, que lo
        ;; normaliza con urb:normalize-axis-angle (colapsa un angulo y su
        ;; opuesto a 180 grados al mismo valor - correcto para agrupar por
        ;; eje, pero aqui necesitamos el sentido real de avance). Se
        ;; recalcula el angulo direccional completo desde los propios
        ;; extremos de cada arista para no heredar ese colapso: si la
        ;; tangente de un tramo curvo pasa cerca de 0/180 grados, usar el
        ;; valor ya colapsado genera un salto falso de ~180 grados justo
        ;; ahi y parte el lado guia en dos a la mitad.
        (setq prev-edge (nth (rem (+ i (1- n)) n) edges)
              next-edge (nth i edges))
        (setq prev-a (urb:normalize-full-angle (angle (nth 0 prev-edge) (nth 1 prev-edge)))
              next-a (urb:normalize-full-angle (angle (nth 0 next-edge) (nth 1 next-edge))))
        (setq delta (urb:turning-angle prev-a next-a))
        (if (> (abs delta) threshold) (setq result (cons i result)))
        (setq i (1+ i)))
      (reverse result))))

(defun urb:polygon-chains-at-corners (points corners / n sorted k chains j start end idx chain)
  ;; Parte el contorno cerrado en tramos abiertos entre esquinas consecutivas.
  ;; Cada tramo conserva sus vertices reales tal como quedaron dibujados.
  (setq n (length points) sorted (vl-sort corners '<) k (length sorted))
  (if (< k 2)
    nil
    (progn
      (setq chains nil j 0)
      (repeat k
        (setq start (nth j sorted)
              end (nth (rem (1+ j) k) sorted))
        (setq idx start chain (list (nth idx points)))
        (while (/= idx end)
          (setq idx (rem (1+ idx) n))
          (setq chain (cons (nth idx points) chain)))
        (setq chains (cons (reverse chain) chains))
        (setq j (1+ j)))
      (reverse chains))))

(defun urb:chain-total-length (chain / total rest)
  (setq total 0.0 rest chain)
  (while (cadr rest)
    (setq total (+ total (distance (car rest) (cadr rest))))
    (setq rest (cdr rest)))
  total
)

(defun urb:longest-chain (chains / best best-length chain len)
  (setq best nil best-length -1.0)
  (foreach chain chains
    (setq len (urb:chain-total-length chain))
    (if (> len best-length) (setq best chain best-length len)))
  best
)

(defun urb:dedupe-ring-points (points / result pt)
  ;; Quita vertices consecutivos duplicados (y el cierre duplicado
  ;; ultimo==primero). Un doble click al dibujar -- o el muestreo de un
  ;; arco que cae exacto sobre el vertice siguiente -- deja una arista de
  ;; longitud CERO: urb:polygon-edge-records la salta, pero
  ;; urb:polygon-corner-indices indexa por vertice, y ese descuadre
  ;; terminaba en (angle nil nil) = "bad argument type: consp nil",
  ;; rechazando por seguridad contornos curvos perfectamente validos.
  (foreach pt points
    ;; descartar de una vez cualquier punto malformado (nil o coordenadas
    ;; no numericas) que se haya colado del muestreo
    (if (and pt (numberp (car pt)) (numberp (cadr pt))
             (or (null result) (> (distance pt (car result)) 1e-8)))
      (setq result (cons pt result))))
  (setq result (reverse result))
  (if (and (> (length result) 1)
           (<= (distance (car result) (last result)) 1e-8))
    (reverse (cdr (reverse result)))
    result)
)

(defun urb:anden-tactile-chain (points / clean corners chains ref best best-d chain mid d)
  ;; Cadena del contorno MAS CERCANA al lado de la via marcado por el
  ;; usuario: la franja tactil debe seguir el borde de la via (p.ej. el
  ;; arco INTERIOR de un anden en abanico), no el lado mas largo del
  ;; contorno -- guiando por el lado largo, en un abanico la guia quedaba
  ;; proyectada desde el otro lado del anillo y salia fragmentada.
  (setq clean (urb:dedupe-ring-points points))
  (setq corners (urb:polygon-corner-indices clean (* pi (/ 45.0 180.0))))
  (setq chains (urb:polygon-chains-at-corners clean corners))
  (setq ref nil)
  (if *urb-current-tactile-side-choice*
    (setq ref (urb:tactile-side-point-from-choice *urb-current-tactile-side-choice* clean)))
  (if (and (null ref) *urb-current-tactile-side-point*)
    (setq ref *urb-current-tactile-side-point*))
  (if (or (null ref) (null chains))
    (if chains (urb:longest-chain chains) nil)
    (progn
      (setq best nil best-d nil)
      (foreach chain chains
        (setq mid (nth (/ (length chain) 2) chain))
        (setq d (distance mid ref))
        ;; ignorar remates cortos (tapas de extremo)
        (if (and (> (urb:chain-total-length chain) 0.5)
                 (or (null best-d) (< d best-d)))
          (setq best chain best-d d)))
      (if best best (urb:longest-chain chains))))
)

(defun urb:anden-driving-chain (points / corners chains)
  ;; Un solo lado largo del anden (tramo abierto de vertices reales) que se
  ;; usa como guia para modular segmento por segmento. Para un anden simple
  ;; de 4 vertices da un unico tramo de 1 arista (equivalente al eje unico
  ;; de siempre); para un anden curvo con muchos vertices da el lado largo
  ;; completo con todos sus quiebres reales.
  (setq points (urb:dedupe-ring-points points))
  (setq corners (urb:polygon-corner-indices points (* pi (/ 45.0 180.0))))
  (setq chains (urb:polygon-chains-at-corners points corners))
  (if chains (urb:longest-chain chains) nil)
)

(defun urb:point-in-list-p (pt lst / found)
  (setq found nil)
  (foreach p lst (if (equal p pt 1e-6) (setq found T)))
  found)

(defun urb:chain-width-samples (points driving-chain / other-points p q d best result)
  ;; Estima el ancho local en cada punto del lado largo (driving-chain)
  ;; como la distancia al punto mas cercano del RESTO del contorno (el
  ;; lado opuesto + remates). No requiere booleans/regiones -- solo sirve
  ;; para detectar una franja que se "infla" en el medio, no para medir
  ;; con precision (eso ya lo hace urb:clip-stripe en el resto del codigo).
  (setq other-points nil)
  (foreach p points
    (if (not (urb:point-in-list-p p driving-chain))
      (setq other-points (cons p other-points))))
  (if (< (length other-points) 1)
    nil
    (progn
      (setq result nil)
      (foreach p driving-chain
        (setq best nil)
        (foreach q other-points
          (setq d (distance p q))
          (if (or (null best) (< d best)) (setq best d)))
        (if best (setq result (cons best result))))
      result)))

(defun urb:anden-width-anomaly-p (points / driving-chain widths minw maxw minmax)
  ;; Detecta un contorno de anden donde el ancho local varia demasiado
  ;; (ej. una franja que se infla bastante en un tramo) -- sintoma de
  ;; clics imprecisos al dibujar, no de un cruce (eso lo cubre
  ;; urb:polygon-self-intersects-p aparte). Un anden real puede angostarse
  ;; gradualmente (una rampa, un remate) sin que eso sea un error; el
  ;; umbral (relacion Y diferencia absoluta) busca solo el caso de bulto
  ;; ancho e inesperado, no variaciones normales de diseno.
  ;;
  ;; IMPORTANTE: se usa min/max RECORTADO (urb:trimmed-min-max), no el
  ;; min/max crudo. urb:chain-width-samples mide distancia al punto mas
  ;; cercano del resto del contorno, y ese heuristico falla puntualmente
  ;; justo antes de una esquina (verificado con un caso real: de 27
  ;; muestras, 26 dieron 3.96-4.93m consistente y solo 1 punto aislado
  ;; junto a una esquina salto a 11.2m). Con min/max crudo ese unico punto
  ;; disparaba un falso positivo sobre un anden bien dibujado.
  (setq driving-chain (urb:anden-driving-chain points))
  (if (and driving-chain (>= (length driving-chain) 2))
    (progn
      (setq widths (urb:chain-width-samples points driving-chain))
      (if (and widths (>= (length widths) 2))
        (progn
          (setq minmax (urb:trimmed-min-max widths))
          (setq minw (nth 0 minmax) maxw (nth 1 minmax))
          (and (> maxw (* 2.5 (max minw 0.01))) (> (- maxw minw) 1.5)))
        nil))
    nil))

(defun urb:trimmed-min-max (widths / sorted n trim)
  ;; min/max descartando el ~10% superior e inferior (minimo 1 muestra de
  ;; cada lado si hay suficientes datos) para no dejar que UN punto atipico
  ;; (comun cerca de una esquina, ver comentario de
  ;; urb:anden-width-anomaly-p) dispare la deteccion.
  (setq sorted (vl-sort widths '<))
  (setq n (length sorted))
  (setq trim (max 1 (fix (* n 0.10))))
  (if (< n (* 2 (1+ trim)))
    (list (car sorted) (last sorted))
    (list (nth trim sorted) (nth (- n 1 trim) sorted))))

(defun urb:open-chain-edges (chain-points / result rest p1 p2 edge-length)
  ;; Igual que urb:polygon-edge-records pero para un tramo ABIERTO (no cierra
  ;; el ultimo vertice contra el primero).
  (setq rest chain-points result nil)
  (while (cadr rest)
    (setq p1 (car rest) p2 (cadr rest) edge-length (distance p1 p2))
    (if (> edge-length 1e-8)
      (setq result
        (cons (list p1 p2 edge-length (urb:normalize-axis-angle (angle p1 p2))) result)))
    (setq rest (cdr rest)))
  (reverse result)
)

(defun urb:decorate-composite-region-segmented
  (base-region driving-chain format parent-handle reverse-pattern
   / edges edge angle-value cosine sine u1 u2 umin umax
   bounds-all vmin-all vmax-all slice count points-all
   cum-offset total-length phase-offset bisectors edge-index bis span)
  ;; Modula el anden segmento por segmento siguiendo el contorno real en vez
  ;; de un unico eje: cada arista del lado guia recorta su propia franja del
  ;; anden (el resto del ancho se recorta solo por el boolean contra el
  ;; contorno real) y se decora con SU angulo local, para que la reticula
  ;; siga la curva en lugar de desviarse a medida que uno se aleja del punto
  ;; donde se calculo el eje unico.
  ;; cum-offset/phase-offset: igual que en urb:create-accessibility-
  ;; features-segmented, para que el patron gris/blanco de 0.80/1.00m sea
  ;; una sola progresion continua a lo largo de todo el corredor en vez de
  ;; reiniciar en cada arista corta del muestreo de un arco (lo que dejaba
  ;; solo una hilera de adoquin en las transiciones de curva).
  (setq edges (urb:open-chain-edges driving-chain))
  (setq points-all (urb:region-outline-points base-region))
  (if (null points-all) (setq points-all (urb:object-box-points base-region)))
  (setq count 0 cum-offset 0.0 edge-index 0)
  (setq total-length (urb:chain-total-length driving-chain))
  ;; Cunas a inglete (bisectrices) en vez de rectangulos por-arista: los
  ;; rectangulos de aristas vecinas se traslapaban en los quiebres y el
  ;; patron quedaba pintado dos veces con angulos distintos en cada
  ;; transicion de curva. Si la cuna falla (boolean degenerado), se cae al
  ;; rectangulo de siempre para no dejar la arista sin material.
  (setq bisectors (urb:chain-edge-bisectors edges))
  (setq span (urb:points-span points-all))
  (foreach edge edges
    (setq angle-value (nth 3 edge)
          cosine (cos angle-value)
          sine (sin angle-value))
    (setq u1 (+ (* (car (nth 0 edge)) cosine) (* (cadr (nth 0 edge)) sine)))
    (setq u2 (+ (* (car (nth 1 edge)) cosine) (* (cadr (nth 1 edge)) sine)))
    (setq umin (min u1 u2) umax (max u1 u2))
    (setq bis (nth edge-index bisectors))
    (setq slice
      (urb:clip-edge-wedge
        base-region (nth 0 edge) (nth 1 edge)
        (nth 0 bis) (nth 1 bis) span))
    (if (null slice)
      (progn
        (setq bounds-all (urb:project-bounds points-all angle-value)
              vmin-all (nth 2 bounds-all)
              vmax-all (nth 3 bounds-all))
        (setq slice (urb:clip-stripe base-region umin umax vmin-all vmax-all angle-value))))
    (setq phase-offset
      (if reverse-pattern
        (- total-length (+ cum-offset (- umax umin)))
        cum-offset))
    (if slice
      (progn
        (urb:decorate-composite-region
          slice angle-value format parent-handle reverse-pattern phase-offset nil)
        (setq count (1+ count))))
    (setq cum-offset (+ cum-offset (- umax umin)))
    (setq edge-index (1+ edge-index)))
  (urb:safe-delete base-region)
  (> count 0)
)

(defun urb:create-composite-loseta
  (ename format / obj copy base-region points fine-points parent-handle clusters
   split-data zones zone success angle-value pattern-mode reverse-pattern
   driving-chain forced-angle)
  (setq obj (vlax-ename->vla-object ename)
        parent-handle (vla-get-Handle obj)
        points (urb:lwpoly-points-with-arcs ename)
        fine-points (urb:lwpoly-points-with-arcs-fine ename)
        pattern-mode (urb:anden-pattern-mode ename)
        reverse-pattern (urb:anden-pattern-reversed-p pattern-mode)
        clusters (urb:dominant-anden-axis-clusters points)
        copy (vla-Copy obj)
        base-region (urb:add-region-from-object copy))
  ;; 2026-08-12: eje FORZADO de modulacion (URB_ANDEN_AXIS) -- lo marca
  ;; el usuario al crear un anden con curva (2 puntos paralelos a las
  ;; bandas del vecino). Si no hay eje guardado pero el contorno tiene
  ;; arcos, se asume bandas paralelas al lado recto mas largo (la tapa
  ;; compartida con el modulo vecino): eje = ese lado + 90.
  (setq forced-angle
    (urb:parse-real
      (urb:safe-string
        (car (urb:get-xdata-strings ename "URB_ANDEN_AXIS")) "")))
  (if (and (null forced-angle) (urb:lwpoly-has-arcs-p ename))
    (progn
      (setq forced-angle (urb:anden-straight-edges-angle ename))
      (if forced-angle
        (setq forced-angle (+ forced-angle (* 0.5 pi))))))
  (urb:safe-delete copy)
  (if (vl-catch-all-error-p base-region)
    nil
    (progn
      ;; IMPORTANTE (2026-08-09, decision del usuario con foto del plano):
      ;; el material NO se modula en abanico siguiendo la curva. Las
      ;; losetas/adoquines conservan la MISMA orientacion del tramo recto
      ;; ("como si el anden fuera recto") y el contorno curvo solo RECORTA
      ;; el patron; en un anden en L cada pierna lleva su propio eje y se
      ;; encuentran en la esquina (two-axis-split, el comportamiento
      ;; original). El modo segmentado por aristas
      ;; (urb:decorate-composite-region-segmented) queda solo como codigo
      ;; de respaldo, ya no se invoca para el material. La franja tactil
      ;; SI sigue el borde curvo (metodo offset), como en el plano.
      (progn
        (progn
          ;; 2026-08-12: la particion en dos ejes SOLO aplica a andenes en
          ;; L con esquinas rectas y sin eje forzado. Con eje forzado o
          ;; arcos, UN solo eje y la curva solo recorta.
          (if (and (null forced-angle)
                   (> (length clusters) 1)
                   (not (urb:lwpoly-has-arcs-p ename)))
            (setq split-data
              (urb:two-axis-split-data
                points (car clusters) (cadr clusters))))
          (if split-data
            (progn
              (setq zones
                (urb:create-two-axis-regions base-region split-data))
              (if zones
                (progn
                  (urb:safe-delete base-region)
                  (setq success T)
                  (foreach zone zones
                    (if (not
                          (urb:decorate-composite-region
                            (car zone)
                            (urb:anden-pattern-angle
                              (cadr zone) pattern-mode)
                            format parent-handle
                            reverse-pattern 0.0 nil))
                      (setq success nil)))
                  success)
                (progn
                  ;; Si la particion geometrica falla, se conserva un resultado
                  ;; util usando el eje principal en lugar de dejar el anden vacio.
                  (setq angle-value
                    (cond
                      (forced-angle forced-angle)
                      (clusters (car (car clusters)))
                      (T (urb:anden-axis-angle points))))
                  (setq angle-value
                    (urb:anden-pattern-angle
                      angle-value pattern-mode))
                  (urb:decorate-composite-region
                    base-region angle-value format parent-handle
                    reverse-pattern 0.0 fine-points))))
            (progn
              (setq angle-value
                (cond
                  (forced-angle forced-angle)
                  (clusters (car (car clusters)))
                  (T (urb:anden-axis-angle points))))
              (setq angle-value
                (urb:anden-pattern-angle
                  angle-value pattern-mode))
              (urb:decorate-composite-region
                base-region angle-value format parent-handle
                reverse-pattern 0.0 fine-points)))))))
)

(defun urb:generated-xdata-fragment (parent-handle role)
  ;; Mismo formato que produce urb:set-xdata-strings (app URB_ANDEN_GEN,
  ;; valores string en grupo 1000) pero como fragmento DXF listo para
  ;; incrustar directo en un entmake -- evita el ciclo entget+entmod+entupd
  ;; de urb:tag-generated-role/urb:set-xdata-strings, que a escala de
  ;; miles de simbolos tactiles (decenas de miles en una franja larga
  ;; real) resulto ser un cuello de botella severo (minutos extra de
  ;; proceso). El caller debe asegurar que el APPID ya este registrado
  ;; (regapp) antes de usar esto -- entmake no registra el APPID solo.
  (list -3
    (list "URB_ANDEN_GEN"
          (cons 1000 (urb:safe-string parent-handle ""))
          (cons 1000 (urb:safe-string role ""))))
)

(defun urb:add-circle-symbol (u v radius angle-value layer parent-handle color / world-pt)
  ;; Punto tactil real (toperol): un circulo dibujado, no una marca de hatch
  ;; de longitud cero. Coincide visualmente con la loseta toperol real
  ;; (domos truncados dibujados como aros), no con un simple punteado.
  ;; El xdata URB_ANDEN_GEN va incrustado aqui mismo (ver
  ;; urb:generated-xdata-fragment) para que urb:package-anden encuentre y
  ;; empaquete el simbolo sin una llamada extra de tag por objeto.
  (setq world-pt (urb:local-to-world u v angle-value))
  (entmake
    (list
      (cons 0 "CIRCLE")
      (cons 100 "AcDbEntity")
      (cons 8 layer)
      ;; tono OPUESTO a la banda (blanco sobre gris, gris sobre blanco):
      ;; con el mismo tono de la tableta el simbolo no se veia
      (cons 62 color)
      (cons 100 "AcDbCircle")
      (cons 10 (list (car world-pt) (cadr world-pt) 0.0))
      (cons 40 radius)
      (urb:generated-xdata-fragment parent-handle "FEATURE_SYMBOL")))
  (entlast)
)

(defun urb:add-capsule-symbol
  (u v half-length half-width angle-value layer parent-handle color
   / p1 p2 p3 p4)
  ;; Barra tactil real (guia): una capsula (rectangulo con extremos
  ;; semicirculares, via bulge=1 en 2 de los 4 vertices) con el eje largo
  ;; a lo largo de U (direccion de avance) -antes era un simple guion recto,
  ;; sin extremos redondeados, que no se parecia a la loseta guia real.
  (setq p1 (urb:local-to-world (- u half-length) (+ v half-width) angle-value)
        p2 (urb:local-to-world (+ u half-length) (+ v half-width) angle-value)
        p3 (urb:local-to-world (+ u half-length) (- v half-width) angle-value)
        p4 (urb:local-to-world (- u half-length) (- v half-width) angle-value))
  (entmake
    (list
      (cons 0 "LWPOLYLINE")
      (cons 100 "AcDbEntity")
      (cons 8 layer)
      ;; mismo criterio que el circulo: tono opuesto a la banda
      (cons 62 color)
      (cons 100 "AcDbPolyline")
      (cons 90 4)
      (cons 70 1)
      (cons 10 p1) (cons 42 0.0)
      (cons 10 p2) (cons 42 1.0)
      (cons 10 p3) (cons 42 0.0)
      (cons 10 p4) (cons 42 1.0)
      (urb:generated-xdata-fragment parent-handle "FEATURE_SYMBOL")))
  (entlast)
)

(defun urb:fill-tactile-symbols
  (region feature angle-value layer phase-offset parent-handle module
   / points bounds umin umax vmin vmax spacing margin v count
   radius half-length half-width global-u local-u seg-len sym-ename
   tile-k tile-g su sym-color)
  ;; Reparte simbolos tactiles reales (circulos o capsulas) en una reticula
  ;; de 5 cm sobre el area ya recortada de la franja, en vez de depender de
  ;; un patron .pat (que solo puede construirse con familias de lineas
  ;; rectas y nunca se va a parecer a un domo truncado circular u ovalado).
  ;; phase-offset es la distancia acumulada desde el INICIO de toda la
  ;; cadena guia hasta el arranque de este segmento: sin esto, cada
  ;; segmento reinicia su propia reticula en 0 y la costura entre
  ;; segmentos vecinos queda desalineada (el patron "salta" en cada union
  ;; en vez de continuar parejo a lo largo de toda la franja).
  ;; Cada simbolo lleva su xdata URB_ANDEN_GEN incrustado directo en el
  ;; entmake (urb:generated-xdata-fragment, dentro de
  ;; urb:add-capsule-symbol/urb:add-circle-symbol): sin esto,
  ;; urb:package-anden (que arma el bloque final via urb:generated-objects)
  ;; nunca los encuentra y quedan sueltos en el dibujo, fuera del bloque.
  ;; No se usa urb:tag-generated-role aqui (entget+entmod+entupd por
  ;; objeto) porque a escala de miles/decenas de miles de simbolos por
  ;; franja resulto demasiado lento (minutos extra).
  (if (not (tblsearch "APPID" "URB_ANDEN_GEN")) (regapp "URB_ANDEN_GEN"))
  (setq points (urb:region-outline-points region))
  (if (null points) (setq points (urb:object-box-points region)))
  (if points
    (progn
      (setq bounds (urb:project-bounds points angle-value)
            umin (nth 0 bounds) umax (nth 1 bounds)
            vmin (nth 2 bounds) vmax (nth 3 bounds))
      (setq spacing 0.05 margin 0.025 count 0 sym-color 8)
      (if (= feature "GUIA")
        (setq half-length 0.075 half-width 0.012)
        (setq radius 0.008))
      (setq seg-len (- umax umin))
      ;; Colocacion POR TABLETA sobre la reticula global de la cadena
      ;; (tabletas de "module" de largo, juntas alineadas con el material):
      ;; cada tableta lleva sus propios simbolos con margen a cada lado
  ;; (4 columnas en la de 20cm, 8 en la de 40cm), en vez de una sola
      ;; secuencia corrida de 5cm que ignoraba donde caen las juntas --
      ;; asi el simbolo nunca queda montado sobre una junta y la franja se
      ;; ve como tabletas individuales, igual que en el plano de
      ;; referencia U-201.
      (if (or (null module) (< module 0.05)) (setq module 0.20))
      (setq tile-k (fix (/ (+ phase-offset 1e-9) module)))
      (setq tile-g (* tile-k module))
      (while (< tile-g (+ phase-offset seg-len (- 1e-6)))
        ;; tono OPUESTO a la banda donde cae la tableta (blanco sobre
        ;; banda gris, gris sobre banda blanca) -- misma fase global que
        ;; el relleno por bandas de la franja
        (setq sym-color
          (if (car (urb:composite-phase-state (+ tile-g (* 0.5 module)))) 7 8))
        (setq su margin)
        (while (<= su (+ (- module margin) 1e-6))
          (setq global-u (+ tile-g su))
          ;; solo las columnas que caen dentro de ESTE segmento
          (if (and (>= (- global-u phase-offset) -1e-6)
                   (<= (- global-u phase-offset) (+ seg-len 1e-6)))
            (progn
              (setq local-u (+ umin (- global-u phase-offset)))
              (setq v (+ vmin margin))
              (while (<= v (+ (- vmax margin) 1e-6))
                (setq sym-ename
                  (if (= feature "GUIA")
                    (urb:add-capsule-symbol local-u v half-length half-width angle-value layer parent-handle sym-color)
                    (urb:add-circle-symbol local-u v radius angle-value layer parent-handle sym-color)))
                (setq count (1+ count))
                (setq v (+ v spacing)))))
          (setq su (+ su spacing)))
        (setq tile-k (1+ tile-k))
        (setq tile-g (* tile-k module)))
      (> count 0))
    nil)
)

(defun urb:decorate-accessibility-strip
  (region layer feature module angle-value origin parent-handle phase-offset
   / fill grid symbols-ok points bounds umin umax vmin vmax phase-state
   gray first-band cursor nxt bw band iter band-ok)
  ;; layer ya es la capa de guia/toperol real (antes esta pieza base vivia
  ;; aparte en URB-ANDEN-AUX); el rol FILL mantiene el orden de dibujo.
  (vla-put-Layer region layer)
  (vla-put-Color region 8)
  (urb:tag-generated-role region parent-handle "FILL")
  ;; TONO POR BANDA (U-201): las tabletas tactiles toman el color de la
  ;; banda gris/blanca del patron donde caen (alternando con la MISMA fase
  ;; 0.80/1.00 global), no un color propio -- la franja queda integrada al
  ;; patron y se distingue solo por la textura (domos/barras). La capa
  ;; sigue siendo la de guia/toperol (las cantidades no cambian).
  (setq band-ok nil)
  (setq points (urb:region-outline-points region))
  (if (null points) (setq points (urb:object-box-points region)))
  (if points
    (progn
      (setq bounds (urb:project-bounds points angle-value)
            umin (nth 0 bounds) umax (nth 1 bounds)
            vmin (- (nth 2 bounds) 1.0) vmax (+ (nth 3 bounds) 1.0))
      (setq phase-state (urb:composite-phase-state (if phase-offset phase-offset 0.0)))
      (setq gray (car phase-state) first-band T cursor umin iter 0)
      (while (and (< cursor (- umax 1e-6)) (< iter 20000))
        (setq iter (1+ iter))
        (setq bw (if first-band (cdr phase-state) (if gray 0.80 1.00)))
        (if (< bw 0.001) (setq bw 0.001))
        (setq nxt (min umax (+ cursor bw)))
        (setq band (urb:clip-stripe region cursor nxt vmin vmax angle-value))
        (if band
          (progn
            (vla-put-Layer band layer)
            (vla-put-Color band (if gray 8 7))
            (urb:tag-generated-role band parent-handle "FILL")
            (setq fill
              (vl-catch-all-apply
                'urb:add-solid-hatch
                (list band layer (if gray 8 7))))
            (if (not (vl-catch-all-error-p fill))
              (urb:tag-generated-role fill parent-handle "FEATURE_FILL"))
            (setq band-ok T)))
        (setq cursor nxt gray (not gray) first-band nil))))
  ;; respaldo: si el particionado por bandas no produjo nada (region
  ;; degenerada), relleno uniforme como antes
  (if (not band-ok)
    (progn
      (setq fill
        (vl-catch-all-apply
          'urb:add-solid-hatch
          (list region layer 8)))
      (if (not (vl-catch-all-error-p fill))
        (urb:tag-generated-role fill parent-handle "FEATURE_FILL"))))
  (setq grid
    (urb:add-user-hatch
      region layer module angle-value T 9 origin))
  (urb:tag-generated-role grid parent-handle "FEATURE")
  (setq symbols-ok
    (vl-catch-all-apply
      'urb:fill-tactile-symbols
      (list region feature angle-value layer (if phase-offset phase-offset 0.0) parent-handle module)))
  T
)

(defun urb:point-v-coordinate (point angle-value)
  (+
    (* (- (car point)) (sin angle-value))
    (* (cadr point) (cos angle-value)))
)

(defun urb:reference-v-edge
  (points angle-value vmin vmax / reference-v reference-point)
  ;; OJO: en AutoLISP (and ...) devuelve T/nil, NO el ultimo valor como en
  ;; otros Lisp -- por eso el punto del choice se calcula en un setq
  ;; separado y no dentro de la condicion.
  (setq reference-point
    (if *urb-current-tactile-side-choice*
      (urb:tactile-side-point-from-choice
        *urb-current-tactile-side-choice* points)
      nil))
  (if (null reference-point)
    (setq reference-point
      (if *urb-current-tactile-side-point*
        *urb-current-tactile-side-point*
        (car points))))
  (setq reference-v
    (urb:point-v-coordinate reference-point angle-value))
  (if (<= (abs (- reference-v vmin))
          (abs (- reference-v vmax)))
    vmin
    vmax)
)

;; ============================================================
;; FRANJA TACTIL POR OFFSET DE LA CURVA REAL (rediseno 2026-08-09)
;; La franja se construye como la region entre dos curvas paralelas
;; (vla-Offset) del borde de la via, en vez de rectangulos por arista:
;; con radios pequenos los rectangulos salian quebrados/doblados sin
;; remedio (verificado visualmente por PDF). Los simbolos y juntas
;; caminan la curva real con vlax-curve (posicion y tangente exactas).
;; ============================================================

(defun urb:point-in-poly-p (pt pts / n i j inside xi yi xj yj x y)
  ;; ray casting estandar sobre el contorno (lista de puntos 2D)
  (setq x (car pt) y (cadr pt) n (length pts) inside nil j (1- n) i 0)
  (while (< i n)
    (setq xi (car (nth i pts)) yi (cadr (nth i pts))
          xj (car (nth j pts)) yj (cadr (nth j pts)))
    (if (and (not (eq (> yi y) (> yj y)))
             (< x (+ xj (/ (* (- xi xj) (- y yj)) (- yi yj)))))
      (setq inside (not inside)))
    (setq j i i (1+ i)))
  inside
)

(defun urb:open-poly-from-points (pts elevation / coords poly)
  (setq coords
    (apply 'append
      (mapcar '(lambda (p) (list (car p) (cadr p))) pts)))
  (setq poly
    (vla-AddLightWeightPolyline
      (urb:space)
      (urb:double-array-variant coords)))
  (if (and (numberp elevation)
           (vlax-property-available-p poly 'Elevation T))
    (vla-put-Elevation poly elevation))
  (vlax-vla-object->ename poly)
)

(defun urb:offset-poly (ename dist / obj res lst keep)
  ;; offset de una polilinea; devuelve el ENAME del resultado o nil.
  ;; Si el offset se parte en varias piezas se descartan todas (el caller
  ;; cae al metodo por segmentos).
  (setq obj (vlax-ename->vla-object ename))
  (setq res (vl-catch-all-apply 'vla-Offset (list obj dist)))
  (if (vl-catch-all-error-p res)
    nil
    (progn
      (setq lst
        (vl-catch-all-apply
          '(lambda () (vlax-safearray->list (vlax-variant-value res)))))
      (if (vl-catch-all-error-p lst) (setq lst nil))
      (cond
        ((null lst) nil)
        ((= (length lst) 1)
          (vlax-vla-object->ename (car lst)))
        (T
          (foreach keep lst (urb:safe-delete keep))
          nil))))
)

(defun urb:curve-length (ename / r)
  (setq r
    (vl-catch-all-apply
      '(lambda ()
         (vlax-curve-getDistAtParam ename (vlax-curve-getEndParam ename)))))
  (if (vl-catch-all-error-p r) 0.0 r)
)

(defun urb:curve-pt (ename dist / r)
  (setq r (vl-catch-all-apply 'vlax-curve-getPointAtDist (list ename dist)))
  (if (or (vl-catch-all-error-p r) (null r)) nil (list (car r) (cadr r)))
)

(defun urb:curve-tangent (ename dist / p r)
  ;; angulo de la tangente en la distancia dada (0 si falla)
  (setq p (vl-catch-all-apply 'vlax-curve-getParamAtDist (list ename dist)))
  (if (vl-catch-all-error-p p)
    0.0
    (progn
      (setq r (vl-catch-all-apply 'vlax-curve-getFirstDeriv (list ename p)))
      (if (or (vl-catch-all-error-p r) (null r))
        0.0
        (atan (cadr r) (car r)))))
)

(defun urb:strip-band-region (c1 c2 elevation / pts poly region)
  ;; region cerrada entre dos curvas offset abiertas (misma direccion)
  (setq pts
    (append (urb:lwpoly-points c1) (reverse (urb:lwpoly-points c2))))
  (if (< (length pts) 3)
    nil
    (progn
      (setq poly
        (vl-catch-all-apply
          '(lambda ()
             (vla-put-Closed
               (vlax-ename->vla-object
                 (urb:open-poly-from-points pts elevation))
               :vlax-true)
             (entlast))))
      (if (vl-catch-all-error-p poly)
        nil
        (progn
          (setq region (urb:add-region-from-object (vlax-ename->vla-object poly)))
          (entdel poly)
          (if (vl-catch-all-error-p region) nil region)))))
)

(defun urb:offset-strip-tones
  (strip chain-poly len layer parent-handle elevation span
   / s nxt bw gray first-band phase-state piece wedge p1 p2 a1 a2 n1 n2 count iter)
  ;; parte la franja lisa en tramos de tono gris/blanco con la MISMA fase
  ;; 0.80/1.00 del patron, cortando con cunas normales a la curva real
  (setq s 0.0 count 0 iter 0)
  (setq phase-state (urb:composite-phase-state 0.0))
  (setq gray (car phase-state) first-band T)
  (while (and (< s (- len 1e-6)) (< iter 20000))
    (setq iter (1+ iter))
    (setq bw (if first-band (cdr phase-state) (if gray 0.80 1.00)))
    (if (< bw 0.001) (setq bw 0.001))
    (setq nxt (min len (+ s bw)))
    (setq p1 (urb:curve-pt chain-poly s)
          p2 (urb:curve-pt chain-poly nxt)
          a1 (urb:curve-tangent chain-poly s)
          a2 (urb:curve-tangent chain-poly nxt))
    (if (and p1 p2)
      (progn
        (setq n1 (+ a1 (* 0.5 pi)) n2 (+ a2 (* 0.5 pi)))
        (setq wedge
          (vl-catch-all-apply
            'urb:quad-region
            (list
              (list (+ (car p1) (* span (cos n1))) (+ (cadr p1) (* span (sin n1))))
              (list (+ (car p2) (* span (cos n2))) (+ (cadr p2) (* span (sin n2))))
              (list (- (car p2) (* span (cos n2))) (- (cadr p2) (* span (sin n2))))
              (list (- (car p1) (* span (cos n1))) (- (cadr p1) (* span (sin n1))))
              elevation)))
        (if (not (vl-catch-all-error-p wedge))
          (progn
            (setq piece (vla-Copy strip))
            (if (vl-catch-all-error-p
                  (vl-catch-all-apply 'vla-Boolean (list piece 1 wedge)))
              (progn (urb:safe-delete piece) (urb:safe-delete wedge))
              (progn
                (vla-put-Layer piece layer)
                (vla-put-Color piece (if gray 8 7))
                (urb:tag-generated-role piece parent-handle "FILL")
                (urb:tag-generated-role
                  (vl-catch-all-apply
                    'urb:add-solid-hatch (list piece layer (if gray 8 7)))
                  parent-handle "FEATURE_FILL")
                (setq count (1+ count))))))))
    (setq s nxt gray (not gray) first-band nil))
  count
)

(defun urb:offset-strip-symbols
  (chain-poly len d1 d2 perp-sign feature module layer parent-handle
   / spacing margin half-length half-width radius tile-k tile-g sym-color
     su dist pt ang normal ro wpt u v cs sn joint-p1 joint-p2
     symbol-result created)
  ;; simbolos y juntas por tableta caminando la curva real
  (setq spacing 0.05 margin 0.025)
  (if (= feature "GUIA")
    (setq half-length 0.075 half-width 0.012)
    (setq radius 0.008))
  (if (not (tblsearch "APPID" "URB_ANDEN_GEN")) (regapp "URB_ANDEN_GEN"))
  (setq tile-k 0 created 0)
  (while (< (setq tile-g (* tile-k module)) (- len 1e-6))
    ;; junta radial en el arranque de cada tableta (excepto la primera)
    (if (> tile-k 0)
      (progn
        (setq pt (urb:curve-pt chain-poly tile-g)
              ang (urb:curve-tangent chain-poly tile-g))
        (if pt
          (progn
            (setq normal (+ ang (* 0.5 pi)))
            (setq joint-p1
              (list (+ (car pt) (* perp-sign d1 (cos normal)))
                    (+ (cadr pt) (* perp-sign d1 (sin normal))))
                  joint-p2
              (list (+ (car pt) (* perp-sign d2 (cos normal)))
                    (+ (cadr pt) (* perp-sign d2 (sin normal)))))
            (entmake
              (list (cons 0 "LINE") (cons 8 layer) (cons 62 8)
                    (cons 10 (list (car joint-p1) (cadr joint-p1) 0.0))
                    (cons 11 (list (car joint-p2) (cadr joint-p2) 0.0))
                    (urb:generated-xdata-fragment parent-handle "FEATURE")))))))
    ;; tono opuesto a la banda de esta tableta
    (setq sym-color
      (if (car (urb:composite-phase-state
                 (min (- len 1e-6) (+ tile-g (* 0.5 module)))))
        7 8))
    (setq su margin)
    (while (<= su (+ (- module margin) 1e-6))
      (setq dist (+ tile-g su))
      (if (<= dist len)
        (progn
          (setq pt (urb:curve-pt chain-poly dist)
                ang (urb:curve-tangent chain-poly dist))
          (if pt
            (progn
              (setq normal (+ ang (* 0.5 pi)))
              (setq cs (cos ang) sn (sin ang))
              (setq ro (+ d1 margin))
              (while (<= ro (+ (- d2 margin) 1e-6))
                (setq wpt
                  (list (+ (car pt) (* perp-sign ro (cos normal)))
                        (+ (cadr pt) (* perp-sign ro (sin normal)))))
                ;; a coordenadas locales del marco (ang) que esperan los
                ;; helpers de simbolo
                (setq u (+ (* (car wpt) cs) (* (cadr wpt) sn))
                      v (+ (* (- (car wpt)) sn) (* (cadr wpt) cs)))
                (setq symbol-result
                  (if (= feature "GUIA")
                    (urb:add-capsule-symbol
                      u v half-length half-width ang layer parent-handle sym-color)
                    (urb:add-circle-symbol
                      u v radius ang layer parent-handle sym-color)))
                (if symbol-result (setq created (1+ created)))
                (setq ro (+ ro spacing)))))))
      (setq su (+ su spacing)))
    (setq tile-k (1+ tile-k)))
  (> created 0)
)

(defun urb:build-offset-strip
  (base-region chain-poly d1 d2 off-sign perp-sign layer feature module
   parent-handle elevation span
   / c1 c2 band strip len booleaned tone-count symbols-ok)
  (setq c1
    (if (< (abs d1) 1e-9)
      (urb:as-ename (vla-Copy (vlax-ename->vla-object chain-poly)))
      (urb:offset-poly chain-poly (* off-sign d1))))
  (setq c2 (urb:offset-poly chain-poly (* off-sign d2)))
  (if (or (null c1) (null c2))
    (progn
      (if c1 (entdel c1))
      (if c2 (entdel c2))
      nil)
    (progn
      (setq band (urb:strip-band-region c1 c2 elevation))
      (if (null band)
        (progn (entdel c1) (entdel c2) nil)
        (progn
          (setq strip (vla-Copy base-region))
          (setq booleaned
            (vl-catch-all-apply 'vla-Boolean (list strip 1 band)))
          (if (vl-catch-all-error-p booleaned)
            (progn
              (urb:safe-delete strip)
              (urb:safe-delete band)
              (entdel c1) (entdel c2)
              nil)
            (progn
              (setq len (urb:curve-length chain-poly))
              (setq tone-count
                (urb:offset-strip-tones
                  strip chain-poly len layer parent-handle elevation span))
              (urb:safe-delete strip)
              (if (<= tone-count 0)
                (progn
                  (entdel c1) (entdel c2)
                  nil)
                (progn
                  ;; bordes de la franja: las dos curvas offset quedan como
                  ;; lineas de junta visibles
                  (foreach c (list c1 c2)
                    (vla-put-Layer (vlax-ename->vla-object c) layer)
                    (vla-put-Color (vlax-ename->vla-object c) 8)
                    (urb:tag-generated-role
                      (vlax-ename->vla-object c) parent-handle "FEATURE"))
                  (setq symbols-ok
                    (urb:offset-strip-symbols
                      chain-poly len d1 d2 perp-sign feature module
                      layer parent-handle))
                  ;; Un strip sin domos/capsulas no cuenta como terminado;
                  ;; el caller puede activar su metodo segmentado de respaldo.
                  symbols-ok))))))))
)

(defun urb:create-accessibility-features-offset
  (base-region points driving-chain guia toperol format parent-handle
   / module goff chain-poly len box elevation off-sign perp-sign
     mid-d mid-pt mid-ang cand test-off count layer span)
  (setq module (urb:loseta-module format))
  (setq goff *urb-guide-offset*)
  (setq box (urb:object-box-points base-region)
        elevation (if (and box (caddr (car box))) (caddr (car box)) 0.0))
  (setq span (urb:points-span points))
  (setq chain-poly (urb:open-poly-from-points driving-chain elevation))
  (setq len (urb:curve-length chain-poly))
  (if (< len (* 2.0 module))
    (progn (entdel chain-poly) nil)
    (progn
      ;; lado hacia ADENTRO del anden: (1) signo del offset probando de
      ;; que lado cae la curva desplazada; (2) signo de la normal para
      ;; los simbolos, probando un punto desplazado a mano
      (setq mid-d (* 0.5 len))
      (setq mid-pt (urb:curve-pt chain-poly mid-d))
      (setq mid-ang (urb:curve-tangent chain-poly mid-d))
      (setq perp-sign 1.0)
      (if mid-pt
        (progn
          (setq cand
            (list (+ (car mid-pt) (* 0.3 (cos (+ mid-ang (* 0.5 pi)))))
                  (+ (cadr mid-pt) (* 0.3 (sin (+ mid-ang (* 0.5 pi)))))))
          (if (not (urb:point-in-poly-p cand points))
            (setq perp-sign -1.0))))
      (setq off-sign 1.0)
      (setq test-off (urb:offset-poly chain-poly 0.3))
      (if test-off
        (progn
          (setq cand (urb:curve-pt test-off (* 0.5 (urb:curve-length test-off))))
          (if (or (null cand) (not (urb:point-in-poly-p cand points)))
            (setq off-sign -1.0))
          (entdel test-off))
        (setq off-sign -1.0))
      (setq count 0)
      (if (urb:yes-p toperol)
        (progn
          (setq layer
            (if (> module 0.30)
              "URB-ANDEN-LOSETA-TOPEROL-40X40" "URB-ANDEN-LOSETA-TOPEROL-20X20"))
          (if (urb:build-offset-strip
                base-region chain-poly 0.0 module off-sign perp-sign
                layer "TOPEROL" module parent-handle elevation span)
            (setq count (1+ count)))))
      (if (urb:yes-p guia)
        (progn
          (setq layer
            (if (> module 0.30)
              "URB-ANDEN-LOSETA-GUIA-40X40" "URB-ANDEN-LOSETA-GUIA-20X20"))
          (if (urb:build-offset-strip
                base-region chain-poly goff (+ goff module) off-sign perp-sign
                layer "GUIA" module parent-handle elevation span)
            (setq count (1+ count)))))
      (entdel chain-poly)
      (> count 0)))
)

(defun urb:create-accessibility-features-segmented
  (base-region points driving-chain guia toperol format parent-handle
   / edges edge angle-value module cosine sine u1 u2 umin umax
   bounds-wide vmin-wide vmax-wide full-slice slice-points bounds-local
   vmin-local vmax-local width reference-edge guide-min guide-max
   top-min top-max region origin layer count cum-offset
   p1-v boundary-side side-decided prefer-boundary
   bisectors edge-index bis span grid-u into)
  ;; Igual que urb:create-accessibility-features pero por segmento real del
  ;; contorno: cada arista del lado guia recorta y mide su propia franja en
  ;; vez de usar el ancho proyectado de TODO el anden sobre un unico eje
  ;; (que en un tramo curvo da un ancho falso, inflado por vertices de otras
  ;; estaciones, y termina sembrando simbolos muy por fuera del area real).
  ;; cum-offset acumula la distancia recorrida desde el arranque de toda la
  ;; cadena hasta el inicio de este segmento: se pasa a
  ;; urb:decorate-accessibility-strip para que la reticula de simbolos de
  ;; 5cm sea UNA sola secuencia continua a lo largo de todo el corredor, en
  ;; vez de reiniciar en 0 en cada segmento (lo que dejaba la costura entre
  ;; segmentos vecinos desalineada / con huecos).
  ;; side-decided/prefer-boundary: en un anden curvo real con barrido de
  ;; tangente grande (60-90+ grados de un extremo al otro de la cadena),
  ;; *urb-current-tactile-side-point* comparado contra vmin-local/vmax-local
  ;; de CADA arista por separado (el metodo viejo, urb:reference-v-edge)
  ;; puede voltear de lado a mitad de camino aunque el punto de referencia
  ;; siga siendo fisicamente el mismo -- un punto de referencia cercano al
  ;; anden puede terminar "adelante" de la curva para las primeras aristas
  ;; y "atras" para las ultimas. Eso hacia que la guia/el toperol saltaran
  ;; al lado opuesto del corredor a mitad de curva: un corte visible en la
  ;; franja seguido de que reaparece del otro lado. Arreglo: decidir UNA
  ;; SOLA VEZ (con la primera arista) si el usuario quiere el lado donde
  ;; esta la arista misma (boundary-side) o el lado opuesto, y de ahi en
  ;; adelante usar boundary-side de cada arista (que es exacto: el vertice
  ;; p1 de la arista SIEMPRE cae casi exacto en uno de los dos bordes del
  ;; recorte local, sin la ambiguedad de comparar contra un punto lejano).
  (setq module (urb:loseta-module format))
  (setq edges (urb:open-chain-edges driving-chain))
  (setq count 0 cum-offset 0.0 side-decided nil edge-index 0)
  ;; Cunas a inglete: mismas bisectrices que usa el material, para que la
  ;; franja de guia/toperol de cada arista termine exactamente donde
  ;; empieza la de la siguiente (sin el traslape que pintaba la guia
  ;; cruzada en diagonal sobre la reticula en las transiciones).
  (setq bisectors (urb:chain-edge-bisectors edges))
  (setq span (urb:points-span points))
  (foreach edge edges
    (setq angle-value (nth 3 edge) cosine (cos angle-value) sine (sin angle-value))
    (setq u1 (+ (* (car (nth 0 edge)) cosine) (* (cadr (nth 0 edge)) sine)))
    (setq u2 (+ (* (car (nth 1 edge)) cosine) (* (cadr (nth 1 edge)) sine)))
    (setq umin (min u1 u2) umax (max u1 u2))
    (setq bis (nth edge-index bisectors))
    (setq full-slice
      (urb:clip-edge-wedge
        base-region (nth 0 edge) (nth 1 edge)
        (nth 0 bis) (nth 1 bis) span))
    (if (null full-slice)
      (progn
        (setq bounds-wide (urb:project-bounds points angle-value)
              vmin-wide (nth 2 bounds-wide) vmax-wide (nth 3 bounds-wide))
        (setq full-slice (urb:clip-stripe base-region umin umax vmin-wide vmax-wide angle-value))))
    (if full-slice
      (progn
        (setq slice-points (urb:region-outline-points full-slice))
        (if (null slice-points) (setq slice-points (urb:object-box-points full-slice)))
        (if slice-points
          (progn
            (setq bounds-local (urb:project-bounds slice-points angle-value)
                  vmin-local (nth 2 bounds-local)
                  vmax-local (nth 3 bounds-local)
                  width (- vmax-local vmin-local))
            (setq p1-v (urb:point-v-coordinate (nth 0 edge) angle-value))
            (setq boundary-side
              (if (<= (abs (- p1-v vmin-local)) (abs (- p1-v vmax-local)))
                vmin-local
                vmax-local))
            (if (null side-decided)
              (progn
                (setq side-decided T)
                (setq prefer-boundary
                  (equal
                    boundary-side
                    (urb:reference-v-edge points angle-value vmin-local vmax-local)
                    1e-6))))
            (setq reference-edge
              (if prefer-boundary
                boundary-side
                (if (equal boundary-side vmin-local 1e-9) vmax-local vmin-local)))
            ;; origen de reticula en u alineado a la cadena GLOBAL (la
            ;; misma fase que usa el material), para que las juntas de la
            ;; franja tactil coincidan con las juntas de la loseta.
            (setq grid-u (- umin (urb:grid-phase-shift cum-offset module)))
            ;; Posicion medida RESPECTO A LA ARISTA de la cadena (que ES
            ;; el borde de la via, porque la cadena tactil se elige del
            ;; lado del click), no respecto a los bounds proyectados del
            ;; recorte: con las cunas a inglete esos bounds varian por
            ;; arista segun la inclinacion de las bisectrices y la guia
            ;; salia en "escalera" de barras sueltas a radios distintos
            ;; (visto en el PDF de verificacion del abanico).
            (setq into
              (if (<= (abs (- p1-v vmin-local)) (abs (- p1-v vmax-local)))
                1.0 -1.0))
            (if (urb:yes-p guia)
              (progn
                (if (< width module)
                  (setq guide-min vmin-local guide-max vmax-local)
                  (if prefer-boundary
                    ;; caso normal: via = lado de la propia cadena
                    (if (> into 0)
                      (setq guide-min (+ p1-v *urb-guide-offset*)
                            guide-max (+ p1-v *urb-guide-offset* module))
                      (setq guide-min (- p1-v *urb-guide-offset* module)
                            guide-max (- p1-v *urb-guide-offset*)))
                    ;; via al lado opuesto de la cadena: como antes
                    (if (= reference-edge vmin-local)
                      (setq guide-min (+ vmin-local *urb-guide-offset*)
                            guide-max (+ vmin-local *urb-guide-offset* module))
                      (setq guide-min (- vmax-local *urb-guide-offset* module)
                            guide-max (- vmax-local *urb-guide-offset*)))))
                (if (>= width module)
                  (setq guide-min (max vmin-local (min (- vmax-local module) guide-min))
                        guide-max (+ guide-min module)))
                ;; el rango en u va MUY holgado a lado y lado: la cuna a
                ;; inglete ya limita angularmente, y a 2.5m del borde la
                ;; cuna es mas ancha que la cuerda de la arista -- recortar
                ;; al rango de la cuerda dejaba HUECOS entre las franjas de
                ;; aristas vecinas (guia punteada en el PDF del abanico).
                (setq region
                  (urb:clip-stripe full-slice (- umin span) (+ umax span)
                    guide-min guide-max angle-value))
                ;; SIN fallback de ancho completo: cuando el recorte fino
                ;; fallaba, pintar la franja a todo el ancho del anden
                ;; dejaba un manchon diagonal cruzando las bandas (visto
                ;; en PDF); un micro-hueco puntual es mucho menos grave.
                (if region
                  (progn
                    ;; origen del grid: u alineado a la cadena global,
                    ;; v en el borde inferior de la propia fila (que tras
                    ;; el snap cae sobre la reticula del material)
                    (setq origin (urb:local-to-world grid-u guide-min angle-value))
                    (setq layer
                      (if (> module 0.30)
                        "URB-ANDEN-LOSETA-GUIA-40X40" "URB-ANDEN-LOSETA-GUIA-20X20"))
                    (urb:decorate-accessibility-strip
                      region layer "GUIA" module angle-value origin parent-handle cum-offset)
                    (setq count (1+ count))))))
            (if (urb:yes-p toperol)
              (progn
                (if prefer-boundary
                  ;; toperol pegado a la ARISTA (borde real de la via)
                  (if (> into 0)
                    (setq top-min p1-v top-max (+ p1-v module))
                    (setq top-min (- p1-v module) top-max p1-v))
                  (if (= reference-edge vmin-local)
                    (setq top-min vmin-local top-max (min vmax-local (+ vmin-local module)))
                    (setq top-min (max vmin-local (- vmax-local module)) top-max vmax-local)))
                (setq region
                  (urb:clip-stripe full-slice (- umin span) (+ umax span)
                    top-min top-max angle-value))
                ;; sin fallback de ancho completo (mismo criterio que guia)
                (if region
                  (progn
                    ;; u alineado a la cadena global; v en el borde
                    ;; inferior de la fila del toperol (pegada a la via)
                    (setq origin (urb:local-to-world grid-u top-min angle-value))
                    (setq layer
                      (if (> module 0.30)
                        "URB-ANDEN-LOSETA-TOPEROL-40X40" "URB-ANDEN-LOSETA-TOPEROL-20X20"))
                    (urb:decorate-accessibility-strip
                      region layer "TOPEROL" module angle-value origin parent-handle cum-offset)
                    (setq count (1+ count))))))))
        (urb:safe-delete full-slice)))
    (setq cum-offset (+ cum-offset (- umax umin)))
    (setq edge-index (1+ edge-index)))
  (> count 0)
)

(defun urb:create-accessibility-features
  (ename guia toperol format / obj copy base-region points angle-value bounds
   umin umax vmin vmax center region parent-handle origin count limits
   reference-edge width guide-min guide-max pattern-v-origin module layer
   top-min top-max driving-chain offset-result)
  (if (and (not (urb:yes-p guia))
           (not (urb:yes-p toperol)))
    T
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (setq parent-handle (vla-get-Handle obj))
      ;; muestreo FINO solo aqui: la franja tactil sigue el arco real
      (setq points (urb:lwpoly-points-with-arcs-fine ename))
      (setq module (urb:loseta-module format))
      (setq copy (vla-Copy obj))
      (setq base-region (urb:add-region-from-object copy))
      (urb:safe-delete copy)
      (if (vl-catch-all-error-p base-region)
        nil
        (progn
          ;; la franja tactil sigue la cadena del lado de la VIA (click
          ;; del usuario), no el lado mas largo del contorno
          (setq driving-chain (urb:anden-tactile-chain points))
          (if (and driving-chain (>= (length (urb:open-chain-edges driving-chain)) 2))
            (progn
              ;; metodo principal: franja como OFFSET de la curva real
              ;; (continua a cualquier radio); si el offset falla
              ;; (contorno con quiebres imposibles de desplazar), cae al
              ;; metodo anterior por segmentos
              (setq offset-result
                (vl-catch-all-apply
                  'urb:create-accessibility-features-offset
                  (list base-region points driving-chain guia toperol format parent-handle)))
              (if (and (not (vl-catch-all-error-p offset-result)) offset-result)
                offset-result
                (urb:create-accessibility-features-segmented
                  base-region points driving-chain guia toperol format parent-handle)))
            (progn
              (setq angle-value (urb:anden-axis-angle points))
              (setq bounds (urb:project-bounds points angle-value))
              (setq umin (nth 0 bounds))
              (setq umax (nth 1 bounds))
              (setq vmin (nth 2 bounds))
              (setq vmax (nth 3 bounds))
              (setq reference-edge
                (urb:reference-v-edge points angle-value vmin vmax))
              (setq pattern-v-origin reference-edge)
              (if (urb:yes-p guia)
                (progn
                  (setq width (- vmax vmin))
                  (if (< width module)
                    (setq guide-min vmin guide-max vmax)
                    (if (= reference-edge vmin)
                      (setq guide-min (+ vmin *urb-guide-offset*)
                            guide-max (+ vmin *urb-guide-offset* module))
                      (setq guide-min (- vmax *urb-guide-offset* module)
                            guide-max (- vmax *urb-guide-offset*))))
                  (if (>= width module)
                    (progn
                      (setq guide-min
                        (max vmin (min (- vmax module) guide-min)))
                      (setq guide-max (+ guide-min module))))
                  (setq center (/ (+ guide-min guide-max) 2.0))
                  (setq region
                    (urb:clip-stripe
                      base-region umin umax guide-min guide-max angle-value))
                  (if region
                    (progn
                      (setq origin
                        (urb:local-to-world
                          umin pattern-v-origin angle-value))
                      (setq layer
                        (if (> module 0.30)
                          "URB-ANDEN-LOSETA-GUIA-40X40"
                          "URB-ANDEN-LOSETA-GUIA-20X20"))
                      (urb:decorate-accessibility-strip
                        region layer "GUIA" module angle-value origin parent-handle 0.0)
                      (setq count (1+ (if count count 0)))))))
              (if (urb:yes-p toperol)
                (progn
                  (if (= reference-edge vmin)
                    (setq top-min vmin top-max (min vmax (+ vmin module)))
                    (setq top-min (max vmin (- vmax module)) top-max vmax))
                  (setq region
                    (urb:clip-stripe
                      base-region umin umax top-min top-max angle-value))
                  (if region
                    (progn
                      (setq origin
                        (urb:local-to-world umin reference-edge angle-value))
                      (setq layer
                        (if (> module 0.30)
                          "URB-ANDEN-LOSETA-TOPEROL-40X40"
                          "URB-ANDEN-LOSETA-TOPEROL-20X20"))
                      (urb:decorate-accessibility-strip
                        region layer "TOPEROL" module angle-value origin parent-handle 0.0)
                      (setq count (1+ (if count count 0)))))))
              (urb:safe-delete base-region)
              (> (if count count 0) 0)))))))
)

(defun urb:draw-polyline-interactive (old-plinewid)
  ;; Idioma repetido en varios comandos de dibujo: lanza PLINE interactivo,
  ;; espera a que el usuario termine (Enter/Esc) y restaura PLINEWID.
  (vl-cmdf "_.PLINE")
  (while (> (getvar "CMDACTIVE") 0)
    (command pause))
  (setvar "PLINEWID" old-plinewid)
)

(defun urb:cross2d (ox oy ax ay bx by)
  (- (* (- ax ox) (- by oy)) (* (- ay oy) (- bx ox))))

(defun urb:segments-cross-p (p1 p2 p3 p4 / d1 d2 d3 d4)
  ;; Cruce ESTRICTO de dos segmentos (no cuenta solo tocarse en un
  ;; extremo compartido, que es normal entre aristas consecutivas).
  (setq d1 (urb:cross2d (car p3) (cadr p3) (car p4) (cadr p4) (car p1) (cadr p1)))
  (setq d2 (urb:cross2d (car p3) (cadr p3) (car p4) (cadr p4) (car p2) (cadr p2)))
  (setq d3 (urb:cross2d (car p1) (cadr p1) (car p2) (cadr p2) (car p3) (cadr p3)))
  (setq d4 (urb:cross2d (car p1) (cadr p1) (car p2) (cadr p2) (car p4) (cadr p4)))
  (and
    (or (and (> d1 0) (< d2 0)) (and (< d1 0) (> d2 0)))
    (or (and (> d3 0) (< d4 0)) (and (< d3 0) (> d4 0))))
)

(defun urb:polygon-self-intersects-p (points / n i j p1 p2 p3 p4 found)
  ;; Revisa todo par de aristas NO adyacentes del contorno cerrado en
  ;; busca de un cruce real (poligono "moño"/autointersectado). Un
  ;; contorno asi produce rellenos con forma anomala (la mancha ancha que
  ;; aparece cuando el usuario dibuja con clics imprecisos) aunque cada
  ;; arista individual se vea razonable.
  (setq n (length points) found nil i 0)
  (while (and (< i n) (not found))
    (setq p1 (nth i points) p2 (nth (rem (1+ i) n) points))
    (setq j (+ i 2))
    (while (and (<= j (1- n)) (not found))
      (if (not (and (= i 0) (= j (1- n))))
        (progn
          (setq p3 (nth j points) p4 (nth (rem (1+ j) n) points))
          (if (urb:segments-cross-p p1 p2 p3 p4)
            (setq found T))))
      (setq j (1+ j)))
    (setq i (1+ i)))
  found)

(defun urb:anden-shape-ok-p (pts / selfx widthx)
  ;; Envuelve las 2 validaciones de forma (moño / ancho anomalo) con
  ;; vl-catch-all-apply: si CUALQUIERA de las dos revienta con un error
  ;; interno (geometria degenerada, division por cero, etc. -- ya se vio
  ;; un caso real con una polilinea casi plana), la validacion se trata
  ;; como RECHAZO por seguridad, no como un crash sin capturar que aborte
  ;; el comando a medio camino. Un error de validacion nunca debe dejar
  ;; pasar una forma sin filtrar.
  (setq pts (urb:dedupe-ring-points pts))
  (setq selfx (vl-catch-all-apply 'urb:polygon-self-intersects-p (list pts)))
  (cond
    ((vl-catch-all-error-p selfx)
      (prompt
        (strcat "\n*** No se pudo validar el contorno (error interno: "
                (vl-catch-all-error-message selfx) ") ***"
                "\nPor seguridad no se genera el acabado sobre esta forma;"
                " revise el contorno (puede tener un segmento degenerado o"
                " un arco extremo) y vuelva a intentar."))
      nil)
    (selfx
      (prompt
        (strcat
          "\n*** El contorno dibujado se cruza a si mismo (forma tipo"
          " \"moño\") ***"
          "\nEsto genera un relleno con una mancha ancha/anomala en"
          " vez de una franja pareja."
          "\nEl contorno queda dibujado para que lo revise/corrija;"
          " no se genera el acabado del anden sobre esta forma."))
      nil)
    (T
      (setq widthx (vl-catch-all-apply 'urb:anden-width-anomaly-p (list pts)))
      (cond
        ((vl-catch-all-error-p widthx)
          (prompt
            (strcat "\n*** No se pudo validar el contorno (error interno: "
                    (vl-catch-all-error-message widthx) ") ***"
                    "\nPor seguridad no se genera el acabado sobre esta forma;"
                    " revise el contorno (puede tener un segmento degenerado o"
                    " un arco extremo) y vuelva a intentar."))
          nil)
        (widthx
          (prompt
            (strcat
              "\n*** El ancho del contorno varia demasiado a lo largo del"
              " anden (ej. angosto en los remates pero muy ancho en la"
              " mitad) ***"
              "\nEsto suele venir de clics imprecisos al dibujar; el"
              " relleno sale con una mancha ancha en la zona inflada en"
              " vez de una franja pareja."
              "\nEl contorno queda dibujado para que lo revise/corrija"
              " (verifique que las dos aristas largas queden paralelas);"
              " no se genera el acabado del anden sobre esta forma."))
          nil)
        (T T)))))

(defun urb:draw-closed-polyline
  (/ before after obj old-plinewid *error* pts)
  (setq old-plinewid (getvar "PLINEWID"))
  (defun *error* (message)
    (if old-plinewid (setvar "PLINEWID" old-plinewid))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al dibujar el contorno: " message)))
    (princ))
  (setvar "PLINEWID" 0.0)
  (setq before (entlast))
  (prompt
    (strcat
      "\nDibuje el contorno del anden. Enter termina y cierra el area."
      " Puede usar OSNAP sobre la arista verde interior del PREFABRICADO."))
  (urb:draw-polyline-interactive old-plinewid)
  (setq after (entlast))
  (if (and after (/= after before)
           (= (cdr (assoc 0 (entget after))) "LWPOLYLINE"))
    (progn
      (setq obj (vlax-ename->vla-object after))
      (if (vlax-property-available-p obj 'ConstantWidth T)
        (vla-put-ConstantWidth obj 0.0))
      (vla-put-Closed obj :vlax-true)
      (if (urb:closed-poly-p after)
        (progn
          (setq pts (urb:lwpoly-points-with-arcs after))
          (if (urb:anden-shape-ok-p pts) after nil))
        nil))
    nil)
)

(defun urb:prepare-anden-layers ()
  (urb:ensure-layer "URB-ANDEN-LOSETA-LISA-40X40" 8 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-GRIS-20X20" 8 T)
  (urb:ensure-layer "URB-ANDEN-BLOQUE-BLANCO-20X10" 7 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-GUIA-20X20" 2 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-TOPEROL-20X20" 2 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-GUIA-40X40" 2 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-TOPEROL-40X40" 2 T)
  (urb:ensure-layer "URB-ANDEN" 7 T)
)

(defun urb:build-anden-finish
  (ename material guia toperol format
   / obj result accessibility-result elevation flattened)
  (setq material (urb:safe-string material "Loseta"))
  (setq guia (urb:safe-string guia "No"))
  (setq toperol (urb:safe-string toperol "No"))
  (setq format (urb:safe-string format "40 x 40 cm"))
  (setq obj (vlax-ename->vla-object ename))
  ;; Los booleanos REGION y los HATCH son mucho mas estables y rapidos en
  ;; el plano Z=0. Se conserva la elevacion en URB_ANDEN y el bloque final
  ;; se inserta nuevamente en esa cota.
  (setq elevation
    (if (vlax-property-available-p obj 'Elevation T)
      (vla-get-Elevation obj)
      0.0))
  (if (and (numberp elevation) (not (equal elevation 0.0 1e-8))
           (vlax-property-available-p obj 'Elevation T))
    (progn
      (vla-put-Elevation obj 0.0)
      (setq flattened T)))
  (urb:prepare-anden-layers)
  ;; 4.18.0: se retiro el material "Adoquin" (capa dedicada + patron propio,
  ;; sin equivalente entre las capas que se conservaron). Todo anden nuevo
  ;; es Loseta; un xdata viejo con material distinto cae aqui igual.
  (vla-put-Layer obj "URB-ANDEN")
  (vla-put-Color obj 256)
  (setq result (urb:create-composite-loseta ename format))
  (if result
    (setq accessibility-result
      (urb:create-accessibility-features ename guia toperol format)))
  (if (and result
           (or (urb:yes-p guia)
               (urb:yes-p toperol)))
    (setq result accessibility-result))
  ;; Si el acabado no pudo construirse, el contorno de trabajo se devuelve
  ;; a su elevacion original para que el usuario pueda repararlo o reintentar.
  (if (and flattened (not result)
           (urb:valid-vla-object-p obj))
    (vla-put-Elevation obj elevation))
  result
)

(defun urb:add-invisible-attribute
  (block point tag prompt-text value / attribute)
  (setq tag (urb:safe-string tag "DATO"))
  (setq prompt-text (urb:safe-string prompt-text tag))
  (setq value (urb:safe-string value ""))
  (setq attribute
    (vla-AddAttribute
      block
      0.20
      1
      prompt-text
      (vlax-3d-point point)
      tag
      value))
  attribute
)

(defun urb:block-attribute-values (block-ref / values attribute obj has-attributes)
  (setq obj (urb:as-vla-object block-ref))
  (if obj
    (setq has-attributes
      (vl-catch-all-apply 'vla-get-HasAttributes (list obj))))
  (if (and has-attributes
           (not (vl-catch-all-error-p has-attributes))
           (= has-attributes :vlax-true))
    (foreach attribute (vlax-invoke obj 'GetAttributes)
      (setq values
        (cons
          (cons
            (strcase (vla-get-TagString attribute))
            (vla-get-TextString attribute))
          values))))
  values
)

(defun urb:set-block-attribute
  (block-ref tag value / attribute obj has-attributes attributes)
  (setq tag (urb:safe-string tag ""))
  (setq value (urb:safe-string value ""))
  (setq obj (urb:as-vla-object block-ref))
  (if obj
    (setq has-attributes
      (vl-catch-all-apply 'vla-get-HasAttributes (list obj))))
  (if (and has-attributes
           (not (vl-catch-all-error-p has-attributes))
           (= has-attributes :vlax-true))
    (progn
      (setq attributes
        (vl-catch-all-apply 'vlax-invoke (list obj 'GetAttributes)))
      (if (not (vl-catch-all-error-p attributes))
        (foreach attribute attributes
          (if (= (strcase (vla-get-TagString attribute))
                 (strcase tag))
            (progn
              (vla-put-TextString attribute value)
              (vla-Update attribute)))))))
  value
)

(defun urb:block-object-list (block / objects item)
  (vlax-for item block
    (if (= (vla-get-ObjectName item) "AcDbEntity")
      (setq objects (cons item objects))
      (if (vlax-property-available-p item 'Layer)
        (setq objects (cons item objects)))))
  (reverse objects)
)

(defun urb:sortents-table (owner / dictionary table)
  (setq dictionary (vla-GetExtensionDictionary owner))
  (setq table
    (vl-catch-all-apply
      'vla-GetObject
      (list dictionary "ACAD_SORTENTS")))
  (if (vl-catch-all-error-p table)
    (setq table
      (vla-AddObject
        dictionary "ACAD_SORTENTS" "AcDbSortentsTable")))
  table
)

;; Clasifica el rol xdata (ver urb:tag-generated-role) en grupos de
;; grupos de orden de dibujo. No depende de en que capa quedo la pieza,
;; asi que las capas se pueden consolidar sin romper el apilamiento.
(defun urb:draw-role-bucket (role)
  (cond
    ((member role '("FILL" "RELLENO")) "FILL")
    ((= role "JOINT") "JOINT")
    ((= role "FEATURE_FILL") "FEATURE_FILL")
    ;; Los domos/capsulas se separan de las juntas y bordes tactiles para
    ;; moverlos al tope en una operacion final y determinista.
    ((= role "FEATURE_SYMBOL") "FEATURE_SYMBOL")
    ((member role '("FEATURE" "INTERIOR" "EXTERIOR" "REMATE")) "FEATURE")
    (T "BOUNDARY"))
)

(defun urb:set-block-draw-order
  (block objects / fills joints feature-fills features feature-symbols
   boundaries item table result bucket)
  (foreach item objects
    (if (vlax-property-available-p item 'Layer)
      (progn
        (setq bucket (urb:draw-role-bucket (urb:generated-role item)))
        (cond
          ((= bucket "FILL") (setq fills (cons item fills)))
          ((= bucket "JOINT") (setq joints (cons item joints)))
          ((= bucket "FEATURE_FILL")
            (setq feature-fills (cons item feature-fills)))
          ((= bucket "FEATURE") (setq features (cons item features)))
          ((= bucket "FEATURE_SYMBOL")
            (setq feature-symbols (cons item feature-symbols)))
          ((= bucket "BOUNDARY")
            (setq boundaries (cons item boundaries))))))
  )
  (setq table (urb:sortents-table block))
  (if fills
    (vl-catch-all-apply
      'vla-MoveToBottom
      (list table (urb:object-array-variant fills))))
  (if boundaries
    (vl-catch-all-apply
      'vla-MoveToTop
      (list table (urb:object-array-variant boundaries))))
  (if joints
    (setq result
      (vl-catch-all-apply
        'vla-MoveToTop
        (list table (urb:object-array-variant joints)))))
  (if feature-fills
    (vl-catch-all-apply
      'vla-MoveToTop
      (list table (urb:object-array-variant feature-fills))))
  (if features
    (setq result
      (vl-catch-all-apply
        'vla-MoveToTop
        (list table (urb:object-array-variant features)))))
  ;; Ultimo movimiento: el patron material y la trama tactil nunca pueden
  ;; tapar los simbolos de toperol/guia.
  (if feature-symbols
    (setq result
      (vl-catch-all-apply
        'vla-MoveToTop
        (list table (urb:object-array-variant feature-symbols)))))
  (or (and (null joints) (null feature-fills) (null features)
           (null feature-symbols))
      (not (vl-catch-all-error-p result)))
)

(defun urb:repair-block-ref-order (block-ref / block-name block result)
  (setq block-name
    (vl-catch-all-apply 'vla-get-Name (list block-ref)))
  (if (vl-catch-all-error-p block-name)
    nil
    (progn
      (setq block
        (vl-catch-all-apply
          'vla-Item
          (list (vla-get-Blocks (urb:doc)) block-name)))
      (if (vl-catch-all-error-p block)
        nil
        (progn
          (setq result
            (vl-catch-all-apply
              'urb:set-block-draw-order
              (list block (urb:block-object-list block))))
          (not (vl-catch-all-error-p result))))))
)

(defun urb:attribute-alist-value (attributes tag default / item)
  (setq item (assoc (strcase tag) attributes))
  (urb:safe-string (if item (cdr item) nil) default)
)

;; Reconstruye el registro minimo desde los atributos cuando un bloque
;; antiguo conserva sus propiedades pero perdio XDATA al copiarse entre DWG.
(defun urb:anden-block-data (ename / data obj attributes)
  (setq data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
  (if data
    data
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (setq attributes (urb:block-attribute-values obj))
      (list "ANDEN"
        (urb:attribute-alist-value attributes "MATERIAL" "LOSETA")
        (urb:attribute-alist-value attributes "ETAPA" "1")
        (urb:attribute-alist-value attributes "SUBETAPA" "1")
        (urb:attribute-alist-value attributes "AREA_M2" "0")
        (urb:attribute-alist-value attributes "PERIMETRO_M" "0")
        "0"
        (urb:attribute-alist-value attributes "LOSETA_GUIA" "No")
        (urb:attribute-alist-value attributes "LOSETA_TOPEROL" "No")
        (urb:attribute-alist-value attributes "FORMATO_LOSETA" "40 x 40 cm")
        "Si"
        (urb:attribute-alist-value attributes "ANDEN_SUPERFICIE" "SUP_TN")
        (urb:attribute-alist-value attributes "ANDEN_RASANTE" "Via creada")
        (urb:attribute-alist-value attributes "LOSETA_LISA_M2" "0")
        (urb:attribute-alist-value attributes "LOSETA_LISA_UND" "0")
        (urb:attribute-alist-value attributes "LOSETA_GUIA_ML" "0")
        (urb:attribute-alist-value attributes "LOSETA_TOPEROL_ML" "0")
        (urb:attribute-alist-value attributes "ADOQUIN_20X10_M2" "0")
        (urb:attribute-alist-value attributes "ADOQUIN_20X10_UND" "0")
        (urb:attribute-alist-value attributes "ANDEN_ELEVACION" "0")
        (urb:attribute-alist-value
          attributes "ANDEN_SENTIDO" "AUTOMATICO"))))
)

(defun urb:anden-block-p (ename / obj data layer name)
  (setq obj
    (vl-catch-all-apply
      'vlax-ename->vla-object
      (list ename)))
  (and
    (not (vl-catch-all-error-p obj))
    (= (vla-get-ObjectName obj) "AcDbBlockReference")
    (or
      (and
        (setq data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
        (urb:string-equal-p (car data) "ANDEN"))
      (progn
        (setq layer (strcase (urb:safe-string (vla-get-Layer obj) "")))
        (setq name (strcase (urb:safe-string (vla-get-Name obj) "")))
        (or (= layer "URB-ANDEN-BLOQUE") (= layer "URB-ANDEN")
            (urb:starts-with name "URB_ANDEN_")))))
)

(defun urb:clean-selector-layer (/ ss index obj deleted)
  (setq deleted 0)
  (if (setq ss
        (ssget "_X"
          '((0 . "HATCH") (8 . "URB-SEL-ANDEN"))))
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq obj
          (vlax-ename->vla-object (ssname ss index)))
        (if (urb:safe-delete obj)
          (setq deleted (1+ deleted)))
        (setq index (1+ index)))))
  deleted
)

(defun urb:package-anden
  (ename / boundary metadata material etapa subetapa guia toperol format
   calculate surface grade-source elevation pattern-mode area perimeter points finish-qty
   quantity-pattern-angle
   handle objects filtered obj block-name blocks block-definition
   copy-result point block-ref insert-result block-ename xdata-result
   fast-ok ss en cmd-result old-attreq)
  (setq boundary (vlax-ename->vla-object ename))
  (urb:ensure-layer "URB-ANDEN" 7 T)
  (setq metadata (urb:get-xdata-strings ename "URB_ANDEN"))
  (setq material
    (urb:safe-string
      (if metadata (nth 1 metadata) nil) "LOSETA"))
  (setq etapa
    (urb:safe-string
      (if metadata (nth 2 metadata) nil) "1"))
  (setq subetapa
    (urb:safe-string
      (if metadata (nth 3 metadata) nil) etapa))
  (setq guia
    (urb:safe-string
      (if (> (length metadata) 4) (nth 4 metadata) nil) "No"))
  (setq toperol
    (urb:safe-string
      (if (> (length metadata) 5) (nth 5 metadata) nil) "No"))
  (setq format
    (urb:safe-string
      (if (> (length metadata) 6) (nth 6 metadata) nil) "40 x 40 cm"))
  (setq calculate
    (urb:safe-string
      (if (> (length metadata) 7) (nth 7 metadata) nil) "Si"))
  (setq surface
    (urb:safe-string
      (if (> (length metadata) 8) (nth 8 metadata) nil) "Seleccionar en dibujo"))
  (setq grade-source
    (urb:safe-string
      (if (> (length metadata) 9) (nth 9 metadata) nil) "Via creada"))
  (setq elevation
    (if (> (length metadata) 10)
      (atof (urb:safe-string (nth 10 metadata) "0"))
      (if (vlax-property-available-p boundary 'Elevation)
        (vla-get-Elevation boundary)
        0.0)))
  (setq pattern-mode (urb:anden-pattern-mode ename))
  (setq area (vla-get-Area boundary))
  (setq perimeter (urb:poly-perimeter boundary))
  ;; Con arcos reales (PLINE opcion Arc) hay que usar la version que sigue
  ;; el arco, no la cuerda recta: corridor-length (y por lo tanto los
  ;; metros lineales de guia/toperol) salen cortos en un anden curvo si no.
  (setq points (urb:lwpoly-points-with-arcs-fine ename))
  (setq quantity-pattern-angle
    (urb:anden-quantity-pattern-angle ename points pattern-mode))
  (setq finish-qty
    (cond
      ((urb:string-equal-p material "Loseta")
        (urb:anden-finish-quantities
          points area format guia toperol pattern-mode
          quantity-pattern-angle))
      ((urb:string-equal-p material "Adoquin")
        (urb:adoquin-finish-quantities points area format guia toperol))
      (T
        (list 0.0 0 0.0 0.0 0.0 0))))
  (setq handle (vla-get-Handle boundary))
  (setq objects
    (cons boundary (urb:generated-objects handle)))
  (foreach obj objects
    (if (not
          (urb:string-equal-p
            (vla-get-Layer obj) "URB-SEL-ANDEN"))
      (setq filtered (cons obj filtered))
      (urb:safe-delete obj)))
  (setq objects (reverse filtered))
  (setq point
    (if (urb:lwpoly-points ename)
      (car (urb:lwpoly-points ename))
      '(0.0 0.0 0.0)))
  (setq block-name
    (strcat
      "URB_ANDEN_"
      handle
      "_"
      (itoa (getvar "MILLISECS"))))
  (setq blocks (vla-get-Blocks (urb:doc)))
  (prompt
    (strcat
      "\nEmpaquetando el anden en un bloque ("
      (itoa (length objects))
      " objetos)..."))
  ;; EMPAQUETADO NATIVO con -BLOCK (2026-08-09): mueve todas las entidades
  ;; a la definicion en UNA operacion nativa, en vez de CopyObjects +
  ;; borrado objeto-por-objeto via COM que tardaba MINUTOS con decenas de
  ;; miles de piezas -- la causa de fondo de "el anden no queda en bloque"
  ;; (el usuario interrumpia la espera y el material quedaba suelto). Si
  ;; el comando falla por cualquier razon, se cae al camino COM anterior.
  (setq fast-ok nil)
  (setq ss (ssadd))
  (foreach obj objects
    (setq en (vl-catch-all-apply 'vlax-vla-object->ename (list obj)))
    (if (not (vl-catch-all-error-p en)) (ssadd en ss)))
  (if (> (sslength ss) 0)
    (progn
      (setq old-attreq (getvar "ATTREQ"))
      (setvar "ATTREQ" 0)
      (setq cmd-result
        (vl-catch-all-apply 'vl-cmdf
          (list "_.-BLOCK" block-name "0,0,0" ss "")))
      (setvar "ATTREQ" old-attreq)
      (if (and (not (vl-catch-all-error-p cmd-result))
               (tblsearch "BLOCK" block-name))
        (progn
          (setq block-definition
            (vl-catch-all-apply '(lambda () (vla-Item blocks block-name))))
          (if (not (vl-catch-all-error-p block-definition))
            (setq fast-ok T))))))
  (if (not fast-ok)
    (progn
      (prompt "\nEmpaquetado nativo no disponible; usando el metodo lento (varios minutos, no interrumpa)...")
      (setq block-definition
        (vla-Add blocks (vlax-3d-point '(0.0 0.0 0.0)) block-name))
      (setq copy-result
        (vl-catch-all-apply
          'vla-CopyObjects
          (list
            (urb:doc)
            (urb:object-array-variant objects)
            block-definition))))
    (setq copy-result nil))
  (if (and (not fast-ok) (vl-catch-all-error-p copy-result))
    (progn
      (urb:safe-delete block-definition)
      (prompt
        (strcat
          "\nERROR al crear el bloque del anden: "
          (vl-catch-all-error-message copy-result)))
      nil)
    (progn
      (urb:set-block-draw-order
        block-definition
        (if fast-ok
          (urb:block-object-list block-definition)
          (urb:variant-object-list copy-result)))
      (urb:add-invisible-attribute
        block-definition point "AREA_M2" "Area m2"
        (rtos area 2 2))
      (urb:add-invisible-attribute
        block-definition point "ETAPA" "Etapa" etapa)
      (urb:add-invisible-attribute
        block-definition point "SUBETAPA" "Subetapa" subetapa)
      (urb:add-invisible-attribute
        block-definition point "LOSETA_GUIA" "Loseta guia" guia)
      (urb:add-invisible-attribute
        block-definition point "LOSETA_TOPEROL" "Loseta toperol" toperol)
      (urb:add-invisible-attribute
        block-definition point "LOSETA_LISA_M2" "Area loseta lisa m2"
        (rtos (nth 0 finish-qty) 2 2))
      (urb:add-invisible-attribute
        block-definition point "LOSETA_LISA_UND" "Loseta lisa unidades"
        (itoa (nth 1 finish-qty)))
      (urb:add-invisible-attribute
        block-definition point "LOSETA_GUIA_ML" "Loseta guia ml"
        (rtos (nth 2 finish-qty) 2 2))
      (urb:add-invisible-attribute
        block-definition point "LOSETA_TOPEROL_ML" "Loseta toperol ml"
        (rtos (nth 3 finish-qty) 2 2))
      (urb:add-invisible-attribute
        block-definition point "ADOQUIN_20X10_M2" "Area adoquin blanco 20x10 m2"
        (rtos (nth 4 finish-qty) 2 2))
      (urb:add-invisible-attribute
        block-definition point "ADOQUIN_20X10_UND" "Adoquin blanco 20x10 unidades"
        (itoa (nth 5 finish-qty)))
      (urb:add-invisible-attribute
        block-definition point "ANDEN_CORTE_M3" "Corte m3" "0")
      (urb:add-invisible-attribute
        block-definition point "ANDEN_RELLENO_M3" "Relleno m3" "0")
      (setq insert-result
        (vl-catch-all-apply
          'vla-InsertBlock
          (list
            (urb:space)
            (vlax-3d-point (list 0.0 0.0 elevation))
            block-name
            1.0 1.0 1.0 0.0)))
      (if (vl-catch-all-error-p insert-result)
        (progn
          (urb:safe-delete block-definition)
          (prompt
            (strcat
              "\nERROR al insertar el bloque del anden: "
              (vl-catch-all-error-message insert-result)))
          nil)
        (progn
          (setq block-ref insert-result)
          (setq block-ename (urb:as-ename block-ref))
          (if (not block-ename)
            (progn
              (urb:safe-delete block-ref)
              (urb:safe-delete block-definition)
              (prompt
                "\nERROR: AutoCAD no devolvio una referencia de bloque valida para el anden.")
              nil)
            (progn
              (vla-put-Layer block-ref "URB-ANDEN")
              (setq xdata-result
                (urb:set-xdata-strings
                  block-ename
                  "URB_ANDEN_BLOCK"
                  (list
                    "ANDEN" material etapa subetapa
                    (rtos area 2 8)
                    (rtos perimeter 2 8)
                    *urb-schema-version* guia toperol format calculate surface grade-source
                     (rtos (nth 0 finish-qty) 2 8)
                     (itoa (nth 1 finish-qty))
                     (rtos (nth 2 finish-qty) 2 8)
                     (rtos (nth 3 finish-qty) 2 8)
                     (rtos (nth 4 finish-qty) 2 8)
                     (itoa (nth 5 finish-qty))
                     (rtos elevation 2 8)
                     pattern-mode)))
              (if xdata-result
                (progn
                  (urb:set-anden-pattern-mode block-ename pattern-mode)
                  ;; con -BLOCK los originales ya fueron MOVIDOS al bloque:
                  ;; no hay nada que borrar (y recorrer decenas de miles de
                  ;; objetos muertos costaba minutos extra)
                  (if (not fast-ok)
                    (foreach obj objects (urb:safe-delete obj)))
                  block-ref)
                (progn
                  (urb:safe-delete block-ref)
                  (urb:safe-delete block-definition)
                  (prompt
                    "\nERROR: no fue posible guardar los datos del bloque de anden.")
                  nil))))))))
)

;; ============================================================
;; MOVIMIENTO DE TIERRAS DE ANDENES (4.9.0)
;; Igual que en vias: opcional, integrado en ANDEN/EDITAR, sin
;; cambiar el esquema principal de datos del anden. Muestrea la superficie
;; Civil 3D mediante una malla interior adaptativa y la
;; compara contra el nivel de acabado menos el espesor de la
;; estructura (0.60 m). Se guarda en la xdata URB_ANDEN_MOV del
;; bloque.
;; ============================================================

;; Espesor total de la estructura de anden (Figura estudio de suelos):
;; 6+4+50 cm = 60 cm. Unica fuente de verdad para el calculo de tierras;
;; *urb-anden-structure* mantiene su propio valor textual igual a este.
(setq *urb-anden-depth* 0.60)
(setq *urb-anden-min-samples* 5)
(setq *urb-anden-min-coverage* 0.90)
(setq *urb-anden-max-samples* 400)

(defun urb:average-terrain-at-points (surface points / total count p z)
  (setq total 0.0 count 0)
  (foreach p points
    (setq z (urb:surface-elevation surface (car p) (cadr p)))
    (if z (setq total (+ total z) count (1+ count))))
  (if (> count 0) (list (/ total count) count) nil)
)

(defun urb:polygon-centroid (points / ring p1 p2 cross sum-cross cx cy)
  ;; Centroide real por la formula del poligono (shoelace). El promedio
  ;; de vertices se desplaza mucho en contornos irregulares.
  (if (> (length points) 2)
    (progn
      (setq ring (append points (list (car points)))
            sum-cross 0.0 cx 0.0 cy 0.0)
      (while (cadr ring)
        (setq p1 (car ring)
              p2 (cadr ring)
              cross (- (* (car p1) (cadr p2)) (* (car p2) (cadr p1)))
              sum-cross (+ sum-cross cross)
              cx (+ cx (* (+ (car p1) (car p2)) cross))
              cy (+ cy (* (+ (cadr p1) (cadr p2)) cross))
              ring (cdr ring)))
      (if (> (abs sum-cross) 1e-12)
        (list (/ cx (* 3.0 sum-cross)) (/ cy (* 3.0 sum-cross)))
        nil))
    nil)
)

(defun urb:point-in-polygon-p
  (point points / x y inside ring p1 p2 x1 y1 x2 y2 crossing-x)
  (setq x (car point) y (cadr point) inside nil)
  (if (> (length points) 2)
    (progn
      (setq ring (append points (list (car points))))
      (while (cadr ring)
        (setq p1 (car ring) p2 (cadr ring)
              x1 (car p1) y1 (cadr p1)
              x2 (car p2) y2 (cadr p2))
        (if (not (equal (> y1 y) (> y2 y)))
          (progn
            (setq crossing-x
              (+ x1 (* (- y y1) (/ (- x2 x1) (- y2 y1)))))
            (if (< x crossing-x) (setq inside (not inside)))))
        (setq ring (cdr ring)))))
  inside
)

(defun urb:point-bounds (points / p minx maxx miny maxy)
  (foreach p points
    (if (null minx)
      (setq minx (car p) maxx (car p) miny (cadr p) maxy (cadr p))
      (setq minx (min minx (car p))
            maxx (max maxx (car p))
            miny (min miny (cadr p))
            maxy (max maxy (cadr p)))))
  (if minx (list minx maxx miny maxy) nil)
)

(defun urb:point-to-local (point cosine sine)
  (list
    (+ (* (car point) cosine) (* (cadr point) sine))
    (+ (* (- (car point)) sine) (* (cadr point) cosine)))
)

(defun urb:point-from-local (point cosine sine)
  (list
    (- (* (car point) cosine) (* (cadr point) sine))
    (+ (* (car point) sine) (* (cadr point) cosine)))
)

(defun urb:add-unique-point (point points / found item)
  (foreach item points
    (if (equal point item 1e-7) (setq found T)))
  (if found points (cons point points))
)

(defun urb:anden-fallback-samples
  (points / ring p1 p2 samples centroid midpoint interior)
  ;; Respaldo para contornos tan pequenos/estrechos que no admitan malla.
  (setq samples nil centroid (urb:polygon-centroid points))
  (if (and centroid (urb:point-in-polygon-p centroid points))
    (setq samples (urb:add-unique-point centroid samples)))
  (if points
    (progn
      (setq ring (append points (list (car points))))
      (while (cadr ring)
        (setq p1 (car ring) p2 (cadr ring))
        (setq midpoint
          (list (/ (+ (car p1) (car p2)) 2.0)
                (/ (+ (cadr p1) (cadr p2)) 2.0)))
        (setq samples (urb:add-unique-point p1 samples))
        (setq samples (urb:add-unique-point midpoint samples))
        (if centroid
          (progn
            (setq interior
              (list (/ (+ (car midpoint) (car centroid)) 2.0)
                    (/ (+ (cadr midpoint) (cadr centroid)) 2.0)))
            (if (urb:point-in-polygon-p interior points)
              (setq samples (urb:add-unique-point interior samples)))))
        (setq ring (cdr ring)))))
  (reverse samples)
)

(defun urb:anden-sample-points
  (points area / angle-value cosine sine local-points bounds
   minx maxx miny maxy width height bbox-area spacing x y
   local-point point samples fallback)
  ;; Malla de centros de celda: las muestras interiores tienen pesos
  ;; aproximadamente uniformes por area y no sobrerrepresentan el perimetro.
  ;; Se orienta con el borde principal para no perder cobertura en andenes
  ;; largos y diagonales por culpa de una caja global X/Y sobredimensionada.
  (setq angle-value (urb:anden-axis-angle points)
        cosine (cos angle-value)
        sine (sin angle-value)
        local-points
          (mapcar
            '(lambda (item) (urb:point-to-local item cosine sine))
            points)
        bounds (urb:point-bounds local-points))
  (if (and bounds (> area 1e-8))
    (progn
      (setq minx (nth 0 bounds) maxx (nth 1 bounds)
            miny (nth 2 bounds) maxy (nth 3 bounds)
            width (- maxx minx) height (- maxy miny)
            bbox-area (* width height))
      (if (and (> width 1e-8) (> height 1e-8))
        (progn
          (setq spacing
            (max 0.25
              (min 5.0
                (sqrt (/ area 160.0))
                (/ (min width height) 2.0))))
          ;; Limita tanto el total estimado como el numero de columnas/filas.
          (setq spacing
            (max spacing
              (/ (max width height) 200.0)
              (sqrt (/ bbox-area (float *urb-anden-max-samples*)))))
          (setq x (+ minx (min (/ spacing 2.0) (/ width 2.0))))
          (while (and (< x maxx)
                      (< (length samples) *urb-anden-max-samples*))
            (setq y (+ miny (min (/ spacing 2.0) (/ height 2.0))))
            (while (and (< y maxy)
                        (< (length samples) *urb-anden-max-samples*))
              (setq local-point (list x y))
              (if (urb:point-in-polygon-p local-point local-points)
                (progn
                  (setq point
                    (urb:point-from-local local-point cosine sine))
                  (setq samples (cons point samples))))
              (setq y (+ y spacing)))
            (setq x (+ x spacing)))))))
  (setq samples (reverse samples))
  (if (< (length samples) *urb-anden-min-samples*)
    (progn
      (setq fallback (urb:anden-fallback-samples points))
      (foreach point fallback
        (setq samples (urb:add-unique-point point samples)))))
  samples
)

(setq *urb-anden-road-crossfall* 0.02)
(setq *urb-anden-crossfall* 0.02)
(setq *urb-anden-curb-height* 0.15)

(defun urb:read-lisp-safe (text / value)
  (if (/= (urb:safe-string text "") "")
    (progn
      (setq value (vl-catch-all-apply 'read (list text)))
      (if (vl-catch-all-error-p value) nil value))
    nil)
)

(defun urb:grade-records-valid-p (records / valid record)
  (setq valid (and (listp records) (> (length records) 1)))
  (foreach record (if valid records nil)
    (if (not
          (and (listp record)
               (> (length record) 1)
               (numberp (nth 0 record))
               (numberp (nth 1 record))))
      (setq valid nil)))
  valid
)

;; XDATA limita cada cadena a 255 caracteres. Conserva hasta diez puntos
;; repartidos a lo largo de la rasante, suficientes para que los andenes
;; asociados reproduzcan sus cambios sin exceder ese limite.
(defun urb:compact-road-grade-samples
  (samples / total step index item result)
  (setq total (length samples))
  (setq step (max 1 (fix (+ (/ (max 0 (- total 1)) 9.0) 0.999999))))
  (setq index 0)
  (foreach item samples
    (if (or (= 0 (rem index step)) (= index (1- total)))
      (setq result
        (append result
          (list (list
            (atof (rtos (nth 0 item) 2 3))
            (atof (rtos (nth 2 item) 2 3)))))))
    (setq index (1+ index)))
  result
)

;; Recupera las cotas de una via antigua que no tenga muestras de rasante
;; guardadas. Primero intenta la capa registrada por VIA; si el XREF perdio
;; su calibracion al recargar el LSP, solicita un solo texto de referencia.
(defun urb:road-grade-records-from-layer
  (axis data / layer texts axis-start span station-start interval direction records info)
  (setq layer (urb:safe-string (nth 7 data) ""))
  (setq axis-start (atof (urb:safe-string (nth 21 data) "0")))
  (setq span (atof (urb:safe-string (nth 18 data) "0")))
  (setq station-start (urb:station-number (urb:safe-string (nth 10 data) "0")))
  (setq interval (atof (urb:safe-string (nth 11 data) "5")))
  (setq direction (urb:safe-string (nth 12 data) "Inicio"))
  (if (<= interval 1e-6) (setq interval 5.0))
  (if (and axis (/= layer ""))
    (progn
      (setq texts (urb:collect-cota-texts layer))
      (setq records
        (if texts
          (urb:cota-stations-on-axis axis texts axis-start span 15.0)
          nil))
      (setq records (urb:cota-best-per-source records))
      (setq records
        (urb:cota-snap-to-project-grid records axis-start span
          station-start interval direction))
      (setq records (urb:cota-deduplicate-stations records 0.05))))
  (if (< (length records) 2)
    (progn
      (prompt
        "\nLa via es anterior a la rasante guardada. Seleccione una cota de su capa para reconstruirla: ")
      (setq info (urb:road-cota-reference "Textos por capa"))
      (if (urb:string-equal-p (urb:safe-string (car info) "") "PICKED")
        ;; auto-detect: cotas seleccionadas una a una (via/etiqueta/texto)
        (setq records
          (urb:cota-deduplicate-stations
            (urb:picked-cotas-to-stations (cadr info) axis) 0.05))
        (progn
          (setq layer (urb:safe-string (car info) layer))
          (setq texts (if (/= layer "") (urb:collect-cota-texts layer) nil))
          (setq records
            (if texts
              (urb:cota-stations-on-axis axis texts axis-start span 15.0)
              nil))
          (setq records (urb:cota-best-per-source records))
          (setq records
            (urb:cota-snap-to-project-grid records axis-start span
              station-start interval direction))
          (setq records (urb:cota-deduplicate-stations records 0.05))))))
  records
)

;; Referencia: (eje registros inicio-eje longitud sentido modo metodo).
;; En una via nueva, registros contiene las muestras de rasante guardadas.
;; Las vias antiguas sin muestras pueden releerlas desde su capa de cotas;
;; el eje siempre se recupera o selecciona entre entidades ya existentes.
(defun urb:select-anden-road-grade
  (/ selected road data mov axis axis-handle via-id records c0 c1 span
   record-mode method axis-start)
  (setq selected (entsel "\nSeleccione la via creada que controla este anden: "))
  (if selected (setq road (urb:road-parent-from-entity (car selected))))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq via-id (if (> (length data) 22) (nth 22 data) ""))
      ;; El eje se identifica SOLO entre entidades existentes: handle,
      ;; cache o vinculo via-id. Nunca se reconstruye uno nuevo del bloque.
      (setq axis (urb:road-axis-recover road data via-id))
      (if axis
        (urb:remember-road-axis road data via-id axis))
      (setq mov (urb:road-movement-data road))
      (if (and mov (> (length mov) 9))
        (setq records (urb:read-lisp-safe (nth 9 mov))))
      (if (not (urb:grade-records-valid-p records)) (setq records nil))
      (if records
        (setq record-mode "LOCAL" method "Via creada - rasante guardada"))
      (setq span
        (atof
          (urb:safe-string
            (if (> (length data) 18) (nth 18 data) nil) "0")))
      (if (and (null records) mov (> (length mov) 8))
        (progn
          (setq c0 (urb:parse-real (nth 7 mov)))
          (setq c1 (urb:parse-real (nth 8 mov)))
           (if (and c0 c1 (> span 1e-6))
             (setq records (list (list 0.0 c0) (list span c1))
                   record-mode "LOCAL" method "Via creada"))))
      (if (and axis (null records))
        (progn
          (setq records (urb:road-grade-records-from-layer axis data))
          (if (urb:grade-records-valid-p records)
            (setq record-mode "RAW"
                  method "Via creada - cotas reconstruidas")
            (setq records nil))))
      (setq axis-start
        (atof
          (urb:safe-string
            (if (> (length data) 21) (nth 21 data) nil) "0")))
      (if (and axis (urb:curve-entity-p axis)
               (urb:grade-records-valid-p records))
        (list axis records
          axis-start span
          (urb:safe-string
            (if (> (length data) 12) (nth 12 data) nil) "Inicio")
          record-mode method
          (urb:safe-string via-id "")
          (urb:safe-string (if (> (length data) 1) (nth 1 data) nil) ""))
        (progn
          (prompt
            (if axis
              "\nLa via seleccionada no tiene rasante calculada."
              "\nLa via no conserva un eje vinculado. Edite esa via una vez; no se creara ni se pedira un eje duplicado."))
          nil)))
    (progn (prompt "\nEl objeto seleccionado no es una via cuantificable.") nil))
)

(defun urb:select-anden-alignment-grade
  (/ axis info layer texts axis-length records)
  (setq axis (urb:select-or-draw-road-axis "Existente"))
  (if axis
    (progn
      (setq info (urb:road-cota-reference "Textos por capa"))
      (setq axis-length
        (vlax-curve-getDistAtParam axis (vlax-curve-getEndParam axis)))
      (if (urb:string-equal-p (urb:safe-string (car info) "") "PICKED")
        ;; auto-detect: cotas seleccionadas una a una (via/etiqueta/texto)
        (setq records
          (urb:cota-deduplicate-stations
            (urb:picked-cotas-to-stations (cadr info) axis) 0.05))
        (progn
          (setq layer (car info))
          (setq texts (if (/= layer "") (urb:collect-cota-texts layer) nil))
          (setq records
            (if texts (urb:cota-stations-on-axis axis texts 0.0 axis-length 15.0) nil))
          (setq records (urb:cota-best-per-source records))
          (setq records (urb:cota-deduplicate-stations records 0.05))))
      (if (urb:grade-records-valid-p records)
        (list axis records 0.0 axis-length "Inicio" "RAW"
          "Alineamiento + cotas" "" "")
        (progn
          (prompt "\nNo se encontraron suficientes cotas cerca del alineamiento.") nil))))
)

;; "Cotas seleccionadas" (2026-08-12, pedido del usuario: rasante del
;; anden SIN via creada y SIN depender de una capa de cotas): se
;; selecciona o dibuja el eje de referencia y luego se clickean N cotas
;; una a una con el mismo picker auto-detect de las vias (texto/etiqueta
;; en CUALQUIER capa o xref, o una via ya creada, o digitada). Cada cota
;; se proyecta al eje en el punto del click -> rasante por tramos.
(defun urb:select-anden-picked-grade (/ axis picks records axis-length)
  (setq axis (urb:select-or-draw-road-axis "Existente"))
  (if axis
    (progn
      (prompt
        (strcat "\nSeleccione las cotas de rasante sobre el eje "
                "(textos en cualquier capa/xref, vias creadas o digitadas)."))
      (setq picks (urb:pick-road-cotas))
      (if picks
        (progn
          (setq records (urb:picked-cotas-to-stations picks axis))
          (setq axis-length
            (vlax-curve-getDistAtParam axis (vlax-curve-getEndParam axis)))
          (if (urb:grade-records-valid-p records)
            (list axis records 0.0 axis-length "Inicio" "RAW"
              "Cotas seleccionadas" "" "")
            (progn
              (prompt "\nNo se pudieron proyectar las cotas al eje.") nil)))
        nil)))
)

(defun urb:select-anden-grade-reference (source)
  (cond
    ((urb:string-equal-p source "Via creada")
      (urb:select-anden-road-grade))
    ((urb:string-equal-p source "Cotas seleccionadas")
      (urb:select-anden-picked-grade))
    (T (urb:select-anden-alignment-grade)))
)

(defun urb:anden-axis-edge-offset (points axis / p closest offset minimum)
  (if (and axis (urb:curve-entity-p axis))
    (foreach p points
      (setq closest (vlax-curve-getClosestPointTo axis p))
      (setq offset (distance p closest))
      (if (or (null minimum) (< offset minimum)) (setq minimum offset))))
  minimum
)

(defun urb:anden-grade-at-point
  (point reference edge-offset / axis records axis-start span direction mode
   closest raw-distance station zaxis offset)
  (setq axis (nth 0 reference) records (nth 1 reference)
        axis-start (nth 2 reference) span (nth 3 reference)
        direction (nth 4 reference) mode (nth 5 reference))
  (setq closest (vlax-curve-getClosestPointTo axis point))
  (setq raw-distance (vlax-curve-getDistAtPoint axis closest))
  (setq station
    (if (urb:string-equal-p mode "LOCAL")
      (if (urb:string-equal-p direction "Final")
        (- (+ axis-start span) raw-distance)
        (- raw-distance axis-start))
      raw-distance))
  (setq zaxis (urb:cota-at-axis-distance station records))
  (setq offset (distance point closest))
  (if zaxis
    (- (+ (- zaxis (* *urb-anden-road-crossfall* edge-offset))
          *urb-anden-curb-height*)
       (* *urb-anden-crossfall* (max 0.0 (- offset edge-offset))))
    nil)
)

(defun urb:grade-slope-at-distance
  (axis-distance records / ordered first-record last-record ring p1 p2)
  ;; Pendiente firmada del segmento de rasante que contiene la estacion.
  ;; En los extremos usa el primer o ultimo segmento, evitando pendientes
  ;; artificiales iguales a cero por extrapolacion constante.
  (setq ordered
    (vl-sort
      records
      '(lambda (a b) (< (car a) (car b)))))
  (if (> (length ordered) 1)
    (progn
      (setq first-record (car ordered)
            last-record (car (last ordered)))
      (cond
        ((<= axis-distance (car first-record))
          (setq p1 first-record p2 (cadr ordered)))
        ((>= axis-distance (car last-record))
          (setq p1 (nth (- (length ordered) 2) ordered)
                p2 last-record))
        (T
          (setq ring ordered)
          (while (and (cadr ring) (null p1))
            (if (and
                  (<= (car (car ring)) axis-distance)
                  (<= axis-distance (car (cadr ring))))
              (setq p1 (car ring) p2 (cadr ring))
              (setq ring (cdr ring))))))
      (if (and p1 p2 (> (- (car p2) (car p1)) 1e-9))
        (* 100.0
          (/ (- (cadr p2) (cadr p1))
             (- (car p2) (car p1))))
        nil))
    nil)
)

(defun urb:anden-longitudinal-slope-at-point
  (point reference / axis records axis-start span direction mode
   closest raw-distance station)
  (setq axis (nth 0 reference) records (nth 1 reference)
        axis-start (nth 2 reference) span (nth 3 reference)
        direction (nth 4 reference) mode (nth 5 reference))
  (setq closest (vlax-curve-getClosestPointTo axis point))
  (setq raw-distance (vlax-curve-getDistAtPoint axis closest))
  (setq station
    (if (urb:string-equal-p mode "LOCAL")
      (if (urb:string-equal-p direction "Final")
        (- (+ axis-start span) raw-distance)
        (- raw-distance axis-start))
      raw-distance))
  (urb:grade-slope-at-distance station records)
)

(defun urb:percent-range-text (minimum maximum)
  (cond
    ((and (numberp minimum) (numberp maximum)
          (equal minimum maximum 1e-6))
      (strcat (rtos minimum 2 2) "%"))
    ((and (numberp minimum) (numberp maximum))
      (strcat (rtos minimum 2 2) "% a " (rtos maximum 2 2) "%"))
    (T "sin calcular"))
)

(defun urb:mark-anden-earthworks-status (block-ref status / obj)
  (if (setq obj (urb:as-vla-object block-ref))
    (progn
      (urb:set-block-attribute obj "ANDEN_METODO" status)
      (vla-Update obj)))
  nil
)

(defun urb:run-anden-earthworks
  (block-ref points area surface-name grade-source
   / block-object ename surface reference axis samples total edge-result
   edge-offset p terrain finish-result finish delta cut-depth fill-depth
   count corte relleno method coverage required coverage-text via-id via-name
   slope-result long-slope long-min long-max total-slope total-min total-max
   slope-count transverse-percent pend-long-text pend-trans-text pend-total-text)
  (setq *urb-anden-earthwork-stage* "validacion del bloque")
  (setq block-object (urb:as-vla-object block-ref))
  (setq ename (urb:as-ename block-object))
  (cond
    ((or (not block-object) (not ename))
      (prompt
        "\nNo se calculo el movimiento: la referencia del bloque de anden no es valida.")
      nil)
    ((or (not (listp points)) (< (length points) 3) (<= area 1e-8))
      (urb:mark-anden-earthworks-status block-object "PENDIENTE - contorno invalido")
      (prompt "\nNo se calculo el movimiento: el contorno del anden no es valido.")
      nil)
    (T
      (setq *urb-anden-earthwork-stage* "seleccion de superficie")
      (setq surface (urb:select-surface-object surface-name))
      (if (not (urb:valid-vla-object-p surface))
        (progn
          (urb:mark-anden-earthworks-status
            block-object "PENDIENTE - superficie no disponible")
          (prompt "\nNo se calculo el movimiento: superficie no disponible.")
          nil)
        (progn
          (setq *urb-anden-earthwork-stage* "seleccion de rasante")
          (setq reference (urb:select-anden-grade-reference grade-source))
          (setq axis (if (and (listp reference) (> (length reference) 6))
                       (nth 0 reference) nil))
          (if (or (not axis)
                  (not (urb:curve-entity-p axis))
                  (not (urb:grade-records-valid-p (nth 1 reference))))
            (progn
              (urb:mark-anden-earthworks-status
                block-object "PENDIENTE - rasante no disponible")
              (prompt "\nNo se calculo el movimiento: rasante no disponible.")
              nil)
            (progn
              (setq *urb-anden-earthwork-stage* "generacion de malla interior")
              (setq samples (urb:anden-sample-points points area))
              (setq total (length samples))
              (setq edge-result
                (vl-catch-all-apply
                  'urb:anden-axis-edge-offset (list points axis)))
              (setq edge-offset
                (if (vl-catch-all-error-p edge-result) nil edge-result))
              (if (or (null edge-offset) (= total 0))
                (progn
                  (urb:mark-anden-earthworks-status
                    block-object "PENDIENTE - geometria no evaluable")
                  (prompt
                    "\nNo se calculo el movimiento: no fue posible evaluar la geometria.")
                  nil)
                (progn
                  (setq *urb-anden-earthwork-stage* "muestreo de superficie y rasante")
                  (setq cut-depth 0.0 fill-depth 0.0 count 0 slope-count 0
                        transverse-percent (* 100.0 *urb-anden-crossfall*))
                  (foreach p samples
                    (setq terrain
                      (urb:surface-elevation surface (car p) (cadr p)))
                    (setq finish-result
                      (vl-catch-all-apply
                        'urb:anden-grade-at-point
                        (list p reference edge-offset)))
                    (setq finish
                      (if (vl-catch-all-error-p finish-result)
                        nil
                        finish-result))
                    (if (and (numberp terrain) (numberp finish))
                      (progn
                        (setq delta (- terrain (- finish *urb-anden-depth*)))
                        (if (> delta 0.0)
                          (setq cut-depth (+ cut-depth delta))
                          (setq fill-depth (+ fill-depth (- delta))))
                        (setq count (1+ count))
                        (setq slope-result
                          (vl-catch-all-apply
                            'urb:anden-longitudinal-slope-at-point
                            (list p reference)))
                        (setq long-slope
                          (if (vl-catch-all-error-p slope-result)
                            nil
                            slope-result))
                        (if (numberp long-slope)
                          (progn
                            (setq total-slope
                              (sqrt
                                (+ (* long-slope long-slope)
                                   (* transverse-percent transverse-percent))))
                            (if (or (null long-min) (< long-slope long-min))
                              (setq long-min long-slope))
                            (if (or (null long-max) (> long-slope long-max))
                              (setq long-max long-slope))
                            (if (or (null total-min) (< total-slope total-min))
                              (setq total-min total-slope))
                            (if (or (null total-max) (> total-slope total-max))
                              (setq total-max total-slope))
                            (setq slope-count (1+ slope-count)))))))
                  (setq coverage
                    (if (> total 0) (/ (float count) (float total)) 0.0))
                  (setq required
                    (max *urb-anden-min-samples*
                      (fix (+ 0.999999
                        (* (float total) *urb-anden-min-coverage*)))))
                  (setq coverage-text
                    (strcat (rtos (* 100.0 coverage) 2 1) "%"))
                  (if (< count required)
                    (progn
                      (urb:set-block-attribute
                        block-object "ANDEN_MUESTRAS"
                        (strcat (itoa count) "/" (itoa total)))
                      (urb:set-block-attribute
                        block-object "ANDEN_COBERTURA" coverage-text)
                      (urb:mark-anden-earthworks-status
                        block-object "PENDIENTE - cobertura insuficiente")
                      (prompt
                        (strcat
                          "\nNo se calculo el movimiento: cobertura de superficie "
                          coverage-text " (" (itoa count) "/" (itoa total)
                          " muestras; minimo " (itoa required) ")."))
                      nil)
                    (progn
                      (setq *urb-anden-earthwork-stage* "guardado de resultados")
                      (setq corte (* area (/ cut-depth count)))
                      (setq relleno (* area (/ fill-depth count)))
                      (setq pend-long-text
                        (urb:percent-range-text long-min long-max))
                      (setq pend-trans-text
                        (strcat (rtos transverse-percent 2 2) "%"))
                      (setq pend-total-text
                        (urb:percent-range-text total-min total-max))
                      (setq method
                        (strcat (urb:safe-string (nth 6 reference) "Rasante")
                          " - malla interior"
                          " | pendientes automaticas"
                          " | estructura " (rtos *urb-anden-depth* 2 2) " m"))
                      (setq via-id
                        (urb:safe-string
                          (if (> (length reference) 7) (nth 7 reference) nil) ""))
                      (setq via-name
                        (urb:safe-string
                          (if (> (length reference) 8) (nth 8 reference) nil) ""))
                      (urb:set-xdata-strings ename "URB_ANDEN_MOV"
                        (list "ANDEN_MOV" method
                          (rtos corte 2 6) (rtos relleno 2 6)
                          (itoa count) (urb:safe-string surface-name "")
                          (itoa total) (rtos coverage 2 6)
                          via-id via-name
                          pend-long-text pend-trans-text pend-total-text))
                      (urb:set-block-attribute
                        block-object "ANDEN_PEND_LONG" pend-long-text)
                      (urb:set-block-attribute
                        block-object "ANDEN_PEND_TRANS" pend-trans-text)
                      (urb:set-block-attribute
                        block-object "ANDEN_PEND_TOTAL" pend-total-text)
                      (urb:set-block-attribute
                        block-object "ANDEN_CORTE_M3" (rtos corte 2 2))
                      (urb:set-block-attribute
                        block-object "ANDEN_RELLENO_M3" (rtos relleno 2 2))
                      (urb:set-block-attribute block-object "ANDEN_METODO" method)
                      (urb:set-block-attribute
                        block-object "ANDEN_MUESTRAS"
                        (strcat (itoa count) "/" (itoa total)))
                      (urb:set-block-attribute
                        block-object "ANDEN_COBERTURA" coverage-text)
                      (urb:set-block-attribute
                        block-object "ANDEN_VIA_ID" via-id)
                      (urb:set-block-attribute
                        block-object "ANDEN_VIA_NOMBRE" via-name)
                      (vla-Update block-object)
                      (prompt
                        (strcat "\nMovimiento de tierras (anden): corte "
                          (rtos corte 2 2) " m3 | relleno "
                          (rtos relleno 2 2) " m3 | cobertura "
                          coverage-text " | pendiente longitudinal "
                          pend-long-text " | transversal "
                          pend-trans-text " | resultante "
                          pend-total-text "."))
                      T)))))))))))

(defun urb:prompt-anden-earthworks
  (block-ref points area calculate surface grade-source / result)
  (if (urb:yes-p calculate)
    (progn
      (setq result
        (vl-catch-all-apply
          'urb:run-anden-earthworks
          (list block-ref points area surface grade-source)))
      (if (vl-catch-all-error-p result)
        (progn
          (urb:mark-anden-earthworks-status
            block-ref "PENDIENTE - error de calculo")
          (prompt
            (strcat
              "\nERROR al calcular movimiento del anden: "
              (vl-catch-all-error-message result)
              " | etapa: "
              (urb:safe-string *urb-anden-earthwork-stage* "desconocida")))
          nil)
        result))
    T)
)

(defun urb:anden-earthworks-totals (/ ss index ename data cut fill count)
  (setq cut 0.0 fill 0.0 count 0)
  (if (setq ss (ssget "_X" '((-3 ("URB_ANDEN_MOV")))))
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_ANDEN_MOV"))
        (if (and (listp data)
                 (> (length data) 3)
                 (urb:string-equal-p (car data) "ANDEN_MOV"))
          (progn
            (setq cut (+ cut (atof (urb:safe-string (nth 2 data) "0"))))
            (setq fill (+ fill (atof (urb:safe-string (nth 3 data) "0"))))
            (setq count (1+ count))))
        (setq index (1+ index)))))
  (list cut fill count)
)

(defun urb:valid-anden-earthworks-data-p (data)
  (and
    (listp data)
    (> (length data) 7)
    (urb:string-equal-p (car data) "ANDEN_MOV")
    (> (atoi (urb:safe-string (nth 4 data) "0")) 0)
    (>= (atof (urb:safe-string (nth 7 data) "0"))
        *urb-anden-min-coverage*))
)

(defun urb:create-sidewalk-command
  (/ data material format etapa subetapa guia toperol calculate surface
   grade-source ename result block-ref anden-points anden-area
   earthworks-ok orientation-choice start-choice pattern-mode
   old-fillmode doc undo-open undo-result *error* mod-p1 mod-p2 mod-angle)
  (setq doc (urb:doc) old-fillmode (getvar "FILLMODE"))
  (defun *error* (message)
    (setq *urb-current-tactile-side-point* nil
          *urb-current-tactile-side-choice* nil)
    (if old-fillmode
      (progn (setvar "FILLMODE" old-fillmode) (vla-Regen doc 1)))
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR EN ANDEN: " message)))
    (princ))
  (setq undo-result
    (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
  (setq undo-open (not (vl-catch-all-error-p undo-result)))
  (setq *urb-current-tactile-side-point* nil
        *urb-current-tactile-side-choice* nil)
  ;; Orientacion y extremo viven DENTRO del dialogo. El lado de la via
  ;; (toperol) se marca con UN click despues de dibujar: con andenes
  ;; diagonales una palabra tipo "arriba/abajo" es ambigua, el click sobre
  ;; el lado real no.
  (setq data
    (if (urb:confirm-meter-units)
      (urb:dialog-anden "Loseta" "40 x 40 cm" "1" "1" "No" "No"
        "Si" "SUP_TN" "Via creada"
        "Automatico" "Normal"
        '("Automatico" "Girar90") '("Normal" "Opuesto"))
      nil))
  (if data
    (progn
      (setq material (nth 0 data))
      (setq format (nth 1 data))
      (setq etapa (nth 2 data))
      (setq subetapa (nth 3 data))
      (setq guia (nth 4 data))
      (setq toperol (nth 5 data))
      (setq calculate (nth 6 data))
      (setq surface (nth 7 data))
      (setq grade-source (nth 8 data))
      (setq orientation-choice (nth 9 data))
      (setq start-choice (nth 10 data))
      (setq ename (urb:draw-closed-polyline)))
  )
  (if ename
    (progn
      (setq pattern-mode
        (urb:compose-anden-pattern-mode
          (= orientation-choice "Girar90")
          (= start-choice "Opuesto")))
      (setq anden-points (urb:lwpoly-points ename))
      (setq anden-area (vla-get-Area (vlax-ename->vla-object ename)))
      (if (or (urb:yes-p guia) (urb:yes-p toperol))
        (setq *urb-current-tactile-side-point*
          (urb:prompt-tactile-side-point)))
      ;; 2026-08-12 curva v2 (pantallazo del usuario: seguia diagonal):
      ;; si el contorno tiene ARCOS, la orientacion de la modulacion se
      ;; marca con 2 puntos PARALELOS a las bandas del anden/rampa vecino
      ;; -- osnap sobre una junta del modulo adyacente da el paralelismo
      ;; exacto que pidio. Enter = automatica (paralela al lado RECTO mas
      ;; largo del contorno, tipicamente la tapa compartida con el
      ;; vecino). El eje interno es perpendicular a las bandas y queda
      ;; guardado en el contorno (URB_ANDEN_AXIS): sobrevive a EDITAR.
      (if (urb:lwpoly-has-arcs-p ename)
        (progn
          (setq mod-p1
            (getpoint
              (strcat "\nContorno con curva -- marque 2 puntos PARALELOS a"
                      " las bandas del anden/rampa vecino (Enter = automatico): ")))
          (if mod-p1
            (setq mod-p2
              (getpoint mod-p1 "\nSegundo punto de la direccion de las bandas: ")))
          (setq mod-angle
            (cond
              ((and mod-p1 mod-p2 (> (distance mod-p1 mod-p2) 1e-6))
                (+ (angle mod-p1 mod-p2) (* 0.5 pi)))
              (T
                (setq mod-angle (urb:anden-straight-edges-angle ename))
                (if mod-angle (+ mod-angle (* 0.5 pi)) nil))))
          (if mod-angle
            (urb:set-xdata-strings ename "URB_ANDEN_AXIS"
              (list (rtos mod-angle 2 8))))))
      (urb:set-anden-data
        ename material etapa subetapa guia toperol format calculate surface grade-source)
      (urb:set-anden-pattern-mode ename pattern-mode)
      (setq result
        (urb:build-anden-finish ename material guia toperol format))
      (if result
        (setq block-ref (urb:package-anden ename)))
      (setvar "FILLMODE" 1)
      (vla-Regen (urb:doc) 1)
      (if block-ref
        (progn
          (setq earthworks-ok
            (urb:prompt-anden-earthworks
              block-ref anden-points anden-area calculate surface grade-source))
          (prompt
            (strcat
              "\nAnden creado: " (strcase material)
              " | Etapa " etapa
              " | Subetapa " subetapa
              (if (and (urb:yes-p calculate) (not earthworks-ok))
                " | Movimiento de tierras PENDIENTE."
                "."))))
        (prompt "\nNo fue posible crear el achurado del anden.")))
    (if data
      (prompt "\nNo se creo una polilinea valida.")
        (prompt "\nComando cancelado.")))
  (setq *urb-current-tactile-side-point* nil
        *urb-current-tactile-side-choice* nil)
  ;; Restaurar FILLMODE al valor original del usuario no alcanza si no se
  ;; regenera despues: el REGEN de mas arriba (FILLMODE=1, para que se vea
  ;; el relleno del anden) deja en pantalla TODO objeto rellenable del
  ;; dibujo mostrado solido -- incluidas regiones/hatches de otras partes
  ;; del proyecto que no tienen nada que ver con este anden (ej. lotes de
  ;; LOTEO FINAL). La variable vuelve a su valor, pero la vista se queda
  ;; regenerada con FILLMODE=1 hasta el proximo REGEN. Con este regen
  ;; final la vista vuelve a coincidir con el FILLMODE real del usuario.
  (if old-fillmode
    (progn (setvar "FILLMODE" old-fillmode) (vla-Regen doc 1)))
  (if undo-open
    (progn
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (setq undo-open nil)))
  (princ)
)

(defun urb:parent-anden-ename
  (ename / metadata generated parent parent-handle obj layer)
  (cond
    ((urb:anden-block-p ename)
      ename)
    ((setq metadata
       (urb:get-xdata-strings ename "URB_ANDEN"))
      (if (urb:string-equal-p (car metadata) "ANDEN") ename nil))
    ((setq generated
       (urb:get-xdata-strings ename "URB_ANDEN_GEN"))
      (setq parent-handle
        (urb:safe-string (car generated) ""))
      (setq parent
        (if (> (strlen parent-handle) 0)
          (vl-catch-all-apply 'handent (list parent-handle))))
      (if (vl-catch-all-error-p parent) (setq parent nil))
      (if (and parent
               (setq metadata
                 (urb:get-xdata-strings parent "URB_ANDEN"))
               (urb:string-equal-p (car metadata) "ANDEN"))
        parent
        nil))
    ((and
       (setq obj
         (vl-catch-all-apply
           'vlax-ename->vla-object
           (list ename)))
       (not (vl-catch-all-error-p obj))
       (setq layer (strcase (vla-get-Layer obj)))
       ;; "URB-Q-ANDEN-*" es el nombre viejo del contorno (antes de
       ;; consolidar capas); "URB-ANDEN" es el nombre actual.
       (or (urb:starts-with layer "URB-Q-ANDEN-") (= layer "URB-ANDEN"))
       (urb:closed-poly-p ename))
      ename)
    (T nil))
)

(defun urb:selected-anden-parents
  (selection / index ename parent handle handles parents)
  (setq index 0)
  (repeat (sslength selection)
    (setq ename (ssname selection index))
    (setq parent (urb:parent-anden-ename ename))
    (if parent
      (progn
        (setq handle
          (vla-get-Handle (vlax-ename->vla-object parent)))
        (if (not (member handle handles))
          (progn
            (setq handles (cons handle handles))
            (setq parents (cons parent parents))))))
    (setq index (1+ index)))
  (reverse parents)
)

(defun urb:prefab-block-p (ename)
  (if (urb:get-xdata-strings ename "URB_PREFAB_BLOCK") T nil)
)

(defun urb:prefab-data (ename)
  (or
    (urb:get-xdata-strings ename "URB_PREFAB_BLOCK")
    (urb:get-xdata-strings ename "URB_PREFAB"))
)

(defun urb:selected-prefabs (selection / index ename data result)
  (setq index 0)
  (repeat (sslength selection)
    (setq ename (ssname selection index))
    (setq data (urb:prefab-data ename))
    (if data (setq result (cons ename result)))
    (setq index (1+ index)))
  (reverse result)
)

(defun urb:selected-mp-entities (selection / index ename result)
  (setq index 0)
  (repeat (sslength selection)
    (setq ename (ssname selection index))
    (if (mp:editable-entity-p ename)
      (setq result (cons ename result)))
    (setq index (1+ index)))
  (reverse result)
)

(defun urb:extract-prefab-reference
  (ename prefab mode / obj exploded objects item layer reference side-edge
   reference-layer side-layer reference-role side-role side-point role)
  (setq obj (vlax-ename->vla-object ename))
  (setq exploded (vl-catch-all-apply 'vla-Explode (list obj)))
  (if (vl-catch-all-error-p exploded)
    nil
    (progn
      (setq objects (urb:variant-object-list exploded))
      (if (urb:string-equal-p mode "Interior")
        (setq reference-role "EXTERIOR" side-role "INTERIOR")
        (setq reference-role "INTERIOR" side-role "EXTERIOR"))
      ;; 4.18.0: identifica interior/exterior por rol xdata (independiente
      ;; de la capa, ya consolidada). Bloques prefabricados de antes de
      ;; este cambio no tienen ese rol -- se cae al nombre de capa viejo
      ;; (URB-PREFAB-<TIPO>-INTERIOR/EXTERIOR) como respaldo.
      (foreach item objects
        (if (member (vla-get-ObjectName item)
              '("AcDbPolyline" "AcDb2dPolyline"))
          (progn
            (setq role (urb:generated-role item))
            (if (= role reference-role) (setq reference item))
            (if (= role side-role) (setq side-edge item)))))
      (if (not (and reference side-edge))
        (progn
          (setq reference-layer
            (strcat "URB-PREFAB-" (urb:prefab-token prefab) "-" reference-role))
          (setq side-layer
            (strcat "URB-PREFAB-" (urb:prefab-token prefab) "-" side-role))
          (foreach item objects
            (if (member (vla-get-ObjectName item)
                  '("AcDbPolyline" "AcDb2dPolyline"))
              (progn
                (setq layer (vla-get-Layer item))
                (if (urb:string-equal-p layer reference-layer)
                  (setq reference item))
                (if (urb:string-equal-p layer side-layer)
                  (setq side-edge item)))))))
      (if side-edge
        (setq side-point
          (vlax-curve-getStartPoint
            (vlax-vla-object->ename side-edge))))
      (foreach item objects
        (if (not (eq item reference)) (urb:safe-delete item)))
      (if (and reference side-point)
        (list (vlax-vla-object->ename reference) side-point)
        (progn
          (if reference (urb:safe-delete reference))
          nil))))
)

(defun urb:flip-side-point (reference-ename side-point / closest)
  (setq closest
    (vlax-curve-getClosestPointTo reference-ename side-point))
  (list
    (- (* 2.0 (car closest)) (car side-point))
    (- (* 2.0 (cadr closest)) (cadr side-point))
    (- (* 2.0 (if (caddr closest) (caddr closest) 0.0))
       (if (caddr side-point) (caddr side-point) 0.0)))
)

(defun urb:update-prefab-block-data
  (ename prefab width etapa subetapa mode / obj data length-value area-value)
  (setq obj (vlax-ename->vla-object ename))
  (setq data (urb:prefab-data ename))
  (setq length-value (urb:safe-string (nth 4 data) "0"))
  (setq area-value (* width (atof length-value)))
  (urb:set-xdata-strings
    ename "URB_PREFAB_BLOCK"
    (list prefab etapa subetapa (rtos width 2 8)
          length-value mode *urb-prefab-schema-version*))
  (urb:set-block-attribute obj "TIPO" (strcase prefab))
  (urb:set-block-attribute obj "ANCHO_M" (rtos width 2 3))
  (urb:set-block-attribute obj "AREA_M2" (rtos area-value 2 2))
  (urb:set-block-attribute obj "ETAPA" etapa)
  (urb:set-block-attribute obj "SUBETAPA" subetapa)
  (urb:set-block-attribute obj "MODELADO" mode)
  T
)

(defun urb:edit-prefabs
  (prefabs / first-data dialog-data prefab width etapa subetapa mode
   ename data old-prefab old-width old-mode extracted reference side-point
   new-block new-ename obj copy-obj copy-ename updated failed deleted)
  (setq first-data (urb:prefab-data (car prefabs)))
  (setq prefab (urb:safe-string (nth 0 first-data) "Bordillo"))
  (setq width (atof (urb:safe-string (nth 3 first-data) "0.20")))
  (setq etapa (urb:safe-string (nth 1 first-data) "1"))
  (setq subetapa (urb:safe-string (nth 2 first-data) etapa))
  (setq mode (urb:safe-string (nth 5 first-data) "Interior"))
  (setq dialog-data
    (urb:dialog-prefab prefab width etapa subetapa mode))
  (if dialog-data
    (progn
      (setq prefab (nth 0 dialog-data))
      (setq width (nth 1 dialog-data))
      (setq etapa (nth 2 dialog-data))
      (setq subetapa (nth 3 dialog-data))
      (setq mode (nth 4 dialog-data))
      (setq updated 0 failed 0 deleted 0)
      (foreach ename prefabs
        (setq new-block nil extracted nil reference nil side-point nil)
        (setq data (urb:prefab-data ename))
        (setq old-prefab (urb:safe-string (nth 0 data) "Bordillo"))
        (setq old-width (atof (urb:safe-string (nth 3 data) "0.20")))
        (setq old-mode (urb:safe-string (nth 5 data) "Interior"))
        (if (urb:prefab-block-p ename)
          (if (and (urb:string-equal-p old-prefab prefab)
                   (equal old-width width 0.0000001)
                   (urb:string-equal-p old-mode mode))
            (progn
              (urb:update-prefab-block-data
                ename prefab width etapa subetapa mode)
              (setq updated (1+ updated)))
            (progn
              (setq extracted
                (urb:call-edit-stage
                  "extraer prefabricado"
                  'urb:extract-prefab-reference
                  (list ename old-prefab old-mode)))
              (if extracted
                (progn
                  (setq reference (car extracted))
                  (setq side-point (cadr extracted))
                  (if (not (urb:string-equal-p old-mode mode))
                    (setq side-point
                      (urb:flip-side-point reference side-point)))
                  (setq new-block
                    (urb:call-edit-stage
                      "reconstruir prefabricado"
                      'urb:build-prefab-from-reference
                      (list reference side-point prefab width
                            etapa subetapa mode)))
                  (if new-block
                    (progn
                      (urb:copy-quantity-scope ename new-block)
                      (if
                      (urb:call-edit-stage
                        "reemplazar prefabricado anterior"
                        'urb:delete-anden-block
                        (list ename))
                      (setq updated (1+ updated))
                      (progn
                        (setq new-ename (urb:as-ename new-block))
                         (if new-ename
                           (urb:delete-anden-block new-ename))
                         (setq failed (1+ failed)))))
                    (setq failed (1+ failed))))
                (setq failed (1+ failed)))))
          (progn
            (setq obj (vlax-ename->vla-object ename))
            (setq copy-obj (vla-Copy obj))
            (if (vlax-property-available-p copy-obj 'ConstantWidth T)
              (vla-put-ConstantWidth copy-obj 0.0))
            (setq copy-ename (vlax-vla-object->ename copy-obj))
            (setq side-point
              (getpoint
                (strcat
                  "\nMarque el lado " mode
                  " para convertir el prefabricado anterior: ")))
            (if side-point
              (setq new-block
                (urb:build-prefab-from-reference
                  copy-ename side-point prefab width
                  etapa subetapa mode)))
            (if new-block
              (progn
                (urb:copy-quantity-scope ename new-block)
                (if (urb:safe-delete obj)
                  (progn
                    (setq updated (1+ updated))
                    (setq deleted (1+ deleted)))
                  (progn
                    (setq new-ename (urb:as-ename new-block))
                    (if new-ename (urb:delete-anden-block new-ename))
                    (setq failed (1+ failed)))))
              (progn
                (urb:safe-delete copy-obj)
                (setq failed (1+ failed))))))
      )
      (vla-Regen (urb:doc) 1)
      (prompt
        (strcat
          "\nPrefabricados actualizados: " (itoa updated)
          " | Fallidos: " (itoa failed)
          " | Anteriores convertidos: " (itoa deleted) "."))))
  T
)

(defun urb:variant-object-list (value / raw)
  (cond
    ((= (type value) 'LIST) value)
    ((= (type value) 'VARIANT)
      (setq raw (vlax-variant-value value))
      (if (= (type raw) 'SAFEARRAY)
        (vlax-safearray->list raw)
        nil))
    ((= (type value) 'SAFEARRAY)
      (vlax-safearray->list value))
    (T nil))
)

(defun urb:update-anden-block-data
  (ename material etapa subetapa guia toperol format calculate surface grade-source
   / obj data area perimeter smooth-area smooth-count guide-ml toperol-ml
   adoquin-area adoquin-count elevation pattern-mode)
  (setq material (urb:safe-string material "Loseta"))
  (setq etapa (urb:safe-string etapa "1"))
  (setq subetapa (urb:safe-string subetapa etapa))
  (setq guia (urb:safe-string guia "No"))
  (setq toperol (urb:safe-string toperol "No"))
  (setq format (urb:safe-string format "40 x 40 cm"))
  (setq obj (vlax-ename->vla-object ename))
  (setq data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
  (setq area (if data (nth 4 data) ""))
  (setq perimeter (if data (nth 5 data) ""))
  (setq smooth-area (if (> (length data) 13) (nth 13 data) "0"))
  (setq smooth-count (if (> (length data) 14) (nth 14 data) "0"))
  (setq guide-ml (if (> (length data) 15) (nth 15 data) "0"))
  (setq toperol-ml (if (> (length data) 16) (nth 16 data) "0"))
  (setq adoquin-area (if (> (length data) 17) (nth 17 data) "0"))
  (setq adoquin-count (if (> (length data) 18) (nth 18 data) "0"))
  (setq pattern-mode (urb:anden-pattern-mode ename))
  (setq elevation
    (if (> (length data) 19)
      (nth 19 data)
      (rtos
        (if (vlax-property-available-p obj 'InsertionPoint)
          (caddr
            (vlax-safearray->list
              (vlax-variant-value (vla-get-InsertionPoint obj))))
          0.0)
        2 8)))
  (urb:set-xdata-strings
    ename
    "URB_ANDEN_BLOCK"
    (list "ANDEN" (strcase material) etapa subetapa area perimeter
          *urb-schema-version* guia toperol format calculate surface grade-source
          smooth-area smooth-count guide-ml toperol-ml adoquin-area adoquin-count
          elevation pattern-mode))
  (urb:set-block-attribute obj "MATERIAL" (strcase material))
  (urb:set-block-attribute obj "ETAPA" etapa)
  (urb:set-block-attribute obj "SUBETAPA" subetapa)
  (urb:set-block-attribute obj "LOSETA_GUIA" guia)
  (urb:set-block-attribute obj "LOSETA_TOPEROL" toperol)
  (urb:set-block-attribute obj "FORMATO_LOSETA" format)
  (urb:set-block-attribute obj "ANDEN_SUPERFICIE" surface)
  (urb:set-block-attribute obj "ANDEN_RASANTE" grade-source)
  (urb:set-block-attribute obj "ADOQUIN_20X10_M2" adoquin-area)
  (urb:set-block-attribute obj "ADOQUIN_20X10_UND" adoquin-count)
  (urb:set-block-attribute obj "ANDEN_ELEVACION" elevation)
  (urb:set-block-attribute obj "ANDEN_SENTIDO" pattern-mode)
  (urb:repair-block-ref-order obj)
  T
)

(defun urb:migrate-anden-block (ename / data schema obj)
  (setq data (urb:anden-block-data ename))
  (setq schema
    (urb:safe-string
      (if (> (length data) 6) (nth 6 data) nil) "0"))
  (if (/= schema *urb-schema-version*)
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (urb:repair-block-ref-order obj)))
  schema
)

(defun urb:explode-anden-block-boundary
  (ename / obj exploded objects item boundary layer)
  (setq obj (vlax-ename->vla-object ename))
  (setq exploded
    (vl-catch-all-apply 'vla-Explode (list obj)))
  (if (vl-catch-all-error-p exploded)
    nil
    (progn
      (setq objects (urb:variant-object-list exploded))
      (foreach item objects
        (setq layer
          (strcase
            (urb:safe-string (vla-get-Layer item) "")))
        (if (and
              (member
                (vla-get-ObjectName item)
                '("AcDbPolyline" "AcDb2dPolyline"))
              (or (urb:starts-with layer "URB-Q-ANDEN-") (= layer "URB-ANDEN")))
          (setq boundary item)))
      (foreach item objects
        (if (not (eq item boundary))
          (urb:safe-delete item)))
      (if boundary
        (vlax-vla-object->ename boundary)
        nil)))
)

(defun urb:call-edit-stage (stage function arguments / result)
  (setq result (vl-catch-all-apply function arguments))
  (if (vl-catch-all-error-p result)
    (progn
      (prompt
        (strcat
          "\nNo se completo la etapa "
          (urb:safe-string stage "desconocida")
          ": "
          (vl-catch-all-error-message result)))
      nil)
    result)
)

(defun urb:cleanup-working-boundary (ename / obj handle)
  (if (and ename (entget ename))
    (progn
      (setq obj
        (vl-catch-all-apply
          'vlax-ename->vla-object
          (list ename)))
      (if (not (vl-catch-all-error-p obj))
        (progn
          (setq handle
            (vl-catch-all-apply 'vla-get-Handle (list obj)))
          (if (not (vl-catch-all-error-p handle))
            (urb:delete-generated handle))
          (urb:safe-delete obj)))))
  nil
)

(defun urb:delete-anden-block
  (ename / obj block-name block-definition deleted)
  (setq obj (urb:as-vla-object ename))
  (if (not obj)
    nil
    (progn
      (setq block-name
        (vl-catch-all-apply 'vla-get-Name (list obj)))
      (setq deleted (urb:safe-delete obj))
      (if (and deleted (not (vl-catch-all-error-p block-name)))
        (progn
          (setq block-definition
            (vl-catch-all-apply
              'vla-Item
              (list (vla-get-Blocks (urb:doc)) block-name)))
          (if (not (vl-catch-all-error-p block-definition))
            (urb:safe-delete block-definition))))
      deleted))
)

(defun urb:rebuild-working-boundary
  (boundary material etapa subetapa guia toperol format calculate surface grade-source
   / saved result block-ref pattern-mode pts)
  (setq pattern-mode (urb:anden-pattern-mode boundary))
  ;; Las versiones 4.17.3 preliminares guardaban el sentido en otra APPID.
  ;; Se retira antes de escribir URB_ANDEN para evitar dos XDATA separadas.
  (urb:clear-xdata-app boundary "URB_ANDEN_PATTERN")
  ;; Misma validacion que urb:draw-closed-polyline (moño/ancho anomalo):
  ;; este es el OTRO camino (edicion, no dibujo nuevo) que regenera el
  ;; acabado sobre un contorno -- sin este chequeo aqui, una polilinea que
  ;; llegue deformada (edicion de grips, seleccion manual, etc.) generaba
  ;; el acabado sin ningun aviso, igual que pasaba antes en el flujo de
  ;; dibujo nuevo.
  (setq pts (urb:lwpoly-points-with-arcs boundary))
  (if (urb:anden-shape-ok-p pts)
    (setq saved
      (urb:call-edit-stage
        "guardar datos"
        'urb:set-anden-data
        (list boundary material etapa subetapa guia toperol format calculate surface grade-source)))
    (setq saved nil))
  (if saved
    (urb:set-anden-pattern-mode boundary pattern-mode))
  (if saved
    (setq result
      (urb:call-edit-stage
        "crear geometria"
        'urb:build-anden-finish
        (list boundary material guia toperol format))))
  (if result
    (setq block-ref
      (urb:call-edit-stage
        "crear bloque"
        'urb:package-anden
        (list boundary))))
  (if (not block-ref)
    (urb:cleanup-working-boundary boundary))
  block-ref
)

(defun urb:prepare-green-layers ()
  (urb:ensure-layer "URB-ZONA-VERDE" 3 T)
)

(defun urb:draw-green-boundary
  (/ option selected source object copy before after old-plinewid)
  (initget "Dibujar Seleccionar")
  (setq option
    (getkword
      "\nDefinir contorno de zona verde [Dibujar/Seleccionar] <Dibujar>: "))
  (if (null option) (setq option "Dibujar"))
  (if (= option "Seleccionar")
    (progn
      (setq selected
        (entsel "\nSeleccione una polilinea cerrada existente: "))
      (if (and selected
               (setq source (car selected))
               (urb:closed-poly-p source))
        (progn
          ;; La geometria original se conserva; la zona verde trabaja con
          ;; una copia propia para no alterar el plano base.
          (setq object (vlax-ename->vla-object source)
                copy (vla-Copy object))
          (if (vlax-property-available-p copy 'ConstantWidth T)
            (vla-put-ConstantWidth copy 0.0))
          (vlax-vla-object->ename copy))
        (progn
          (prompt "\nLa seleccion no es una polilinea cerrada valida.")
          nil)))
    (progn
      (setq old-plinewid (getvar "PLINEWID")
            before (entlast))
      (setvar "PLINEWID" 0.0)
      (prompt
        "\nDibuje el contorno de la zona verde. Enter termina y cierra el area.")
      (urb:draw-polyline-interactive old-plinewid)
      (setq after (entlast))
      (if (and after (/= after before)
               (= (cdr (assoc 0 (entget after))) "LWPOLYLINE"))
        (progn
          (setq object (vlax-ename->vla-object after))
          (vla-put-Closed object :vlax-true)
          (if (urb:closed-poly-p after) after nil))
        nil)))
)

(defun urb:green-zone-data (ename / data object attributes)
  (setq data (urb:get-xdata-strings ename "URB_GREEN_BLOCK"))
  (if data
    data
    (progn
      (setq object (urb:as-vla-object ename))
      (if object
        (progn
          (setq attributes (urb:block-attribute-values object))
          (list "ZONA_VERDE"
            (urb:attribute-alist-value attributes "ETAPA" "1")
            (urb:attribute-alist-value attributes "SUBETAPA" "1")
            (urb:attribute-alist-value attributes "AREA_M2" "0")
            (urb:attribute-alist-value attributes "PERIMETRO_M" "0")
            (urb:attribute-alist-value
              attributes "ESPESOR_TIERRA_NEGRA_M" "0.20")
            (urb:attribute-alist-value
              attributes "TIERRA_NEGRA_M3" "0")
            "0"))
        nil)))
)

(defun urb:green-zone-block-p (ename / data object layer name)
  (setq data (urb:get-xdata-strings ename "URB_GREEN_BLOCK")
        object (urb:as-vla-object ename))
  (and object
       (urb:string-equal-p (vla-get-ObjectName object)
         "AcDbBlockReference")
       (or
         (and data
              (urb:string-equal-p (car data) "ZONA_VERDE"))
         (progn
           (setq layer
             (strcase (urb:safe-string (vla-get-Layer object) ""))
                 name
             (strcase (urb:safe-string (vla-get-Name object) "")))
           (or (= layer "URB-ZONA-VERDE-BLOQUE") (= layer "URB-ZONA-VERDE")
               (urb:starts-with name "URB_ZONA_VERDE_")))))
)

(defun urb:selected-green-zones
  (selection / index ename result)
  (setq index 0)
  (repeat (sslength selection)
    (setq ename (ssname selection index))
    (if (urb:green-zone-block-p ename)
      (setq result (cons ename result)))
    (setq index (1+ index)))
  (reverse result)
)

(defun urb:package-green-zone
  (ename hatch etapa subetapa thickness
   / boundary area perimeter volume point handle objects block-name blocks
   block-definition copy-result insert-result block-ref block-ename
   xdata-result)
  (setq boundary (vlax-ename->vla-object ename)
        area (vla-get-Area boundary)
        perimeter (urb:poly-perimeter boundary)
        volume (* area thickness)
        point
          (if (urb:lwpoly-points ename)
            (car (urb:lwpoly-points ename))
            '(0.0 0.0 0.0))
        handle (vla-get-Handle boundary)
        objects (list boundary))
  (if (urb:valid-vla-object-p hatch)
    (setq objects (append objects (list hatch))))
  (setq block-name
    (strcat "URB_ZONA_VERDE_" handle "_"
      (itoa (getvar "MILLISECS")))
        blocks (vla-get-Blocks (urb:doc))
        block-definition
          (vla-Add blocks
            (vlax-3d-point '(0.0 0.0 0.0)) block-name)
        copy-result
          (vl-catch-all-apply 'vla-CopyObjects
            (list (urb:doc)
              (urb:object-array-variant objects)
              block-definition)))
  (if (vl-catch-all-error-p copy-result)
    (progn
      (urb:safe-delete block-definition)
      (prompt
        (strcat "\nERROR al crear el bloque de zona verde: "
          (vl-catch-all-error-message copy-result)))
      nil)
    (progn
      (urb:set-block-draw-order
        block-definition
        (urb:variant-object-list copy-result))
      (urb:add-invisible-attribute
        block-definition point "TIPO" "Tipo" "ZONA VERDE")
      (urb:add-invisible-attribute
        block-definition point "ETAPA" "Etapa" etapa)
      (urb:add-invisible-attribute
        block-definition point "SUBETAPA" "Subetapa" subetapa)
      (urb:add-invisible-attribute
        block-definition point "AREA_M2" "Area zona verde m2"
        (rtos area 2 2))
      (urb:add-invisible-attribute
        block-definition point "PERIMETRO_M" "Perimetro m"
        (rtos perimeter 2 2))
      (urb:add-invisible-attribute
        block-definition point "ESPESOR_TIERRA_NEGRA_M"
        "Espesor tierra negra m" (rtos thickness 2 3))
      (urb:add-invisible-attribute
        block-definition point "TIERRA_NEGRA_M3"
        "Tierra negra m3" (rtos volume 2 2))
      (setq insert-result
        (vl-catch-all-apply 'vla-InsertBlock
          (list (urb:space)
            (vlax-3d-point '(0.0 0.0 0.0))
            block-name 1.0 1.0 1.0 0.0)))
      (if (vl-catch-all-error-p insert-result)
        (progn
          (urb:safe-delete block-definition)
          (prompt
            (strcat "\nERROR al insertar la zona verde: "
              (vl-catch-all-error-message insert-result)))
          nil)
        (progn
          (setq block-ref insert-result
                block-ename (urb:as-ename block-ref))
          (vla-put-Layer block-ref "URB-ZONA-VERDE")
          (setq xdata-result
            (urb:set-xdata-strings block-ename "URB_GREEN_BLOCK"
              (list "ZONA_VERDE" etapa subetapa
                (rtos area 2 8)
                (rtos perimeter 2 8)
                (rtos thickness 2 8)
                (rtos volume 2 8)
                *urb-green-schema-version*)))
          (if xdata-result
            (progn
              (foreach object objects (urb:safe-delete object))
              block-ref)
            (progn
              (urb:safe-delete block-ref)
              (urb:safe-delete block-definition)
              (prompt
                "\nERROR: no fue posible guardar los datos de la zona verde.")
              nil))))))
)

(defun urb:create-green-zone-command
  (/ data etapa subetapa thickness ename object area volume hatch block-ref
   old-fillmode doc undo-open undo-result *error*)
  (setq doc (urb:doc)
        old-fillmode (getvar "FILLMODE"))
  (defun *error* (message)
    (if old-fillmode
      (progn (setvar "FILLMODE" old-fillmode) (vla-Regen doc 1)))
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message
               '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR EN ZONA VERDE: " message)))
    (princ))
  (setq undo-result
    (vl-catch-all-apply 'vla-StartUndoMark (list doc))
        undo-open (not (vl-catch-all-error-p undo-result))
        data
          (if (urb:confirm-meter-units)
            (urb:dialog-green "1" "1" 0.20)
            nil))
  (if data
    (progn
      (setq etapa (nth 0 data)
            subetapa (nth 1 data)
            thickness (nth 2 data)
            ename (urb:draw-green-boundary))))
  (if ename
    (progn
      (urb:prepare-green-layers)
      (setq object (vlax-ename->vla-object ename))
      (setq area (vla-get-Area object)
            volume (* area thickness))
      (vla-put-Layer object "URB-ZONA-VERDE")
      (vla-put-Color object 256)
      (setq hatch
        (urb:add-hatch object "URB-ZONA-VERDE"
          "GRASS" 1 "ANSI31" 0.50 3))
      (if (vl-catch-all-error-p hatch) (setq hatch nil))
      (setq block-ref
        (urb:package-green-zone
          ename hatch etapa subetapa thickness))
      (setvar "FILLMODE" 1)
      (vla-Regen doc 1)
      (if block-ref
        (prompt
          (strcat "\nZona verde creada: "
            (rtos area 2 2)
            " m2 | Tierra negra: "
            (rtos volume 2 2)
            " m3 | Espesor "
            (rtos thickness 2 3) " m."))
        (prompt "\nNo fue posible crear la zona verde.")))
    (if data
      (prompt "\nNo se definio un contorno valido.")
      (prompt "\nCreacion de zona verde cancelada.")))
  ;; ver comentario equivalente en urb:create-sidewalk-command: sin este
  ;; regen la vista se queda mostrando todo objeto rellenable del dibujo
  ;; solido (heredado del REGEN con FILLMODE=1 de mas arriba) aunque la
  ;; variable ya haya vuelto a su valor original.
  (if old-fillmode
    (progn (setvar "FILLMODE" old-fillmode) (vla-Regen doc 1)))
  (if undo-open
    (progn
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (setq undo-open nil)))
  (princ)
)

(defun urb:update-green-zone-data
  (ename etapa subetapa thickness
   / data object area perimeter volume)
  (setq data (urb:green-zone-data ename)
        object (urb:as-vla-object ename)
        area (atof (urb:safe-string (nth 3 data) "0"))
        perimeter (atof (urb:safe-string (nth 4 data) "0"))
        volume (* area thickness))
  (urb:set-xdata-strings ename "URB_GREEN_BLOCK"
    (list "ZONA_VERDE" etapa subetapa
      (rtos area 2 8)
      (rtos perimeter 2 8)
      (rtos thickness 2 8)
      (rtos volume 2 8)
      *urb-green-schema-version*))
  (urb:set-block-attribute object "ETAPA" etapa)
  (urb:set-block-attribute object "SUBETAPA" subetapa)
  (urb:set-block-attribute object
    "ESPESOR_TIERRA_NEGRA_M" (rtos thickness 2 3))
  (urb:set-block-attribute object
    "TIERRA_NEGRA_M3" (rtos volume 2 2))
  T
)

(defun urb:edit-green-zones
  (zones / first data etapa subetapa thickness dialog-data ename updated)
  (setq first (car zones)
        data (urb:green-zone-data first)
        etapa (urb:safe-string (nth 1 data) "1")
        subetapa (urb:safe-string (nth 2 data) etapa)
        thickness (atof (urb:safe-string (nth 5 data) "0.20"))
        dialog-data
          (urb:dialog-green etapa subetapa thickness))
  (if dialog-data
    (progn
      (setq etapa (nth 0 dialog-data)
            subetapa (nth 1 dialog-data)
            thickness (nth 2 dialog-data)
            updated 0)
      (foreach ename zones
        (if (urb:update-green-zone-data
              ename etapa subetapa thickness)
          (setq updated (1+ updated))))
      (vla-Regen (urb:doc) 1)
      (prompt
        (strcat "\nZonas verdes actualizadas: "
          (itoa updated) "."))))
  T
)

(defun c:EDITAR
  (/ selection parents prefabs greens first metadata material format etapa subetapa
   guia toperol calculate surface grade-source data
   ename obj result deleted updated failed old-material boundary block-ref
   cleaned old-guia old-toperol old-format old-calculate old-surface
   old-grade-source old-schema mp-entities roads omitted
   mixed-count orientation-choice start-choice pattern-mode old-pattern-mode
   old-rotated old-reversed new-rotated new-reversed
   anden-points anden-area earthworks-ok new-ename old-handle
   old-movement old-earthworks-p
   doc undo-open undo-result *error*)
  (setq doc (urb:doc))
  (defun *error* (message)
    (setq *urb-current-tactile-side-point* nil
          *urb-current-tactile-side-choice* nil)
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR EN EDITAR: " message)))
    (princ))
  (setq undo-result
    (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
  (setq undo-open (not (vl-catch-all-error-p undo-result)))
  (setq *urb-current-tactile-side-point* nil
        *urb-current-tactile-side-choice* nil)
  (setq cleaned (urb:clean-selector-layer))
  (if (> cleaned 0)
    (prompt
      (strcat
        "\nEfectos defectuosos eliminados: "
        (itoa cleaned) ".")))
  (prompt
    "\nSeleccione uno o varios elementos para editar: ")
  (setq selection (ssget))
  (if selection
    (progn
      (setq parents (urb:selected-anden-parents selection))
      (setq prefabs (urb:selected-prefabs selection))
      (setq greens (urb:selected-green-zones selection))
      (setq roads (urb:selected-roads selection))
      (setq mp-entities (urb:selected-mp-entities selection))
      ;; Una seleccion mixta ya no descarta objetos silenciosamente. Se
      ;; rechaza completa para que el usuario sepa exactamente qué se editó.
      (setq mixed-count
        (+ (if roads 1 0)
           (if parents 1 0)
           (if prefabs 1 0)
           (if greens 1 0)
           (if mp-entities 1 0)))
      (if (> mixed-count 1)
        (progn
          (prompt
            "\nLa seleccion contiene categorias diferentes. No se modifico ningun objeto; seleccione un solo tipo.")
          (setq roads nil parents nil prefabs nil greens nil mp-entities nil)))
      (if roads
        (foreach ename roads (urb:edit-road ename))
        (if parents
        (progn
          (foreach ename parents
            (if (urb:anden-block-p ename)
              (urb:call-edit-stage
                "revisar bloque anterior"
                'urb:migrate-anden-block
                (list ename))))
          (setq first (car parents))
          (setq metadata
            (if (urb:anden-block-p first)
              (urb:anden-block-data first)
              (urb:get-xdata-strings first "URB_ANDEN")))
          (setq material
            (if metadata
              (nth 1 metadata)
              (if
                (urb:string-equal-p
                  (vla-get-Layer
                    (vlax-ename->vla-object first))
                  "URB-Q-ANDEN-ADOQUIN")
                "Adoquin"
                "Loseta")))
          (setq etapa
            (if metadata (nth 2 metadata) "1"))
          (setq subetapa
            (if metadata (nth 3 metadata) "1"))
          (setq guia
            (if (urb:anden-block-p first)
              (if (> (length metadata) 7) (nth 7 metadata) "No")
              (if (> (length metadata) 4) (nth 4 metadata) "No")))
          (setq toperol
            (if (urb:anden-block-p first)
              (if (> (length metadata) 8) (nth 8 metadata) "No")
              (if (> (length metadata) 5) (nth 5 metadata) "No")))
          (setq format
            (if (urb:anden-block-p first)
              (if (> (length metadata) 9) (nth 9 metadata) "20 x 20 cm")
              (if (> (length metadata) 6) (nth 6 metadata) "20 x 20 cm")))
          (setq calculate
            (if (urb:anden-block-p first)
              (if (> (length metadata) 10) (nth 10 metadata) "Si")
              (if (> (length metadata) 7) (nth 7 metadata) "Si")))
          (setq surface
            (if (urb:anden-block-p first)
              (if (> (length metadata) 11) (nth 11 metadata) "SUP_TN")
              (if (> (length metadata) 8) (nth 8 metadata) "SUP_TN")))
          (setq grade-source
            (if (urb:anden-block-p first)
              (if (> (length metadata) 12) (nth 12 metadata) "Via creada")
              (if (> (length metadata) 9) (nth 9 metadata) "Via creada")))
          (setq material (urb:safe-string material "Loseta"))
          (setq etapa (urb:safe-string etapa "1"))
          (setq subetapa (urb:safe-string subetapa etapa))
          (setq guia (urb:safe-string guia "No"))
          (setq toperol (urb:safe-string toperol "No"))
          (setq format (urb:safe-string format "20 x 20 cm"))
          (setq calculate (urb:safe-string calculate "Si"))
          (setq surface (urb:safe-string surface "SUP_TN"))
          (setq grade-source (urb:safe-string grade-source "Via creada"))
          ;; Orientacion/extremo van dentro del mismo dialogo (igual que en
          ;; la creacion); aqui las listas incluyen "Conservar" para
          ;; mantener el sentido propio de cada anden seleccionado. El lado
          ;; del toperol se marca con un click despues de aceptar.
          (setq data
            (urb:dialog-anden
              material format etapa subetapa guia toperol
              calculate surface grade-source
              "Conservar" "Conservar"
              '("Conservar" "Automatico" "Girar90")
              '("Conservar" "Normal" "Opuesto")))
          (if data
            (progn
              (setq material (nth 0 data))
              (setq format (nth 1 data))
              (setq etapa (nth 2 data))
              (setq subetapa (nth 3 data))
              (setq guia (nth 4 data))
              (setq toperol (nth 5 data))
              (setq calculate (nth 6 data))
              (setq surface (nth 7 data))
              (setq grade-source (nth 8 data))
              (setq orientation-choice (nth 9 data))
              (setq start-choice (nth 10 data))
              (setq material (urb:safe-string material "Loseta"))
              (setq etapa (urb:safe-string etapa "1"))
              (setq subetapa (urb:safe-string subetapa etapa))
              (setq guia (urb:safe-string guia "No"))
              (setq toperol (urb:safe-string toperol "No"))
              (setq format (urb:safe-string format "40 x 40 cm"))
              (setq calculate (urb:safe-string calculate "Si"))
              (setq surface (urb:safe-string surface "SUP_TN"))
              (setq grade-source (urb:safe-string grade-source "Via creada"))
              (if (or (urb:yes-p guia) (urb:yes-p toperol))
                (setq *urb-current-tactile-side-point*
                  (urb:prompt-tactile-side-point)))
              (setq deleted 0 updated 0 failed 0)
              (foreach ename parents
                (setq old-pattern-mode (urb:anden-pattern-mode ename)
                      old-rotated
                        (urb:anden-pattern-rotated-p old-pattern-mode)
                      old-reversed
                        (urb:anden-pattern-reversed-p old-pattern-mode)
                      new-rotated
                        (cond
                          ((= orientation-choice "Automatico") nil)
                          ((= orientation-choice "Girar90") T)
                          (T old-rotated))
                      new-reversed
                        (cond
                          ((= start-choice "Normal") nil)
                          ((= start-choice "Opuesto") T)
                          (T old-reversed))
                      pattern-mode
                        (urb:compose-anden-pattern-mode
                          new-rotated new-reversed))
                (if (urb:anden-block-p ename)
                  (progn
                    (setq metadata
                      (urb:anden-block-data ename))
                    (setq old-material (nth 1 metadata))
                    (setq old-schema
                      (if (> (length metadata) 6) (nth 6 metadata) "0"))
                    (setq old-guia
                      (if (> (length metadata) 7) (nth 7 metadata) "No"))
                    (setq old-toperol
                      (if (> (length metadata) 8) (nth 8 metadata) "No"))
                    (setq old-format
                      (if (> (length metadata) 9) (nth 9 metadata) "20 x 20 cm"))
                    (setq old-calculate
                      (if (> (length metadata) 10) (nth 10 metadata) "Si"))
                    (setq old-surface
                      (if (> (length metadata) 11) (nth 11 metadata) "SUP_TN"))
                    (setq old-grade-source
                      (if (> (length metadata) 12) (nth 12 metadata) "Via creada"))
                    (setq old-movement
                      (urb:get-xdata-strings ename "URB_ANDEN_MOV"))
                    (setq old-earthworks-p
                      (urb:valid-anden-earthworks-data-p old-movement))
                    (if (and
                          (= old-schema *urb-schema-version*)
                          (urb:string-equal-p old-material material)
                          (urb:string-equal-p old-guia guia)
                          (urb:string-equal-p old-toperol toperol)
                          (urb:string-equal-p old-format format)
                          (urb:string-equal-p old-calculate calculate)
                          (urb:string-equal-p old-surface surface)
                          (urb:string-equal-p old-grade-source grade-source)
                          (urb:string-equal-p
                            old-pattern-mode pattern-mode)
                          ;; Con calculo activo, EDITAR tambien funciona como
                          ;; recalculo aunque el dialogo no haya cambiado.
                          (not (urb:yes-p calculate)))
                      (progn
                        (if
                          (urb:call-edit-stage
                            "actualizar propiedades"
                            'urb:update-anden-block-data
                            (list ename material etapa subetapa guia toperol
                              format calculate surface grade-source))
                          (setq updated (1+ updated))
                          (setq failed (1+ failed))))
                      (progn
                        (setq boundary
                          (urb:call-edit-stage
                            "extraer contorno"
                            'urb:explode-anden-block-boundary
                            (list ename)))
                        (if boundary
                          (progn
                            (urb:set-anden-pattern-mode
                              boundary pattern-mode)
                            (setq anden-points (urb:lwpoly-points boundary))
                            (setq anden-area
                              (vla-get-Area (vlax-ename->vla-object boundary)))
                            (setq block-ref
                              (urb:rebuild-working-boundary
                                boundary material etapa subetapa
                                guia toperol format calculate surface grade-source))
                            (if block-ref
                              (urb:copy-quantity-scope ename block-ref))
                            (setq earthworks-ok
                              (if block-ref
                                (urb:prompt-anden-earthworks
                                  block-ref anden-points anden-area
                                  calculate surface grade-source)
                                nil))
                            (if
                              (and
                                block-ref
                                (or earthworks-ok (not old-earthworks-p)))
                              (progn
                                ;; La geometria corregida se conserva aunque
                                ;; el movimiento siga pendiente, siempre que
                                ;; el bloque anterior tampoco tuviera un
                                ;; calculo valido que debamos proteger.
                                (if
                                  (urb:call-edit-stage
                                    "reemplazar bloque anterior"
                                    'urb:delete-anden-block
                                    (list ename))
                                  (setq updated (1+ updated))
                                  (progn
                                    (setq new-ename (urb:as-ename block-ref))
                                    (if new-ename
                                      (urb:delete-anden-block new-ename))
                                    (setq failed (1+ failed)))))
                              (progn
                                ;; Un movimiento anterior valido no se pierde
                                ;; si su recalculo fue cancelado o fallo.
                                (setq new-ename (urb:as-ename block-ref))
                                (if new-ename (urb:delete-anden-block new-ename))
                                (setq failed (1+ failed)))))
                          (setq failed (1+ failed))))))
                  (progn
                    (setq obj (vlax-ename->vla-object ename))
                    (setq result
                      (urb:call-edit-stage
                        "copiar contorno anterior"
                        'vla-Copy
                        (list obj)))
                    (setq boundary
                      (if result
                        (urb:call-edit-stage
                          "preparar contorno"
                          'urb:as-ename
                          (list result))))
                    (if boundary
                      (progn
                        (urb:set-anden-pattern-mode
                          boundary pattern-mode)
                        (setq anden-points (urb:lwpoly-points boundary))
                        (setq anden-area
                          (vla-get-Area (vlax-ename->vla-object boundary)))))
                    (setq block-ref
                      (if boundary
                        (urb:rebuild-working-boundary
                          boundary material etapa subetapa
                          guia toperol format calculate surface grade-source)))
                    (if block-ref
                      (urb:copy-quantity-scope ename block-ref))
                    ;; Este contorno no era un anden empacado: nunca hubo
                    ;; movimiento de tierras previo, se ofrece calcularlo.
                    (setq earthworks-ok
                      (if block-ref
                        (urb:prompt-anden-earthworks
                          block-ref anden-points anden-area
                          calculate surface grade-source)
                        nil))
                    (setq old-handle
                      (vl-catch-all-apply 'vla-get-Handle (list obj)))
                    (if (vl-catch-all-error-p old-handle)
                      (setq old-handle nil))
                    (if block-ref
                      (if (urb:safe-delete obj)
                        (progn
                          ;; Los auxiliares se limpian solo despues de confirmar
                          ;; que el contorno anterior realmente fue eliminado.
                          (if old-handle
                            (progn
                              (urb:remove-anden-group old-handle)
                              (setq deleted
                                (+ deleted
                                   (urb:delete-generated old-handle)))))
                          (setq updated (1+ updated)))
                        (progn
                          ;; Evita dejar dos andenes si AutoCAD impide borrar
                          ;; el objeto anterior (capa bloqueada, proxy, etc.).
                          (setq new-ename (urb:as-ename block-ref))
                          (if new-ename (urb:delete-anden-block new-ename))
                          (setq failed (1+ failed))))
                      (progn
                        (setq new-ename (urb:as-ename block-ref))
                        (if new-ename (urb:delete-anden-block new-ename))
                        (setq failed (1+ failed))))))
              )
              (vla-Regen (urb:doc) 1)
              (prompt
                (strcat
                  "\nAndenes actualizados: " (itoa updated)
                  " | Fallidos: " (itoa failed)
                  " | Elementos reemplazados: "
                  (itoa deleted) ".")))))
        (if prefabs
          (urb:edit-prefabs prefabs)
          (if greens
            (urb:edit-green-zones greens)
            (if mp-entities
              (foreach ename mp-entities (mp:edit-entity ename))
              (prompt
                "\nLa seleccion no contiene elementos editables.")))))))
    (prompt "\nNo se selecciono ningun objeto."))
  (setq *urb-current-tactile-side-point* nil
        *urb-current-tactile-side-choice* nil)
  (if undo-open
    (progn
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (setq undo-open nil)))
  (princ)
)


(defun urb:add-hatch
  (boundary layer pattern pattern-type fallback scale color
   / first-error result)
  (setq result
    (vl-catch-all-apply
      'urb:add-hatch-raw
      (list boundary layer pattern pattern-type scale color)))
  (if (vl-catch-all-error-p result)
    (progn
      (setq first-error (vl-catch-all-error-message result))
      (prompt
        (strcat
          "\nEl patron " pattern " no pudo crearse: "
          first-error
          "\nIntentando patron nativo " fallback "..."))
      (setq result
        (vl-catch-all-apply
          'urb:add-hatch-raw
          (list boundary layer fallback 1 scale color)))
      (if (vl-catch-all-error-p result)
        (prompt
          (strcat
            "\nERROR al crear el achurado: "
            (vl-catch-all-error-message result)))
      )
    )
  )
  result
)

;; Nota 4.1.0: se eliminaron urb:prepare-layers, urb:process-selection,
;; urb:get-scale y urb:select-polygons (solo las usaban los antiguos
;; comandos URBLOSETA/URBVIA retirados del sistema).

(defun urb:layer-description (layer / parts)
  (setq parts
    (cond
      ((= layer "URB-ANDEN") '("ANDEN" "LOSETA"))
      ((= layer "URB-BORDILLO") '("BORDILLO" "PREFABRICADO"))
      ((= layer "URB-SARDINEL") '("SARDINEL" "PREFABRICADO"))
      ((= layer "URB-CANUELA") '("CANUELA" "PREFABRICADO"))
      ;; Nombres de capa anteriores a la consolidacion 4.18.0 -- se
      ;; conservan para etiquetar filas de dibujos viejos correctamente.
      ((= layer "URB-Q-ANDEN-LOSETA") '("ANDEN" "LOSETA"))
      ((= layer "URB-Q-ANDEN-ADOQUIN") '("ANDEN" "ADOQUIN"))
      ((= layer "URB-Q-VIA-ASFALTO") '("VIA" "ASFALTO"))
      ((= layer "URB-Q-VIA-CONCRETO") '("VIA" "CONCRETO"))
      ((= layer "URB-Q-VIA-ADOQUIN") '("VIA" "ADOQUIN"))
      ((= layer "URB-PREFAB-SARDINEL") '("SARDINEL" "PREFABRICADO"))
      ((= layer "URB-PREFAB-BORDILLO") '("BORDILLO" "PREFABRICADO"))
      ((= layer "URB-PREFAB-BORDILLO-BLOQUE")
        '("BORDILLO" "PREFABRICADO"))
      ((= layer "URB-PREFAB-SARDINEL-BLOQUE")
        '("SARDINEL" "PREFABRICADO"))
      ((= layer "URB-PREFAB-CANUELA-BLOQUE")
        '("CANUELA" "PREFABRICADO"))
    )
  )
  parts
)

(defun urb:accumulate
  (rows key layer etapa subetapa area perimeter / item)
  (if (setq item (assoc key rows))
    (subst
      (list key
        (1+ (nth 1 item))
        (+ area (nth 2 item))
        (+ perimeter (nth 3 item))
        layer etapa subetapa)
      item
      rows)
    (cons
      (list key 1 area perimeter layer etapa subetapa)
      rows)
  )
)

(defun urb:draw-open-polyline
  (label / before after obj old-plinewid *error*)
  (setq old-plinewid (getvar "PLINEWID"))
  (defun *error* (message)
    (if old-plinewid (setvar "PLINEWID" old-plinewid))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al dibujar el recorrido: " message)))
    (princ))
  (setvar "PLINEWID" 0.0)
  (setq before (entlast))
  (prompt
    (strcat
      "\nDibuje el recorrido de " label
      ". Enter termina el trazado."))
  (urb:draw-polyline-interactive old-plinewid)
  (setq after (entlast))
  (if (and after (/= after before)
           (= (cdr (assoc 0 (entget after))) "LWPOLYLINE"))
    (progn
      (setq obj (vlax-ename->vla-object after))
      (if (vlax-property-available-p obj 'ConstantWidth T)
        (vla-put-ConstantWidth obj 0.0))
      after)
    nil)
)

(defun urb:offset-candidate (obj distance-value / result objects candidate item)
  (setq result
    (vl-catch-all-apply 'vla-Offset (list obj distance-value)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq objects (urb:variant-object-list result))
      (setq candidate (car objects))
      (foreach item (cdr objects) (urb:safe-delete item))
      candidate))
)

(defun urb:point-to-curve-distance (point obj / closest result)
  (setq result
    (vl-catch-all-apply
      'vlax-curve-getClosestPointTo
      (list (vlax-vla-object->ename obj) point)))
  (if (vl-catch-all-error-p result)
    1.0e99
    (distance point result))
)

(defun urb:offset-toward-point
  (obj width side-point / positive negative selected)
  (setq positive (urb:offset-candidate obj width))
  (setq negative (urb:offset-candidate obj (- width)))
  (cond
    ((and positive negative)
      (if
        (<= (urb:point-to-curve-distance side-point positive)
            (urb:point-to-curve-distance side-point negative))
        (progn (setq selected positive) (urb:safe-delete negative))
        (progn (setq selected negative) (urb:safe-delete positive))))
    (positive (setq selected positive))
    (negative (setq selected negative)))
  selected
)

(defun urb:add-solid-hatch-loop (objects layer color / hatch result)
  (setq hatch
    (vl-catch-all-apply
      'vla-AddHatch
      (list (urb:space) 1 "SOLID" :vlax-true)))
  (if (vl-catch-all-error-p hatch)
    nil
    (progn
      (setq result
        (vl-catch-all-apply
          'vla-AppendOuterLoop
          (list hatch (urb:object-array-variant objects))))
      (if (vl-catch-all-error-p result)
        (progn (urb:safe-delete hatch) nil)
        (progn
          (vla-put-Layer hatch layer)
          (vla-put-Color hatch color)
          (vla-Evaluate hatch)
          hatch))))
)

(defun urb:prefab-token (prefab)
  (strcase (urb:safe-string prefab "Bordillo"))
)

;; 4.18.0: una sola capa por tipo de prefabricado (antes 5: BLOQUE/
;; INTERIOR/EXTERIOR/REMATE/RELLENO). El rol de cada pieza (interior,
;; exterior, remate, relleno) ahora se guarda como xdata (urb:tag-generated-role)
;; en vez de codificarse en el nombre de la capa.
(defun urb:prefab-layer (prefab)
  (strcat "URB-" (urb:prefab-token prefab))
)

(defun urb:prefab-color (prefab)
  (cond
    ((= (urb:prefab-token prefab) "SARDINEL") 30)
    ((= (urb:prefab-token prefab) "CANUELA") 4)
    (T 1))
)

(defun urb:package-prefab-block
  (objects source prefab width etapa subetapa mode length-value
   / handle block-name blocks block-definition copy-result point
   block-ref area-value obj block-layer insert-result block-ename xdata-result)
  (setq handle (vla-get-Handle source))
  (setq block-name
    (strcat
      "URB_" prefab "_" handle "_"
      (itoa (getvar "MILLISECS"))))
  (setq point
    (vlax-curve-getStartPoint (vlax-vla-object->ename source)))
  (setq blocks (vla-get-Blocks (urb:doc)))
  (setq block-definition
    (vla-Add blocks (vlax-3d-point '(0.0 0.0 0.0)) block-name))
  (setq copy-result
    (vl-catch-all-apply
      'vla-CopyObjects
      (list
        (urb:doc)
        (urb:object-array-variant objects)
        block-definition)))
  (if (vl-catch-all-error-p copy-result)
    (progn
      (urb:safe-delete block-definition)
      nil)
    (progn
      (urb:set-block-draw-order
        block-definition
        (urb:variant-object-list copy-result))
      (setq area-value (* width length-value))
      (urb:add-invisible-attribute
        block-definition point "TIPO" "Tipo" prefab)
      (urb:add-invisible-attribute
        block-definition point "ANCHO_M" "Ancho m" (rtos width 2 3))
      (urb:add-invisible-attribute
        block-definition point "LONGITUD_M" "Longitud m"
        (rtos length-value 2 2))
      (urb:add-invisible-attribute
        block-definition point "AREA_M2" "Area m2"
        (rtos area-value 2 2))
      (urb:add-invisible-attribute
        block-definition point "ETAPA" "Etapa" etapa)
      (urb:add-invisible-attribute
        block-definition point "SUBETAPA" "Subetapa" subetapa)
      (urb:add-invisible-attribute
        block-definition point "MODELADO" "Modelado" mode)
      (setq insert-result
        (vl-catch-all-apply
          'vla-InsertBlock
          (list
            (urb:space)
            (vlax-3d-point '(0.0 0.0 0.0))
            block-name 1.0 1.0 1.0 0.0)))
      (if (vl-catch-all-error-p insert-result)
        (progn
          (urb:safe-delete block-definition)
          (prompt
            (strcat "\nERROR al insertar el bloque prefabricado: "
              (vl-catch-all-error-message insert-result)))
          nil)
        (progn
          (setq block-ref insert-result block-ename (urb:as-ename block-ref))
          (if (not block-ename)
            (progn
              (urb:safe-delete block-ref)
              (urb:safe-delete block-definition)
              (prompt
                "\nERROR: AutoCAD no devolvio una referencia de bloque prefabricado valida.")
              nil)
            (progn
              (setq block-layer (urb:prefab-layer prefab))
              (vla-put-Layer block-ref block-layer)
              (setq xdata-result
                (urb:set-xdata-strings
                  block-ename
                  "URB_PREFAB_BLOCK"
                  (list prefab etapa subetapa
                        (rtos width 2 8)
                        (rtos length-value 2 8)
                        mode *urb-prefab-schema-version*)))
              (if xdata-result
                (progn
                  (foreach obj objects (urb:safe-delete obj))
                  block-ref)
                (progn
                  (urb:safe-delete block-ref)
                  (urb:safe-delete block-definition)
                  (prompt
                    "\nERROR: no fue posible guardar los datos del bloque prefabricado.")
                  nil))))))))
)

(defun urb:prepare-prefab-layers (prefab / color)
  (setq color (urb:prefab-color prefab))
  (urb:ensure-layer (urb:prefab-layer prefab) color T)
)

(defun urb:build-prefab-from-reference
  (ename side-point prefab width etapa subetapa mode
   / source offset piece-layer source-role offset-role
   source-start source-end offset-start offset-end temp connector-start
   connector-end hatch objects length-value block-ref color parent-handle)
  (setq prefab (urb:safe-string prefab "Bordillo"))
  (setq mode (urb:safe-string mode "Interior"))
  (urb:prepare-prefab-layers prefab)
  (setq color (urb:prefab-color prefab))
  (setq source (vlax-ename->vla-object ename))
  (setq offset (urb:offset-toward-point source width side-point))
  (if offset
    (progn
      ;; 4.18.0: una sola capa por tipo (piece-layer). Interior/exterior/
      ;; remate/relleno se distinguen por rol xdata, no por capa; el color
      ;; de interior (3, verde) se conserva como color de entidad.
      (setq piece-layer (urb:prefab-layer prefab))
      (if (urb:string-equal-p mode "Interior")
        (setq source-role "EXTERIOR" offset-role "INTERIOR")
        (setq source-role "INTERIOR" offset-role "EXTERIOR"))
      (setq parent-handle (vla-get-Handle source))
      (vla-put-Layer source piece-layer)
      (vla-put-Layer offset piece-layer)
      (vla-put-Color source (if (= source-role "INTERIOR") 3 color))
      (vla-put-Color offset (if (= offset-role "INTERIOR") 3 color))
      (urb:tag-generated-role source parent-handle source-role)
      (urb:tag-generated-role offset parent-handle offset-role)
      (setq source-start (vlax-curve-getStartPoint ename))
      (setq source-end (vlax-curve-getEndPoint ename))
      (setq offset-start
        (vlax-curve-getStartPoint (vlax-vla-object->ename offset)))
      (setq offset-end
        (vlax-curve-getEndPoint (vlax-vla-object->ename offset)))
      (if (> (distance source-start offset-start)
             (distance source-start offset-end))
        (progn
          (setq temp offset-start)
          (setq offset-start offset-end)
          (setq offset-end temp)))
      (setq connector-start
        (vla-AddLine
          (urb:space)
          (vlax-3d-point source-start)
          (vlax-3d-point offset-start)))
      (setq connector-end
        (vla-AddLine
          (urb:space)
          (vlax-3d-point source-end)
          (vlax-3d-point offset-end)))
      (vla-put-Layer connector-start piece-layer)
      (vla-put-Layer connector-end piece-layer)
      (urb:tag-generated-role connector-start parent-handle "REMATE")
      (urb:tag-generated-role connector-end parent-handle "REMATE")
      (setq objects (list source connector-end offset connector-start))
      (setq hatch
        (urb:add-solid-hatch-loop objects piece-layer color))
      (if hatch
        (progn
          (urb:tag-generated-role hatch parent-handle "RELLENO")
          (setq objects (append objects (list hatch)))))
      (setq length-value (urb:poly-perimeter source))
      (setq block-ref
        (urb:package-prefab-block
          objects source prefab width etapa subetapa mode length-value))
      (if (not block-ref)
        (foreach temp objects (urb:safe-delete temp))))
    (urb:safe-delete source))
  block-ref
)

(defun urb:create-prefabricado
  (/ data prefab width etapa subetapa mode ename side-point block-ref)
  (setq data
    (urb:dialog-prefab "Bordillo" 0.20 "1" "1" "Interior"))
  (if data
    (progn
      (setq prefab (nth 0 data))
      (setq width (nth 1 data))
      (setq etapa (nth 2 data))
      (setq subetapa (nth 3 data))
      (setq mode (nth 4 data))
      (setq ename
        (urb:draw-open-polyline
          (strcat (strcase prefab) " - arista de referencia")))
      (if ename
        (progn
          (setq side-point
            (getpoint
              (strcat
                "\nMarque un punto hacia el lado " mode
                " donde crecera el espesor: ")))
          (if side-point
            (progn
              (setq block-ref
                (urb:build-prefab-from-reference
                  ename side-point prefab width etapa subetapa mode))
              (if block-ref
                (prompt
                  (strcat
                    "\n" (strcase prefab) " creado como bloque."
                    " Use la arista verde como limite del ANDEN."))
                (prompt "\nNo fue posible crear el bloque prefabricado.")))
            (progn
              (urb:safe-delete (vlax-ename->vla-object ename))
              (prompt "\nComando cancelado."))))
        (prompt "\nNo se creo una polilinea valida.")))
    (prompt "\nComando cancelado."))
  (princ)
)

(defun urb:create-precast-command ()
  (if (urb:confirm-meter-units)
    (urb:create-prefabricado)
    (prompt "\nComando cancelado: confirme que el dibujo trabaja en metros."))
)

(defun urb:collect-quantities
  (/ ss i ename obj layer rows metadata etapa subetapa key
   material area perimeter prefab)
  (setq rows nil)
  (if (setq ss
        (ssget "_X"
          '((0 . "LWPOLYLINE,POLYLINE"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ename (ssname ss i))
        (setq obj (vlax-ename->vla-object ename))
        (setq layer (strcase (vla-get-Layer obj)))
        (if (and
              (urb:q-modelspace-p ename)
              (urb:starts-with layer "URB-Q-")
              (urb:closed-poly-p ename)
              (urb:layer-description layer))
          (progn
            (setq metadata
              (urb:get-xdata-strings ename "URB_ANDEN"))
            (setq etapa
              (if metadata (nth 2 metadata) ""))
            (setq subetapa
              (if metadata (nth 3 metadata) ""))
            (setq key
              (strcat layer "|" etapa "|" subetapa))
            (setq rows
              (urb:accumulate
                rows key layer etapa subetapa
                (vla-get-Area obj)
                (urb:poly-perimeter obj))))
          (if (setq metadata (urb:prefab-data ename))
            (progn
              (setq etapa (nth 1 metadata))
              (setq subetapa (nth 2 metadata))
              (setq key
                (strcat layer "|" etapa "|" subetapa))
              (setq rows
                (urb:accumulate
                  rows key layer etapa subetapa
                  0.0 (urb:poly-perimeter obj)))))
        )
        (setq i (1+ i))
      )
    )
  )
  (if (setq ss (ssget "_X" '((0 . "INSERT"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ename (ssname ss i))
        (if (and (urb:q-modelspace-p ename)
                 (urb:anden-block-p ename))
          (progn
            (setq metadata
              (urb:get-xdata-strings
                ename "URB_ANDEN_BLOCK"))
            (setq material (nth 1 metadata))
            (setq etapa (nth 2 metadata))
            (setq subetapa (nth 3 metadata))
            (setq area (atof (nth 4 metadata)))
            (setq perimeter (atof (nth 5 metadata)))
            (setq layer
              (if (= (strcase material) "ADOQUIN")
                "URB-Q-ANDEN-ADOQUIN"
                "URB-Q-ANDEN-LOSETA"))
            (setq key
              (strcat layer "|" etapa "|" subetapa))
            (setq rows
              (urb:accumulate
                rows key layer etapa subetapa area perimeter)))
          (if (and (urb:q-modelspace-p ename)
                   (urb:prefab-block-p ename))
            (progn
              (setq metadata
                (urb:get-xdata-strings
                  ename "URB_PREFAB_BLOCK"))
              (setq prefab (urb:safe-string (nth 0 metadata) "BORDILLO"))
              (setq etapa (urb:safe-string (nth 1 metadata) ""))
              (setq subetapa (urb:safe-string (nth 2 metadata) ""))
              (setq perimeter
                (atof (urb:safe-string (nth 4 metadata) "0")))
              (setq layer
                (urb:prefab-layer prefab))
              (setq key
                (strcat layer "|" etapa "|" subetapa))
              (setq rows
                (urb:accumulate
                  rows key layer etapa subetapa 0.0 perimeter)))))
        (setq i (1+ i)))))
  (reverse rows)
)

(defun urb:set-cell (table row col value)
  (vla-SetText table row col value)
)

(defun urb:create-table (point rows / space table textheight rowheight
                         rowindex item description)
  (setq space (urb:space))
  (setq textheight (max 0.01 (getvar "TEXTSIZE")))
  (setq rowheight (* textheight 1.8))
  (setq table
    (vla-AddTable
      space
      (vlax-3d-point point)
      (+ 2 (length rows))
      7
      rowheight
      (* textheight 12.0)))
  (vla-MergeCells table 0 0 0 6)
  (urb:set-cell table 0 0 "CUADRO DE CANTIDADES URBANISMO")
  (urb:set-cell table 1 0 "ELEMENTO")
  (urb:set-cell table 1 1 "MATERIAL")
  (urb:set-cell table 1 2 "ETAPA")
  (urb:set-cell table 1 3 "SUBETAPA")
  (urb:set-cell table 1 4 "UNIDADES")
  (urb:set-cell table 1 5 "AREA")
  (urb:set-cell table 1 6 "PERIM./LONG.")
  (setq rowindex 2)
  (foreach item rows
    (setq description (urb:layer-description (nth 4 item)))
    (urb:set-cell table rowindex 0 (nth 0 description))
    (urb:set-cell table rowindex 1 (nth 1 description))
    (urb:set-cell table rowindex 2 (nth 5 item))
    (urb:set-cell table rowindex 3 (nth 6 item))
    (urb:set-cell table rowindex 4 (itoa (nth 1 item)))
    (urb:set-cell table rowindex 5 (rtos (nth 2 item) 2 2))
    (urb:set-cell table rowindex 6 (rtos (nth 3 item) 2 2))
    (setq rowindex (1+ rowindex))
  )
  table
)

;; Estructura de pavimento de andenes, senderos peatonales y plazoletas
;; segun estudio de suelos AUS-10786-10. Capas de arriba hacia abajo,
;; espesores en metros; el geotextil tejido tipo 2100 se cuantifica en
;; m2 con traslapo. La excavacion NO se incluye como una capa fija:
;; cuando existe topografia ya forma parte del corte/relleno hasta subrasante.
;; Si no existe topografia se reporta como pendiente, evitando duplicar 0.60 m.
(setq *urb-anden-structure*
  '(("Adoquin o loseta prefabricada" "Tratamiento" "0.06" "0")
    ("Arena de nivelacion" "Volumen" "0.04" "0")
    ("Suministro e instalacion de subbase granular SBG-C" "Volumen" "0.50" "0")
    ("Suministro y colocacion de geotextil Tejido 2100" "Geotextil" "0" "15")
    ("Suministro e instalacion de Geomembrana (Incluye excavacion)" "Geomalla" "0" "0")))

(defun urb:anden-structure-rows
  (area / result layer layer-type thickness overlap quantity unit thick-label)
  ;; La capa de acabado se informa por formato y tipo en
  ;; urb:anden-finish-rows; aqui quedan solamente las capas inferiores.
  (foreach layer (cdr *urb-anden-structure*)
    (setq layer-type (nth 1 layer))
    (setq thickness (atof (nth 2 layer)))
    (setq overlap (atof (nth 3 layer)))
    (if (urb:string-equal-p layer-type "Volumen")
      (setq quantity (* area thickness)
            unit "M3"
            thick-label (strcat (rtos (* 100.0 thickness) 2 0) " cm"))
      (setq quantity (* area (+ 1.0 (/ overlap 100.0)))
            unit "M2"
            thick-label
              (if (> thickness 0.0)
                (strcat (rtos (* 100.0 thickness) 2 0) " cm")
                "-")))
    (setq result
      (append result
        (list (list (nth 0 layer) thick-label quantity unit)))))
  result
)

(defun urb:finish-total-add (totals key value / pair)
  (setq pair (assoc key totals))
  (if pair
    (subst (cons key (+ (cdr pair) value)) pair totals)
    (cons (cons key value) totals))
)

(defun urb:anden-finish-rows
  (/ ss index data material format totals key result pair label unit)
  (setq ss (ssget "_X" '((-3 ("URB_ANDEN_BLOCK")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq data
          (urb:get-xdata-strings (ssname ss index) "URB_ANDEN_BLOCK"))
        (setq material (strcase (urb:safe-string (nth 1 data) "")))
        (if (= material "LOSETA")
          (progn
            (setq format
              (if (> (length data) 9) (nth 9 data) "20 x 20 cm"))
            (setq totals
              (urb:finish-total-add totals (strcat "LISA|" format)
                (atof (urb:safe-string
                  (if (> (length data) 14) (nth 14 data) "0") "0"))))
            (setq totals
              (urb:finish-total-add totals (strcat "GUIA|" format)
                (atof (urb:safe-string
                  (if (> (length data) 15) (nth 15 data) "0") "0"))))
            (setq totals
              (urb:finish-total-add totals (strcat "TOPEROL|" format)
                (atof (urb:safe-string
                  (if (> (length data) 16) (nth 16 data) "0") "0"))))
            (setq totals
              (urb:finish-total-add totals "ADOQUIN|20 x 10 cm"
                (atof (urb:safe-string
                  (if (> (length data) 18) (nth 18 data) "0") "0"))))))
        (setq index (1+ index)))))
  (foreach pair (reverse totals)
    (cond
      ((urb:starts-with (car pair) "LISA|")
        (setq label (strcat "Loseta lisa " (substr (car pair) 6)) unit "UND"))
      ((urb:starts-with (car pair) "GUIA|")
        (setq label (strcat "Loseta guia " (substr (car pair) 6)) unit "ML"))
      ((urb:starts-with (car pair) "TOPEROL|")
        (setq label (strcat "Loseta toperol " (substr (car pair) 9)) unit "ML"))
      (T
        (setq label "Adoquin blanco 20 x 10 cm" unit "UND")))
    (if (> (cdr pair) 1e-9)
      (setq result
        (append result (list (list label "-" (cdr pair) unit))))))
  result
)

(defun urb:create-anden-structure-table
  (point area / rows mov extra space table textheight rowheight rowindex item)
  (setq rows
    (append (urb:anden-finish-rows) (urb:anden-structure-rows area)))
  (setq mov (urb:anden-earthworks-totals))
  (setq extra (if (> (nth 2 mov) 0) 2 0))
  (setq space (urb:space))
  (setq textheight (max 0.01 (getvar "TEXTSIZE")))
  (setq rowheight (* textheight 1.8))
  (setq table
    (vla-AddTable
      space
      (vlax-3d-point point)
      (+ 2 (length rows) extra)
      4
      rowheight
      (* textheight 10.0)))
  (vla-MergeCells table 0 0 0 3)
  (urb:set-cell table 0 0 "ESTRUCTURA ANDENES, SENDEROS Y PLAZOLETAS")
  (urb:set-cell table 1 0 "CAPA")
  (urb:set-cell table 1 1 "ESPESOR")
  (urb:set-cell table 1 2 "CANTIDAD")
  (urb:set-cell table 1 3 "UND")
  (setq rowindex 2)
  (foreach item rows
    (urb:set-cell table rowindex 0 (nth 0 item))
    (urb:set-cell table rowindex 1 (nth 1 item))
    (urb:set-cell table rowindex 2 (rtos (nth 2 item) 2 2))
    (urb:set-cell table rowindex 3 (nth 3 item))
    (setq rowindex (1+ rowindex)))
  (if (> extra 0)
    (progn
      (urb:set-cell table rowindex 0
        (strcat "Corte con topografia (" (itoa (nth 2 mov)) " anden(es))"))
      (urb:set-cell table rowindex 1 "-")
      (urb:set-cell table rowindex 2 (rtos (nth 0 mov) 2 2))
      (urb:set-cell table rowindex 3 "M3")
      (setq rowindex (1+ rowindex))
      (urb:set-cell table rowindex 0 "Relleno con topografia")
      (urb:set-cell table rowindex 1 "-")
      (urb:set-cell table rowindex 2 (rtos (nth 1 mov) 2 2))
      (urb:set-cell table rowindex 3 "M3")))
  table
)

;; Comando 4.1.0: genera el cuadro de cantidades de andenes y prefabricados.
;; Reconecta urb:collect-quantities y urb:create-table, que quedaron sin
;; comando al retirar el antiguo URBCANT. Si hay andenes, agrega debajo
;; la tabla de la estructura de pavimento peatonal.
(defun urb:insert-quantities-table-command
  (/ rows point item anden-area textheight offset)
  (if (urb:confirm-meter-units)
    (progn
      (setq rows (urb:collect-quantities))
      (if rows
        (progn
          (setq point
            (getpoint "\nPunto de insercion del cuadro de cantidades: "))
          (if point
            (progn
              (urb:create-table point rows)
              (setq anden-area 0.0)
              (foreach item rows
                (if (urb:starts-with (nth 4 item) "URB-Q-ANDEN-")
                  (setq anden-area (+ anden-area (nth 2 item)))))
              (if (> anden-area 1e-6)
                (progn
                  (setq textheight (max 0.01 (getvar "TEXTSIZE")))
                  (setq offset (* textheight 1.8 (+ 4 (length rows))))
                  (urb:create-anden-structure-table
                    (list (car point) (- (cadr point) offset) 0.0)
                    anden-area)
                  (prompt
                    (strcat
                      "\nEstructura de anden calculada sobre "
                      (rtos anden-area 2 2) " m2."))))
              (vla-Regen (urb:doc) 1)
              (prompt
                (strcat
                  "\nCuadro de cantidades creado con "
                  (itoa (length rows)) " fila(s).")))
            (prompt "\nComando cancelado.")))
        (prompt
          "\nNo se encontraron andenes ni prefabricados cuantificables.")))
    (prompt "\nCANTIDADES cancelado: confirme primero las unidades del dibujo."))
  (princ)
)

(setq *urb-pattern-install-result*
  (vl-catch-all-apply 'urb:install-patterns nil))
(if (and
      (not (vl-catch-all-error-p *urb-pattern-install-result*))
      *urb-pattern-install-result*)
  (prompt
    (strcat
      "\nUrbanismo Cantidades " *urb-version*
      " cargado."))
  (prompt
    "\nUrbanismo cargado, pero no fue posible instalar los patrones temporales."))
(prompt
  "\nComandos principales: URBANISMO y EDITAR.")
(princ)

;;; ============================================================
;;; MODULO INTEGRADO MAIPORE REDES V13
;;; ============================================================
;;; MAIPORE_BLOQUES_REDES_ELECT_LISTAS_V13_OPTIMIZADO.lsp
;;; Urbanismo Interno Maipore - Captura y exportacion de cantidades PPTO
;;;
;;; Mejoras V13:
;;; - Codigo consolidado: una sola definicion por funcion y comando.
;;; - Reutilizacion de definiciones para reducir el crecimiento del DWG.
;;; - Cancelacion segura, longitud geometrica protegida y CSV con conteo.
;;; - Edicion unificada con el comando EDITAR.
;;; - Migracion de atributos existentes mediante las rutinas internas.
;;; - Pendiente hidrosanitaria visible y actualizada por EDITAR.
;;;
;;; Flujo: cargue el LSP, ejecute MAIPORE_BLOQUES_REDES_ELECT,
;;; inserte cantidades, edite con EDITAR y exporte desde URBANISMO.


(vl-load-com)

;; Desactiva comandos de edicion de versiones anteriores al recargar.
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDITAR_PPTO))
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDIT_CANTIDAD))
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDITAR_CANTIDAD))
(setq c:EDITAR_PPTO nil)
(setq c:EDIT_CANTIDAD nil)
(setq c:EDITAR_CANTIDAD nil)

(setq *mp-vis-width* 2.00) ; ancho visual del tramo
(setq *mp-vis-radius* 1.50) ; radio de circulos de inicio/fin
(setq *mp-vis-text-height* 1.50) ; altura de datos de elementos puntuales
(setq *mp-vis-tramo-text-height* 1.50) ; altura de etiqueta y pendiente del tramo

;; Separador del CSV: ";" abre en columnas en Excel con configuracion
;; regional de Colombia/Espana. Cambie a "," si su sistema usa la coma.
(setq *mp-csv-sep* ";")

;; Marcas de sesion: fuerzan a reescribir los DCL temporales tras recargar.
(setq *mp-dcl-listas-ok* nil)
(setq *mp-dcl-puntos-ok* nil)
(setq *mp-dcl-editar-ok* nil)

(setq *mp-blocks*
  '("TRAMO_E_MT" "TRAMO_E_BT_AP" "CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"
    "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "LUMINARIA_AP" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E"
    "TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO" "POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"
    "ACCESORIO_ACUEDUCTO"))


(setq *mp-red-list* '("Aresidual" "Alluvias" "Acueducto"))
(setq *mp-extremo-hidro-list*
  '("NINGUNO" "POZO" "SUMIDERO" "ACCESORIO_ACUEDUCTO"))
(setq *mp-extremo-elec-list*
  '("NINGUNO" "CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"
    "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "TRANSFORMADOR_AP"
    "PUNTO_CONEXION_E"))
(setq *mp-diam-alc-list* '("6" "8" "10" "12" "14" "15" "16" "18" "20" "24" "27" "30" "33" "36" "48" "51" "54" "64"))
(setq *mp-diam-acu-list* '("4" "6" "8" "10" "12" "18" "24"))
(setq *mp-material-acu-list* '("PVC" "WSP" "CCP" "PE" "ACERO" "HDPE" "OTRO"))
(setq *mp-material-red-list* '("PVC" "HDPE" "GRP" "CONCRETO" "ACERO" "OTRO"))
(setq *mp-acc-acu-list*
  '("TAPON" "TEE" "VALVULA_RED_MENOR" "VALVULA_VENTOSA" "VALVULA_PURGA" "REDUCCION"
    "CODO_90" "CODO_45" "CODO_22_5" "CODO_11_5" "VALVULA_REDUCTORA_PRESION"
    "VALVULA_CIERRE_PERMANENTE" "VALVULA_PIE_HIDRANTE" "HIDRANTE_TORRE" "NIPLE_PASAMUROS" "JUNTA_CONSTRUCCION" "OTRO"))
(setq *mp-cond-mt-list*
  '("3x70mm2 Al XLPE 15kV" "3x120mm2 Al XLPE 15kV" "3x150mm2 Cu XLPE 15kV"
    "3x185mm2 Al XLPE 15kV" "2(3x185mm2) Al XLPE 15kV" "3(3x185mm2) Al XLPE 15kV"
    "5(3x185mm2) Al XLPE 15kV" "3x240mm2 Al XLPE 15kV" "3x300mm2 Al XLPE 15kV"
    "2(3x300mm2) Al XLPE 15kV" "3x500mm2 Al XLPE 35kV" "3x2/0 ACSR" "3x4/0 ACSR" "OTRO"))
(setq *mp-ductos-list* '("1" "2" "3" "4" "5" "6" "9" "12"))
(setq *mp-diam-ducto-list* '("2\"" "3\"" "4\"" "6\""))
(setq *mp-mat-ducto-list* '("PVC" "IMC" "RMC" "EMT" "OTRO"))
(setq *mp-cond-bt-list* '("3x4+4 THW" "3x6+6 THW" "3x8+8 THW" "2x4 THW" "2x6 THW" "1x4 THW" "1x6 THW" "OTRO"))
(setq *mp-elem-elec-list* '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "LUMINARIA_AP" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E"))
(setq *mp-lum-list* '("RALED II" "AREALED II" "OTRA"))
(setq *mp-led-list* '("32 LED" "48 LED" "64 LED" "160 LED" "OTRO"))

(defun mp:layer (name color / doc layers lay)
  ;; Crea la capa o reactiva una existente para evitar bloques invisibles.
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))
  (setq lay
    (if (tblsearch "LAYER" name)
      (vla-Item layers name)
      (vla-Add layers name)))
  (vla-put-LayerOn lay :vlax-true)
  (vla-put-Lock lay :vlax-false)
  (vl-catch-all-apply 'vla-put-Freeze (list lay :vlax-false))
  (vla-put-Color lay color)
  lay)

(defun mp:store-cant-data (ename alist / serialized)
  (if (and ename alist)
    (progn
      (setq serialized (urb:serialize-lisp alist))
      (urb:set-xdata-strings ename "MP_CANT_DATA"
        (urb:string-chunks serialized 240)))))

(defun mp:read-cant-data (ename / chunks value)
  (setq chunks (urb:get-xdata-strings ename "MP_CANT_DATA"))
  (if chunks
    (progn
      (setq value (urb:read-lisp-safe (apply 'strcat chunks)))
      (if (listp value) value nil))))

(defun mp:setatts (ename alist / obj a tag pair changed)
  ;; Guarda y actualiza cada atributo; devuelve cuantos fueron modificados.
  (setq obj (vlax-ename->vla-object ename) changed 0)
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (foreach a (vlax-invoke obj 'GetAttributes)
      (setq tag (strcase (vla-get-TagString a)))
      (if (setq pair (assoc tag alist))
        (progn
          (vla-put-TextString a (mp:safe-str (cdr pair)))
          (vla-Update a)
          (setq changed (1+ changed))))))
  (vla-Update obj)
  ;; La copia completa en XDATA permite mostrar en Propiedades solo los
  ;; campos utiles sin perder controles internos, exportacion ni edicion.
  (mp:store-cant-data ename alist)
  changed)

(defun mp:getval (tag vals def / a)
  (setq a (assoc tag vals))
  (if (and a (/= (cdr a) "")) (cdr a) def))

(defun mp:safe-str (x) (if (null x) "" (vl-princ-to-string x)))

;; 2026-08-12: tiles etapa/subetapa OCULTOS en los dialogos de CREACION
;; cuando las etapas estan deshabilitadas. Los DCL de creacion emiten
;; esta cadena (vacia si estan deshabilitadas); los de EDICION mantienen
;; los tiles (grises). *mp-dialog-edit-mode* lo fijan los write-dcl.
(setq *mp-dialog-edit-mode* nil)
(defun mp:dcl-etapa-str ()
  (if (urb:etapas-enabled-p)
    ": popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; }"
    ""))

(defun mp:reset-dialog-capture ()
  (setq *mp-dialog-values* nil)
  (setq *mp-dialog-values-active* nil))

(defun mp:capture-dialog-values (/ keys key value result)
  ;; DCL deja de exponer get_tile despues de done_dialog. Capture antes de cerrar.
  (setq keys
    '("red" "blk" "tipo" "acc" "etapa" "subetapa" "tipo_ini" "tipo_fin"
      "pini" "pfin" "diam" "diamsal" "mat" "long" "pend"
      "ctni" "ctnf" "ccini" "ccfin" "ctn" "cclave" "cc_dig" "cc_sel"
      "serie" "circuito" "desde" "hasta" "cond" "ductos"
      "diamducto" "matducto" "libres" "prof" "id" "lote"
      "anchoz" "cama" "repos"
      "cd" "pf" "lum" "led" "altura" "brazo" "avance"))
  (setq result nil)
  (foreach key keys
    (setq value (vl-catch-all-apply 'get_tile (list key)))
    (if (not (vl-catch-all-error-p value))
      (setq result (cons (cons key (if value value "")) result))))
  (setq *mp-dialog-values* result)
  (setq *mp-dialog-values-active* T)
  T)

(defun mp:gettile (key / pair v)
  (if (and *mp-dialog-values-active*
           (setq pair (assoc key *mp-dialog-values*)))
    (cdr pair)
    (progn
      ;; vl-catch-all: un tile oculto (etapa/subetapa deshabilitadas) no
      ;; queda en la captura y get_tile puede tronar tras done_dialog
      (setq v (vl-catch-all-apply 'get_tile (list key)))
      (if (or (null v) (vl-catch-all-error-p v)) "" v))))

(defun mp:update-red-diam ()
  (if (= (mp:gettile "red") "2")
    (progn (mp:fill-popup "diam" *mp-diam-acu-list* 0) (mp:fill-popup "mat" *mp-material-acu-list* 0))
    (progn (mp:fill-popup "diam" *mp-diam-alc-list* 5) (mp:fill-popup "mat" *mp-material-red-list* 0))))

(defun mp:csv-safe (s / out i ch) (if (not s) (setq s "")) (setq out "" i 1) (while (<= i (strlen s)) (setq ch (substr s i 1)) (if (= ch "\"") (setq out (strcat out "\"\"")) (setq out (strcat out ch))) (setq i (1+ i))) (strcat "\"" out "\""))
(defun mp:att-alist (ename / obj atts res a stored pair)
  (setq obj (vlax-ename->vla-object ename) res nil)
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (foreach a (vlax-invoke obj 'GetAttributes)
      (setq res
        (cons
          (cons (strcase (vla-get-TagString a)) (vla-get-TextString a))
          res))))
  (setq stored (mp:read-cant-data ename))
  (foreach pair stored
    (if (not (assoc (strcase (car pair)) res))
      (setq res (cons (cons (strcase (car pair)) (cdr pair)) res))))
  res)

(setq *mp-cant-counter* 0)

(defun mp:starts-with (s pref / n)
  (setq s (strcase (mp:safe-str s)) pref (strcase pref) n (strlen pref))
  (and (>= (strlen s) n) (= (substr s 1 n) pref)))

(defun mp:3d (p)
  (vlax-3d-point (list (float (car p)) (float (cadr p)) (if (caddr p) (float (caddr p)) 0.0))))

(defun mp:var-dbls (lst)
  (vlax-make-variant
    (vlax-safearray-fill
      (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length lst))))
      (mapcar 'float lst))))

(defun mp:vla-add-att (blk tag prompt def pt h invisible lay col / att mode)
  ;; Modo 1 = invisible, 0 = normal. Son atributos editables con EATTEDIT.
  (setq mode (if invisible 1 0))
  (setq att (vla-AddAttribute blk (float h) mode prompt (mp:3d pt) tag (mp:safe-str def)))
  (vla-put-Layer att lay)
  (vla-put-Color att col)
  att)

(defun mp:center-visible-att (att pt height)
  ;; 10 = acAlignmentMiddleCenter.
  (vl-catch-all-apply 'vla-put-Height (list att (float height)))
  (vl-catch-all-apply 'vla-put-Alignment (list att 10))
  (vl-catch-all-apply 'vla-put-TextAlignmentPoint (list att (mp:3d pt)))
  att)

(defun mp:make-cant-tramo-block (blkname baseb dist vals / doc blks blk lay col w r th lab mid y pl ln c1 c2 cut a)
  ;; V9: crea la definicion de bloque con ActiveX, no con INSERT de DWG externo.
  ;; Esto evita el error: Can't find file "CANT_TRAMO_....dwg".
  (vl-load-com)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq lay (mp:vis-layer baseb)
        col (mp:vis-color baseb)
        w   *mp-vis-width*
        r   *mp-vis-radius*
        th  *mp-vis-tramo-text-height*)
  (if (< w 0.01) (setq w 0.01))
  (if (< r 2.00) (setq r 2.00))
  (if (< th 0.10) (setq th 0.10))
  (setq lab (mp:label-tramo baseb vals))
  (setq blk (vla-Add blks (mp:3d '(0 0 0)) blkname))

  ;; La geometria conserva la longitud centro a centro, pero la franja
  ;; visible termina en el borde de los circulos de inicio y fin.
  (setq cut (min r (/ dist 4.0)))
  (setq pl
    (vla-AddLightWeightPolyline
      blk
      (mp:var-dbls
        (if (mp:hydro-tramo-p baseb)
          (list 0.0 0.0 dist 0.0)
          (list cut 0.0 (- dist cut) 0.0)))))
  (vla-put-Layer pl lay)
  (vla-put-Color pl col)
  (vla-put-ConstantWidth pl (float w))

  ;; En redes hidrosanitarias los pozos/accesorios son bloques puntuales
  ;; independientes y compartibles. Dibujar ademas circulos dentro de
  ;; CADA tramo producia dos o tres anillos superpuestos en una union.
  (if (not (mp:hydro-tramo-p baseb))
    (progn
      (setq c1 (vla-AddCircle blk (mp:3d '(0 0 0)) (float r)))
      (vla-put-Layer c1 lay)
      (vla-put-Color c1 col)
      (setq c2 (vla-AddCircle blk (mp:3d (list dist 0.0 0.0)) (float r)))
      (vla-put-Layer c2 lay)
      (vla-put-Color c2 col)))

  ;; Etiqueta y pendiente centradas respecto al punto medio del tramo.
  (setq mid (list (/ dist 2.0) (* th 1.35) 0.0))
  (mp:center-visible-att
    (mp:vla-add-att blk "ETIQUETA" "Etiqueta visible" lab mid th nil lay col)
    mid
    th)
  (if (member baseb '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO"))
    (progn
      (setq mid (list (/ dist 2.0) (- (* th 1.35)) 0.0))
      (mp:center-visible-att
        (mp:vla-add-att
          blk
          "PENDIENTE_VIS"
          "Pendiente visible"
          (mp:pendiente-label vals)
          mid
          th
          nil
          lay
          col)
        mid
        th)))

  ;; Atributos invisibles de datos.
  (setq y (- (* th 1.25)))
  (foreach a (mp:base-atts-for baseb)
    (mp:vla-add-att blk (car a) (cadr a) (if (caddr a) (caddr a) "") (list 0 y 0.0) 0.10 T lay col)
    (setq y (- y 0.20)))
  blkname)

(defun mp:ins-block-scaled (bname p1 p2 vals)
  (mp:insert-cant-tramo bname p1 p2 vals))

;; Ahora reconoce los bloques CANT_TRAMO_* como bloques de cantidad.
(defun mp:is-mp-block (en / obj b)
  (if (and en (= (cdr (assoc 0 (entget en))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq b (vla-get-EffectiveName obj))
      (mp:is-cant-blockname b))))

(defun mp:setatt-one (ename tag val / obj a vals)
  (setq vals (mp:att-alist ename))
  (setq obj (vlax-ename->vla-object ename))
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (foreach a (vlax-invoke obj 'GetAttributes)
      (if (= (strcase (vla-get-TagString a)) (strcase tag))
        (progn
          (vla-put-TextString a (mp:safe-str val))
          (vla-Update a)))))
  (vla-Update obj)
  (mp:store-cant-data ename (mp:alist-set vals (strcase tag) (mp:safe-str val))))


;; Unificado 4.1.0: una sola lista de etapas para todo el archivo.
(setq *mp-etapa-list* *urb-etapa-list*)
(setq *mp-csv-tags*
  '("BLOQUE" "HANDLE" "LAYER" "X" "Y" "ID" "CODIGO" "ETAPA" "SUBETAPA" "RED" "TIPO_RED"
    "POZO_INI" "POZO_FIN" "COTA_TN_INI" "COTA_TN_FIN" "COTA_CLAVE_INI" "COTA_CLAVE_FIN"
    "DIAMETRO" "DIAMETRO_SALIDA" "MATERIAL" "LONGITUD" "PENDIENTE" "SERIE" "CIRCUITO" "CIRCUITO_AP"
    "DESDE" "HASTA" "CONDUCTORES" "CONDUCTOR" "CALIBRE" "MATERIAL_COND" "DUCTOS" "DIAM_DUCTO"
    "MATERIAL_DUCTO" "LIBRES" "PROFUNDIDAD" "TIPO_CAJA" "TIPO_LUMINARIA" "FUENTE_LED"
    "ALTURA_M" "BRAZO_M" "AVANCE_M" "TIPO_SE" "LOTE" "CD" "PF" "ENTRADAS" "SALIDAS" "CELDAS"
    "TIPO_ACCESORIO" "TIPO_EXTREMO_INI" "TIPO_EXTREMO_FIN"
    "HANDLE_EXTREMO_INI" "HANDLE_EXTREMO_FIN" "LONGITUD_2D" "LONGITUD_3D"
    "MODO_LONGITUD" "PENDIENTE_CALCULADA" "PROFUNDIDAD_INI"
    "PROFUNDIDAD_FIN" "PROFUNDIDAD_MEDIA" "ANCHO_ZANJA" "ESPESOR_CAMA"
    "ANCHO_REPOSICION" "EXCAVACION_M3" "CAMA_M3" "VOLUMEN_ELEMENTO_M3"
    "RELLENO_M3" "SOBRANTE_M3" "REPOSICION_M2" "METODO_CANTIDADES"
    "SUPERFICIE_TN" "ESTADO_COTA_TN" "ORIGEN_CREACION"
    "CONTROL_ESTADO" "CONTROL_MENSAJES"))

;; Unificado 4.1.0: delega en urb:subetapas-for para mantener una sola
;; matriz de etapas/subetapas en todo el archivo.
(defun mp:subetapas-for (e)
  (urb:subetapas-for e))

(defun mp:update-subetapa ()
  ;; sin etapas habilitadas el tile no existe en los dialogos de creacion
  (if (or (urb:etapas-enabled-p) *mp-dialog-edit-mode*)
    (mp:fill-popup "subetapa" (mp:subetapas-for (mp:item *mp-etapa-list* "etapa")) 0)))

(defun mp:ensure-layers ()
  ;; Capas nuevas de presupuesto: siempre con prefijo PPTO-
  (mp:layer "PPTO-ACUEDUCTO" 5)
  (mp:layer "PPTO-ALC-SANITARIO" 1)
  (mp:layer "PPTO-ALC-PLUVIAL" 3)
  (mp:layer "PPTO-ELECTRICA-MT" 6)
  (mp:layer "PPTO-ELECTRICA-BT-AP" 2)
  (mp:layer "PPTO-ACCESORIOS-ACUEDUCTO" 4)
  (mp:layer "PPTO-EQUIPOS-ELECTRICOS" 30)
  (mp:layer "PPTO-TEXTOS-CANTIDADES" 7)
  ;; Capas antiguas quedan solo por compatibilidad con bloques puntuales existentes.
  (mp:layer "RED-ELECTRICA-MT" 6)
  (mp:layer "RED-ELECTRICA-BT-AP" 2)
  (mp:layer "EQUIPOS-ELECTRICOS" 30)
  (mp:layer "REDES-ALCANTARILLADO" 1)
  (mp:layer "REDES-ACUEDUCTO" 5)
  (mp:layer "ACCESORIOS-ACUEDUCTO" 4)
  (mp:layer "TEXTOS-CANTIDADES" 7))

(defun mp:vis-layer (bname)
  (cond
    ((= bname "TRAMO_ACUEDUCTO") "PPTO-ACUEDUCTO")
    ((= bname "TRAMO_ALLUVIAS") "PPTO-ALC-PLUVIAL")
    ((= bname "TRAMO_ARESIDUAL") "PPTO-ALC-SANITARIO")
    ((= bname "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
    ((= bname "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
    (T "PPTO-TEXTOS-CANTIDADES")))

(defun mp:vis-color (bname)
  (cond
    ((= bname "TRAMO_ACUEDUCTO") 5) ; azul
    ((= bname "TRAMO_ALLUVIAS") 3) ; verde
    ((= bname "TRAMO_ARESIDUAL") 1) ; rojo
    ((= bname "TRAMO_E_MT") 6) ; magenta
    ((= bname "TRAMO_E_BT_AP") 2) ; amarillo
    (T 7)))

(defun mp:tramo-common-atts ()
  '(("HANDLE_EXTREMO_INI" "Handle extremo inicial" "")
    ("HANDLE_EXTREMO_FIN" "Handle extremo final" "")
    ("LONGITUD" "Longitud de presupuesto m" "")
    ("LONGITUD_2D" "Longitud en planta m" "")
    ("LONGITUD_3D" "Longitud espacial m" "")
    ("MODO_LONGITUD" "Modo de longitud" "PLANTA")
    ("ANCHO_ZANJA" "Ancho de zanja m" "")
    ("ESPESOR_CAMA" "Espesor de cama m" "0.10")
    ("ANCHO_REPOSICION" "Ancho de reposicion m" "")
    ("PROFUNDIDAD_INI" "Profundidad inicial m" "")
    ("PROFUNDIDAD_FIN" "Profundidad final m" "")
    ("PROFUNDIDAD_MEDIA" "Profundidad media m" "")
    ("PENDIENTE_CALCULADA" "Pendiente calculada %" "")
    ("EXCAVACION_M3" "Excavacion m3" "0")
    ("CAMA_M3" "Cama de apoyo m3" "0")
    ("VOLUMEN_ELEMENTO_M3" "Volumen desplazado m3" "0")
    ("RELLENO_M3" "Relleno m3" "0")
    ("SOBRANTE_M3" "Retiro sobrante m3" "0")
    ("REPOSICION_M2" "Reposicion superficial m2" "0")
    ("MEMORIAS" "Memorias - use QMEMORIATRAMO" "OCULTAS")
    ("METODO_CANTIDADES" "Metodo de cantidades" "PRELIMINAR_GEOMETRICO")
    ("CONTROL_ESTADO" "Estado de control" "PENDIENTE")
    ("CONTROL_MENSAJES" "Mensajes de control" "")))

(defun mp:tramo-public-property-p (tag)
  (member (strcase (mp:safe-str tag))
    '("ETAPA" "SUBETAPA" "RED" "TIPO_RED" "SERIE" "CIRCUITO"
      "CIRCUITO_AP" "DESDE" "HASTA" "POZO_INI" "POZO_FIN"
      "DIAMETRO" "MATERIAL" "PENDIENTE" "CONDUCTORES" "CONDUCTOR"
      "DUCTOS" "DIAM_DUCTO" "MATERIAL_DUCTO" "LIBRES" "PROFUNDIDAD"
      "COTA_TN_INI" "COTA_TN_FIN" "COTA_CLAVE_INI" "COTA_CLAVE_FIN"
      "LONGITUD" "ANCHO_ZANJA" "EXCAVACION_M3" "CAMA_M3"
      "VOLUMEN_ELEMENTO_M3" "RELLENO_M3" "SOBRANTE_M3"
      "REPOSICION_M2" "MEMORIAS")))

(defun mp:base-atts-for (bname / specific all)
  (setq specific
    (cond
      ((= bname "TRAMO_E_MT")
        '(("SERIE" "Serie" "1") ("ETAPA" "Etapa" "")
          ("SUBETAPA" "Subetapa" "") ("TIPO_RED" "Tipo red" "MT")
          ("CIRCUITO" "Circuito" "") ("DESDE" "Desde" "")
          ("HASTA" "Hasta" "")
          ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "")
          ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
          ("CONDUCTORES" "Conductores" "3x185mm2 Al XLPE 15kV")
          ("CONDUCTOR" "Conductor" "3x185mm2 Al XLPE 15kV")
          ("CALIBRE" "Calibre" "185mm2")
          ("MATERIAL_COND" "Material conductor" "Al XLPE")
          ("DUCTOS" "Ductos" "6") ("DIAM_DUCTO" "Diam ducto" "6\"")
          ("MATERIAL_DUCTO" "Material ducto" "PVC")
          ("LIBRES" "Ductos libres" "")
          ("PROFUNDIDAD" "Profundidad m" "")
          ("COTA_TN_INI" "Cota terreno ini" "")
          ("COTA_TN_FIN" "Cota terreno fin" "")))
      ((= bname "TRAMO_E_BT_AP")
        '(("SERIE" "Serie" "6") ("ETAPA" "Etapa" "")
          ("SUBETAPA" "Subetapa" "") ("TIPO_RED" "Tipo red" "BT")
          ("CIRCUITO_AP" "Circuito AP/BT" "")
          ("DESDE" "Desde" "") ("HASTA" "Hasta" "")
          ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "")
          ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
          ("CONDUCTOR" "Conductor" "3x4+4 THW")
          ("DUCTOS" "Ductos" "1") ("DIAM_DUCTO" "Diam ducto" "3\"")
          ("MATERIAL_DUCTO" "Material ducto" "PVC")
          ("LIBRES" "Ductos libres" "")
          ("PROFUNDIDAD" "Profundidad m" "")
          ("COTA_TN_INI" "Cota terreno ini" "")
          ("COTA_TN_FIN" "Cota terreno fin" "")))
      (T
        '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "")
          ("RED" "Red" "")
          ("POZO_INI" "Nodo/pozo inicial" "")
          ("POZO_FIN" "Nodo/pozo final" "")
          ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "")
          ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
          ("DIAMETRO" "Diametro" "") ("MATERIAL" "Material" "PVC")
          ("PENDIENTE" "Pendiente %" "")
          ("COTA_TN_INI" "Cota terreno ini" "")
          ("COTA_TN_FIN" "Cota terreno fin" "")
          ("COTA_CLAVE_INI" "Cota clave ini" "")
          ("COTA_CLAVE_FIN" "Cota clave fin" "")))))
  (setq all
    (append
      specific
      '(("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE"))
      (mp:tramo-common-atts)))
  (vl-remove-if-not
    '(lambda (item) (mp:tramo-public-property-p (car item))) all))

(defun mp:write-dcl (/ fn f)
  (mp:reset-dialog-capture)
  (setq *mp-dialog-edit-mode* nil)
  (setq fn (urb:temp-file "maipore_listas_v10" ".dcl"))
  (if (and *mp-dcl-listas-ok* (findfile fn))
    fn
    (progn
  (setq f (open fn "w"))
  (write-line "maipore_tramo_red : dialog { label = \"Maipore - Tramo red PPTO\";" f)
  (write-line ": boxed_column { label = \"Datos de presupuesto\";" f)
  (write-line ": popup_list { label = \"Red\"; key = \"red\"; }" f)
  (write-line (mp:dcl-etapa-str) f)
  (write-line ": popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Diametro\"; key = \"diam\"; }" f)
  (write-line ": popup_list { label = \"Material\"; key = \"mat\"; } }" f)
  (write-line ": boxed_column { label = \"Cotas de diseno\";" f)
  (write-line ": radio_row { label = \"Cota clave\";" f)
  (write-line ": radio_button { label = \"Digitar\"; key = \"cc_dig\"; value = \"1\"; }" f)
  (write-line ": radio_button { label = \"Seleccionar en dibujo\"; key = \"cc_sel\"; } }" f)
  (write-line ": edit_box { label = \"Cota clave inicial\"; key = \"ccini\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Cota clave final\"; key = \"ccfin\"; edit_width = 12; } }" f)
  (write-line ": text { label = \"Las cotas TN se toman de SUP_TN al marcar los extremos.\"; } ok_cancel; }" f)

  (write-line "maipore_tramo_mt : dialog { label = \"Maipore - Tramo MT PPTO\"; : boxed_column {" f)
  (write-line ": edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; }" f)
  (write-line (mp:dcl-etapa-str) f)
  (write-line ": edit_box { label = \"Circuito\"; key = \"circuito\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; }" f)
  (write-line ": edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad de zanja m\"; key = \"prof\"; edit_width = 12; } : text { label = \"Cotas TN: automaticas desde SUP_TN al marcar los extremos.\"; } : text { label = \"Cantidades de construccion: pendientes de parametros.\"; } } ok_cancel; }" f)

  (write-line "maipore_tramo_bt : dialog { label = \"Maipore - Tramo BT/AP PPTO\"; : boxed_column {" f)
  (write-line ": edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; }" f)
  (write-line (mp:dcl-etapa-str) f)
  (write-line ": edit_box { label = \"Circuito AP/BT\"; key = \"circuito\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } : edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad de zanja m\"; key = \"prof\"; edit_width = 12; } : text { label = \"Cotas TN: automaticas desde SUP_TN al marcar los extremos.\"; } : text { label = \"Cantidades de construccion: pendientes de parametros.\"; } } ok_cancel; }" f)

  ;; Se mantienen los formularios de puntos/accesorios para compatibilidad con los comandos existentes.
  (write-line (strcat "maipore_elem_elec : dialog { label = \"Maipore - Elemento electrico\"; : boxed_column { : popup_list { label = \"Tipo elemento\"; key = \"blk\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 26; } : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } " (mp:dcl-etapa-str) " : edit_box { label = \"Lote / circuito\"; key = \"lote\"; edit_width = 26; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 20; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 20; } : popup_list { label = \"Luminaria\"; key = \"lum\"; } : popup_list { label = \"Fuente LED\"; key = \"led\"; } : edit_box { label = \"Altura montaje m\"; key = \"altura\"; edit_width = 12; } : edit_box { label = \"Brazo m\"; key = \"brazo\"; edit_width = 12; } : edit_box { label = \"Avance m\"; key = \"avance\"; edit_width = 12; } } ok_cancel; }") f)
  (write-line (strcat "maipore_acc_acu : dialog { label = \"Maipore - Accesorio acueducto\"; : boxed_column { : popup_list { label = \"Tipo accesorio\"; key = \"acc\"; } " (mp:dcl-etapa-str) " : popup_list { label = \"Diametro principal\"; key = \"diam\"; } : popup_list { label = \"Diametro salida\"; key = \"diamsal\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Lote/Sector\"; key = \"lote\"; edit_width = 26; } } ok_cancel; }") f)
  (close f)
  (setq *mp-dcl-listas-ok* T)
  fn)))

(defun mp:dialog-tramo-red (forced-red / dcl ok res etapa red-index modo-clave)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_red" dcl)) (exit))
  (setq red-index
    (if forced-red (mp:idx forced-red *mp-red-list*) 0))
  (mp:fill-popup "red" *mp-red-list* red-index)
  (if forced-red (mode_tile "red" 1))
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:update-red-diam)
  (mp:fill-popup "tipo_ini" *mp-extremo-hidro-list*
    (if (= forced-red "Acueducto") 3 1))
  (mp:fill-popup "tipo_fin" *mp-extremo-hidro-list*
    (if (= forced-red "Acueducto") 3 1))
  ;; Cota clave: "Digitar" (por defecto, radio_button value="1" en el DCL)
  ;; deja los 2 edit_box habilitados; "Seleccionar en dibujo" los apaga en
  ;; vivo -- se leen despues de cerrar el dialogo, con un clic sobre la
  ;; etiqueta real (mp:prompt-clave-from-label), asi que digitar algo ahi
  ;; no serviria de nada.
  (set_tile "cc_dig" "1")
  (action_tile "cc_dig" "(mode_tile \"ccini\" 0)(mode_tile \"ccfin\" 0)")
  (action_tile "cc_sel" "(mode_tile \"ccini\" 1)(mode_tile \"ccfin\" 1)")
  (action_tile "red" "(mp:update-red-diam)")
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq modo-clave
        (if (= (mp:safe-str (mp:gettile "cc_sel")) "1") "Seleccionar" "Digitar"))
      (setq res
        (list
          (cons "REDOPT" (mp:item *mp-red-list* "red"))
          (cons "ETAPA" etapa)
          (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
          (cons "POZO_INI" "")
          (cons "POZO_FIN" "")
          (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-hidro-list* "tipo_ini"))
          (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-hidro-list* "tipo_fin"))
          (cons "DIAMETRO" (if (= (mp:gettile "red") "2") (mp:item *mp-diam-acu-list* "diam") (mp:item *mp-diam-alc-list* "diam")))
          (cons "MATERIAL" (if (= (mp:gettile "red") "2") (mp:item *mp-material-acu-list* "mat") (mp:item *mp-material-red-list* "mat")))
          ;; Sin campo en el dialogo (se saco a pedido del usuario): siempre
          ;; en blanco, asi mp:derive-tramo-values la calcula sola de las
          ;; cotas clave (mismo camino que si el usuario la dejaba vacia).
          (cons "PENDIENTE" "")
          (cons "COTA_TN_INI" "")
          (cons "COTA_TN_FIN" "")
          (cons "COTA_CLAVE_INI" (mp:gettile "ccini"))
          (cons "COTA_CLAVE_FIN" (mp:gettile "ccfin"))
          (cons "MODO_CLAVE" modo-clave)))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-tramo-mt (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_mt" dcl)) (exit))
  (set_tile "serie" "1")
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:fill-popup "cond" *mp-cond-mt-list* 3)
  (mp:fill-popup "ductos" *mp-ductos-list* 5)
  (mp:fill-popup "diamducto" *mp-diam-ducto-list* 3)
  (mp:fill-popup "matducto" *mp-mat-ducto-list* 0)
  (mp:fill-popup "tipo_ini" *mp-extremo-elec-list* 1)
  (mp:fill-popup "tipo_fin" *mp-extremo-elec-list* 1)
  (set_tile "libres" "0")
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "CIRCUITO" (mp:gettile "circuito")) (cons "DESDE" "") (cons "HASTA" "")
              (cons "CONDUCTORES" (mp:item *mp-cond-mt-list* "cond")) (cons "CONDUCTOR" (mp:item *mp-cond-mt-list* "cond"))
              (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos")) (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto"))
              (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto")) (cons "LIBRES" (mp:gettile "libres"))
              (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini"))
              (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-tramo-bt (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_bt" dcl)) (exit))
  (set_tile "serie" "6")
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:fill-popup "cond" *mp-cond-bt-list* 0)
  (mp:fill-popup "ductos" *mp-ductos-list* 0)
  (mp:fill-popup "diamducto" *mp-diam-ducto-list* 1)
  (mp:fill-popup "matducto" *mp-mat-ducto-list* 0)
  (mp:fill-popup "tipo_ini" *mp-extremo-elec-list* 1)
  (mp:fill-popup "tipo_fin" *mp-extremo-elec-list* 1)
  (set_tile "libres" "0")
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "CIRCUITO_AP" (mp:gettile "circuito")) (cons "DESDE" "") (cons "HASTA" "")
              (cons "CONDUCTOR" (mp:item *mp-cond-bt-list* "cond")) (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos"))
              (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto")) (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto"))
              (cons "LIBRES" (mp:gettile "libres"))
              (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini")) (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl)
  res)


(defun mp:point-layer (base)
  (cond
    ((= base "POZO_SANITARIO") "PPTO-ALC-SANITARIO")
    ((= base "POZO_PLUVIAL") "PPTO-ALC-PLUVIAL")
    ((= base "SUMIDERO") "PPTO-ALC-PLUVIAL")
    ((= base "ACCESORIO_ACUEDUCTO") "PPTO-ACCESORIOS-ACUEDUCTO")
    ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E")) "PPTO-EQUIPOS-ELECTRICOS")
    (T "PPTO-EQUIPOS-ELECTRICOS")))

(defun mp:point-color (base)
  (cond
    ((= base "POZO_SANITARIO") 1)
    ((= base "POZO_PLUVIAL") 3)
    ((= base "SUMIDERO") 3)
    ((= base "ACCESORIO_ACUEDUCTO") 5)
    ((= base "LUMINARIA_AP") 2)
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E")) 6)
    (T 7)))


(defun mp:base-atts-for-point (base)
  (cond
    ((member base '("POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"))
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("RED" "Red" "")
        ("ID" "ID / Codigo" "") ("DIAMETRO" "Diametro" "")
        ("COTA_TN_INI" "Cota terreno" "") ("COTA_CLAVE_INI" "Cota clave" "")
        ("PROFUNDIDAD" "Profundidad" "")
        ("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE")
        ("ORIGEN_CREACION" "Origen de creacion" "MANUAL")))
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_CAJA" "Tipo caja" "") ("DUCTOS" "Ductos" "") ("LIBRES" "Libres" "")
        ("PROFUNDIDAD" "Profundidad" "") ("CD" "CD" "") ("PF" "PF" "")
        ("COTA_TN_INI" "Cota terreno" "")
        ("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE")
        ("ORIGEN_CREACION" "Origen de creacion" "MANUAL")))
    ((= base "ACCESORIO_ACUEDUCTO")
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_ACCESORIO" "Tipo accesorio" "") ("DIAMETRO" "Diametro principal" "")
        ("DIAMETRO_SALIDA" "Diametro salida" "") ("MATERIAL" "Material" "") ("LOTE" "Lote/Sector" "")
        ("COTA_TN_INI" "Cota terreno" "")
        ("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE")
        ("ORIGEN_CREACION" "Origen de creacion" "MANUAL")))
    ((= base "LUMINARIA_AP")
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("CODIGO" "Codigo" "")
        ("TIPO_LUMINARIA" "Tipo luminaria" "") ("FUENTE_LED" "Fuente LED" "")
        ("ALTURA_M" "Altura montaje" "") ("BRAZO_M" "Brazo" "") ("AVANCE_M" "Avance" "") ("CIRCUITO_AP" "Circuito AP" "")
        ("COTA_TN_INI" "Cota terreno" "")
        ("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE")
        ("ORIGEN_CREACION" "Origen de creacion" "MANUAL")))
    (T
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_RED" "Tipo red" "") ("LOTE" "Lote/Sector" "") ("CD" "CD" "") ("PF" "PF" "")
        ("ENTRADAS" "Entradas" "") ("SALIDAS" "Salidas" "") ("CELDAS" "Celdas" "")
        ("COTA_TN_INI" "Cota terreno" "")
        ("SUPERFICIE_TN" "Superficie de terreno" "SUP_TN")
        ("ESTADO_COTA_TN" "Estado cota terreno" "PENDIENTE")
        ("ORIGEN_CREACION" "Origen de creacion" "MANUAL")))) )


(defun mp:make-cant-punto-block (blkname base vals / doc blks blk lay col th r lab pl c y att pos a)
  (vl-load-com)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq lay (mp:point-layer base) col (mp:point-color base) th *mp-vis-text-height* r *mp-vis-radius*)
  (if (< r 2.00) (setq r 2.00))
  (if (< th 0.50) (setq th 0.50))
  (setq lab (mp:label-point base vals))
  (setq blk (vla-Add blks (mp:3d '(0 0 0)) blkname))
  (cond
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "SUBESTACION_E" "CDMT_E"))
      (setq pl (vla-AddLightWeightPolyline blk (mp:var-dbls (list (- r) (- r) r (- r) r r (- r) r))))
      (vla-put-Closed pl :vlax-true) (vla-put-Layer pl lay) (vla-put-Color pl col) (vla-put-ConstantWidth pl (float (/ r 3.0))))
    ((= base "SUMIDERO")
      (setq pl (vla-AddLightWeightPolyline blk (mp:var-dbls (list (- r) 0.0 0.0 r r 0.0 0.0 (- r)))))
      (vla-put-Closed pl :vlax-true) (vla-put-Layer pl lay) (vla-put-Color pl col) (vla-put-ConstantWidth pl (float (/ r 3.0))))
    (T
      (setq c (vla-AddCircle blk (mp:3d '(0 0 0)) (float r)))
      (vla-put-Layer c lay) (vla-put-Color c col)))
  (if (member base '("POZO_SANITARIO" "POZO_PLUVIAL"))
    (progn
      (setq pos '(0.0 0.0 0.0))
      (setq att (mp:vla-add-att blk "ETIQUETA" "Numero de pozo" lab pos th nil lay col))
      (mp:center-visible-att att pos th))
    (mp:vla-add-att blk "ETIQUETA" "Etiqueta visible" lab (list (* r 1.5) (* r 1.5) 0.0) th nil lay col))
  (mp:vla-add-att blk "BLOQUE_BASE" "Bloque base" base (list 0 (- (* th 1.25)) 0.0) 0.10 T lay col)
  (setq y (- (* th 1.5)))
  (foreach a (mp:base-atts-for-point base)
    (mp:vla-add-att blk (car a) (cadr a) (if (caddr a) (caddr a) "") (list 0 y 0.0) 0.10 T lay col)
    (setq y (- y 0.20)))
  blkname)


(defun mp:write-dcl-puntos (/ fn f)
  (mp:reset-dialog-capture)
  (setq *mp-dialog-edit-mode* nil)
  (setq fn (urb:temp-file "maipore_puntos_v11" ".dcl"))
  (if (and *mp-dcl-puntos-ok* (findfile fn))
    fn
    (progn
  (setq f (open fn "w"))
  (write-line "maipore_punto_hidro : dialog { label = \"Maipore - Punto hidrosanitario\"; : boxed_column {" f)
  (write-line (mp:dcl-etapa-str) f)
  (write-line ": edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro\"; key = \"diam\"; }" f)
  (write-line ": edit_box { label = \"Cota terreno (automatica SUP_TN)\"; key = \"ctn\"; edit_width = 12; } : edit_box { label = \"Cota clave\"; key = \"cclave\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } } ok_cancel; }" f)
  (write-line "maipore_caja_elec : dialog { label = \"Maipore - Caja / camara electrica\"; : boxed_column {" f)
  (write-line ": popup_list { label = \"Tipo\"; key = \"tipo\"; }" f)
  (write-line (mp:dcl-etapa-str) f)
  (write-line ": edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : edit_box { label = \"Ductos\"; key = \"ductos\"; edit_width = 12; } : edit_box { label = \"Libres\"; key = \"libres\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 14; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 14; } } ok_cancel; }" f)
  (close f)
  (setq *mp-dcl-puntos-ok* T)
  fn)))

(defun mp:dialog-punto-hidro (red tipo / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-puntos)))
  (if (not (new_dialog "maipore_punto_hidro" dcl)) (exit))
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (if (= red "Acueducto") (mp:fill-popup "diam" *mp-diam-acu-list* 2) (mp:fill-popup "diam" *mp-diam-alc-list* 1))
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "RED" red) (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (if (= red "Acueducto") (mp:item *mp-diam-acu-list* "diam") (mp:item *mp-diam-alc-list* "diam")))
              (cons "COTA_TN_INI" (mp:gettile "ctn")) (cons "COTA_CLAVE_INI" (mp:gettile "cclave")) (cons "PROFUNDIDAD" (mp:gettile "prof"))))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-caja-electrica (/ dcl ok etapa res tipo)
  (setq dcl (load_dialog (mp:write-dcl-puntos)))
  (if (not (new_dialog "maipore_caja_elec" dcl)) (exit))
  (mp:fill-popup "tipo" '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281") 0)
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq tipo (mp:item '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281") "tipo"))
      (setq res
        (list (cons "BLK" tipo) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "ID" (mp:gettile "id")) (cons "TIPO_CAJA" (cond ((= tipo "CAMARA_CS276") "CS276") ((= tipo "CAMARA_CS280") "CS280") (T "CS281")))
              (cons "DUCTOS" (mp:gettile "ductos")) (cons "LIBRES" (mp:gettile "libres")) (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "CD" (mp:gettile "cd")) (cons "PF" (mp:gettile "pf"))))))
  (unload_dialog dcl)
  res)

(defun mp:insert-tramo-forced (redopt / vals base modo-clave modo-relleno v *error*)
  (defun *error* (message)
    (setq *mp-tramo-road-ref* nil)
    (if (and message (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR EN TRAMO: " message)))
    (princ))
  (mp:ensure-layers)
  (setq vals (mp:dialog-tramo-red redopt))
  (if vals
    (progn
      (setq vals (mp:alist-set vals "REDOPT" redopt)
            vals (mp:alist-set vals "RED" redopt)
            base
              (cond
                ((= redopt "Acueducto") "TRAMO_ACUEDUCTO")
                ((= redopt "Alluvias") "TRAMO_ALLUVIAS")
                (T "TRAMO_ARESIDUAL")))
      ;; Cota clave: la eleccion Digitar/Seleccionar ya se hizo DENTRO del
      ;; dialogo (radio_row "cc_dig"/"cc_sel"); si eligio Seleccionar los
      ;; edit_box de cota clave quedaron deshabilitados alla, asi que aqui
      ;; solo falta el clic sobre la etiqueta real.
      (setq modo-clave (mp:getval "MODO_CLAVE" vals "Digitar"))
      (if (urb:string-equal-p modo-clave "Seleccionar")
        (progn
          (setq v (mp:prompt-clave-from-label "\nSeleccione la etiqueta de cota clave INICIAL: "))
          (if v (setq vals (mp:alist-set vals "COTA_CLAVE_INI" (rtos v 2 4))))
          (setq v (mp:prompt-clave-from-label "\nSeleccione la etiqueta de cota clave FINAL: "))
          (if v (setq vals (mp:alist-set vals "COTA_CLAVE_FIN" (rtos v 2 4))))))
      ;; Referencia de relleno: modo configurado UNA VEZ desde URBANISMO ->
      ;; Configuracion -> Referencia de relleno de tramos de red (no se
      ;; pregunta aqui). Solo tiene efecto en tramos a gravedad
      ;; (mp:tramo-depth-profile, unico lugar que la usa, solo corre para
      ;; sanitario/pluvial) -- no aplica a acueducto.
      (if (mp:gravity-tramo-p base)
        (progn
          (setq modo-relleno
            (urb:safe-string (urb:config-read "MP_TRAMO_RELLENO_MODO") "Terreno"))
          (setq *mp-tramo-road-ref*
            (if (urb:string-equal-p modo-relleno "Subrasante")
              (mp:select-road-subrasante-reference)
              nil))))
      (mp:create-linked-tramo
        base vals
        (strcat "\nExtremo inicial tramo " redopt ": ")
        (strcat "\nExtremo final tramo " redopt ": "))
      (setq *mp-tramo-road-ref* nil))))


(defun mp:idx (val lst / i found)
  (setq i 0 found nil val (mp:safe-str val))
  (while (and lst (not found))
    (if (= (strcase val) (strcase (car lst)))
      (setq found i)
      (progn (setq i (1+ i)) (setq lst (cdr lst)))))
  (if found found 0))


(defun mp:attval (atts tag def / v)
  (setq v (cdr (assoc (strcase tag) atts)))
  (if (and v (/= v "")) v def))

(defun mp:subetapa-fill-current (/ etapa cur)
  (setq etapa (mp:item *mp-etapa-list* "etapa"))
  (setq cur (if (and (boundp '*mp-edit-subetapa-current*) *mp-edit-subetapa-current*) *mp-edit-subetapa-current* ""))
  (mp:fill-popup-val "subetapa" (mp:subetapas-for etapa) cur))

(defun mp:edit-layer-for-base (base)
  (cond
    ((= base "TRAMO_ACUEDUCTO") "PPTO-ACUEDUCTO")
    ((= base "TRAMO_ARESIDUAL") "PPTO-ALC-SANITARIO")
    ((= base "TRAMO_ALLUVIAS") "PPTO-ALC-PLUVIAL")
    ((= base "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
    ((= base "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
    ((= base "POZO_SANITARIO") "PPTO-ALC-SANITARIO")
    ((= base "POZO_PLUVIAL") "PPTO-ALC-PLUVIAL")
    ((= base "SUMIDERO") "PPTO-ALC-PLUVIAL")
    ((= base "ACCESORIO_ACUEDUCTO") "PPTO-ACCESORIOS-ACUEDUCTO")
    ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
    (T "PPTO-EQUIPOS-ELECTRICOS")))

(defun mp:write-dcl-editar (/ fn f)
  (mp:reset-dialog-capture)
  ;; dialogos de EDICION: los tiles etapa/subetapa se conservan siempre
  ;; (grises si las etapas estan deshabilitadas)
  (setq *mp-dialog-edit-mode* T)
  (setq fn (urb:temp-file "maipore_editar_v12" ".dcl"))
  (if (and *mp-dcl-editar-ok* (findfile fn))
    fn
    (progn
  (setq f (open fn "w"))

  (write-line "edit_tramo_red : dialog { label = \"Editar PPTO - Tramo hidrosanitario\";" f)
  (write-line ": boxed_column { label = \"Clasificacion\"; : text { key = \"redtxt\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } }" f)
  (write-line ": boxed_column { label = \"Datos\"; : edit_box { label = \"Nodo/pozo inicial\"; key = \"pini\"; edit_width = 22; } : edit_box { label = \"Nodo/pozo final\"; key = \"pfin\"; edit_width = 22; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Diametro\"; key = \"diam\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } : edit_box { label = \"Pendiente %\"; key = \"pend\"; edit_width = 12; } }" f)
  (write-line ": boxed_column { label = \"Cotas\"; : edit_box { label = \"Cota terreno inicial (automatica SUP_TN)\"; key = \"ctni\"; edit_width = 12; } : edit_box { label = \"Cota terreno final (automatica SUP_TN)\"; key = \"ctnf\"; edit_width = 12; } : edit_box { label = \"Cota clave inicial\"; key = \"ccini\"; edit_width = 12; } : edit_box { label = \"Cota clave final\"; key = \"ccfin\"; edit_width = 12; } }" f)
  (write-line ": boxed_column { label = \"Cantidades de construccion\"; : edit_box { label = \"Ancho de zanja m\"; key = \"anchoz\"; edit_width = 12; } : edit_box { label = \"Espesor de cama m\"; key = \"cama\"; edit_width = 12; } : edit_box { label = \"Ancho de reposicion m\"; key = \"repos\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_tramo_mt : dialog { label = \"Editar PPTO - Media tension\"; : boxed_column { : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Circuito\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } : edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"Ancho de zanja\"; key = \"anchoz\"; edit_width = 12; } : edit_box { label = \"Espesor de cama\"; key = \"cama\"; edit_width = 12; } : edit_box { label = \"Ancho de reposicion\"; key = \"repos\"; edit_width = 12; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_tramo_bt : dialog { label = \"Editar PPTO - Alumbrado / BT\"; : boxed_column { : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Circuito AP/BT\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } : edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"Ancho de zanja\"; key = \"anchoz\"; edit_width = 12; } : edit_box { label = \"Espesor de cama\"; key = \"cama\"; edit_width = 12; } : edit_box { label = \"Ancho de reposicion\"; key = \"repos\"; edit_width = 12; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_punto_hidro : dialog { label = \"Editar PPTO - Pozo / Sumidero\"; : boxed_column { : text { key = \"redtxt\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro\"; key = \"diam\"; } : edit_box { label = \"Cota terreno (automatica SUP_TN)\"; key = \"ctn\"; edit_width = 12; } : edit_box { label = \"Cota clave\"; key = \"cclave\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_acc_acu : dialog { label = \"Editar PPTO - Accesorio acueducto\"; : boxed_column { : popup_list { label = \"Tipo accesorio\"; key = \"acc\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro principal\"; key = \"diam\"; } : popup_list { label = \"Diametro salida\"; key = \"diamsal\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Lote/Sector\"; key = \"lote\"; edit_width = 26; } } ok_cancel; }" f)

  (write-line "edit_caja_elec : dialog { label = \"Editar PPTO - Caja / camara electrica\"; : boxed_column { : popup_list { label = \"Tipo\"; key = \"tipo\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : edit_box { label = \"Ductos\"; key = \"ductos\"; edit_width = 12; } : edit_box { label = \"Libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 14; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 14; } } ok_cancel; }" f)

  (write-line "edit_luminaria : dialog { label = \"Editar PPTO - Luminaria / equipo\"; : boxed_column { : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Codigo / ID\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Tipo luminaria\"; key = \"lum\"; } : popup_list { label = \"Fuente LED\"; key = \"led\"; } : edit_box { label = \"Altura montaje m\"; key = \"altura\"; edit_width = 12; } : edit_box { label = \"Brazo m\"; key = \"brazo\"; edit_width = 12; } : edit_box { label = \"Avance m\"; key = \"avance\"; edit_width = 12; } : edit_box { label = \"Circuito AP\"; key = \"circuito\"; edit_width = 24; } } ok_cancel; }" f)
  (close f)
  (setq *mp-dcl-editar-ok* T)
  fn)))

(defun mp:edit-dialog-tramo-red (atts base / dcl ok etapa red diamlist matlist res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_red" dcl)) (exit))
  (setq red (cond ((= base "TRAMO_ACUEDUCTO") "Acueducto") ((= base "TRAMO_ALLUVIAS") "Alluvias") (T "Aresidual")))
  (set_tile "redtxt" (strcat "Red fija del bloque: " red))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1"))
  (mp:subetapa-fill-current)
  (setq diamlist (if (= base "TRAMO_ACUEDUCTO") *mp-diam-acu-list* *mp-diam-alc-list*))
  (setq matlist (if (= base "TRAMO_ACUEDUCTO") *mp-material-acu-list* *mp-material-red-list*))
  (mp:fill-popup-val "diam" diamlist (mp:attval atts "DIAMETRO" ""))
  (mp:fill-popup-val "mat" matlist (mp:attval atts "MATERIAL" "PVC"))
  (set_tile "pini" (mp:attval atts "POZO_INI" "")) (set_tile "pfin" (mp:attval atts "POZO_FIN" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-hidro-list* (mp:attval atts "TIPO_EXTREMO_INI" "POZO"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-hidro-list* (mp:attval atts "TIPO_EXTREMO_FIN" "POZO"))
  (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1) (set_tile "pend" (mp:attval atts "PENDIENTE" ""))
  (set_tile "ctni" (mp:attval atts "COTA_TN_INI" "")) (set_tile "ctnf" (mp:attval atts "COTA_TN_FIN" ""))
  (set_tile "ccini" (mp:attval atts "COTA_CLAVE_INI" "")) (set_tile "ccfin" (mp:attval atts "COTA_CLAVE_FIN" ""))
  (set_tile "anchoz" (mp:attval atts "ANCHO_ZANJA" ""))
  (set_tile "cama" (mp:attval atts "ESPESOR_CAMA" "0.10"))
  (set_tile "repos" (mp:attval atts "ANCHO_REPOSICION" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res (list (cons "RED" red) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                      (cons "POZO_INI" (mp:gettile "pini")) (cons "POZO_FIN" (mp:gettile "pfin"))
                      (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-hidro-list* "tipo_ini"))
                      (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-hidro-list* "tipo_fin"))
                      (cons "DIAMETRO" (mp:item diamlist "diam")) (cons "MATERIAL" (mp:item matlist "mat"))
                      (cons "PENDIENTE" (mp:gettile "pend"))
                      (cons "COTA_TN_INI" (mp:gettile "ctni"))
                      (cons "COTA_TN_FIN" (mp:gettile "ctnf")) (cons "COTA_CLAVE_INI" (mp:gettile "ccini"))
                      (cons "COTA_CLAVE_FIN" (mp:gettile "ccfin"))
                      (cons "ANCHO_ZANJA" (mp:gettile "anchoz"))
                      (cons "ESPESOR_CAMA" (mp:gettile "cama"))
                      (cons "ANCHO_REPOSICION" (mp:gettile "repos"))))))
  (unload_dialog dcl)
  res)

(defun mp:edit-dialog-tramo-mt (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_mt" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (set_tile "serie" (mp:attval atts "SERIE" "1"))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "circuito" (mp:attval atts "CIRCUITO" "")) (set_tile "desde" (mp:attval atts "DESDE" "")) (set_tile "hasta" (mp:attval atts "HASTA" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_INI" "CAMARA_CS276"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_FIN" "CAMARA_CS276"))
  (mp:fill-popup-val "cond" *mp-cond-mt-list* (mp:attval atts "CONDUCTOR" (mp:attval atts "CONDUCTORES" "")))
  (mp:fill-popup-val "ductos" *mp-ductos-list* (mp:attval atts "DUCTOS" "6"))
  (mp:fill-popup-val "diamducto" *mp-diam-ducto-list* (mp:attval atts "DIAM_DUCTO" "6\""))
  (mp:fill-popup-val "matducto" *mp-mat-ducto-list* (mp:attval atts "MATERIAL_DUCTO" "PVC"))
  (set_tile "libres" (mp:attval atts "LIBRES" "")) (set_tile "prof" (mp:attval atts "PROFUNDIDAD" "")) (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1)
  (set_tile "anchoz" (mp:attval atts "ANCHO_ZANJA" ""))
  (set_tile "cama" (mp:attval atts "ESPESOR_CAMA" "0.10"))
  (set_tile "repos" (mp:attval atts "ANCHO_REPOSICION" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "TIPO_RED" "MT") (cons "CIRCUITO" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
                    (cons "CONDUCTORES" (mp:item *mp-cond-mt-list* "cond")) (cons "CONDUCTOR" (mp:item *mp-cond-mt-list* "cond"))
                    (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos")) (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto"))
                    (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto")) (cons "LIBRES" (mp:gettile "libres"))
                    (cons "PROFUNDIDAD" (mp:gettile "prof"))
                    (cons "ANCHO_ZANJA" (mp:gettile "anchoz"))
                    (cons "ESPESOR_CAMA" (mp:gettile "cama"))
                    (cons "ANCHO_REPOSICION" (mp:gettile "repos"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini"))
              (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-tramo-bt (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_bt" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (set_tile "serie" (mp:attval atts "SERIE" "6"))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "circuito" (mp:attval atts "CIRCUITO_AP" "")) (set_tile "desde" (mp:attval atts "DESDE" "")) (set_tile "hasta" (mp:attval atts "HASTA" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_INI" "CAMARA_CS276"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_FIN" "CAMARA_CS276"))
  (mp:fill-popup-val "cond" *mp-cond-bt-list* (mp:attval atts "CONDUCTOR" ""))
  (mp:fill-popup-val "ductos" *mp-ductos-list* (mp:attval atts "DUCTOS" "1"))
  (mp:fill-popup-val "diamducto" *mp-diam-ducto-list* (mp:attval atts "DIAM_DUCTO" "3\""))
  (mp:fill-popup-val "matducto" *mp-mat-ducto-list* (mp:attval atts "MATERIAL_DUCTO" "PVC"))
  (set_tile "libres" (mp:attval atts "LIBRES" "0"))
  (set_tile "prof" (mp:attval atts "PROFUNDIDAD" ""))
  (set_tile "anchoz" (mp:attval atts "ANCHO_ZANJA" ""))
  (set_tile "cama" (mp:attval atts "ESPESOR_CAMA" "0.10"))
  (set_tile "repos" (mp:attval atts "ANCHO_REPOSICION" ""))
  (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1)
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "TIPO_RED" (mp:attval atts "TIPO_RED" "BT")) (cons "CIRCUITO_AP" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
                    (cons "CONDUCTOR" (mp:item *mp-cond-bt-list* "cond")) (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos"))
                    (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto")) (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto"))
                    (cons "LIBRES" (mp:gettile "libres"))
                    (cons "PROFUNDIDAD" (mp:gettile "prof"))
                    (cons "ANCHO_ZANJA" (mp:gettile "anchoz"))
                    (cons "ESPESOR_CAMA" (mp:gettile "cama"))
                    (cons "ANCHO_REPOSICION" (mp:gettile "repos"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini")) (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-punto-hidro (atts base / dcl ok etapa red diamlist res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_punto_hidro" dcl)) (exit))
  (setq red (mp:attval atts "RED" (cond ((= base "POZO_SANITARIO") "Aresidual") ((= base "POZO_PLUVIAL") "Alluvias") (T "Alluvias"))))
  (set_tile "redtxt" (strcat "Red fija del bloque: " red))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" ""))
  (setq diamlist (if (= red "Acueducto") *mp-diam-acu-list* *mp-diam-alc-list*))
  (mp:fill-popup-val "diam" diamlist (mp:attval atts "DIAMETRO" ""))
  (set_tile "ctn" (mp:attval atts "COTA_TN_INI" "")) (set_tile "cclave" (mp:attval atts "COTA_CLAVE_INI" "")) (set_tile "prof" (mp:attval atts "PROFUNDIDAD" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "RED" red) (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (mp:item diamlist "diam"))
                    (cons "COTA_TN_INI" (mp:gettile "ctn")) (cons "COTA_CLAVE_INI" (mp:gettile "cclave")) (cons "PROFUNDIDAD" (mp:gettile "prof"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-acc-acu (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_acc_acu" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "acc" *mp-acc-acu-list* (mp:attval atts "TIPO_ACCESORIO" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" ""))
  (mp:fill-popup-val "diam" *mp-diam-acu-list* (mp:attval atts "DIAMETRO" ""))
  (mp:fill-popup-val "diamsal" *mp-diam-acu-list* (mp:attval atts "DIAMETRO_SALIDA" ""))
  (mp:fill-popup-val "mat" *mp-material-acu-list* (mp:attval atts "MATERIAL" "PVC"))
  (set_tile "lote" (mp:attval atts "LOTE" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "TIPO_ACCESORIO" (mp:item *mp-acc-acu-list* "acc")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (mp:item *mp-diam-acu-list* "diam"))
                    (cons "DIAMETRO_SALIDA" (mp:item *mp-diam-acu-list* "diamsal")) (cons "MATERIAL" (mp:item *mp-material-acu-list* "mat"))
                    (cons "LOTE" (mp:gettile "lote"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-caja-elec (atts base / dcl ok etapa res typelist)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_caja_elec" dcl)) (exit))
  (setq typelist '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
  (mp:fill-popup-val "tipo" typelist base)
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" "")) (set_tile "ductos" (mp:attval atts "DUCTOS" "")) (set_tile "libres" (mp:attval atts "LIBRES" ""))
  (set_tile "prof" (mp:attval atts "PROFUNDIDAD" "")) (set_tile "cd" (mp:attval atts "CD" "")) (set_tile "pf" (mp:attval atts "PF" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq base (mp:item typelist "tipo"))
    (setq res (list (cons "BLOQUE_BASE" base) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "ID" (mp:gettile "id")) (cons "TIPO_CAJA" (cond ((= base "CAMARA_CS276") "CS276") ((= base "CAMARA_CS280") "CS280") (T "CS281")))
                    (cons "DUCTOS" (mp:gettile "ductos")) (cons "LIBRES" (mp:gettile "libres"))
                    (cons "PROFUNDIDAD" (mp:gettile "prof")) (cons "CD" (mp:gettile "cd")) (cons "PF" (mp:gettile "pf"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-luminaria (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_luminaria" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "CODIGO" (mp:attval atts "ID" "")))
  (mp:fill-popup-val "lum" *mp-lum-list* (mp:attval atts "TIPO_LUMINARIA" ""))
  (mp:fill-popup-val "led" *mp-led-list* (mp:attval atts "FUENTE_LED" ""))
  (set_tile "altura" (mp:attval atts "ALTURA_M" "")) (set_tile "brazo" (mp:attval atts "BRAZO_M" "")) (set_tile "avance" (mp:attval atts "AVANCE_M" ""))
  (set_tile "circuito" (mp:attval atts "CIRCUITO_AP" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "CODIGO" (mp:gettile "id")) (cons "ID" (mp:gettile "id"))
                    (cons "TIPO_LUMINARIA" (mp:item *mp-lum-list* "lum")) (cons "FUENTE_LED" (mp:item *mp-led-list* "led"))
                    (cons "ALTURA_M" (mp:gettile "altura")) (cons "BRAZO_M" (mp:gettile "brazo")) (cons "AVANCE_M" (mp:gettile "avance"))
                    (cons "CIRCUITO_AP" (mp:gettile "circuito"))))))
  (unload_dialog dcl) res)


(defun mp:editable-base-p (base)
  (or
    (member base
      '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO"
        "TRAMO_E_MT" "TRAMO_E_BT_AP" "POZO_SANITARIO"
        "POZO_PLUVIAL" "SUMIDERO" "ACCESORIO_ACUEDUCTO"
        "CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"
        "LUMINARIA_AP"))))

(defun mp:editable-entity-p (en / obj bname atts base)
  (and en
       (= (cdr (assoc 0 (entget en))) "INSERT")
       (setq obj (vlax-ename->vla-object en))
       (setq bname (vla-get-EffectiveName obj))
       (setq atts (mp:att-alist en))
       (setq base (mp:infer-base bname atts))
       (mp:editable-base-p base))
)

(defun mp:edit-entity (en / obj bname atts base vals saved)
  (if (mp:editable-entity-p en)
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq bname (vla-get-EffectiveName obj))
      (setq atts (mp:att-alist en))
      (setq base (mp:infer-base bname atts))
      (setq vals
        (cond
          ((member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO")) (mp:edit-dialog-tramo-red atts base))
          ((= base "TRAMO_E_MT") (mp:edit-dialog-tramo-mt atts))
          ((= base "TRAMO_E_BT_AP") (mp:edit-dialog-tramo-bt atts))
          ((member base '("POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO")) (mp:edit-dialog-punto-hidro atts base))
          ((= base "ACCESORIO_ACUEDUCTO") (mp:edit-dialog-acc-acu atts))
          ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281")) (mp:edit-dialog-caja-elec atts base))
          ((= base "LUMINARIA_AP") (mp:edit-dialog-luminaria atts))
          (T nil)))
      (if vals
        (progn
          (setq saved (mp:update-block-after-edit en vals))
          (princ (strcat "\nBloque PPTO actualizado. Atributos guardados: " (itoa saved)))
          T)
        (progn
          (princ "\nEste bloque no tiene formulario de edicion.")
          nil)))
    nil)
)

;;; ============================================================
;;; V13 OPTIMIZADA
;;; - Una sola implementacion activa, sin versiones concatenadas.
;;; - Reutiliza bloques de puntos por tipo.
;;; - Reutiliza bloques de tramos cuando tipo y longitud coinciden.
;;; - Cancelacion segura y formularios de elementos completos.
;;; - Conserva valores heredados que no existan en las listas.
;;; - LONGITUD se calcula desde la geometria y no se edita manualmente.
;;; ============================================================

(setq *mp-popup-lists* nil)

(defun mp:popup-list (key fallback / pair)
  (setq pair (assoc key *mp-popup-lists*))
  (if pair (cdr pair) fallback))

(defun mp:remember-popup (key lst / pair)
  (if (setq pair (assoc key *mp-popup-lists*))
    (setq *mp-popup-lists* (subst (cons key lst) pair *mp-popup-lists*))
    (setq *mp-popup-lists* (cons (cons key lst) *mp-popup-lists*))))

(defun mp:fill-popup (key lst idx)
  ;; 2026-08-12: con etapas deshabilitadas los tiles etapa/subetapa NO se
  ;; emiten en los DCL de creacion (ocultos, no grises) -- llenar un tile
  ;; inexistente truena, asi que se omite aqui centralizadamente. Los
  ;; dialogos de EDICION si conservan los tiles y quedan grises.
  (if (and (member key '("etapa" "subetapa"))
           (not (urb:etapas-enabled-p))
           (not *mp-dialog-edit-mode*))
    nil
    (progn
      (mp:remember-popup key lst)
      (start_list key)
      (mapcar 'add_list lst)
      (end_list)
      (if (not idx) (setq idx 0))
      (set_tile key (itoa idx))
      ;; etapas deshabilitadas -> popup gris (dialogos de edicion)
      (if (and (member key '("etapa" "subetapa"))
               (not (urb:etapas-enabled-p)))
        (mode_tile key 1)))))

(defun mp:item (lst key / raw i use)
  (setq use (mp:popup-list key lst))
  (setq raw (mp:gettile key))
  (if (= raw "") (setq raw "0"))
  (setq i (atoi raw))
  (if (and (>= i 0) (< i (length use))) (nth i use) (if use (car use) "")))

(defun mp:fill-popup-val (key lst val / use)
  (setq val (mp:safe-str val))
  (setq use
    (if (or (= val "") (member (strcase val) (mapcar 'strcase lst)))
      lst
      (cons val lst)))
  (mp:fill-popup key use (mp:idx val use)))

(defun mp:block-token (base)
  (cond
    ((= base "TRAMO_ARESIDUAL") "SAN")
    ((= base "TRAMO_ALLUVIAS") "PLU")
    ((= base "TRAMO_ACUEDUCTO") "ACU")
    ((= base "TRAMO_E_MT") "MT")
    ((= base "TRAMO_E_BT_AP") "BTAP")
    ((= base "POZO_SANITARIO") "POZO_SAN")
    ((= base "POZO_PLUVIAL") "POZO_PLU")
    ((= base "SUMIDERO") "SUMIDERO")
    ((= base "ACCESORIO_ACUEDUCTO") "ACC_ACU")
    ((= base "LUMINARIA_AP") "LUMINARIA")
    (T (vl-string-translate " -" "__" base))))

(defun mp:tramo-block-name (base dist / ds)
  ;; 2 decimales (antes 4): tramos de longitud casi igual comparten una
  ;; misma definicion de bloque y el DWG no acumula definiciones de mas.
  (setq ds (vl-string-translate ".-" "_M" (rtos dist 2 2)))
  (strcat "MP_TRAMO_" (mp:block-token base) "_" ds))

(defun mp:point-block-name (base)
  (strcat "MP_PUNTO_" (mp:block-token base)))

(defun mp:is-cant-blockname (bname)
  (or (member (strcase bname) (mapcar 'strcase *mp-blocks*))
      (mp:starts-with bname "CANT_TRAMO_")
      (mp:starts-with bname "CANT_PUNTO_")
      (mp:starts-with bname "MP_TRAMO_")
      (mp:starts-with bname "MP_PUNTO_")))

(defun mp:is-tramo-name (bname)
  (or (mp:starts-with bname "CANT_TRAMO_")
      (mp:starts-with bname "MP_TRAMO_")))

(defun mp:is-point-name (bname)
  (or (mp:starts-with bname "CANT_PUNTO_")
      (mp:starts-with bname "MP_PUNTO_")))

(defun mp:diametro-label (vals / d)
  (setq d (vl-string-trim " " (mp:getval "DIAMETRO" vals "?")))
  (if (and (> (strlen d) 0) (= (substr d (strlen d) 1) "\""))
    d
    (strcat d "\"")))

(defun mp:label-tramo (base vals / l d mat)
  (setq l (mp:getval "LONGITUD" vals ""))
  (setq d (mp:diametro-label vals))
  (setq mat (mp:getval "MATERIAL" vals ""))
  (cond
    ((= base "TRAMO_ACUEDUCTO")
      (strcat "ACU L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_ALLUVIAS")
      (strcat "ALL L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_ARESIDUAL")
      (strcat "SAN L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_E_MT")
      (strcat "MT L=" l "- " (mp:getval "DUCTOS" vals "") "x%%c" (mp:getval "DIAM_DUCTO" vals "") "-" (mp:getval "MATERIAL_DUCTO" vals "")))
    ((= base "TRAMO_E_BT_AP")
      (strcat (mp:getval "TIPO_RED" vals "BT/AP") " L=" l "- "
        (mp:getval "DUCTOS" vals "") "x%%c"
        (mp:getval "DIAM_DUCTO" vals "") "-"
        (mp:getval "MATERIAL_DUCTO" vals "")))
    (T (strcat base " L=" l))))

;; "last" es funcion nativa de AutoLISP; renombrado por prevencion
;; (mismo patron que distance/length/type en otras partes del archivo),
;; aunque aqui no llegaba a colisionar con una llamada real.
(defun mp:pendiente-label (vals / p last-char)
  (setq p (vl-string-trim " " (mp:getval "PENDIENTE" vals "")))
  (if (= p "")
    ""
    (progn
      (setq last-char (substr p (strlen p) 1))
      (if (= last-char "%") p (strcat p "%")))))
(defun mp:label-point (base vals / id)
  (setq id (mp:getval "ID" vals (mp:getval "CODIGO" vals "")))
  (cond
    ((= base "POZO_SANITARIO") id)
    ((= base "POZO_PLUVIAL") id)
    ((= base "SUMIDERO") (strcat "SUM " id))
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281")) (strcat (mp:getval "TIPO_CAJA" vals base) " " id))
    ((= base "ACCESORIO_ACUEDUCTO") (strcat (mp:getval "TIPO_ACCESORIO" vals "ACC") " D" (mp:getval "DIAMETRO" vals "") " " id))
    ((= base "LUMINARIA_AP") (strcat "LUM " (mp:getval "CODIGO" vals id)))
    (T (strcat base " " id))))

(defun mp:alist-set (values tag value / pair)
  (setq tag (strcase tag)
        pair (assoc tag values))
  (if pair
    (subst (cons tag value) pair values)
    (cons (cons tag value) values)))

(defun mp:numeric-real (value / text index character cleaned parsed)
  (setq text (mp:safe-str value)
        index 1
        cleaned "")
  (while (<= index (strlen text))
    (setq character (substr text index 1))
    (if (vl-string-search character "0123456789,.-+")
      (setq cleaned (strcat cleaned character)))
    (setq index (1+ index)))
  (setq parsed (urb:parse-real cleaned))
  parsed)

(defun mp:number-or (value default / parsed)
  (setq parsed (mp:numeric-real value))
  (if parsed parsed default))

(defun mp:join-messages (messages / result message)
  (setq result "")
  (foreach message messages
    (setq result
      (if (= result "") message (strcat result " | " message))))
  result)

(defun mp:hydro-tramo-p (base)
  (member base
    '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO")))

(defun mp:gravity-tramo-p (base)
  (member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS")))

(defun mp:current-terrain-surface
  (/ ss index ename obj name-result found)
  ;; La busqueda se hace siempre en el dibujo activo. No se reutiliza a
  ;; ciegas una superficie almacenada de otro DWG y no se toman superficies
  ;; anidadas en XREF: SUP_TN debe pertenecer a URB_MASTER_GENERAL.
  (setq ss
    (ssget "_X"
      '((0 . "AECC_TIN_SURFACE,AECC_GRID_SURFACE,AECC_TIN_VOLUME_SURFACE"))))
  (if ss
    (progn
      (setq index 0)
      (while (and (< index (sslength ss)) (not found))
        (setq ename (ssname ss index)
              obj (vlax-ename->vla-object ename)
              name-result
                (vl-catch-all-apply 'vla-get-Name (list obj)))
        (if (and
              (not (vl-catch-all-error-p name-result))
              (urb:string-equal-p
                name-result *mp-terrain-surface-name*))
          (setq found obj))
        (setq index (1+ index)))))
  found)

(defun mp:terrain-elevation-at-point (surface point / result)
  (if (and surface point (car point) (cadr point))
    (progn
      (setq result
        (vl-catch-all-apply
          'vlax-invoke
          (list surface 'FindElevationAtXY
            (float (car point)) (float (cadr point)))))
      (if (or (vl-catch-all-error-p result) (not (numberp result)))
        nil
        result))
    nil))

(defun mp:auto-terrain-values
  (values point-initial point-final
   / surface elevation-initial elevation-final state)
  (setq values
    (mp:alist-set values "SUPERFICIE_TN" *mp-terrain-surface-name*)
        surface (mp:current-terrain-surface))
  (if surface
    (progn
      (setq elevation-initial
              (mp:terrain-elevation-at-point surface point-initial)
            elevation-final
              (if point-final
                (mp:terrain-elevation-at-point surface point-final)
                nil))
      ;; Una consulta fallida nunca borra una cota anterior ni escribe cero.
      (if elevation-initial
        (setq values
          (mp:alist-set values "COTA_TN_INI"
            (rtos elevation-initial 2 3))))
      (if elevation-final
        (setq values
          (mp:alist-set values "COTA_TN_FIN"
            (rtos elevation-final 2 3))))
      (setq state
        (cond
          ((not point-final)
            (if elevation-initial "OK" "FUERA_SUPERFICIE"))
          ((and elevation-initial elevation-final) "OK")
          ((or elevation-initial elevation-final) "PARCIAL")
          (T "FUERA_SUPERFICIE"))))
    (setq state "SIN_SUPERFICIE"))
  (mp:alist-set values "ESTADO_COTA_TN" state))

;; Tabla literal de la hoja "Anchos Exc. PVC (Ent)" del presupuesto de redes
;; (tuberia NOVAFORT/NOVALOC, alcantarillado). Se copian los anchos ya
;; calculados en Excel -no se reconstruye la formula de holguras variables
;; por rango de diametro- para no arriesgar un error de traduccion; si el
;; Excel cambia, esta tabla se debe resincronizar a mano.
;; Cada entrada: diametro-nominal-en-pulgadas . anchos-por-rango-de-profundidad
;; Rangos de profundidad, columnas H..Q del Excel, en metros: hasta 1.5,
;; hasta 2.5, hasta 3.5, hasta 4.5, hasta 5.5, hasta 6.5, hasta 7.5,
;; hasta 8.5, hasta 9.5, hasta 10.5 (y mas alla de 10.5 usa la ultima).
(setq *mp-pvc-trench-width-table*
  '((4 . (0.90 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (6 . (0.90 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (8 . (0.90 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (10 . (0.90 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (12 . (0.90 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (14 . (0.95 1.00 1.10 1.20 1.20 1.20 1.20 1.20 1.20 1.20))
    (16 . (1.15 1.15 1.25 1.25 1.25 1.25 1.25 1.25 1.25 1.25))
    (18 . (1.20 1.20 1.30 1.30 1.30 1.30 1.30 1.30 1.30 1.30))
    (20 . (1.25 1.25 1.35 1.35 1.35 1.35 1.35 1.35 1.35 1.35))
    (24 . (1.40 1.40 1.50 1.50 1.50 1.50 1.50 1.50 1.50 1.50))
    (27 . (1.45 1.45 1.55 1.55 1.55 1.55 1.55 1.55 1.55 1.55))
    (30 . (1.70 1.70 1.80 1.80 1.80 1.80 1.80 1.80 1.80 1.80))
    (33 . (1.75 1.75 1.85 1.85 1.85 1.85 1.85 1.85 1.85 1.85))
    (36 . (1.85 1.85 1.95 1.95 1.95 1.95 1.95 1.95 1.95 1.95))
    (39 . (1.95 1.95 2.05 2.05 2.05 2.05 2.05 2.05 2.05 2.05))
    (42 . (2.00 2.00 2.10 2.10 2.10 2.10 2.10 2.10 2.10 2.10))
    (45 . (2.10 2.10 2.20 2.20 2.20 2.20 2.20 2.20 2.20 2.20))
    (48 . (2.15 2.15 2.25 2.25 2.25 2.25 2.25 2.25 2.25 2.25))
    (51 . (2.40 2.40 2.50 2.50 2.50 2.50 2.50 2.50 2.50 2.50))
    (54 . (2.45 2.45 2.55 2.55 2.55 2.55 2.55 2.55 2.55 2.55))
    (57 . (2.55 2.55 2.65 2.65 2.65 2.65 2.65 2.65 2.65 2.65))
    (60 . (2.60 2.60 2.70 2.70 2.70 2.70 2.70 2.70 2.70 2.70))))

(defun mp:trench-width-bracket-index (depth)
  (cond
    ((<= depth 1.5) 0) ((<= depth 2.5) 1) ((<= depth 3.5) 2)
    ((<= depth 4.5) 3) ((<= depth 5.5) 4) ((<= depth 6.5) 5)
    ((<= depth 7.5) 6) ((<= depth 8.5) 7) ((<= depth 9.5) 8)
    (T 9)))

(defun mp:pvc-trench-width (diameter-in depth / entry)
  (setq entry (assoc (fix (+ diameter-in 0.5)) *mp-pvc-trench-width-table*))
  (if entry
    (nth
      (mp:trench-width-bracket-index (max 0.0 (mp:number-or depth 0.0)))
      (cdr entry))
    nil))

(defun mp:max-nonnil (values / result v)
  (foreach v values
    (if (and v (or (null result) (> v result))) (setq result v)))
  result)

;; 2026-08-03: modo de referencia del relleno de tramos, configurado UNA
;; VEZ desde URBANISMO -> Configuracion (no se pregunta en cada tramo).
;; Persistido en el dibujo igual que URB_DRAWING_ID (urb:config-read/write).
(defun mp:network-fill-reference-command (/ current choice)
  (setq current (urb:safe-string (urb:config-read "MP_TRAMO_RELLENO_MODO") "Terreno"))
  (prompt
    (strcat "\nReferencia de relleno actual para tramos de red (sanitario/pluvial): "
      current "."))
  (initget "Terreno Subrasante")
  (setq choice
    (getkword
      (strcat "\nNueva referencia [Terreno/Subrasante_via] <" current ">: ")))
  (if (null choice) (setq choice current))
  (urb:config-write "MP_TRAMO_RELLENO_MODO" choice)
  (prompt
    (strcat "\nQuedo configurado: " choice
      (if (= choice "Subrasante")
        ". Al crear un tramo a gravedad se pedira seleccionar la via de referencia."
        ". El relleno vuelve a calcularse hasta el terreno natural (como siempre).")))
  (princ)
)

;; 2026-08-04: recalculo en lote de tramos ya existentes contra la
;; referencia de relleno ACTUAL (MP_TRAMO_RELLENO_MODO). Cambiar la
;; configuracion no actualiza solos los tramos ya creados (el modo se lee
;; una sola vez al crearlos, ver mp:insert-tramo-forced); este comando
;; recorre todos los tramos a gravedad del dibujo y vuelve a llamar
;; mp:sync-tramo-values (via mp:update-block-after-edit) para cada uno.
;; En modo Subrasante pide la via por cada tramo (nentsel/entsel no se
;; puede automatizar de forma confiable: podria haber mas de una via
;; candidata sobre un mismo tramo), igual que al crearlo. Si el usuario
;; cancela la seleccion de un tramo puntual, ese tramo se deja como estaba
;; (no se pisa con un calculo a terreno natural sin que lo pida).
(defun mp:recalc-tramos-earthworks-command
  (/ ss i en obj bname atts base doc undo-open modo-relleno
   found updated skipped ref *error*)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (message)
    (setq *mp-tramo-road-ref* nil)
    (if undo-open
      (progn (vl-catch-all-apply 'vla-EndUndoMark (list doc)) (setq undo-open nil)))
    (if (and message (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al recalcular tramos: " message)))
    (princ))
  (setq modo-relleno (urb:safe-string (urb:config-read "MP_TRAMO_RELLENO_MODO") "Terreno"))
  (prompt (strcat "\nReferencia de relleno actual: " modo-relleno "."))
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (setq found 0 updated 0 skipped 0)
  (if ss
    (progn
      (vla-StartUndoMark doc)
      (setq undo-open T)
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq obj (vlax-ename->vla-object en))
        (setq bname (vla-get-EffectiveName obj))
        (if (mp:is-cant-blockname bname)
          (progn
            (setq atts (mp:att-alist en))
            (setq base (mp:infer-base bname atts))
            (if (and (/= base "") (mp:gravity-tramo-p base))
              (progn
                (setq found (1+ found))
                (setq *mp-tramo-road-ref* nil)
                (setq ref T)
                (if (urb:string-equal-p modo-relleno "Subrasante")
                  (progn
                    (prompt
                      (strcat "\nTramo " (mp:getval "ETIQUETA" atts "(sin etiqueta)") ":"))
                    (setq ref (mp:select-road-subrasante-reference))
                    (setq *mp-tramo-road-ref* ref)))
                (if ref
                  (progn
                    (mp:update-block-after-edit en nil)
                    (setq updated (1+ updated)))
                  (setq skipped (1+ skipped)))
                (setq *mp-tramo-road-ref* nil)))))
        (setq i (1+ i)))
      (vla-Regen doc 1)
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (setq undo-open nil)))
  (prompt
    (strcat "\nRecalculo terminado. Tramos a gravedad encontrados: " (itoa found)
      " | Actualizados: " (itoa updated)
      (if (> skipped 0) (strcat " | Omitidos (sin via seleccionada): " (itoa skipped)) "")))
  (princ))

;; referencia opcional de subrasante (ver mp:tramo-depth-profile
;; y *mp-tramo-road-ref*). Reusa el mismo mecanismo de seleccion/lectura de
;; rasante que ya usa el anden (urb:select-anden-road-grade), pero agrega la
;; PROFUNDIDAD DEL PERFIL de la via para poder restarla y llegar a la
;; subrasante (bajo la estructura de pavimento), no solo a la rasante.
(defun mp:select-road-subrasante-reference
  (/ selected road data mov axis axis-handle via-id records c0 c1 span profile depth)
  (setq selected (entsel "\nSeleccione la via que define la subrasante: "))
  (if selected (setq road (urb:road-parent-from-entity (car selected))))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq profile (urb:safe-string (if (> (length data) 4) (nth 4 data) nil) ""))
      (setq depth (urb:road-profile-depth profile))
      (setq via-id (if (> (length data) 22) (nth 22 data) ""))
      (setq axis-handle
        (if (> (length data) 5) (urb:safe-string (nth 5 data) "") ""))
      (setq axis
        (or
          (if (/= axis-handle "") (handent axis-handle) nil)
          (if (/= via-id "") (urb:cached-road-axis via-id) nil)))
      (if (and axis (not (urb:curve-entity-p axis))) (setq axis nil))
      (if (not axis) (setq axis (urb:select-or-draw-road-axis "Existente")))
      (setq mov (urb:road-movement-data road))
      (if (and mov (> (length mov) 9))
        (setq records (urb:read-lisp-safe (nth 9 mov))))
      (if (not (urb:grade-records-valid-p records)) (setq records nil))
      (setq span
        (atof
          (urb:safe-string
            (if (> (length data) 18) (nth 18 data) nil) "0")))
      (if (and (null records) mov (> (length mov) 8))
        (progn
          (setq c0 (urb:parse-real (nth 7 mov)))
          (setq c1 (urb:parse-real (nth 8 mov)))
          (if (and c0 c1 (> span 1e-6))
            (setq records (list (list 0.0 c0) (list span c1))))))
      (setq axis-start
        (atof
          (urb:safe-string
            (if (> (length data) 21) (nth 21 data) nil) "0")))
      (cond
        ((not (and depth (> depth 0.0)))
          (prompt
            (strcat "\nEl perfil " profile " de esa via no tiene profundidad definida; no se puede calcular subrasante."))
          nil)
        ((and axis records)
          (list axis records axis-start span
            (urb:safe-string (if (> (length data) 12) (nth 12 data) nil) "Inicio")
            "LOCAL" depth))
        (T
          (prompt "\nLa via seleccionada no tiene rasante calculada.")
          nil)))
    (progn (prompt "\nEl objeto seleccionado no es una via cuantificable.") nil))
)

(defun mp:subrasante-at-point
  (point reference / axis records axis-start span direction depth
   closest raw-distance station zaxis)
  (setq axis (nth 0 reference) records (nth 1 reference)
        axis-start (nth 2 reference) span (nth 3 reference)
        direction (nth 4 reference) depth (nth 6 reference))
  (setq closest
    (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list axis point)))
  (if (vl-catch-all-error-p closest)
    nil
    (progn
      (setq raw-distance
        (vl-catch-all-apply 'vlax-curve-getDistAtPoint (list axis closest)))
      (if (vl-catch-all-error-p raw-distance)
        nil
        (progn
          (setq station
            (if (urb:string-equal-p direction "Final")
              (- (+ axis-start span) raw-distance)
              (- raw-distance axis-start)))
          (setq zaxis (urb:cota-at-axis-distance station records))
          (if zaxis (- zaxis depth) nil)))))
)

;; BUG (2026-08-03, encontrado por el usuario en vivo): las etiquetas
;; reales de cota (MLeader/MText) traen la cota pozo Y la cota clave
;; apiladas en el MISMO objeto, y vla-get-TextString devuelve el texto
;; CRUDO con codigos de formato MTEXT (ej. "\pxt6;{\Fsimplex|c0;2559.63
;; \P2557.83}" -- \P separa las 2 lineas). Intentar parsear ese string
;; completo como un numero mezclaba digitos sueltos de los codigos (el
;; "6" de "pxt6", el "0" de "c0") con la cota real, dando basura como
;; "62556.310" en vez de "2556.31".
;; mp:last-decimal-number busca especificamente numeros CON PUNTO
;; DECIMAL (los codigos de formato solo tienen digitos sueltos, sin
;; punto) y devuelve el ULTIMO -- que es la cota clave, la linea de
;; abajo en la etiqueta apilada, tanto en texto crudo con codigos como
;; en texto plano simple (un TEXT sin formato tambien funciona igual).
(defun mp:last-decimal-number (text / i n c buf best)
  (setq text (mp:safe-str text) n (strlen text) i 1 buf "" best nil)
  (while (<= i n)
    (setq c (substr text i 1))
    (cond
      ((wcmatch c "#") (setq buf (strcat buf c)))
      ((and (= c ".") (> (strlen buf) 0) (not (vl-string-search "." buf)))
        (setq buf (strcat buf c)))
      (T
        (if (and (> (strlen buf) 0) (vl-string-search "." buf)
                 (/= (substr buf (strlen buf) 1) "."))
          (setq best buf))
        (setq buf "")))
    (setq i (1+ i)))
  (if (and (> (strlen buf) 0) (vl-string-search "." buf)
           (/= (substr buf (strlen buf) 1) "."))
    (setq best buf))
  best
)

;; Lee una cota clave directamente de una etiqueta ya dibujada (evita
;; transcribir el numero a mano). nentsel (no entsel) porque estas
;; etiquetas suelen vivir dentro de un xref (ej. el plano de residual).
(defun mp:prompt-clave-from-label (prompt-text / selected ename obj txt clean val)
  (setq selected (nentsel prompt-text))
  (if (not selected)
    nil
    (progn
      (setq ename (car selected))
      (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
      (if (vl-catch-all-error-p obj)
        (progn (prompt "\nNo se pudo leer el objeto seleccionado.") nil)
        (progn
          (setq txt (vl-catch-all-apply 'vla-get-TextString (list obj)))
          (if (vl-catch-all-error-p txt)
            (progn (prompt "\nEl objeto seleccionado no tiene texto legible.") nil)
            (progn
              (setq clean (mp:last-decimal-number txt))
              (setq val (if clean (mp:numeric-real clean) nil))
              (if val
                (progn (prompt (strcat "\nCota leida: " (rtos val 2 3))) val)
                (progn
                  (prompt
                    (strcat "\nNo se encontro un numero valido en el texto seleccionado (\""
                      (mp:safe-str txt) "\")."))
                  nil))))))))
)

(defun mp:tramo-depth-profile
  (surface p1 p2 key-ini key-fin diameter-m bedding n road-ref
   / i frac x y terrain reference subrasante key depth depths max-depth)
  ;; Muestrea la superficie a lo largo del tramo (no solo los 2 pozos) porque
  ;; el terreno entre pozos puede no ser perfectamente lineal; con esto el
  ;; ancho de zanja y el volumen de excavacion usan la profundidad real, no
  ;; un promedio que podria subestimar una loma intermedia.
  ;; road-ref (opcional, ver mp:select-road-subrasante-reference): si viene,
  ;; en cada punto se usa min(terreno,subrasante) en vez de solo terreno --
  ;; asi el relleno del tramo no cuenta material que la via va a volver a
  ;; cortar por separado hasta su subrasante.
  (setq depths nil max-depth nil i 0)
  (if (and surface p1 p2 key-ini key-fin (> n 1))
    (repeat (1+ n)
      (setq frac (/ (float i) (float n))
            x (+ (car p1) (* frac (- (car p2) (car p1))))
            y (+ (cadr p1) (* frac (- (cadr p2) (cadr p1))))
            terrain (mp:terrain-elevation-at-point surface (list x y))
            key (+ key-ini (* frac (- key-fin key-ini))))
      (if terrain
        (progn
          (setq reference terrain)
          (if road-ref
            (progn
              (setq subrasante
                (vl-catch-all-apply 'mp:subrasante-at-point (list (list x y) road-ref)))
              (if (and (not (vl-catch-all-error-p subrasante)) subrasante)
                (setq reference (min terrain subrasante)))))
          (setq depth (+ (- reference key) diameter-m bedding)
                depths (cons depth depths)
                max-depth (if max-depth (max max-depth depth) depth))))
      (setq i (1+ i))))
  (list (reverse depths) max-depth))

;; BUG (2026-08-03, mismo patron que distance/length/type/last ya
;; documentados en este archivo): el parametro se llamaba "length" y tapaba
;; la funcion nativa mientras (setq n (length depths)) intentaba usarla --
;; "bad function: 10.0" (el valor de longitud pasado). Nunca se habia
;; ejercitado porque *mp-network-construction-enabled* estaba en nil.
;; Renombrado a total-length.
(defun mp:integrate-trench-volume (depths total-length width / n seg-length i vol)
  (setq n (length depths))
  (if (or (< n 2) (<= total-length 1e-9))
    0.0
    (progn
      (setq seg-length (/ total-length (float (1- n))) vol 0.0 i 0)
      (repeat (1- n)
        (setq vol
          (+ vol
            (* width seg-length
              (/ (+ (nth i depths) (nth (1+ i) depths)) 2.0))))
        (setq i (1+ i)))
      vol)))

(defun mp:default-trench-width
  (base vals depth / diameter ducts columns width minimum diameter-in table-width)
  (if (mp:hydro-tramo-p base)
    (progn
      (setq diameter-in (mp:number-or (mp:getval "DIAMETRO" vals "0") 0.0)
            diameter (* 0.0254 diameter-in)
            table-width
              (if (and (mp:gravity-tramo-p base) depth)
                (mp:pvc-trench-width diameter-in depth)
                nil))
      (if table-width table-width (max 0.60 (+ diameter 0.40))))
    (progn
      (setq diameter (* 0.0254 (mp:number-or (mp:getval "DIAM_DUCTO" vals "0") 0.0))
            ducts (max 1.0 (mp:number-or (mp:getval "DUCTOS" vals "1") 1.0))
            columns (max 1 (fix (+ (sqrt ducts) 0.999999)))
            minimum (if (= base "TRAMO_E_MT") 0.80 0.60)
            width
              (+ 0.30
                (* columns diameter)
                (* (max 0 (1- columns)) 0.05)))
      (max minimum width))))

(defun mp:validate-tramo-values
  (base vals / messages stage substage length-value diameter material
   type-ini type-fin handle-ini handle-fin slope slope-calculated ducts
   free-ducts depth depth-ini depth-fin conductor width bedding endpoint
   endpoint-base actual-type id-ini id-fin diameter-number duct-diameter
   duct-material type-red link-data minimum-width tn-ini tn-fin key-ini key-fin
   terrain-state check-depth)
  (setq stage (mp:getval "ETAPA" vals "")
        substage (mp:getval "SUBETAPA" vals "")
        length-value (mp:number-or (mp:getval "LONGITUD" vals "0") 0.0)
        type-ini (strcase (mp:getval "TIPO_EXTREMO_INI" vals "NINGUNO"))
        type-fin (strcase (mp:getval "TIPO_EXTREMO_FIN" vals "NINGUNO"))
        handle-ini (mp:getval "HANDLE_EXTREMO_INI" vals "")
        handle-fin (mp:getval "HANDLE_EXTREMO_FIN" vals "")
        id-ini
          (mp:getval
            (if (member base '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
              "DESDE" "POZO_INI") vals "")
        id-fin
          (mp:getval
            (if (member base '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
              "HASTA" "POZO_FIN") vals "")
        width (mp:number-or (mp:getval "ANCHO_ZANJA" vals "0") 0.0)
        bedding (mp:number-or (mp:getval "ESPESOR_CAMA" vals "0") 0.0)
        terrain-state
          (strcase (mp:getval "ESTADO_COTA_TN" vals "PENDIENTE")))
  (cond
    ((= terrain-state "SIN_SUPERFICIE")
      (setq messages
        (cons
          (strcat "No se encontro la superficie "
            *mp-terrain-surface-name*) messages)))
    ((= terrain-state "FUERA_SUPERFICIE")
      (setq messages
        (cons "Los extremos estan fuera de la superficie de terreno" messages)))
    ((= terrain-state "PARCIAL")
      (setq messages
        (cons "Solo se obtuvo la cota de terreno de un extremo" messages))))
  (if (= stage "") (setq messages (cons "Falta la etapa" messages)))
  (if (= substage "") (setq messages (cons "Falta la subetapa" messages)))
  (if (<= length-value 1e-9)
    (setq messages (cons "La longitud no es valida" messages)))
  (if (and (/= type-ini "NINGUNO") (= handle-ini ""))
    (setq messages (cons "El extremo inicial no esta vinculado" messages)))
  (if (and (/= type-fin "NINGUNO") (= handle-fin ""))
    (setq messages (cons "El extremo final no esta vinculado" messages)))
  (if (and (= type-ini "NINGUNO") (/= handle-ini ""))
    (setq messages (cons "El extremo inicial tiene vinculo pero tipo NINGUNO" messages)))
  (if (and (= type-fin "NINGUNO") (/= handle-fin ""))
    (setq messages (cons "El extremo final tiene vinculo pero tipo NINGUNO" messages)))
  (if (and (/= type-ini "NINGUNO") (= id-ini ""))
    (setq messages (cons "Falta el identificador del extremo inicial" messages)))
  (if (and (/= type-fin "NINGUNO") (= id-fin ""))
    (setq messages (cons "Falta el identificador del extremo final" messages)))
  (if (and (/= handle-ini "") (null (handent handle-ini)))
    (setq messages (cons "El vinculo del extremo inicial esta roto" messages)))
  (if (and (/= handle-fin "") (null (handent handle-fin)))
    (setq messages (cons "El vinculo del extremo final esta roto" messages)))
  (foreach link-data (list (list handle-ini type-ini "inicial")
                            (list handle-fin type-fin "final"))
    (if (and (/= (car link-data) "")
             (setq endpoint (handent (car link-data))))
      (progn
        (setq endpoint-base (mp:point-reference-base endpoint)
              actual-type
                (strcase
                  (mp:safe-str (mp:endpoint-type-for-base endpoint-base))))
        (if (not (mp:endpoint-compatible-p base endpoint-base))
          (setq messages
            (cons
              (strcat "El extremo " (caddr link-data)
                " apunta a un elemento incompatible") messages)))
        (if (/= actual-type (cadr link-data))
          (setq messages
            (cons
              (strcat "El tipo declarado del extremo " (caddr link-data)
                " no coincide con el elemento vinculado") messages))))))
  (if (and (/= handle-ini "") (= (strcase handle-ini) (strcase handle-fin)))
    (setq messages (cons "Los dos extremos apuntan al mismo elemento" messages)))
  (if (<= width 1e-9)
    (setq messages (cons "Falta el ancho de zanja" messages)))
  ;; PROFUNDIDAD_MEDIA ya viene calculada en vals (mp:derive-tramo-values la
  ;; llena antes de validar); se usa para elegir el rango correcto de la
  ;; tabla de anchos en vez de asumir el rango mas superficial.
  (setq check-depth (mp:numeric-real (mp:getval "PROFUNDIDAD_MEDIA" vals "")))
  ;; BUG (2026-08-03): mp:default-trench-width con la formula generica
  ;; (max 0.60 (+ diametro 0.40)) casi nunca da un numero limpio a 2
  ;; decimales (ej. 8" -> 0.6032). ANCHO_ZANJA se guarda redondeado a 2
  ;; decimales (rtos ... 2 2), pero minimum-width se recalculaba aqui SIN
  ;; redondear -- la comparacion fallaba (0.60 < 0.6032) aunque el ancho
  ;; guardado fuera exactamente el minimo real. Se redondea minimum-width
  ;; igual que se redondeo width al guardarlo, para comparar a la misma
  ;; precision.
  (setq minimum-width (atof (rtos (mp:default-trench-width base vals check-depth) 2 2)))
  (if (< width (- minimum-width 1e-6))
    (setq messages
      (cons
        (strcat "El ancho de zanja es menor al minimo geometrico de "
          (rtos minimum-width 2 2) " m") messages)))
  (if (< bedding 0.0)
    (setq messages (cons "El espesor de cama no puede ser negativo" messages)))
  (if (mp:hydro-tramo-p base)
    (progn
      (setq diameter (mp:getval "DIAMETRO" vals "")
            diameter-number (mp:numeric-real diameter)
            material (mp:getval "MATERIAL" vals "")
            tn-ini (mp:numeric-real (mp:getval "COTA_TN_INI" vals ""))
            tn-fin (mp:numeric-real (mp:getval "COTA_TN_FIN" vals ""))
            key-ini (mp:numeric-real (mp:getval "COTA_CLAVE_INI" vals ""))
            key-fin (mp:numeric-real (mp:getval "COTA_CLAVE_FIN" vals ""))
            depth-ini (mp:numeric-real (mp:getval "PROFUNDIDAD_INI" vals ""))
            depth-fin (mp:numeric-real (mp:getval "PROFUNDIDAD_FIN" vals "")))
      (if (or (null diameter-number) (<= diameter-number 0.0))
        (setq messages (cons "Falta un diametro valido" messages)))
      (if (= material "") (setq messages (cons "Falta el material" messages)))
      (if (or (null depth-ini) (<= depth-ini 0.0)
              (null depth-fin) (<= depth-fin 0.0))
        (setq messages
          (cons "Faltan cotas completas para calcular la profundidad" messages)))
      (if (and tn-ini key-ini (<= tn-ini key-ini))
        (setq messages
          (cons "La cota de terreno inicial debe estar sobre la clave" messages)))
      (if (and tn-fin key-fin (<= tn-fin key-fin))
        (setq messages
          (cons "La cota de terreno final debe estar sobre la clave" messages)))
      (if (mp:gravity-tramo-p base)
        (progn
          (setq slope (mp:numeric-real (mp:getval "PENDIENTE" vals ""))
                slope-calculated
                  (mp:numeric-real
                    (mp:getval "PENDIENTE_CALCULADA" vals "")))
          (if (null slope)
            (setq messages (cons "Falta la pendiente" messages)))
          (if (and slope (<= slope 0.0))
            (setq messages (cons "La pendiente debe bajar del inicio al final" messages)))
          (if (null slope-calculated)
            (setq messages (cons "Faltan cotas de clave para calcular la pendiente" messages)))
          (if (and slope-calculated (<= slope-calculated 0.0))
            (setq messages (cons "Las cotas no producen flujo descendente" messages)))
          (if (and slope slope-calculated (> (abs (- slope slope-calculated)) 0.05))
            (setq messages
              (cons "La pendiente digitada no coincide con las cotas" messages))))))
    (progn
      (setq ducts (mp:number-or (mp:getval "DUCTOS" vals "0") 0.0)
            free-ducts (mp:number-or (mp:getval "LIBRES" vals "0") 0.0)
            depth (mp:number-or (mp:getval "PROFUNDIDAD" vals "0") 0.0)
            conductor (mp:getval "CONDUCTOR" vals
              (mp:getval "CONDUCTORES" vals ""))
            duct-diameter
              (mp:numeric-real (mp:getval "DIAM_DUCTO" vals ""))
            duct-material (mp:getval "MATERIAL_DUCTO" vals "")
            type-red (strcase (mp:getval "TIPO_RED" vals "")))
      (if (<= ducts 0.0) (setq messages (cons "Falta la cantidad de ductos" messages)))
      (if (/= ducts (fix ducts))
        (setq messages (cons "La cantidad de ductos debe ser entera" messages)))
      (if (or (< free-ducts 0.0) (> free-ducts ducts))
        (setq messages (cons "Los ductos libres no son coherentes" messages)))
      (if (/= free-ducts (fix free-ducts))
        (setq messages (cons "La cantidad de ductos libres debe ser entera" messages)))
      (if (<= depth 0.0) (setq messages (cons "Falta la profundidad" messages)))
      (if (and (> depth 0.0) (<= depth bedding))
        (setq messages
          (cons "La profundidad debe ser mayor que el espesor de cama" messages)))
      (if (or (null duct-diameter) (<= duct-diameter 0.0))
        (setq messages (cons "Falta un diametro de ducto valido" messages)))
      (if (= duct-material "")
        (setq messages (cons "Falta el material del ducto" messages)))
      (if (= conductor "") (setq messages (cons "Falta el conductor" messages)))
      (if (and (= base "TRAMO_E_MT") (/= type-red "MT"))
        (setq messages (cons "El tipo de red debe ser MT" messages)))
      (if (and (= base "TRAMO_E_BT_AP")
               (not (member type-red '("BT" "AP"))))
        (setq messages (cons "El tipo de red debe ser BT o AP" messages)))))
  (setq messages (reverse messages))
  (setq vals
    (mp:alist-set vals "CONTROL_ESTADO" (if messages "REVISAR" "OK")))
  (mp:alist-set vals "CONTROL_MENSAJES" (mp:join-messages messages)))

;; Figura 4 del estudio de suelos (tuberias flexibles, K=0.083): la cama
;; bajo el tubo es Bc/4 (Bc = diametro exterior), con minimo 0.10 m y
;; maximo 0.15 m. Antes del 2026-08-03 el codigo usaba 0.10 m fijo para
;; cualquier diametro -- correcto solo para el extremo inferior del rango.
(defun mp:pipe-bedding-thickness (diameter-m)
  (min 0.15 (max 0.10 (/ diameter-m 4.0)))
)

(defun mp:derive-tramo-values
  (base p1 p2 vals
   / length-2d length-3d length-value mode diameter-m diameter-in ducts width
   bedding bedding-raw replacement-raw replacement-width tn-ini tn-fin key-ini key-fin
   cover-ini cover-fin depth-ini depth-fin depth-mean slope-calculated
   entered-slope excavation bedding-volume element-volume fill surplus
   replacement duct-diameter surface depth-profile depths max-depth-sampled
   critical-depth sample-count)
  (setq length-2d (if (and p1 p2) (mp:distance-2d p1 p2)
                    (mp:number-or (mp:getval "LONGITUD_2D" vals
                      (mp:getval "LONGITUD" vals "0")) 0.0))
        length-3d (if (and p1 p2) (distance p1 p2)
                    (mp:number-or (mp:getval "LONGITUD_3D" vals
                      (mp:getval "LONGITUD" vals "0")) 0.0))
        mode "PLANTA"
        length-value length-2d
        width (mp:number-or (mp:getval "ANCHO_ZANJA" vals "") 0.0))
  ;; diametro adelantado (se vuelve a leer mas abajo dentro de la rama
  ;; hidraulica, sin costo, para no reordenar el resto de la funcion) --
  ;; solo para poder resolver la cama por Bc/4 antes de que se necesite.
  (if (mp:hydro-tramo-p base)
    (setq diameter-in (mp:number-or (mp:getval "DIAMETRO" vals "0") 0.0)
          diameter-m (* 0.0254 diameter-in)))
  (setq bedding-raw (mp:getval "ESPESOR_CAMA" vals ""))
  (setq bedding
    (max 0.0
      (if (/= (vl-string-trim " " (mp:safe-str bedding-raw)) "")
        (mp:number-or bedding-raw 0.10)
        (if diameter-m (mp:pipe-bedding-thickness diameter-m) 0.10))))
  (if (mp:hydro-tramo-p base)
    (progn
      (setq diameter-in (mp:number-or (mp:getval "DIAMETRO" vals "0") 0.0)
            diameter-m (* 0.0254 diameter-in)
            tn-ini (mp:numeric-real (mp:getval "COTA_TN_INI" vals ""))
            tn-fin (mp:numeric-real (mp:getval "COTA_TN_FIN" vals ""))
            key-ini (mp:numeric-real (mp:getval "COTA_CLAVE_INI" vals ""))
            key-fin (mp:numeric-real (mp:getval "COTA_CLAVE_FIN" vals "")))
      (if (and tn-ini key-ini)
        (setq cover-ini (- tn-ini key-ini)
              depth-ini (+ cover-ini diameter-m bedding)))
      (if (and tn-fin key-fin)
        (setq cover-fin (- tn-fin key-fin)
              depth-fin (+ cover-fin diameter-m bedding)))
      (setq depth-mean
        (cond
          ((and depth-ini depth-fin) (/ (+ depth-ini depth-fin) 2.0))
          (depth-ini depth-ini)
          (depth-fin depth-fin)
          (T 0.0)))
      ;; Muestreo de superficie a lo largo del tramo (no solo los 2 pozos):
      ;; la superficie de terreno ya existe en el dibujo, asi que se usa un
      ;; perfil real de profundidad en vez de solo el promedio de extremos,
      ;; que podria subestimar una loma o vaguada intermedia.
      (if (mp:gravity-tramo-p base)
        (progn
          (setq surface (mp:current-terrain-surface))
          (setq sample-count
            (min 200
              (max 2 (fix (+ 0.999999 (/ length-2d 2.50))))))
          (setq depth-profile
            (if (and surface p1 p2 key-ini key-fin)
              (mp:tramo-depth-profile surface p1 p2 key-ini key-fin
                diameter-m bedding sample-count
                (if (boundp '*mp-tramo-road-ref*) *mp-tramo-road-ref* nil))
              (list nil nil)))
          (setq depths (car depth-profile)
                max-depth-sampled (cadr depth-profile))))
      (setq critical-depth (mp:max-nonnil (list depth-ini depth-fin max-depth-sampled)))
      (if (and key-ini key-fin (> length-2d 1e-9))
        (setq slope-calculated (* 100.0 (/ (- key-ini key-fin) length-2d))))
      (setq entered-slope (mp:numeric-real (mp:getval "PENDIENTE" vals "")))
      (if (and (null entered-slope) slope-calculated)
        (setq vals (mp:alist-set vals "PENDIENTE" (rtos slope-calculated 2 3))))
      (setq vals (mp:alist-set vals "PROFUNDIDAD_INI"
                   (if depth-ini (rtos depth-ini 2 3) ""))
            vals (mp:alist-set vals "PROFUNDIDAD_FIN"
                   (if depth-fin (rtos depth-fin 2 3) ""))
            vals (mp:alist-set vals "PROFUNDIDAD_MEDIA"
                   (if (> depth-mean 0.0) (rtos depth-mean 2 3) ""))
            vals (mp:alist-set vals "PENDIENTE_CALCULADA"
                   (if slope-calculated (rtos slope-calculated 2 3) ""))
            element-volume (* pi 0.25 diameter-m diameter-m length-value))
      (if (<= width 1e-9)
        (setq width (mp:default-trench-width base vals critical-depth))))
    (progn
      (setq depth-mean
        (max 0.0 (mp:number-or (mp:getval "PROFUNDIDAD" vals "0") 0.0))
            depth-ini depth-mean
            depth-fin depth-mean
            ducts (max 0.0 (mp:number-or (mp:getval "DUCTOS" vals "0") 0.0))
            duct-diameter
              (* 0.0254 (mp:number-or (mp:getval "DIAM_DUCTO" vals "0") 0.0))
            element-volume
              (* ducts pi 0.25 duct-diameter duct-diameter length-value))
      (setq vals (mp:alist-set vals "PROFUNDIDAD_INI"
                   (if (> depth-mean 0.0) (rtos depth-mean 2 3) ""))
            vals (mp:alist-set vals "PROFUNDIDAD_FIN"
                   (if (> depth-mean 0.0) (rtos depth-mean 2 3) ""))
            vals (mp:alist-set vals "PROFUNDIDAD_MEDIA"
                   (if (> depth-mean 0.0) (rtos depth-mean 2 3) ""))
            vals (mp:alist-set vals "PENDIENTE_CALCULADA" ""))
      (if (<= width 1e-9) (setq width (mp:default-trench-width base vals nil)))))
  ;; Vacio hereda el ancho de zanja; cero explicito significa que no hay
  ;; reposicion superficial (por ejemplo, excavacion en zona verde).
  (setq replacement-raw (mp:getval "ANCHO_REPOSICION" vals "")
        replacement-width
          (if (= (vl-string-trim " " replacement-raw) "")
            width
            (max 0.0 (mp:number-or replacement-raw 0.0))))
  (setq vals (mp:alist-set vals "LONGITUD" (rtos length-value 2 2))
        vals (mp:alist-set vals "LONGITUD_2D" (rtos length-2d 2 2))
        vals (mp:alist-set vals "LONGITUD_3D" (rtos length-3d 2 2))
        vals (mp:alist-set vals "MODO_LONGITUD" mode)
        vals (mp:alist-set vals "ANCHO_ZANJA" (rtos width 2 2))
        vals (mp:alist-set vals "ESPESOR_CAMA" (rtos bedding 2 2))
        vals (mp:alist-set vals "ANCHO_REPOSICION" (rtos replacement-width 2 2)))
  (if *mp-network-construction-enabled*
    (setq excavation
            (cond
              ((and depths (> (length depths) 1))
                (mp:integrate-trench-volume depths length-value width))
              ((> depth-mean 0.0) (* length-value width depth-mean))
              (T 0.0))
          bedding-volume (* length-value width bedding)
          fill (max 0.0 (- excavation bedding-volume element-volume))
          surplus (max 0.0 (- excavation fill))
          replacement (* length-value replacement-width)
          vals (mp:alist-set vals "EXCAVACION_M3" (rtos excavation 2 3))
          vals (mp:alist-set vals "CAMA_M3" (rtos bedding-volume 2 3))
          vals (mp:alist-set vals "VOLUMEN_ELEMENTO_M3" (rtos element-volume 2 3))
          vals (mp:alist-set vals "RELLENO_M3" (rtos fill 2 3))
          vals (mp:alist-set vals "SOBRANTE_M3" (rtos surplus 2 3))
          vals (mp:alist-set vals "REPOSICION_M2" (rtos replacement 2 3))
          vals (mp:alist-set vals "METODO_CANTIDADES"
                 (strcat
                   (if depths "PERFIL_MUESTREADO" "PRELIMINAR_GEOMETRICO")
                   (if (and (boundp '*mp-tramo-road-ref*) *mp-tramo-road-ref*)
                     " (ref. subrasante via)" ""))))
    (setq vals (mp:alist-set vals "EXCAVACION_M3" "")
          vals (mp:alist-set vals "CAMA_M3" "")
          vals (mp:alist-set vals "VOLUMEN_ELEMENTO_M3" "")
          vals (mp:alist-set vals "RELLENO_M3" "")
          vals (mp:alist-set vals "SOBRANTE_M3" "")
          vals (mp:alist-set vals "REPOSICION_M2" "")
          vals
            (mp:alist-set vals "METODO_CANTIDADES"
              "PENDIENTE_PARAMETROS")))
  (mp:validate-tramo-values base vals))

(defun mp:insert-cant-tramo
  (baseb p1 p2 vals / doc ms dist ang blk br vals2 en lay added sync-result)
  (vl-load-com)
  ;; La referencia grafica siempre se dibuja en planta. La longitud 3D se
  ;; conserva por separado para trazabilidad, evitando que un desnivel Z
  ;; haga que el bloque sobrepase el extremo final en la vista en planta.
  (setq dist (mp:distance-2d p1 p2)
        ang (angle p1 p2))
  (if (> dist 1e-9)
    (progn
      (setq vals2
        (mp:auto-terrain-values vals p1 p2))
      (setq vals2 (mp:derive-tramo-values baseb p1 p2 vals2))
      (setq vals2
        (mp:alist-set vals2 "BLOQUE_BASE" baseb))
      (setq vals2
        (mp:alist-set vals2 "ETIQUETA" (mp:label-tramo baseb vals2)))
      (setq vals2
        (mp:alist-set vals2 "PENDIENTE_VIS" (mp:pendiente-label vals2)))
      (setq blk (mp:tramo-block-name baseb dist))
      (if (not (tblsearch "BLOCK" blk))
        (mp:make-cant-tramo-block blk baseb dist vals2))
      (setq added (mp:ensure-block-schema blk baseb T))
      (if (> added 0)
        (setq sync-result
          (vl-catch-all-apply 'vl-cmdf
            (list "_.ATTSYNC" "_N" blk))))
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq ms (vla-get-ModelSpace doc))
      (setq br (vla-InsertBlock ms (mp:3d p1) blk 1.0 1.0 1.0 (float ang)))
      (setq en (vlax-vla-object->ename br))
      (setq lay (mp:vis-layer baseb))
      (if (tblsearch "LAYER" lay) (vla-put-Layer br lay))
      (mp:setatts en vals2)
      (vl-catch-all-apply 'urb:attach-memory-reactor-to-block (list en))
      (princ
        (strcat
          "\nTramo PPTO creado en " lay ": " blk
          " | Cota TN "
          (mp:getval "ESTADO_COTA_TN" vals2 "PENDIENTE") "."))
      en)
    (progn
      (princ "\nNo se creo el tramo: los puntos coinciden.")
      nil)))

(defun mp:insert-cant-point
  (base p vals / doc ms blk br en vals2 lay added sync-result)
  (vl-load-com)
  (setq vals2 (mp:auto-terrain-values vals p nil))
  (if (= (mp:getval "ORIGEN_CREACION" vals2 "") "")
    (setq vals2
      (mp:alist-set vals2 "ORIGEN_CREACION" "MANUAL")))
  (setq vals2 (mp:alist-set vals2 "BLOQUE_BASE" base))
  (setq vals2 (append vals2 (list (cons "ETIQUETA" (mp:label-point base vals2)))))
  (setq blk (mp:point-block-name base))
  (if (not (tblsearch "BLOCK" blk))
    (mp:make-cant-punto-block blk base vals2))
  (setq added (mp:ensure-block-schema blk base nil))
  (if (> added 0)
    (setq sync-result
      (vl-catch-all-apply 'vl-cmdf
        (list "_.ATTSYNC" "_N" blk))))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq br (vla-InsertBlock ms (mp:3d p) blk 1.0 1.0 1.0 0.0))
  (setq en (vlax-vla-object->ename br))
  (setq lay (mp:point-layer base))
  (if (tblsearch "LAYER" lay) (vla-put-Layer br lay))
  (mp:setatts en vals2)
  (princ
    (strcat
      "\nPunto PPTO creado en " lay ": " blk
      " | Cota TN "
      (mp:getval "ESTADO_COTA_TN" vals2 "PENDIENTE") "."))
  en)

(defun mp:dialog-elem-elec (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (and dcl (new_dialog "maipore_elem_elec" dcl))
    (progn
      (mp:fill-popup "blk" *mp-elem-elec-list* 0)
      (mp:fill-popup "etapa" *mp-etapa-list* 0)
      (mp:update-subetapa)
      (mp:fill-popup "lum" *mp-lum-list* 0)
      (mp:fill-popup "led" *mp-led-list* 0)
      (set_tile "serie" "1")
      (set_tile "altura" "8.4")
      (set_tile "brazo" "0.5")
      (set_tile "avance" "0.3")
      (action_tile "etapa" "(mp:update-subetapa)")
      (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
      (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
      (start_dialog)
      (if ok
        (progn
          (setq etapa (mp:item *mp-etapa-list* "etapa"))
          (setq res
            (list
              (cons "BLK" (mp:item *mp-elem-elec-list* "blk"))
              (cons "ID" (mp:gettile "id"))
              (cons "CODIGO" (mp:gettile "id"))
              (cons "SERIE" (mp:gettile "serie"))
              (cons "ETAPA" etapa)
              (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "LOTE" (mp:gettile "lote"))
              (cons "CIRCUITO_AP" (mp:gettile "lote"))
              (cons "CIRCUITO" (mp:gettile "lote"))
              (cons "CD" (mp:gettile "cd"))
              (cons "PF" (mp:gettile "pf"))
              (cons "TIPO_LUMINARIA" (mp:item *mp-lum-list* "lum"))
              (cons "FUENTE_LED" (mp:item *mp-led-list* "led"))
              (cons "ALTURA_M" (mp:gettile "altura"))
              (cons "BRAZO_M" (mp:gettile "brazo"))
              (cons "AVANCE_M" (mp:gettile "avance"))))))))
  (if dcl (unload_dialog dcl))
  res)

(defun mp:dialog-acc-acu (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (and dcl (new_dialog "maipore_acc_acu" dcl))
    (progn
      (mp:fill-popup "acc" *mp-acc-acu-list* 0)
      (mp:fill-popup "etapa" *mp-etapa-list* 0)
      (mp:update-subetapa)
      (mp:fill-popup "diam" *mp-diam-acu-list* 0)
      (mp:fill-popup "diamsal" *mp-diam-acu-list* 0)
      (mp:fill-popup "mat" *mp-material-acu-list* 0)
      (action_tile "etapa" "(mp:update-subetapa)")
      (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
      (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
      (start_dialog)
      (if ok
        (progn
          (setq etapa (mp:item *mp-etapa-list* "etapa"))
          (setq res
            (list
              (cons "TIPO_ACCESORIO" (mp:item *mp-acc-acu-list* "acc"))
              (cons "ETAPA" etapa)
              (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "DIAMETRO" (mp:item *mp-diam-acu-list* "diam"))
              (cons "DIAMETRO_SALIDA" (mp:item *mp-diam-acu-list* "diamsal"))
              (cons "MATERIAL" (mp:item *mp-material-acu-list* "mat"))
              (cons "LOTE" (mp:gettile "lote"))))))))
  (if dcl (unload_dialog dcl))
  res)

(defun mp:endpoint-base (tramo tipo)
  (cond
    ((or (= tipo "") (= tipo "NINGUNO")) nil)
    ((= tipo "POZO")
      (cond
        ((= tramo "TRAMO_ARESIDUAL") "POZO_SANITARIO")
        ((= tramo "TRAMO_ALLUVIAS") "POZO_PLUVIAL")
        ;; Compatibilidad con tramos de acueducto creados antes de 4.13.
        ((= tramo "TRAMO_ACUEDUCTO") "ACCESORIO_ACUEDUCTO")
        (T nil)))
    ((and (= tipo "SUMIDERO") (= tramo "TRAMO_ALLUVIAS")) "SUMIDERO")
    ((and (= tipo "ACCESORIO_ACUEDUCTO")
          (= tramo "TRAMO_ACUEDUCTO"))
      "ACCESORIO_ACUEDUCTO")
    ((member tipo *mp-extremo-elec-list*) tipo)
    (T nil)))

(defun mp:distance-2d (p1 p2)
  (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2))))

(defun mp:point-reference-base (en / obj bname atts base)
  (if (and en (= (cdr (assoc 0 (entget en))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq bname (vla-get-EffectiveName obj))
      (setq atts (mp:att-alist en))
      (setq base (mp:infer-base bname atts))
      (if (and (/= base "") (not (mp:base-is-tramo base))) base ""))))

(defun mp:point-z (point)
  (if (and point (caddr point)) (float (caddr point)) 0.0))

(defun mp:point-distance-3d (p1 p2)
  (distance
    (list (car p1) (cadr p1) (mp:point-z p1))
    (list (car p2) (cadr p2) (mp:point-z p2))))

(defun mp:entity-handle (ename / obj)
  (if ename
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (vla-get-Handle obj))
    ""))

(defun mp:entity-insertion-point (ename / obj point)
  (if ename
    (progn
      (setq obj (vlax-ename->vla-object ename)
            point (vlax-get obj 'InsertionPoint))
      point)))

(defun mp:entity-point-id (ename / atts)
  (if ename
    (progn
      (setq atts (mp:att-alist ename))
      (mp:getval "ID" atts (mp:getval "CODIGO" atts "")))
    ""))

(defun mp:find-point-reference
  (base point id / ss index ename found ip candidate-id positional positional-count)
  ;; Coincidencia estricta: tipo, identificador y posicion 3D dentro de 5 cm.
  ;; Evita confundir redes superpuestas a distintas cotas o nodos cercanos.
  (setq id (strcase (vl-string-trim " " (mp:safe-str id)))
        ss (ssget "_X" '((0 . "INSERT")))
        index 0)
  (if ss
    (while (< index (sslength ss))
        (setq ename (ssname ss index)
              ip (cdr (assoc 10 (entget ename))))
        (if (and ip
                 (<= (mp:point-distance-3d point ip) 0.05)
                 (= (mp:point-reference-base ename) base))
          (progn
            (setq candidate-id
              (strcase
                (vl-string-trim " " (mp:entity-point-id ename))))
            (cond
              ((or (= id "") (= id candidate-id))
                (if (null found) (setq found ename)))
              (T
                ;; Respaldo espacial: si existe UN solo pozo compatible en
                ;; la misma coordenada se reutiliza aunque el segundo tramo
                ;; haya escrito otro ID o lo haya dejado vacio. El merge
                ;; posterior adopta el ID real del bloque conservado.
                (setq positional ename
                      positional-count (1+ (if positional-count positional-count 0)))))))
        (setq index (1+ index))))
  (if found found
    (if (= positional-count 1) positional nil)))

(defun mp:point-exists-p (base point)
  (if (mp:find-point-reference base point "") T nil))

(defun mp:endpoint-compatible-p (tramo base)
  (cond
    ((= tramo "TRAMO_ARESIDUAL") (= base "POZO_SANITARIO"))
    ((= tramo "TRAMO_ALLUVIAS")
      (member base '("POZO_PLUVIAL" "SUMIDERO")))
    ((= tramo "TRAMO_ACUEDUCTO") (= base "ACCESORIO_ACUEDUCTO"))
    ((member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
      (member base (cdr *mp-extremo-elec-list*)))
    (T nil)))

(defun mp:endpoint-type-for-base (base)
  (cond
    ((member base '("POZO_SANITARIO" "POZO_PLUVIAL")) "POZO")
    ((= base "SUMIDERO") "SUMIDERO")
    ((= base "ACCESORIO_ACUEDUCTO") "ACCESORIO_ACUEDUCTO")
    (T base)))

(defun mp:getpoint-wcs (base-point prompt-text / raw-point)
  ;; GETPOINT entrega coordenadas del UCS actual; ActiveX e INSERT usan WCS.
  ;; Esta conversion evita tramos desplazados con UCS girados o trasladados.
  (setq raw-point
    (if base-point
      (getpoint (trans base-point 0 1) prompt-text)
      (getpoint prompt-text)))
  (if raw-point (trans raw-point 1 0) nil))

(defun mp:select-network-endpoint
  (tramo prompt-text base-point / pick ename base point done)
  (while (not done)
    (setq pick
      (entsel
        (strcat prompt-text
          " Seleccione un extremo existente o Enter para indicar un punto: ")))
    (if pick
      (progn
        (setq ename (car pick)
              base (mp:point-reference-base ename))
        (if (mp:endpoint-compatible-p tramo base)
          (setq point (mp:entity-insertion-point ename) done T)
          (prompt
            (strcat "\nEl elemento seleccionado (" (mp:safe-str base)
              ") no es compatible con este tramo."))))
      (progn
        (setq point (mp:getpoint-wcs base-point prompt-text))
        (setq done T))))
  (if point (list point ename) nil))

(defun mp:last-number-token (text / i n c buf best)
  ;; Numeros de pozo suelen ser enteros (32, 33...), a diferencia de las
  ;; cotas. Devuelve el ultimo token numerico del texto seleccionado.
  (setq text (mp:safe-str text) i 1 n (strlen (mp:safe-str text))
        buf "" best nil)
  (while (<= i n)
    (setq c (substr text i 1))
    (if (or (wcmatch c "#")
            (and (= c ".") (> (strlen buf) 0)
                 (not (vl-string-search "." buf))))
      (setq buf (strcat buf c))
      (progn
        (if (> (strlen (vl-string-trim "." buf)) 0) (setq best buf))
        (setq buf "")))
    (setq i (1+ i)))
  (if (> (strlen (vl-string-trim "." buf)) 0) (setq best buf))
  best)

(defun mp:number-from-selected-label (prompt-text / selected ename obj txt layer value)
  (setq selected (nentsel prompt-text))
  (if selected
    (progn
      (setq ename (car selected)
            obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename))
            layer (cdr (assoc 8 (entget ename))))
      (if (and obj (not (vl-catch-all-error-p obj)))
        (setq txt (vl-catch-all-apply 'vla-get-TextString (list obj))))
      (if (vl-catch-all-error-p txt) (setq txt nil))
      (if (null txt) (setq txt (cdr (assoc 1 (entget ename)))))
      (setq value (mp:last-number-token txt))
      (if layer
        (progn
          (setq *mp-node-number-layer* layer)
          (urb:config-write "MP_NODE_NUMBER_LAYER" layer)))
      (if value
        (prompt
          (strcat "\nNumero " value " reconocido en la capa "
            (urb:safe-string layer "sin nombre") "."))
        (prompt "\nEl objeto seleccionado no contiene un numero legible."))))
  value)

(defun mp:prompt-new-endpoint-id (is-final / answer value label)
  (setq label (if is-final "final" "inicial"))
  (setq answer
    (getstring T
      (strcat "\nNumero del extremo " label
        " [S=seleccionar texto/capa] <Enter omite>: ")))
  (cond
    ((= (vl-string-trim " " (mp:safe-str answer)) "") "")
    ((member (strcase answer) '("S" "SELECCIONAR"))
      (setq value
        (mp:number-from-selected-label
          (strcat "\nSeleccione el numero del extremo " label ": ")))
      (mp:safe-str value))
    (T answer)))

(defun mp:reuse-existing-endpoint-selection
  (tramo selection vals is-final / tipo base existing)
  (if (and selection (null (cadr selection)))
    (progn
      (setq tipo
        (mp:getval
          (if is-final "TIPO_EXTREMO_FIN" "TIPO_EXTREMO_INI") vals "NINGUNO")
            base (mp:endpoint-base tramo tipo))
      (if base
        (setq existing (mp:find-point-reference base (car selection) "")))
      (if existing (list (car selection) existing) selection))
    selection))

(defun mp:resolve-new-endpoint-ids
  (tramo vals selection-ini selection-fin / tag)
  ;; Un extremo existente conserva su ID. Solo se solicita el de los
  ;; extremos nuevos y despues de haber definido la geometria.
  (if (cadr selection-ini)
    (setq vals (mp:merge-endpoint-data tramo vals (cadr selection-ini) nil))
    (progn
      (setq tag
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
          "DESDE" "POZO_INI"))
      (setq vals (mp:alist-set vals tag (mp:prompt-new-endpoint-id nil)))))
  (if (cadr selection-fin)
    (setq vals (mp:merge-endpoint-data tramo vals (cadr selection-fin) T))
    (progn
      (setq tag
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
          "HASTA" "POZO_FIN"))
      (setq vals (mp:alist-set vals tag (mp:prompt-new-endpoint-id T)))))
  vals)

(defun mp:endpoint-values (tramo vals is-final base / id result)
  (setq id
    (if is-final
      (mp:getval
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "HASTA" "POZO_FIN")
        vals
        "")
      (mp:getval
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "DESDE" "POZO_INI")
        vals
        "")))
  (setq result
    (list
      (cons "ETAPA" (mp:getval "ETAPA" vals ""))
      (cons "SUBETAPA" (mp:getval "SUBETAPA" vals ""))
      (cons "RED" (mp:getval "RED" vals ""))
      (cons "ID" id)
      (cons "DIAMETRO" (mp:getval "DIAMETRO" vals ""))
      (cons "DUCTOS" (mp:getval "DUCTOS" vals ""))
      (cons "LIBRES" (mp:getval "LIBRES" vals ""))
      (cons "PROFUNDIDAD" (mp:getval "PROFUNDIDAD" vals ""))))
  (if is-final
    (setq result
      (append result
        (list
          (cons "COTA_TN_INI" (mp:getval "COTA_TN_FIN" vals ""))
          (cons "COTA_CLAVE_INI" (mp:getval "COTA_CLAVE_FIN" vals "")))))
    (setq result
      (append result
        (list
          (cons "COTA_TN_INI" (mp:getval "COTA_TN_INI" vals ""))
          (cons "COTA_CLAVE_INI" (mp:getval "COTA_CLAVE_INI" vals ""))))))
  (if (member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
    (setq result
      (append result
        (list
          (cons "TIPO_CAJA"
            (cond
              ((= base "CAMARA_CS276") "CS276")
              ((= base "CAMARA_CS280") "CS280")
              (T "CS281")))))))
  (if (= base "ACCESORIO_ACUEDUCTO")
    (setq result
      (append result
        (list
          (cons "TIPO_ACCESORIO" "OTRO")
          (cons "DIAMETRO_SALIDA" (mp:getval "DIAMETRO" vals ""))
          (cons "MATERIAL" (mp:getval "MATERIAL" vals ""))))))
  result)

(defun mp:insert-auto-endpoint (tramo p vals is-final / tipo base id existing)
  (setq tipo
    (mp:getval
      (if is-final "TIPO_EXTREMO_FIN" "TIPO_EXTREMO_INI")
      vals
      "NINGUNO"))
  (setq base (mp:endpoint-base tramo tipo)
        id
          (mp:getval
            (if is-final
              (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "HASTA" "POZO_FIN")
              (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "DESDE" "POZO_INI"))
            vals ""))
  (if base
    (progn
      (setq existing (mp:find-point-reference base p id))
      (if existing
        existing
        (mp:insert-cant-point base p
          (mp:alist-set
            (mp:endpoint-values tramo vals is-final base)
            "ORIGEN_CREACION" "AUTO_TRAMO"))))))

(defun mp:merge-endpoint-data
  (tramo vals ename is-final / atts base id tag type value terrain-value)
  (if ename
    (progn
      (setq atts (mp:att-alist ename)
            base (mp:point-reference-base ename)
            id (mp:getval "ID" atts (mp:getval "CODIGO" atts ""))
            tag
              (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
                (if is-final "HASTA" "DESDE")
                (if is-final "POZO_FIN" "POZO_INI"))
            vals (mp:alist-set vals tag id)
            vals
              (mp:alist-set vals
                (if is-final "TIPO_EXTREMO_FIN" "TIPO_EXTREMO_INI")
                (mp:endpoint-type-for-base base))
            vals
              (mp:alist-set vals
                (if is-final "HANDLE_EXTREMO_FIN" "HANDLE_EXTREMO_INI")
                (mp:entity-handle ename)))
      ;; La cota de terreno del elemento puntual sirve tambien como respaldo
      ;; para redes secas cuando SUP_TN no pueda consultarse temporalmente.
      (setq terrain-value (mp:getval "COTA_TN_INI" atts ""))
      (if (/= terrain-value "")
        (setq vals
          (mp:alist-set vals
            (if is-final "COTA_TN_FIN" "COTA_TN_INI")
            terrain-value)))
      (if (mp:hydro-tramo-p tramo)
        (progn
          (setq vals
            (mp:alist-set vals
              (if is-final "COTA_CLAVE_FIN" "COTA_CLAVE_INI")
              (mp:getval "COTA_CLAVE_INI" atts "")))))
      (if (and (not (mp:hydro-tramo-p tramo))
               (= (mp:getval "PROFUNDIDAD" vals "") ""))
        (setq vals
          (mp:alist-set vals "PROFUNDIDAD"
            (mp:getval "PROFUNDIDAD" atts ""))))))
  vals)

(defun mp:prepare-linked-endpoints
  (tramo selection-ini selection-fin vals / p1 p2 ename-ini ename-fin)
  (setq p1 (car selection-ini)
        p2 (car selection-fin)
        ename-ini (cadr selection-ini)
        ename-fin (cadr selection-fin))
  (if ename-ini (setq vals (mp:merge-endpoint-data tramo vals ename-ini nil)))
  (if ename-fin (setq vals (mp:merge-endpoint-data tramo vals ename-fin T)))
  (if (null ename-ini)
    (setq ename-ini (mp:insert-auto-endpoint tramo p1 vals nil)))
  (if (null ename-fin)
    (setq ename-fin (mp:insert-auto-endpoint tramo p2 vals T)))
  (if ename-ini (setq vals (mp:merge-endpoint-data tramo vals ename-ini nil)))
  (if ename-fin (setq vals (mp:merge-endpoint-data tramo vals ename-fin T)))
  (if (null ename-ini)
    (setq vals (mp:alist-set vals "HANDLE_EXTREMO_INI" "")))
  (if (null ename-fin)
    (setq vals (mp:alist-set vals "HANDLE_EXTREMO_FIN" "")))
  (list vals ename-ini ename-fin))

(defun mp:insert-auto-endpoints (tramo p1 p2 vals / ename-ini ename-fin)
  (setq ename-ini (mp:insert-auto-endpoint tramo p1 vals nil)
        ename-fin (mp:insert-auto-endpoint tramo p2 vals T))
  (list ename-ini ename-fin))

(defun mp:get-two-points (msg1 msg2 / p1 p2)
  (setq p1 (getpoint msg1))
  (if p1 (setq p2 (getpoint p1 msg2)))
  (if (and p1 p2) (list p1 p2) nil))

(defun mp:create-linked-tramo
  (base vals msg1 msg2
   / doc selection-ini selection-fin p1 p2 prepared ename-ini ename-fin
   new-ini new-fin segment undo-open *error*)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (message)
    (if segment (vl-catch-all-apply 'entdel (list segment)))
    (if new-ini (vl-catch-all-apply 'entdel (list new-ini)))
    (if new-fin (vl-catch-all-apply 'entdel (list new-fin)))
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al crear el tramo vinculado: " message)))
    (princ))
  (setq selection-ini (mp:select-network-endpoint base msg1 nil))
  (if selection-ini
    (setq selection-fin
      (mp:select-network-endpoint base msg2 (car selection-ini))))
  (if (and selection-ini selection-fin)
    (progn
      (setq p1 (car selection-ini)
            p2 (car selection-fin))
      (if (<= (mp:distance-2d p1 p2) 1e-9)
        (prompt "\nNo se creo el tramo: los extremos coinciden en planta.")
        (progn
          ;; Si el usuario marco exactamente un pozo/camara existente sin
          ;; seleccionarlo, se reconoce espacialmente (5 cm) antes de pedir
          ;; numeros. Asi 32-33 seguido de 33-34 hereda 33 automaticamente.
          (setq selection-ini
            (mp:reuse-existing-endpoint-selection base selection-ini vals nil)
                selection-fin
            (mp:reuse-existing-endpoint-selection base selection-fin vals T)
                vals
            (mp:resolve-new-endpoint-ids
              base vals selection-ini selection-fin))
          (vla-StartUndoMark doc)
          (setq undo-open T
                prepared
                  (mp:prepare-linked-endpoints
                    base selection-ini selection-fin vals)
                vals (car prepared)
                ename-ini (cadr prepared)
                ename-fin (caddr prepared)
                new-ini (if (and (null (cadr selection-ini)) ename-ini) ename-ini nil)
                new-fin (if (and (null (cadr selection-fin)) ename-fin) ename-fin nil)
                segment (mp:insert-cant-tramo base p1 p2 vals))
          (if segment
            (progn
              (setq vals (mp:att-alist segment))
              (if (= (mp:getval "CONTROL_ESTADO" vals "REVISAR") "OK")
                (prompt "\nTramo vinculado y validado correctamente.")
                (prompt
                  (strcat "\nTramo creado con observaciones: "
                    (mp:getval "CONTROL_MENSAJES" vals "Revisar datos."))))
              (setq new-ini nil new-fin nil segment nil))
            (progn
              (if new-ini (entdel new-ini))
              (if new-fin (entdel new-fin))
              (setq new-ini nil new-fin nil)))
          (if undo-open
            (progn
              (vla-EndUndoMark doc)
              (setq undo-open nil)))))))
  (princ))

(defun mp:insert-electrical-tramo
  (base msg1 msg2 dialog-fn type-red / vals)
  (mp:ensure-layers)
  (if (setq vals (apply dialog-fn nil))
    (progn
      (setq vals (mp:alist-set vals "TIPO_RED" type-red))
      (mp:create-linked-tramo base vals msg1 msg2)))
  (princ))

(defun urb:create-network-segment-command (/ tipo)
  (if (urb:confirm-meter-units)
    (progn
      (initget "Sanitario Pluvial Acueducto MediaTension BajaTension Alumbrado")
      (setq tipo
        (getkword
          "\nTipo de tramo [Sanitario/Pluvial/Acueducto/MediaTension/BajaTension/Alumbrado] <Sanitario>: "))
      (if (null tipo) (setq tipo "Sanitario"))
      (cond
        ((= tipo "Sanitario")
          (mp:insert-tramo-forced "Aresidual"))
        ((= tipo "Pluvial")
          (mp:insert-tramo-forced "Alluvias"))
        ((= tipo "Acueducto")
          (mp:insert-tramo-forced "Acueducto"))
        ((= tipo "MediaTension")
          (mp:insert-electrical-tramo
            "TRAMO_E_MT"
            "\nExtremo inicial tramo MT: "
            "\nExtremo final tramo MT: "
            'mp:dialog-tramo-mt
            "MT"))
        ((= tipo "BajaTension")
          (mp:insert-electrical-tramo
            "TRAMO_E_BT_AP"
            "\nExtremo inicial tramo BT: "
            "\nExtremo final tramo BT: "
            'mp:dialog-tramo-bt
            "BT"))
        ((= tipo "Alumbrado")
          (mp:insert-electrical-tramo
            "TRAMO_E_BT_AP"
            "\nExtremo inicial tramo alumbrado: "
            "\nExtremo final tramo alumbrado: "
            'mp:dialog-tramo-bt
            "AP"))))
    (prompt "\nCreacion de tramo cancelada: confirme primero las unidades del dibujo."))
  (princ))

(defun urb:create-sanitary-manhole (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Aresidual" "POZO_SANITARIO"))
    (if (setq p (mp:getpoint-wcs nil "\nPunto de pozo sanitario: "))
      (mp:insert-cant-point "POZO_SANITARIO" p vals)))
  (princ))

(defun urb:create-storm-manhole (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Alluvias" "POZO_PLUVIAL"))
    (if (setq p (mp:getpoint-wcs nil "\nPunto de pozo pluvial: "))
      (mp:insert-cant-point "POZO_PLUVIAL" p vals)))
  (princ))

(defun urb:create-inlet (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Alluvias" "SUMIDERO"))
    (if (setq p (mp:getpoint-wcs nil "\nPunto de sumidero: "))
      (mp:insert-cant-point "SUMIDERO" p vals)))
  (princ))

(defun urb:create-electrical-chamber (/ data vals p base)
  (mp:ensure-layers)
  (if (setq data (mp:dialog-caja-electrica))
    (if (setq p (mp:getpoint-wcs nil "\nPunto de caja/camara electrica: "))
      (progn
        (setq base (cdr (assoc "BLK" data)))
        (setq vals (vl-remove (assoc "BLK" data) data))
        (mp:insert-cant-point base p vals))))
  (princ))

(defun urb:create-water-accessory (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-acc-acu))
    (if (setq p (mp:getpoint-wcs nil "\nPunto del accesorio de acueducto: "))
      (mp:insert-cant-point "ACCESORIO_ACUEDUCTO" p vals)))
  (princ))

(defun urb:create-luminaire (/ data vals p base)
  (mp:ensure-layers)
  (if (setq data (mp:dialog-elem-elec))
    (if (setq p (mp:getpoint-wcs nil "\nPunto de insercion elemento electrico: "))
      (progn
        (setq base (cdr (assoc "BLK" data)))
        (setq vals (vl-remove (assoc "BLK" data) data))
        (mp:insert-cant-point base p vals))))
  (princ))

(defun urb:update-quantity-labels-command
  (/ ss i en obj bname atts base lab)
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i) obj (vlax-ename->vla-object en) bname (vla-get-EffectiveName obj))
        (if (mp:is-cant-blockname bname)
          (progn
            (setq atts (mp:att-alist en))
            (setq base (mp:infer-base bname atts))
            (if (/= base "")
              (progn
                (setq lab
                  (if (mp:base-is-tramo base)
                    (mp:label-tramo base atts)
                    (mp:label-point base atts)))
                (mp:setatt-one en "ETIQUETA" lab)
                (if (mp:base-is-tramo base)
                  (mp:setatt-one en "PENDIENTE_VIS" (mp:pendiente-label atts)))))))
        (setq i (1+ i)))
      (princ "\nEtiquetas de cantidades actualizadas."))
    (princ "\nNo se encontraron bloques."))
  (princ))

(defun mp:merge-atts (old new / res pair)
  (setq res old)
  (foreach pair new
    (if (assoc (strcase (car pair)) res)
      (setq res (subst (cons (strcase (car pair)) (cdr pair)) (assoc (strcase (car pair)) res) res))
      (setq res (cons (cons (strcase (car pair)) (cdr pair)) res))))
  res)
(defun mp:reference-geometry-length (obj / doc blks blk bname span scale)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq bname (vla-get-EffectiveName obj))
  (setq blk (vl-catch-all-apply 'vla-Item (list blks bname)))
  (if (vl-catch-all-error-p blk)
    ""
    (progn
      (setq span (mp:block-tramo-length blk))
      (setq scale (abs (vla-get-XScaleFactor obj)))
      (if (> span 1e-9) (rtos (* span scale) 2 2) ""))))

(defun mp:ensure-reference-length (en obj atts / value)
  (setq value (mp:getval "LONGITUD" atts ""))
  (if (= value "")
    (progn
      (setq value (mp:reference-geometry-length obj))
      (if (/= value "") (mp:setatt-one en "LONGITUD" value))))
  value)

(defun mp:reference-plan-points (obj / doc blocks block span scale length-value angle p1 p2)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        blocks (vla-get-Blocks doc)
        block
          (vl-catch-all-apply 'vla-Item
            (list blocks (vla-get-EffectiveName obj))))
  (if (vl-catch-all-error-p block)
    nil
    (progn
      (setq span (mp:block-tramo-length block)
            scale (abs (vla-get-XScaleFactor obj))
            length-value (* span scale)
            angle (vla-get-Rotation obj)
            p1 (vlax-get obj 'InsertionPoint)
            p2
              (list
                (+ (car p1) (* length-value (cos angle)))
                (+ (cadr p1) (* length-value (sin angle)))
                (mp:point-z p1)))
      (list p1 p2 span))))

(defun mp:auto-link-endpoint-value (base point vals is-final / type endpoint-base id found)
  (setq type
    (mp:getval
      (if is-final "TIPO_EXTREMO_FIN" "TIPO_EXTREMO_INI")
      vals "NINGUNO")
        endpoint-base (mp:endpoint-base base type)
        id
          (mp:getval
            (if (member base '("TRAMO_E_MT" "TRAMO_E_BT_AP"))
              (if is-final "HASTA" "DESDE")
              (if is-final "POZO_FIN" "POZO_INI"))
            vals ""))
  (if endpoint-base
    (progn
      (setq found (mp:find-point-reference endpoint-base point id))
      (if found (mp:merge-endpoint-data base vals found is-final) vals))
    vals))

(defun mp:sync-tramo-values
  (ename obj base vals
   / reference p1 p2 span handle-ini handle-fin endpoint-ini endpoint-fin
   linked-p1 linked-p2 length-2d scale)
  (setq reference (mp:reference-plan-points obj))
  (if reference
    (progn
      (setq p1 (car reference)
            p2 (cadr reference)
            span (caddr reference)
            vals (mp:auto-link-endpoint-value base p1 vals nil)
            vals (mp:auto-link-endpoint-value base p2 vals T)
            handle-ini (mp:getval "HANDLE_EXTREMO_INI" vals "")
            handle-fin (mp:getval "HANDLE_EXTREMO_FIN" vals "")
            endpoint-ini (if (/= handle-ini "") (handent handle-ini) nil)
            endpoint-fin (if (/= handle-fin "") (handent handle-fin) nil))
      (if endpoint-ini
        (progn
          (setq linked-p1 (mp:entity-insertion-point endpoint-ini)
                vals (mp:merge-endpoint-data base vals endpoint-ini nil))))
      (if endpoint-fin
        (progn
          (setq linked-p2 (mp:entity-insertion-point endpoint-fin)
                vals (mp:merge-endpoint-data base vals endpoint-fin T))))
      (if (and linked-p1 linked-p2)
        (progn
          (setq p1 linked-p1
                p2 linked-p2
                length-2d (mp:distance-2d p1 p2))
          (if (and (> span 1e-9) (> length-2d 1e-9))
            (progn
              (setq scale (/ length-2d span))
              (vla-put-InsertionPoint obj (mp:3d p1))
              (vla-put-Rotation obj (angle p1 p2))
              (vla-put-XScaleFactor obj (float scale))))))
      (setq vals (mp:auto-terrain-values vals p1 p2))
      (mp:derive-tramo-values base p1 p2 vals))
    (mp:validate-tramo-values base vals)))

(defun mp:update-segments-for-endpoint (endpoint / handle ss index ename obj atts base merged)
  (setq handle (strcase (mp:entity-handle endpoint))
        ss (ssget "_X" '((0 . "INSERT")))
        index 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index)
            atts (mp:att-alist ename)
            base (mp:infer-base
              (vla-get-EffectiveName (vlax-ename->vla-object ename)) atts))
      (if (and (mp:base-is-tramo base)
               (or (= handle (strcase (mp:getval "HANDLE_EXTREMO_INI" atts "")))
                   (= handle (strcase (mp:getval "HANDLE_EXTREMO_FIN" atts "")))))
        (progn
          (setq obj (vlax-ename->vla-object ename)
                merged (mp:sync-tramo-values ename obj base atts))
          (mp:setatts ename merged)
          (mp:setatt-one ename "ETIQUETA" (mp:label-tramo base merged))
          (mp:setatt-one ename "PENDIENTE_VIS" (mp:pendiente-label merged))
          (vla-Update obj)))
      (setq index (1+ index)))))

(defun mp:update-block-after-edit (en vals / obj atts merged base lab lay bname doc saved)
  (setq obj (vlax-ename->vla-object en))
  (setq atts (mp:att-alist en))
  (setq bname (vla-get-EffectiveName obj))
  (setq base (mp:infer-base bname atts))
  (setq merged (mp:merge-atts atts vals))
  (if (/= base "")
    (progn
      (setq lay (mp:edit-layer-for-base base))
      (if (tblsearch "LAYER" lay) (vla-put-Layer obj lay))
      (cond
        ((mp:base-is-tramo base)
          (setq merged (mp:sync-tramo-values en obj base merged)
                saved (mp:setatts en merged))
          (setq lab (mp:label-tramo base merged))
          (mp:setatt-one en "ETIQUETA" lab)
          (mp:setatt-one en "PENDIENTE_VIS" (mp:pendiente-label merged)))
        ((not (mp:base-is-tramo base))
          (setq merged
            (mp:auto-terrain-values
              merged (mp:entity-insertion-point en) nil))
          (setq saved (mp:setatts en merged))
          (setq lab (mp:label-point base merged))
          (mp:setatt-one en "ETIQUETA" lab)
          (mp:update-segments-for-endpoint en)))
      ;; Fuerza la actualizacion visual inmediata de atributos y referencia.
      (vla-Update obj)
      (entupd en)
      (redraw en 1)
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-Regen doc 1)
      (vl-catch-all-apply 'vla-Update (list obj))
      (entupd en)))
  (if (null saved) (setq saved (mp:setatts en vals)))
  saved)

(defun urb:export-networks-csv-command
  (/ fn f ss i en obj bname pt row atts val count h)
  (setq fn (getfiled "Guardar cantidades CSV" (strcat (getvar "DWGPREFIX") "cantidades_maipore.csv") "csv" 1))
  (if fn
    (if (setq f (open fn "w"))
      (progn
        (write-line (vl-string-right-trim *mp-csv-sep* (apply 'strcat (mapcar '(lambda (x) (strcat (mp:csv-safe x) *mp-csv-sep*)) *mp-csv-tags*))) f)
        (setq ss (ssget "X" '((0 . "INSERT"))) count 0)
        (if ss
          (progn
            (setq i 0)
            (while (< i (sslength ss))
              (setq en (ssname ss i) obj (vlax-ename->vla-object en) bname (vla-get-EffectiveName obj))
              (if (mp:is-cant-blockname bname)
                (progn
                  (setq pt (vlax-get obj 'InsertionPoint))
                  (setq atts (mp:att-alist en))
                  (setq row "")
                  (foreach h *mp-csv-tags*
                    (setq val
                      (cond
                        ((= h "BLOQUE") (mp:getval "BLOQUE_BASE" atts bname))
                        ((= h "HANDLE") (vla-get-Handle obj))
                        ((= h "LAYER") (vla-get-Layer obj))
                        ((= h "X") (rtos (car pt) 2 3))
                        ((= h "Y") (rtos (cadr pt) 2 3))
                        (T (cdr (assoc (strcase h) atts)))))
                    (setq row (strcat row (mp:csv-safe val) *mp-csv-sep*)))
                  (write-line (vl-string-right-trim *mp-csv-sep* row) f)
                  (setq count (1+ count))))
              (setq i (1+ i)))))
        (close f)
        (princ (strcat "\nCSV exportado: " fn " | Registros: " (itoa count))))
      (princ "\nNo se pudo abrir el archivo CSV para escritura.")))
  (princ))

(defun mp:block-attdef-tags (blk / tags item)
  (setq tags nil)
  (vlax-for item blk
    (if (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
      (setq tags (cons (strcase (vla-get-TagString item)) tags))))
  tags)

(defun mp:infer-base (bname atts / up red tipo)
  (setq up (strcase (mp:safe-str bname)))
  (cond
    ((/= (mp:getval "BLOQUE_BASE" atts "") "")
      (mp:getval "BLOQUE_BASE" atts ""))
    ((member up (mapcar 'strcase *mp-blocks*)) up)
    ((mp:starts-with up "MP_TRAMO_SAN_") "TRAMO_ARESIDUAL")
    ((mp:starts-with up "MP_TRAMO_PLU_") "TRAMO_ALLUVIAS")
    ((mp:starts-with up "MP_TRAMO_ACU_") "TRAMO_ACUEDUCTO")
    ((mp:starts-with up "MP_TRAMO_MT_") "TRAMO_E_MT")
    ((mp:starts-with up "MP_TRAMO_BTAP_") "TRAMO_E_BT_AP")
    ((= up "MP_PUNTO_POZO_SAN") "POZO_SANITARIO")
    ((= up "MP_PUNTO_POZO_PLU") "POZO_PLUVIAL")
    ((= up "MP_PUNTO_SUMIDERO") "SUMIDERO")
    ((= up "MP_PUNTO_ACC_ACU") "ACCESORIO_ACUEDUCTO")
    ((= up "MP_PUNTO_LUMINARIA") "LUMINARIA_AP")
    ((mp:starts-with up "MP_PUNTO_")
      (substr up 10))
    ((mp:starts-with up "CANT_TRAMO_")
      (setq red (strcase (mp:getval "RED" atts "")))
      (setq tipo (strcase (mp:getval "TIPO_RED" atts "")))
      (cond
        ((= red "ACUEDUCTO") "TRAMO_ACUEDUCTO")
        ((= red "ALLUVIAS") "TRAMO_ALLUVIAS")
        ((= red "ARESIDUAL") "TRAMO_ARESIDUAL")
        ((= tipo "MT") "TRAMO_E_MT")
        ((= tipo "BT/AP") "TRAMO_E_BT_AP")
        (T "")))
    (T "")))

(defun mp:base-is-tramo (base)
  (member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO" "TRAMO_E_MT" "TRAMO_E_BT_AP")))

(defun mp:desired-atts (base is-tramo / specs visible)
  (setq specs (if is-tramo (mp:base-atts-for base) (mp:base-atts-for-point base)))
  (setq visible
    (if (and is-tramo (member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO")))
      (list
        (list "ETIQUETA" "Etiqueta visible" "")
        (list "PENDIENTE_VIS" "Pendiente visible" ""))
      (list (list "ETIQUETA" "Etiqueta visible" ""))))
  (if is-tramo
    (append visible specs)
    (append visible (list (list "BLOQUE_BASE" "Bloque base" base)) specs)))

(defun mp:block-tramo-circle-span (blk / item center x minx maxx)
  ;; Los centros de los circulos definen la longitud geometrica completa.
  (setq minx nil maxx nil)
  (vlax-for item blk
    (if (= (vla-get-ObjectName item) "AcDbCircle")
      (progn
        (setq center
          (vlax-safearray->list
            (vlax-variant-value (vla-get-Center item))))
        (setq x (car center))
        (if (or (null minx) (< x minx)) (setq minx x))
        (if (or (null maxx) (> x maxx)) (setq maxx x)))))
  (if (and minx maxx (> (- maxx minx) 1e-9))
    (- maxx minx)
    0.0))

(defun mp:block-tramo-length (blk / item value best span)
  ;; Prioriza la distancia centro a centro para que el recorte visual
  ;; no reduzca LONGITUD ni las cantidades.
  (setq span (mp:block-tramo-circle-span blk))
  (if (> span 1e-9)
    span
    (progn
      (setq best 0.0)
      (vlax-for item blk
        (if (and (= (vla-get-ObjectName item) "AcDbPolyline")
                 (vlax-property-available-p item 'Length))
          (progn
            (setq value (vla-get-Length item))
            (if (> value best) (setq best value)))))
      best)))

(defun mp:normalize-tramo-graphics (blk base / item span cut width victims removed)
  ;; Ajusta definiciones existentes al borde de sus circulos.
  (setq span (mp:block-tramo-length blk))
  (setq cut (min (max 2.0 *mp-vis-radius*) (/ span 4.0)))
  (setq width (max 0.01 *mp-vis-width*))
  ;; Los circulos de extremos de un tramo hidrosanitario no son pozos:
  ;; eran geometria duplicada. El pozo real es su INSERT puntual enlazado.
  (if (mp:hydro-tramo-p base)
    (progn
      (vlax-for item blk
        (if (= (vla-get-ObjectName item) "AcDbCircle")
          (setq victims (cons item victims))))
      (foreach item victims
        (if (urb:safe-delete item) (setq removed (1+ (if removed removed 0)))))))
  (if (> span 1e-9)
    (vlax-for item blk
      (if (= (vla-get-ObjectName item) "AcDbPolyline")
        (progn
          (vla-put-Coordinates
            item
            (mp:var-dbls
              (if (mp:hydro-tramo-p base)
                (list 0.0 0.0 span 0.0)
                (list cut 0.0 (- span cut) 0.0))))
          (vla-put-ConstantWidth item (float width))
          (vla-Update item)))))
  (list span (if removed removed 0)))

(defun mp:repair-hydro-tramo-definitions
  (/ blocks blk bname base result removed)
  ;; Migra definiciones compartidas ya existentes. No borra ningun INSERT
  ;; de pozo ni modifica sus atributos; solo retira los anillos falsos de
  ;; los bloques lineales CANT_TRAMO/MP_TRAMO hidrosanitarios.
  (setq blocks (vla-get-Blocks (urb:doc)) removed 0)
  (vlax-for blk blocks
    (if (and (= (vla-get-IsLayout blk) :vlax-false)
             (= (vla-get-IsXRef blk) :vlax-false))
      (progn
        (setq bname (vla-get-Name blk)
              base (mp:infer-base bname nil))
        (if (and (mp:base-is-tramo base) (mp:hydro-tramo-p base))
          (progn
            (setq result (mp:normalize-tramo-graphics blk base))
            (setq removed (+ removed (cadr result))))))))
  removed)

(defun mp:normalize-visible-attdefs (blk is-tramo base / item tag span pos)
  (if is-tramo
    (progn
      (setq span (mp:block-tramo-length blk))
      (vlax-for item blk
        (if (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
          (progn
            (setq tag (strcase (vla-get-TagString item)))
            (if (member tag '("ETIQUETA" "PENDIENTE_VIS"))
              (progn
                (setq pos
                  (list
                    (/ span 2.0)
                    (if (= tag "ETIQUETA")
                      (* *mp-vis-tramo-text-height* 1.35)
                      (- (* *mp-vis-tramo-text-height* 1.35)))
                    0.0))
                (mp:center-visible-att item pos *mp-vis-tramo-text-height*)))))))
    (if (member base '("POZO_SANITARIO" "POZO_PLUVIAL"))
      (vlax-for item blk
        (if (and
              (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString item)) "ETIQUETA"))
          (mp:center-visible-att item '(0.0 0.0 0.0) *mp-vis-text-height*))))))

(defun mp:ensure-block-schema (bname base is-tramo / doc blks blk tags specs lay col y added spec tag invisible span pos height display-height)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq blk (vl-catch-all-apply 'vla-Item (list blks bname)))
  (if (vl-catch-all-error-p blk)
    0
    (progn
      (if is-tramo (mp:normalize-tramo-graphics blk base))
      (mp:normalize-visible-attdefs blk is-tramo base)
      (setq tags (mp:block-attdef-tags blk))
      (setq specs (mp:desired-atts base is-tramo))
      (setq lay (if is-tramo (mp:vis-layer base) (mp:point-layer base)))
      (setq col (if is-tramo (mp:vis-color base) (mp:point-color base)))
      (setq display-height
        (if is-tramo *mp-vis-tramo-text-height* *mp-vis-text-height*))
      (setq span (if is-tramo (mp:block-tramo-length blk) 0.0))
      (setq y -100.0 added 0)
      (foreach spec specs
        (setq tag (strcase (car spec)))
        (if (not (member tag tags))
          (progn
            (setq invisible (not (member tag '("ETIQUETA" "PENDIENTE_VIS"))))
            (setq pos
              (cond
                ((= tag "ETIQUETA") (list (/ span 2.0) (* display-height 1.35) 0.0))
                ((= tag "PENDIENTE_VIS") (list (/ span 2.0) (- (* display-height 1.35)) 0.0))
                (T (list 0.0 y 0.0))))
            (setq height (if invisible 0.10 (max 0.10 display-height)))
            (mp:vla-add-att
              blk
              tag
              (cadr spec)
              (if (caddr spec) (caddr spec) "")
              pos
              height
              invisible
              lay
              col)
            (setq tags (cons tag tags))
            (setq y (- y 0.20))
            (setq added (1+ added)))))
      added)))

(defun mp:definition-record (bname defs)
  (assoc (strcase bname) defs))

(defun mp:remove-duplicate-points (/ ss i en obj base atts id ip kept rec removed tol candidate)
  ;; Solo elimina coincidencias inequivocas: mismo tipo, ID y coordenada.
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (setq kept nil removed 0 tol 0.50)
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq base (mp:point-reference-base en))
        (if (/= base "")
          (progn
            (setq obj (vlax-ename->vla-object en))
            (setq atts (mp:att-alist en))
            (setq id
              (strcase
                (vl-string-trim
                  " "
                  (mp:getval "ID" atts (mp:getval "CODIGO" atts "")))))
            (setq ip (vlax-get obj 'InsertionPoint))
            (setq rec nil)
            (if (/= id "")
              (foreach candidate kept
                (if (and
                      (null rec)
                      (= (car candidate) base)
                      (= (cadr candidate) id)
                      (<= (mp:distance-2d ip (caddr candidate)) tol))
                  (setq rec candidate))))
            (if rec
              (progn
                (entdel en)
                (setq removed (1+ removed)))
              (setq kept (cons (list base id ip en) kept)))))
        (setq i (1+ i)))))
  removed)

(defun mp:referenced-endpoint-handles
  (/ ss index ename obj atts base handle result)
  (setq ss (ssget "_X" '((0 . "INSERT")))
        index 0
        result nil)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index)
            obj (vlax-ename->vla-object ename)
            atts (mp:att-alist ename)
            base
              (mp:infer-base
                (vla-get-EffectiveName obj) atts))
      (if (mp:base-is-tramo base)
        (foreach handle
          (list
            (mp:getval "HANDLE_EXTREMO_INI" atts "")
            (mp:getval "HANDLE_EXTREMO_FIN" atts ""))
          (if (and (/= handle "")
                   (not (member (strcase handle) result)))
            (setq result (cons (strcase handle) result)))))
      (setq index (1+ index))))
  result)

(defun mp:cleanup-orphan-auto-points
  (/ referenced ss index ename base atts origin handle deleted result)
  ;; Solo se eliminan puntos creados como auxiliares de un tramo. Los puntos
  ;; creados desde el menu, los heredados y los compartidos se conservan.
  (setq referenced (mp:referenced-endpoint-handles)
        ss (ssget "_X" '((0 . "INSERT")))
        index 0
        deleted 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index)
            base (mp:point-reference-base ename))
      (if (and
            (/= base "")
            (urb:q-modelspace-p ename))
        (progn
          (setq atts (mp:att-alist ename)
                origin
                  (strcase
                    (mp:getval "ORIGEN_CREACION" atts "MANUAL"))
                handle (strcase (mp:entity-handle ename)))
          (if (and
                (= origin "AUTO_TRAMO")
                (not (member handle referenced)))
            (progn
              (setq result
                (vl-catch-all-apply 'entdel (list ename)))
              (if (and
                    (not (vl-catch-all-error-p result))
                    result)
                (setq deleted (1+ deleted)))))))
      (setq index (1+ index))))
  (if (> deleted 0)
    (prompt
      (strcat
        "\nExtremos automaticos huerfanos eliminados: "
        (itoa deleted) ".")))
  deleted)

(defun mp:on-network-command-ended
  (reactor command-data / command result)
  (setq command
    (strcase
      (mp:safe-str
        (if command-data (car command-data) ""))))
  (if (member command '("ERASE" "DELETE" "BORRAR"))
    (setq result
      (vl-catch-all-apply 'mp:cleanup-orphan-auto-points nil)))
  (princ))

(defun mp:install-network-erase-reactor (/ old)
  (if (and
        (boundp '*mp-network-erase-reactor*)
        *mp-network-erase-reactor*)
    (vl-catch-all-apply
      'vlr-remove (list *mp-network-erase-reactor*)))
  (setq *mp-network-erase-reactor*
    (vlr-command-reactor
      nil
      '((:vlr-commandEnded . mp:on-network-command-ended))))
  *mp-network-erase-reactor*)

(defun urb:update-network-blocks-command
  (/ ss i en obj bname atts base is-tramo handle refs defs rec added
   total-added sync-errors sync-result doc removed-dups duplicate-choice
   undo-open *error*)
  (vl-load-com)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (message)
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al actualizar redes: " message)))
    (princ))
  ;; La eliminacion ya no es automatica: el valor por defecto conserva
  ;; todo. Si el usuario acepta, la migracion completa queda en un UNDO.
  (initget "Si No")
  (setq duplicate-choice
    (getkword
      "\nEliminar pozos/puntos duplicados durante la actualizacion [Si/No] <No>: "))
  (vla-StartUndoMark doc)
  (setq undo-open T)
  (setq removed-dups
    (if (= duplicate-choice "Si") (mp:remove-duplicate-points) 0))
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (setq refs nil defs nil total-added 0 sync-errors 0)
  (if ss
    (progn
      ;; Primera pasada: conserva todos los valores y agrupa definiciones.
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq obj (vlax-ename->vla-object en))
        (setq bname (vla-get-EffectiveName obj))
        (if (mp:is-cant-blockname bname)
          (progn
            (setq atts (mp:att-alist en))
            (setq base (mp:infer-base bname atts))
            (if (/= base "")
              (progn
                (setq is-tramo (mp:base-is-tramo base))
                (setq handle (vla-get-Handle obj))
                (setq refs (cons (list handle bname base is-tramo atts) refs))
                (if (not (mp:definition-record bname defs))
                  (setq defs (cons (list (strcase bname) bname base is-tramo) defs)))))))
        (setq i (1+ i)))

      ;; Segunda pasada: agrega ATTDEF faltantes y sincroniza cada definicion.
      (foreach rec defs
        (setq bname (cadr rec) base (caddr rec) is-tramo (cadddr rec))
        (setq added (mp:ensure-block-schema bname base is-tramo))
        (setq total-added (+ total-added added))
        (setq sync-result (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bname)))
        (if (vl-catch-all-error-p sync-result)
          (setq sync-errors (1+ sync-errors))))

      ;; Tercera pasada: restaura valores por handle y repara longitud/etiquetas.
      (foreach rec refs
        (setq en (handent (car rec)))
        (if en
          (progn
            (setq base (caddr rec))
            (setq atts (nth 4 rec))
            (mp:setatts en atts)
            (mp:setatt-one en "BLOQUE_BASE" base)
            (mp:update-block-after-edit en nil))))

      (vla-Regen doc 1)
      (princ
        (strcat
          "\nActualizacion de redes terminada. Bloques: " (itoa (length defs))
          " | Referencias: " (itoa (length refs))
          " | Atributos nuevos: " (itoa total-added)
          " | Pozos duplicados eliminados: " (itoa removed-dups)
          " | Errores de sincronizacion: " (itoa sync-errors))))
    (princ "\nNo se encontraron bloques insertados."))
  (if undo-open
    (progn
      (vla-EndUndoMark doc)
      (setq undo-open nil)))
  (princ))
(defun urb:repair-network-visibility-command (/ doc)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-Regen doc 1)
  (princ "\nCapas PPTO encendidas, descongeladas y desbloqueadas. Dibujo regenerado.")
  (princ))

(defun urb:initialize-network-module-command ()
  (mp:ensure-layers)
  (princ "\nRedes Maipore listas. Use URBANISMO para crear, mantener y exportar; use EDITAR para modificar elementos.")
  (princ))

(princ "\nFunciones de redes integradas en el menu URBANISMO.")
(princ)

;;; ============================================================
;;; MODULO URBANISMO 4 - MENU, VIAS Y PERFILES ESTRATIGRAFICOS
;;; ============================================================

(setq *urb-road-profile-types*
  '("Volumen" "Geotextil" "Geomalla" "Tratamiento"))
(setq *urb-road-profile-scopes* '("Total" "Base"))
(setq *urb-road-alignment-modes* '("Existente" "Nuevo"))
(setq *urb-road-cota-modes* '("Pendiente" "Textos por capa"))
(setq *urb-road-overwidth-modes* '("Ambos" "Derecho" "Izquierdo"))
;; Parametros geometricos editables por dibujo. El dialogo de via solo
;; decide el COSTADO; las magnitudes se administran en Ajustes para que no
;; cambien accidentalmente de una via a otra.
(setq *urb-road-overwidth-left* 1.00)
(setq *urb-road-overwidth-right* 1.00)
(setq *urb-road-crossfall* 0.02)
(setq *urb-road-earthwork-interval* 2.50)
(setq *urb-anden-default-width* 3.50)
;; Perfiles de diseno segun Figura 4.1 (estructuras de pavimento) y
;; estudio de suelos AUS-10786-10 (Alfonso Uribe S.).
;; Capas de arriba hacia abajo, espesores en metros.
;; Geotextil tejido Tipo 2400 (40 kN/m) sobre el rajon en todos los
;; perfiles; traslapo 15% equivale a ~45 cm por rollo (rango 30-60 cm).
;; El rajon de Figura 4.1 incluye el sello de 10 cm.
;;
;; Quinto campo por capa (2026-07-06, opcional): "Base" = se cuantifica
;; solo con el area de la calzada principal, SIN sobreanchos; "Total" o
;; ausente = area completa CON sobreanchos (comportamiento de siempre).
;; Confirmado con el usuario: solo la carpeta asfaltica (Rodadura +
;; Intermedia) va sin sobreancho -- las capas granulares y el
;; mejoramiento si dan soporte estructural hasta el sobreancho.
(setq *urb-road-default-profiles*
  '(("MPD"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.05" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.30" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPI"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.07" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.25" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPK"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.08" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.30" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPG"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.08" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.35" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("VIA B0"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.09" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.25" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPB2-MPC-MPJ-MPHA-MPHB"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.09" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.30" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPN1-MPN2-MPGL-MPM2"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.09" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.35" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("MPPAR-MPE-MPF"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.09" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.40" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Mejoramiento rajon y sello" "Volumen" "0.40" "0")))
    ("ESTUDIO SUELOS PD10"
      (("Rodadura MDC-19" "Volumen" "0.05" "0" "Base")
       ("Intermedia MDC-25" "Volumen" "0.08" "0" "Base")
       ("Base granular BG" "Volumen" "0.20" "0")
       ("Subbase granular SBG" "Volumen" "0.30" "0")
       ("Geotextil tejido T2400" "Geotextil" "0" "15")
       ("Subrasante mejorada SBG" "Volumen" "0.05" "0")
       ("Subrasante mejorada rajon" "Volumen" "0.25" "0")))))

(defun urb:config-dictionary (/ nod found created)
  (setq nod (namedobjdict))
  (setq found (dictsearch nod "URB_CONFIG"))
  (if found
    (cdr (assoc -1 found))
    (progn
      (setq created
        (entmakex
          '((0 . "DICTIONARY")
            (100 . "AcDbDictionary")
            (280 . 0)
            (281 . 1))))
      (if created (dictadd nod "URB_CONFIG" created))
      created)))

(defun urb:string-chunks (value size / result)
  (setq value (urb:safe-string value ""))
  (while (> (strlen value) size)
    (setq result (cons (substr value 1 size) result))
    (setq value (substr value (1+ size))))
  (reverse (cons value result)))

(defun urb:config-read (key / dict record value item)
  (setq dict (urb:config-dictionary))
  (if (and dict (setq record (dictsearch dict key)))
    (progn
      (foreach item record
        (if (= (car item) 1)
          (setq value (strcat (urb:safe-string value "") (cdr item)))))
      value)))

(defun urb:config-write (key value / dict old xrecord data)
  (setq dict (urb:config-dictionary))
  (if dict
    (progn
      (if (setq old (dictsearch dict key))
        (progn
          (dictremove dict key)
          (entdel (cdr (assoc -1 old)))))
      (setq data
        (append
          '((0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1))
          (mapcar '(lambda (part) (cons 1 part))
            (urb:string-chunks value 2000))))
      (setq xrecord (entmakex data))
      (if xrecord (dictadd dict key xrecord))
      (if xrecord value))))

(defun urb:load-geometric-settings (/ value pair)
  (foreach pair
    '(("URB_ROAD_OVERWIDTH_LEFT" *urb-road-overwidth-left* 0.0 20.0)
      ("URB_ROAD_OVERWIDTH_RIGHT" *urb-road-overwidth-right* 0.0 20.0)
      ("URB_ROAD_CROSSFALL" *urb-road-crossfall* 0.0 0.20)
      ("URB_ROAD_EARTHWORK_INTERVAL" *urb-road-earthwork-interval* 0.25 20.0)
      ("URB_ANDEN_DEFAULT_WIDTH" *urb-anden-default-width* 0.20 20.0))
    (setq value
      (urb:parse-real
        (urb:safe-string (urb:config-read (car pair)) "")))
    (if (and value (>= value (nth 2 pair)) (<= value (nth 3 pair)))
      (set (cadr pair) value)))
  (list *urb-road-overwidth-left* *urb-road-overwidth-right*
    *urb-road-crossfall* *urb-road-earthwork-interval*
    *urb-anden-default-width*)
  (setq *urb-anden-road-crossfall* *urb-road-crossfall*)
  (list *urb-road-overwidth-left* *urb-road-overwidth-right*
    *urb-road-crossfall* *urb-road-earthwork-interval*
    *urb-anden-default-width*))

(defun urb:write-geometric-settings-dcl (/ filename)
  (setq filename (urb:temp-file "urb_geometria" ".dcl"))
  (if
    (urb:write-lines filename
      '("urb_geometria : dialog { label = \"Tabla de anchos y calculo\";"
        ": boxed_column { label = \"Parametro | valor por dibujo\";"
        ": row { : text { label = \"Sobreancho izquierdo de via (m)\"; width = 38; } : edit_box { key = \"road_left\"; edit_width = 12; } }"
        ": row { : text { label = \"Sobreancho derecho de via (m)\"; width = 38; } : edit_box { key = \"road_right\"; edit_width = 12; } }"
        ": row { : text { label = \"Bombeo de la calzada (%)\"; width = 38; } : edit_box { key = \"road_cross\"; edit_width = 12; } }"
        ": row { : text { label = \"Intervalo secciones movimiento (m)\"; width = 38; } : edit_box { key = \"road_interval\"; edit_width = 12; } }"
        ": row { : text { label = \"Ancho predeterminado de anden (m)\"; width = 38; } : edit_box { key = \"anden_width\"; edit_width = 12; } }"
        ": text { label = \"El desplegable de la via solo define Ambos, Derecho o Izquierdo.\"; }"
        "} ok_cancel; }"))
    filename))

(defun urb:geometric-settings-capture (/ left right cross interval anden)
  (setq left (urb:parse-real (get_tile "road_left"))
        right (urb:parse-real (get_tile "road_right"))
        cross (urb:parse-real (get_tile "road_cross"))
        interval (urb:parse-real (get_tile "road_interval"))
        anden (urb:parse-real (get_tile "anden_width")))
  (cond
    ((or (null left) (< left 0.0) (> left 20.0))
      (alert "El sobreancho izquierdo debe estar entre 0 y 20 m.") nil)
    ((or (null right) (< right 0.0) (> right 20.0))
      (alert "El sobreancho derecho debe estar entre 0 y 20 m.") nil)
    ((or (null cross) (< cross 0.0) (> cross 20.0))
      (alert "El bombeo debe estar entre 0% y 20%.") nil)
    ((or (null interval) (< interval 0.25) (> interval 20.0))
      (alert "El intervalo debe estar entre 0.25 m y 20 m.") nil)
    ((or (null anden) (< anden 0.20) (> anden 20.0))
      (alert "El ancho del anden debe estar entre 0.20 m y 20 m.") nil)
    (T
      (setq *urb-road-overwidth-left* left
            *urb-road-overwidth-right* right
            *urb-road-crossfall* (/ cross 100.0)
            *urb-anden-road-crossfall* (/ cross 100.0)
            *urb-road-earthwork-interval* interval
            *urb-anden-default-width* anden)
      (urb:config-write "URB_ROAD_OVERWIDTH_LEFT" (rtos left 2 6))
      (urb:config-write "URB_ROAD_OVERWIDTH_RIGHT" (rtos right 2 6))
      (urb:config-write "URB_ROAD_CROSSFALL" (rtos (/ cross 100.0) 2 8))
      (urb:config-write "URB_ROAD_EARTHWORK_INTERVAL" (rtos interval 2 6))
      (urb:config-write "URB_ANDEN_DEFAULT_WIDTH" (rtos anden 2 6))
      T)))

(defun urb:geometric-settings-command (/ filename dcl ok)
  (urb:load-geometric-settings)
  (setq filename (urb:write-geometric-settings-dcl)
        dcl (if filename (load_dialog filename) -1))
  (if (and (> dcl 0) (new_dialog "urb_geometria" dcl))
    (progn
      (set_tile "road_left" (rtos *urb-road-overwidth-left* 2 3))
      (set_tile "road_right" (rtos *urb-road-overwidth-right* 2 3))
      (set_tile "road_cross" (rtos (* 100.0 *urb-road-crossfall*) 2 2))
      (set_tile "road_interval" (rtos *urb-road-earthwork-interval* 2 2))
      (set_tile "anden_width" (rtos *urb-anden-default-width* 2 2))
      (action_tile "accept"
        "(if (urb:geometric-settings-capture) (done_dialog 1))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq ok (= 1 (start_dialog)))))
  (if (> dcl 0) (unload_dialog dcl))
  (if filename (vl-catch-all-apply 'vl-file-delete (list filename)))
  (if ok
    (prompt "\nTabla de anchos, bombeo e intervalo guardada para este dibujo."))
  (princ))

(defun mp:load-tramo-appearance-settings (/ value)
  ;; Ajustes por DWG: al abrir otro proyecto se respetan sus escalas y el
  ;; valor predeterminado sigue disponible en dibujos nuevos.
  (setq value
    (urb:parse-real
      (urb:safe-string (urb:config-read "MP_TRAMO_LINE_WIDTH") "")))
  (if (and value (>= value 0.01) (<= value 20.0))
    (setq *mp-vis-width* value))
  (setq value
    (urb:parse-real
      (urb:safe-string (urb:config-read "MP_TRAMO_TEXT_HEIGHT") "")))
  (if (and value (>= value 0.10) (<= value 50.0))
    (setq *mp-vis-tramo-text-height* value))
  (list *mp-vis-width* *mp-vis-tramo-text-height*)
)

(defun mp:apply-tramo-appearance-to-drawing
  (/ blocks blk bname base definitions ss index ename obj atts att tag refs)
  ;; Las polilineas viven en la definicion compartida; los textos visibles
  ;; son referencias de atributo y se actualizan tambien en cada INSERT.
  (setq blocks (vla-get-Blocks (urb:doc)) definitions 0 refs 0)
  (vlax-for blk blocks
    (if (and (= (vla-get-IsLayout blk) :vlax-false)
             (= (vla-get-IsXRef blk) :vlax-false))
      (progn
        (setq bname (vla-get-Name blk)
              base (mp:infer-base bname nil))
        (if (mp:base-is-tramo base)
          (progn
            (mp:normalize-tramo-graphics blk base)
            (mp:normalize-visible-attdefs blk T base)
            (setq definitions (1+ definitions)))))))
  (setq ss (ssget "_X" '((0 . "INSERT"))) index 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index)
            obj (vlax-ename->vla-object ename)
            base (mp:infer-base (vla-get-EffectiveName obj) (mp:att-alist ename)))
      (if (and (mp:base-is-tramo base)
               (= (vla-get-HasAttributes obj) :vlax-true))
        (progn
          (setq atts (vlax-invoke obj 'GetAttributes))
          (foreach att atts
            (setq tag (strcase (vla-get-TagString att)))
            (if (member tag '("ETIQUETA" "PENDIENTE_VIS"))
              (progn
                (vl-catch-all-apply 'vla-put-Height
                  (list att (float *mp-vis-tramo-text-height*)))
                (vla-Update att))))
          (setq refs (1+ refs))))
      (setq index (1+ index))))
  (vla-Regen (urb:doc) 1)
  (list definitions refs)
)

(defun mp:write-tramo-appearance-dcl (/ filename)
  (setq filename (urb:temp-file "urb_tramo_apariencia" ".dcl"))
  (if
    (urb:write-lines filename
      '("urb_tramo_apariencia : dialog { label = \"Apariencia de tramos\";"
        ": boxed_column { label = \"Geometria y datos visibles\";"
        ": edit_box { label = \"Espesor de linea del tramo (m)\"; key = \"line_width\"; edit_width = 12; }"
        ": edit_box { label = \"Altura de datos del tramo (m)\"; key = \"text_height\"; edit_width = 12; }"
        ": text { label = \"Se aplica a tramos existentes y a los que se creen despues.\"; } }"
        "ok_cancel; }"))
    filename)
)

(defun mp:tramo-appearance-capture (/ line-width text-height updated)
  (setq line-width (urb:parse-real (get_tile "line_width"))
        text-height (urb:parse-real (get_tile "text_height")))
  (cond
    ((or (null line-width) (< line-width 0.01) (> line-width 20.0))
      (alert "El espesor debe estar entre 0.01 m y 20.00 m.") nil)
    ((or (null text-height) (< text-height 0.10) (> text-height 50.0))
      (alert "La altura de los datos debe estar entre 0.10 m y 50.00 m.") nil)
    (T
      (setq *mp-vis-width* line-width
            *mp-vis-tramo-text-height* text-height)
      (urb:config-write "MP_TRAMO_LINE_WIDTH" (rtos line-width 2 6))
      (urb:config-write "MP_TRAMO_TEXT_HEIGHT" (rtos text-height 2 6))
      (setq *mp-tramo-appearance-result*
        (mp:apply-tramo-appearance-to-drawing))
      T))
)

(defun mp:tramo-appearance-command (/ filename dcl ok result)
  (mp:load-tramo-appearance-settings)
  (setq *mp-tramo-appearance-result* nil
        filename (mp:write-tramo-appearance-dcl)
        dcl (if filename (load_dialog filename) -1))
  (if (and (> dcl 0) (new_dialog "urb_tramo_apariencia" dcl))
    (progn
      (set_tile "line_width" (rtos *mp-vis-width* 2 3))
      (set_tile "text_height" (rtos *mp-vis-tramo-text-height* 2 3))
      (action_tile "accept"
        "(if (mp:tramo-appearance-capture) (done_dialog 1))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq ok (= 1 (start_dialog)))))
  (if (> dcl 0) (unload_dialog dcl))
  (if filename (vl-catch-all-apply 'vl-file-delete (list filename)))
  (if ok
    (progn
      (setq result *mp-tramo-appearance-result*)
      (prompt
        (strcat
          "\nApariencia actualizada: espesor " (rtos *mp-vis-width* 2 3)
          " m | datos " (rtos *mp-vis-tramo-text-height* 2 3)
          " m | definiciones " (itoa (if result (car result) 0))
          " | tramos insertados " (itoa (if result (cadr result) 0)) "."))))
  (princ)
)

;; vl-princ-to-string (lo que se usaba aqui antes) NO conserva las
;; comillas de los strings dentro de una lista -- un perfil como "MPD"
;; se guardaba como texto sin comillas y al leerlo de vuelta con
;; (read ...) se convertia en el SIMBOLO MPD en vez de la cadena "MPD".
;; Eso rompia add_list mas adelante ("bad argument type: stringp MPD").
;; prin1 si conserva las comillas (por eso es "leible" de vuelta), pero
;; solo escribe a un stream, no devuelve un string directamente; por
;; eso se usa un archivo temporal como intermediario.
(defun urb:serialize-lisp (value / filename stream text)
  (setq filename (urb:temp-file "urb_config" ".txt"))
  (setq stream (open filename "w"))
  (if stream
    (progn
      (prin1 value stream)
      (close stream)
      (setq stream (open filename "r"))
      (setq text (read-line stream))
      (close stream)
      (vl-catch-all-apply 'vl-file-delete (list filename))))
  (if text text (vl-princ-to-string value))
)

;; Auto-reparacion: si el dibujo ya tiene una biblioteca guardada con el
;; bug anterior (strings convertidos en simbolos), esta validacion lo
;; detecta y urb:road-profiles la reemplaza por los valores por defecto,
;; guardados correctamente esta vez con urb:serialize-lisp.
(defun urb:valid-road-profiles-p (profiles / ok profile layer)
  (setq ok (and (listp profiles) (> (length profiles) 0)))
  (foreach profile profiles
    (if (not (and (listp profile)
                  (stringp (car profile))
                  (listp (cadr profile))))
      (setq ok nil)
      (foreach layer (cadr profile)
        (if (not (and (listp layer)
                      (stringp (nth 0 layer)) (stringp (nth 1 layer))
                      (stringp (nth 2 layer)) (stringp (nth 3 layer))))
          (setq ok nil)))))
  ok
)

;; Normaliza las capas conocidas al nombre corto del MATERIAL. Las
;; descripciones de actividad ("Suministro, extendida...") hacian ilegible
;; la paleta Properties y no aportaban informacion adicional al metrado.
;; Las capas personalizadas del usuario permanecen intactas.
(defun urb:budget-road-layer-name (name)
  (cond
    ((or (urb:string-equal-p name "Rodadura MDC-19")
         (urb:string-equal-p name
           "Suministro, extendida y compactacion de Rodadura Asfaltica MD-12"))
      "Rodadura Asfaltica MD-12")
    ((or (urb:string-equal-p name "Intermedia MDC-25")
         (urb:string-equal-p name
           "Suministro, extendida y compactacion de Base Asfaltica MD-20"))
      "Base Asfaltica MD-20")
    ((or (urb:string-equal-p name "Base granular BG")
         (urb:string-equal-p name
           "Suministro e instalacion de base granular BG-A"))
      "Base granular BG-A")
    ((or (urb:string-equal-p name "Subbase granular SBG")
         (urb:string-equal-p name
           "Suministro e instalacion de subbase granular SBG-A"))
      "Subbase granular SBG-A")
    ((or (urb:string-equal-p name "Geotextil tejido T2400")
         (urb:string-equal-p name
           "Suministro y colocacion de geotextil Tejido 2400"))
      "Geotextil tejido 2400")
    ((or (urb:string-equal-p name "Subrasante mejorada SBG")
         (urb:string-equal-p name
           "Suministro e instalacion de sello en subbase granular SBG-C"))
      "Sello subbase granular SBG-C")
    ((or (urb:string-equal-p name "Subrasante mejorada rajon")
         (urb:string-equal-p name
           "Suministro y colocacion de piedra rajon y/o media zonga"))
      "Piedra rajon y/o media zonga")
    (T name))
)

(defun urb:migrate-budget-road-layer
  (layer / name thickness seal-thickness rajon-thickness scope)
  (setq name (urb:safe-string (nth 0 layer) "")
        scope (urb:safe-string (nth 4 layer) "Total"))
  (if (urb:string-equal-p name "Mejoramiento rajon y sello")
    (progn
      ;; Los perfiles base documentan un sello de 10 cm incluido dentro
      ;; del mejoramiento. Se separa sin cambiar el espesor total.
      (setq thickness (max 0.0 (atof (urb:safe-string (nth 2 layer) "0")))
            seal-thickness (min 0.10 thickness)
            rajon-thickness (max 0.0 (- thickness seal-thickness)))
      (append
        (if (> seal-thickness 1e-9)
          (list
            (list
              "Sello subbase granular SBG-C"
              "Volumen" (rtos seal-thickness 2 4) "0" scope))
          nil)
        (if (> rajon-thickness 1e-9)
          (list
            (list
              "Piedra rajon y/o media zonga"
              "Volumen" (rtos rajon-thickness 2 4) "0" scope))
          nil)))
    (list
      (cons (urb:budget-road-layer-name name) (cdr layer))))
)

(defun urb:migrate-budget-road-profiles
  (profiles / result profile layers layer)
  (foreach profile profiles
    (setq layers nil)
    (foreach layer (cadr profile)
      (setq layers
        (append layers (urb:migrate-budget-road-layer layer))))
    (setq result
      (append result (list (list (car profile) layers)))))
  result
)

(defun urb:road-profiles (/ raw parsed valid migrated)
  (setq raw (urb:config-read "ROAD_PROFILES"))
  (if (and raw (/= raw ""))
    (setq parsed (vl-catch-all-apply 'read (list raw))))
  (if (vl-catch-all-error-p parsed) (setq parsed nil))
  ;; La validacion tambien se blinda: si los datos guardados vienen de
  ;; una version anterior con datos corruptos, revisarlos no deberia
  ;; poder tronar el comando completo -- cualquier error aqui se trata
  ;; igual que "no es valido" y cae a los valores por defecto.
  (if parsed
    (setq valid (vl-catch-all-apply 'urb:valid-road-profiles-p (list parsed))))
  (if (or (null parsed) (vl-catch-all-error-p valid) (not valid))
    (progn
      (setq parsed *urb-road-default-profiles*)
      (urb:config-write "ROAD_PROFILES" (urb:serialize-lisp parsed))))
  (setq migrated (urb:migrate-budget-road-profiles parsed))
  (if (not (equal migrated parsed))
    (progn
      (setq parsed migrated)
      (urb:config-write "ROAD_PROFILES" (urb:serialize-lisp parsed))))
  parsed)

(defun urb:save-road-profiles (profiles)
  (urb:config-write "ROAD_PROFILES" (urb:serialize-lisp profiles))
  profiles)

(defun urb:road-profile-names (/ result profile)
  (foreach profile (urb:road-profiles)
    (setq result (cons (car profile) result)))
  (reverse result))

(defun urb:road-profile-by-name (name / found profile)
  (foreach profile (urb:road-profiles)
    (if (urb:string-equal-p (car profile) name)
      (setq found profile)))
  found)

(defun urb:replace-road-profile (profiles old-name new-profile / result profile)
  (foreach profile profiles
    (if (and old-name (urb:string-equal-p (car profile) old-name))
      (setq result (cons new-profile result))
      (setq result (cons profile result))))
  (if (null old-name) (setq result (cons new-profile result)))
  (reverse result))

(defun urb:remove-road-profile (profiles name / result profile)
  (foreach profile profiles
    (if (not (urb:string-equal-p (car profile) name))
      (setq result (cons profile result))))
  (reverse result))

;; 4.1.0: incorpora al DWG actual los perfiles de diseno que falten,
;; sin tocar los que el usuario ya creo o modifico. Los dibujos nuevos
;; los reciben solos; los dibujos con biblioteca ya guardada usan esto.
(defun urb:merge-default-road-profiles (/ profiles candidate added)
  (setq profiles (urb:road-profiles))
  (setq added 0)
  (foreach candidate *urb-road-default-profiles*
    (if (not
          (vl-some
            '(lambda (profile)
              (urb:string-equal-p (car profile) (car candidate)))
            profiles))
      (progn
        (setq profiles (append profiles (list candidate)))
        (setq added (1+ added)))))
  (if (> added 0)
    (urb:save-road-profiles profiles))
  added)

(defun urb:load-base-profiles-command (/ added)
  (setq added (urb:merge-default-road-profiles))
  (if (> added 0)
    (prompt
      (strcat
        "\nPerfiles de diseno agregados a este dibujo: "
        (itoa added) "."))
    (prompt
      "\nEste dibujo ya tiene todos los perfiles de diseno."))
  (princ)
)

(defun urb:road-profile-in-use-p (name / ss index data found)
  (setq ss (ssget "_X" '((-3 ("URB_VIA")))))
  (if ss
    (progn
      (setq index 0)
      (while (and (< index (sslength ss)) (not found))
        (setq data
          (urb:get-xdata-strings (ssname ss index) "URB_VIA"))
        (if (and data (> (length data) 4)
                 (urb:string-equal-p (nth 4 data) name))
          (setq found T))
        (setq index (1+ index)))))
  found)

(defun urb:write-road-profile-dcl (/ filename)
  (setq filename (urb:temp-file "urbanismo_via_perfiles" ".dcl"))
  (if
    (urb:write-lines filename
      '("urb_profile_manager : dialog { label = \"Perfiles estratigraficos de vias\";"
        ": list_box { label = \"Perfiles disponibles\"; key = \"profiles\"; height = 9; width = 48; }"
        ": row { : button { label = \"Nuevo\"; key = \"new\"; } : button { label = \"Editar\"; key = \"edit\"; } : button { label = \"Eliminar\"; key = \"delete\"; } }"
        "cancel_button; }"
        "urb_profile_editor : dialog { label = \"Perfil estratigrafico vial\";"
        ": edit_box { label = \"Nombre del perfil\"; key = \"name\"; edit_width = 30; }"
        ": list_box { label = \"Capas de arriba hacia abajo\"; key = \"layers\"; height = 9; width = 62; }"
        ": boxed_column { label = \"Capa\";"
        ": edit_box { label = \"Material\"; key = \"material\"; edit_width = 30; }"
        ": popup_list { label = \"Tipo\"; key = \"type\"; }"
        ": edit_box { label = \"Espesor (cm, solo volumen)\"; key = \"thickness\"; edit_width = 12; }"
        ": edit_box { label = \"Traslapo (%, geosinteticos)\"; key = \"overlap\"; edit_width = 12; }"
        ": popup_list { label = \"Area de aplicacion\"; key = \"scope\"; }"
        ": row { : button { label = \"Agregar\"; key = \"add_layer\"; } : button { label = \"Actualizar\"; key = \"update_layer\"; } : button { label = \"Quitar\"; key = \"remove_layer\"; } } }"
        "ok_cancel; }"))
    filename))

;; BUG (mismo patron de distance/length): "type" es una funcion nativa
;; de AutoLISP; usarla como variable local tapa la funcion mientras esta
;; activa, y urb:string-equal-p (via urb:safe-string) SI llama (type
;; value) internamente -- rompe con "no function definition: TYPE".
(defun urb:profile-layer-label (layer / layer-type layer-scope)
  (setq layer-type (nth 1 layer))
  (setq layer-scope (urb:safe-string (nth 4 layer) "Total"))
  (strcat (nth 0 layer) " | " layer-type
    (if (urb:string-equal-p layer-type "Volumen")
      (strcat " | " (rtos (* 100.0 (atof (nth 2 layer))) 2 2) " cm")
      (strcat " | traslapo " (rtos (atof (nth 3 layer)) 2 1) "%"))
    " | " layer-scope))

(defun urb:profile-editor-refresh (/ layer)
  (start_list "layers")
  (foreach layer *urb-profile-edit-layers*
    (add_list (urb:profile-layer-label layer)))
  (end_list)
  (set_tile "layers" "0")
  (if *urb-profile-edit-layers* (urb:profile-editor-select "0")))

(defun urb:profile-editor-select (value / layer)
  (setq *urb-profile-layer-index* (atoi value))
  (setq layer (nth *urb-profile-layer-index* *urb-profile-edit-layers*))
  (if layer
    (progn
      (set_tile "material" (nth 0 layer))
      (set_tile "type" (itoa (urb:index-of (nth 1 layer) *urb-road-profile-types*)))
      (set_tile "thickness" (rtos (* 100.0 (atof (nth 2 layer))) 2 2))
      (set_tile "overlap" (rtos (atof (nth 3 layer)) 2 2))
      (set_tile "scope"
        (itoa
          (urb:index-of
            (urb:safe-string (nth 4 layer) "Total")
            *urb-road-profile-scopes*))))))

;; "type" tapa la funcion nativa mientras esta activa (ver nota en
;; urb:profile-layer-label); renombrado a layer-type.
(defun urb:profile-editor-layer-from-tiles
  (/ material layer-type thickness overlap layer-scope)
  (setq material (vl-string-trim " " (get_tile "material")))
  (setq layer-type (nth (atoi (get_tile "type")) *urb-road-profile-types*))
  (setq thickness (urb:parse-real (get_tile "thickness")))
  (setq overlap (urb:parse-real (get_tile "overlap")))
  (setq layer-scope
    (nth (atoi (get_tile "scope")) *urb-road-profile-scopes*))
  (cond
    ((= material "") (alert "Escriba el material de la capa.") nil)
    ((null thickness) (alert "El espesor no es un numero valido.") nil)
    ((null overlap) (alert "El traslapo no es un numero valido.") nil)
    ((and (urb:string-equal-p layer-type "Volumen") (<= thickness 0.0))
      (alert "Las capas volumetricas requieren un espesor mayor que cero.") nil)
    (T
      (setq thickness (/ thickness 100.0))
      (setq overlap (max 0.0 overlap))
      (list material layer-type (rtos thickness 2 6)
            (rtos overlap 2 4) layer-scope))))

(defun urb:profile-editor-add-layer (/ layer)
  (if (setq layer (urb:profile-editor-layer-from-tiles))
    (progn
      (setq *urb-profile-edit-layers*
        (append *urb-profile-edit-layers* (list layer)))
      (urb:profile-editor-refresh))))

(defun urb:profile-editor-update-layer (/ layer index result item position)
  (if (and *urb-profile-edit-layers*
           (setq layer (urb:profile-editor-layer-from-tiles)))
    (progn
      (setq index 0)
      (foreach item *urb-profile-edit-layers*
        (setq result
          (append result
            (list (if (= index *urb-profile-layer-index*) layer item))))
        (setq index (1+ index)))
      (setq *urb-profile-edit-layers* result)
      (urb:profile-editor-refresh))))

(defun urb:profile-editor-remove-layer (/ index result item)
  (if *urb-profile-edit-layers*
    (progn
      (setq index 0)
      (foreach item *urb-profile-edit-layers*
        (if (/= index *urb-profile-layer-index*)
          (setq result (append result (list item))))
        (setq index (1+ index)))
      (setq *urb-profile-edit-layers* result)
      (urb:profile-editor-refresh))))

(defun urb:profile-editor-accept ()
  (setq *urb-profile-edit-name* (vl-string-trim " " (get_tile "name")))
  (cond
    ((= *urb-profile-edit-name* "")
      (alert "Escriba un nombre para el perfil.") nil)
    ((null *urb-profile-edit-layers*)
      (alert "Agregue al menos una capa.") nil)
    (T T)))

(defun urb:edit-road-profile (profile / dcl result)
  (setq *urb-profile-edit-name* (if profile (car profile) ""))
  (setq *urb-profile-edit-layers* (if profile (cadr profile) nil))
  (setq *urb-profile-layer-index* 0)
  (setq dcl (load_dialog (urb:write-road-profile-dcl)))
  (if (and (> dcl 0) (new_dialog "urb_profile_editor" dcl))
    (progn
      (set_tile "name" *urb-profile-edit-name*)
      (urb:fill-popup "type" *urb-road-profile-types* 0)
      (urb:fill-popup "scope" *urb-road-profile-scopes* 0)
      (set_tile "thickness" "0.00")
      (set_tile "overlap" "0.00")
      (urb:profile-editor-refresh)
      (action_tile "layers" "(urb:profile-editor-select $value)")
      (action_tile "add_layer" "(urb:profile-editor-add-layer)")
      (action_tile "update_layer" "(urb:profile-editor-update-layer)")
      (action_tile "remove_layer" "(urb:profile-editor-remove-layer)")
      (action_tile "accept" "(if (urb:profile-editor-accept) (done_dialog 1))")
      (action_tile "cancel" "(done_dialog 0)")
      (if (= 1 (start_dialog))
        (setq result (list *urb-profile-edit-name* *urb-profile-edit-layers*)))))
  (if (> dcl 0) (unload_dialog dcl))
  result)

(defun urb:profile-manager-dialog (profiles / dcl action index profile)
  (setq dcl (load_dialog (urb:write-road-profile-dcl)))
  (if (and (> dcl 0) (new_dialog "urb_profile_manager" dcl))
    (progn
      (start_list "profiles")
      (foreach profile profiles (add_list (car profile)))
      (end_list)
      (set_tile "profiles" "0")
      (action_tile "new" "(setq action \"new\" index (atoi (get_tile \"profiles\")))(done_dialog 1)")
      (action_tile "edit" "(setq action \"edit\" index (atoi (get_tile \"profiles\")))(done_dialog 1)")
      (action_tile "delete" "(setq action \"delete\" index (atoi (get_tile \"profiles\")))(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (start_dialog)))
  (if (> dcl 0) (unload_dialog dcl))
  (if action (list action index)))

(defun urb:manage-road-profiles (/ profiles choice action index old edited continue)
  (setq continue T)
  (while continue
    (setq profiles (urb:road-profiles))
    (setq choice (urb:profile-manager-dialog profiles))
    (if (null choice)
      (setq continue nil)
      (progn
        (setq action (car choice) index (cadr choice))
        (setq old (nth index profiles))
        (cond
          ((= action "new")
            (if (setq edited (urb:edit-road-profile nil))
              (urb:save-road-profiles
                (urb:replace-road-profile profiles nil edited))))
          ((= action "edit")
            (if (and old (setq edited (urb:edit-road-profile old)))
              (if (and
                    (not (urb:string-equal-p (car old) (car edited)))
                    (urb:road-profile-in-use-p (car old)))
                (alert
                  (strcat
                    "El perfil esta asignado a una via."
                    " Puede editar sus capas, pero no cambiarle el nombre."))
                (urb:save-road-profiles
                  (urb:replace-road-profile profiles (car old) edited)))))
          ((= action "delete")
            (cond
              ((null old) nil)
              ((= (length profiles) 1)
                (alert "Debe conservar al menos un perfil."))
              ((urb:road-profile-in-use-p (car old))
                (alert "El perfil esta asignado a una via y no puede eliminarse."))
              (T
                (urb:save-road-profiles
                  (urb:remove-road-profile profiles (car old)))))))))
  (princ)))

(defun urb:add-unique-string (value values)
  (if (or (null value) (= value "")
          (vl-some '(lambda (item) (urb:string-equal-p item value)) values))
    values
    (append values (list value))))

(defun urb:civil-surface-names (/ ss index ename obj name result)
  (setq ss
    (ssget "_X"
      '((0 . "AECC_TIN_SURFACE,AECC_GRID_SURFACE,AECC_TIN_VOLUME_SURFACE"))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq obj (vlax-ename->vla-object ename))
        (setq name (vl-catch-all-apply 'vla-get-Name (list obj)))
        (if (and name (not (vl-catch-all-error-p name)))
          (setq result (urb:add-unique-string name result)))
        (setq index (1+ index)))))
  (if result result '("Seleccionar en dibujo")))

(defun urb:write-road-dcl (/ filename)
  (setq filename (urb:temp-file "urbanismo_via" ".dcl"))
  (if
    (urb:write-lines filename
      (list
        "urb_road : dialog { label = \"Crear / editar via\";"
        ": boxed_column { label = \"Clasificacion\";"
        ": edit_box { label = \"Nombre de la via\"; key = \"name\"; edit_width = 24; }"
        ;; etapa/subetapa ocultas cuando las etapas estan deshabilitadas
        (if (urb:etapas-enabled-p)
          ": popup_list { label = \"Etapa\"; key = \"etapa\"; }" "")
        (if (urb:etapas-enabled-p)
          ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" "")
        ": popup_list { label = \"Perfil estratigrafico\"; key = \"profile\"; } }"
        ": boxed_column { label = \"Referencia\";"
        ": popup_list { label = \"Eje / alineamiento (admite XREF)\"; key = \"alignment\"; }"
        ": popup_list { label = \"Superficie topografica\"; key = \"surface\"; }"
        ": popup_list { label = \"Cotas de rasante (admite otro XREF)\"; key = \"cota\"; }"
        ": edit_box { label = \"Abscisado cada (m)\"; key = \"station_interval\"; edit_width = 14; } }"
        ": boxed_column { label = \"Geometria\";"
        ": text { label = \"El contorno cerrado define el area y el ancho real de la via.\"; }"
        ": popup_list { label = \"Sobreancho\"; key = \"overwidth\"; }"
        ": text { label = \"Las magnitudes se modifican en Ajustes > Tabla de anchos.\"; } }"
        "ok_cancel; }"))
    filename))

(defun urb:road-default (defaults key fallback / pair)
  (setq pair (assoc key defaults))
  (if pair (cdr pair) fallback))

(defun urb:road-dialog-update-subetapa ()
  (setq *urb-road-dialog-etapa*
    (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
  (urb:fill-popup "subetapa"
    (urb:subetapas-for *urb-road-dialog-etapa*) 0))

(defun urb:road-dialog-update-overwidth () nil)

(defun urb:road-dialog-capture
  (/ name interval stage subetapas mode left right)
  (setq name (vl-string-trim " " (get_tile "name")))
  (setq interval (urb:parse-real (get_tile "station_interval")))
  (setq mode
    (nth (atoi (get_tile "overwidth")) *urb-road-overwidth-modes*))
  (cond
    ((= name "") (alert "Escriba el nombre de la via.") nil)
    ((null interval) (alert "El intervalo no es un numero valido.") nil)
    ((<= interval 0.0) (alert "El intervalo debe ser mayor que cero.") nil)
    (T
      (setq stage
        (if (urb:etapas-enabled-p)
          (nth (atoi (get_tile "etapa")) *urb-etapa-list*)
          (car *urb-etapa-list*)))
      (setq subetapas (urb:subetapas-for stage))
      (setq left
        (if (member mode '("Izquierdo" "Ambos"))
          *urb-road-overwidth-left* 0.0))
      (setq right
        (if (member mode '("Derecho" "Ambos"))
          *urb-road-overwidth-right* 0.0))
      (setq *urb-road-dialog-result*
        (list
          name
          stage
          (if (urb:etapas-enabled-p)
            (nth (atoi (get_tile "subetapa")) subetapas)
            (car subetapas))
          (nth (atoi (get_tile "profile")) *urb-road-dialog-profiles*)
          (nth (atoi (get_tile "alignment")) *urb-road-alignment-modes*)
          (nth (atoi (get_tile "surface")) *urb-road-dialog-surfaces*)
          (nth (atoi (get_tile "cota")) *urb-road-cota-modes*)
          ;; La abscisa inicial ya no se pide aqui: se sugiere sola
          ;; despues de dibujar el contorno (ver urb:create-road).
          ""
          (rtos interval 2 4)
          mode
          (rtos left 2 4)
          (rtos right 2 4)
          "0.0000"))
      T)))

(defun urb:dialog-road (defaults / dcl ok stage sub profile surface cota over)
  (setq *urb-road-dialog-profiles* (urb:road-profile-names))
  (setq *urb-road-dialog-surfaces* (urb:civil-surface-names))
  (setq surface (urb:road-default defaults "surface" (car *urb-road-dialog-surfaces*)))
  (setq *urb-road-dialog-surfaces*
    (urb:add-unique-string surface *urb-road-dialog-surfaces*))
  (setq stage (urb:road-default defaults "stage" "1"))
  (setq sub (urb:road-default defaults "substage" stage))
  (setq profile (urb:road-default defaults "profile" (car *urb-road-dialog-profiles*)))
  (setq cota (urb:road-default defaults "cota" "Textos por capa"))
  ;; Vias antiguas pueden guardar modos ya retirados del dialogo. Al
  ;; editarlas se llevan a la opcion vigente sin dejar un indice nulo.
  (if (not (member cota *urb-road-cota-modes*))
    (setq cota "Textos por capa"))
  ;; Estudio AUS-10786-10: sobreancho minimo 1.0 m a cada lado en las
  ;; capas granulares, por eso el predeterminado es Ambos con 1.00 m.
  (setq over (urb:road-default defaults "overwidth" "Ambos"))
  (if (not (member over *urb-road-overwidth-modes*)) (setq over "Ambos"))
  (setq *urb-road-dialog-result* nil)
  (setq dcl (load_dialog (urb:write-road-dcl)))
  (if (and (> dcl 0) (new_dialog "urb_road" dcl))
    (progn
      (set_tile "name" (urb:road-default defaults "name" "VIA-01"))
      (if (urb:etapas-enabled-p)
        (progn
          (urb:fill-popup "etapa" *urb-etapa-list*
            (urb:index-of stage *urb-etapa-list*))
          (urb:fill-popup "subetapa" (urb:subetapas-for stage)
            (urb:index-of sub (urb:subetapas-for stage)))
          (action_tile "etapa" "(urb:road-dialog-update-subetapa)")))
      (urb:fill-popup "profile" *urb-road-dialog-profiles*
        (urb:index-of profile *urb-road-dialog-profiles*))
      (urb:fill-popup "alignment" *urb-road-alignment-modes*
        (urb:index-of (urb:road-default defaults "alignment" "Existente")
          *urb-road-alignment-modes*))
      (urb:fill-popup "surface" *urb-road-dialog-surfaces*
        (urb:index-of surface *urb-road-dialog-surfaces*))
      (urb:fill-popup "cota" *urb-road-cota-modes*
        (urb:index-of cota *urb-road-cota-modes*))
      (urb:fill-popup "overwidth" *urb-road-overwidth-modes*
        (urb:index-of over *urb-road-overwidth-modes*))
      (set_tile "station_interval" (urb:road-default defaults "station_interval" "5.00"))
      (urb:road-dialog-update-overwidth)
      (action_tile "overwidth" "(urb:road-dialog-update-overwidth)")
      (action_tile "accept" "(if (urb:road-dialog-capture) (done_dialog 1))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq ok (= 1 (start_dialog)))))
  (if (> dcl 0) (unload_dialog dcl))
  (if ok *urb-road-dialog-result*))

(defun urb:curve-entity-p (ename / result)
  (setq result
    (vl-catch-all-apply 'vlax-curve-getEndParam (list ename)))
  (and ename (not (vl-catch-all-error-p result))))

;; BUG (existia desde antes de esta sesion): vl-cmdf solo ENVIA el
;; comando PLINE, no espera a que el usuario termine de dibujar. Sin el
;; bucle "CMDACTIVE" de abajo, entlast se revisaba de inmediato (con el
;; PLINE recien iniciado, 0 puntos), asi que urb:draw-road-boundary
;; siempre recibia un contorno vacio ("no genera un area valida") y el
;; comando de via terminaba ahi -- todo lo dibujado despues quedaba
;; como un PLINE suelto, sin relacion con la via.
(defun urb:draw-polyline
  (message layer / before ename obj old-plinewid *error*)
  (setq old-plinewid (getvar "PLINEWID"))
  (defun *error* (msg)
    (if old-plinewid (setvar "PLINEWID" old-plinewid))
    (if (and msg
             (not (member msg '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError al dibujar: " msg)))
    (princ))
  (setvar "PLINEWID" 0.0)
  (prompt message)
  (setq before (entlast))
  (urb:draw-polyline-interactive old-plinewid)
  (setq ename (entlast))
  (if (and ename (/= ename before))
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (if layer (vla-put-Layer obj layer))
      ename)))

;; Cache en memoria de sesion (boundary-handle -> ename del eje ya
;; resuelto). handent no puede volver a encontrar un eje que vive
;; dentro de un xref (su handle pertenece a la base de datos del xref,
;; no a la del dibujo actual), asi que sin esta cache el usuario tenia
;; que volver a seleccionar el eje con nentsel en CADA edicion, aunque
;; fuera la misma via recien creada en la misma sesion de AutoCAD. La
;; cache se pierde si se cierra/reabre el dibujo o se recarga el xref
;; (el ename deja de ser valido); en ese caso se vuelve a pedir una
;; sola vez y se recachea con el nuevo ename.
(setq *urb-road-axis-cache* nil)

(defun urb:cache-road-axis (boundary-handle axis / entry)
  (if (and (/= (urb:safe-string boundary-handle "") "")
           axis
           (urb:curve-entity-p axis))
    (progn
      (setq entry (assoc boundary-handle *urb-road-axis-cache*))
      (if entry
        (setq *urb-road-axis-cache*
          (subst (cons boundary-handle axis) entry *urb-road-axis-cache*))
        (setq *urb-road-axis-cache*
          (cons (cons boundary-handle axis) *urb-road-axis-cache*)))
      axis)
    nil))

(defun urb:cached-road-axis (boundary-handle / entry axis check)
  (setq entry (assoc boundary-handle *urb-road-axis-cache*))
  (if entry
    (progn
      (setq axis (cdr entry))
      (setq check (vl-catch-all-apply 'entget (list axis)))
      (if (or (vl-catch-all-error-p check)
              (null check)
              (not (urb:curve-entity-p axis)))
        (progn
          (setq *urb-road-axis-cache*
            (vl-remove entry *urb-road-axis-cache*))
          nil)
        axis))
    nil))

(defun urb:select-or-draw-road-axis (mode / selected ename)
  (urb:ensure-layer "URB-VIA" 3 T)
  (if (urb:string-equal-p mode "Nuevo")
    (setq ename
      (urb:draw-polyline
        "\nDibuje el eje de la via. Enter termina: " "URB-VIA"))
    (progn
      ;; nentsel (no entsel) perfora bloques y xrefs: permite tomar como
      ;; eje una polilinea que vive dentro de una referencia externa.
      (setq selected
        (nentsel
          (strcat
            "\nSeleccione una polilinea del eje dentro o fuera del XREF."
            " Aunque se resalte el XREF completo, se usara la entidad anidada: ")))
      (if selected (setq ename (car selected)))))
  (if (and ename (urb:curve-entity-p ename))
    ename
    (progn (prompt "\nEl eje seleccionado no es una curva valida.") nil)))

(defun urb:road-axis-direction (/ choice)
  (initget "Inicio Final")
  (setq choice
    (getkword "\nSentido del abscisado [Inicio/Final] <Inicio>: "))
  (if choice choice "Inicio"))

(defun urb:station-number (value / text position kilometer remainder)
  (setq text (vl-string-translate "," "." (urb:safe-string value "0")))
  (setq position (vl-string-search "+" text))
  (if position
    (progn
      (setq kilometer (atof (substr text 1 position)))
      (setq remainder (atof (substr text (+ position 2))))
      (+ (* kilometer 1000.0) remainder))
    (atof text)))

(defun urb:pad-station-remainder (value / text dot whole decimal)
  (setq text (rtos value 2 (if (< (abs (- value (fix value))) 0.001) 0 2)))
  (setq dot (vl-string-search "." text))
  (if dot
    (setq whole (substr text 1 dot) decimal (substr text (+ dot 2)))
    (setq whole text decimal ""))
  (while (and (> (strlen decimal) 0)
              (= (substr decimal (strlen decimal) 1) "0"))
    (setq decimal (substr decimal 1 (1- (strlen decimal)))))
  (while (< (strlen whole) 3) (setq whole (strcat "0" whole)))
  (strcat whole (if (= decimal "") "" (strcat "." decimal))))

(defun urb:format-station (value / kilometer remainder)
  (setq value (max 0.0 value))
  (setq kilometer (fix (/ value 1000.0)))
  (setq remainder (- value (* kilometer 1000.0)))
  (strcat (itoa kilometer) "+" (urb:pad-station-remainder remainder)))

;; La abscisa inicial ya no se digita antes de dibujar: se sugiere
;; despues, a partir de axis-start (donde el contorno cayo sobre el
;; eje compartido). Enter acepta la sugerencia; si el usuario tiene
;; una referencia de abscisado distinta, la escribe y se usa esa.
(defun urb:prompt-station-start (suggested / label)
  (setq label
    (getstring
      (strcat "\nAbscisa inicial de este tramo <" suggested ">: ")))
  (if (= (vl-string-trim " " (urb:safe-string label "")) "")
    suggested
    label)
)

(defun urb:tag-road-generated (obj parent-handle / ename)
  (if obj
    (progn
      (setq ename (vlax-vla-object->ename obj))
      (urb:set-xdata-strings ename "URB_VIA_GEN" (list parent-handle))))
  obj)

(defun urb:delete-road-generated (parent-handle / ss index ename data obj count)
  (setq ss (ssget "_X" '((-3 ("URB_VIA_GEN")))))
  (if ss
    (progn
      (setq index 0 count 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_VIA_GEN"))
        (if (and data (= (car data) parent-handle))
          (progn
            (setq obj (vlax-ename->vla-object ename))
            (if (urb:safe-delete obj)
              (setq count (1+ count)))))
        (setq index (1+ index)))))
  (if count count 0))

;; Agrupa el contorno de la via con todo su abscisado (URB_VIA_GEN) en
;; un GROUP nativo de AutoCAD: con PICKSTYLE en modo grupo (el valor por
;; defecto), un clic en cualquier miembro selecciona todos, y se puede
;; borrar todo de una sola vez. No se uso un bloque (como en andenes)
;; (2026-07-06) Se reemplazo el empaquetado por GROUP con un BLOQUE de
;; atributos invisibles (ver urb:package-road mas abajo), igual que
;; anden -- asi los datos calculados se ven en el panel Properties de
;; AutoCAD con solo seleccionar la via. urb:create-group/urb:refresh-
;; road-group quedaron sin uso y se retiraron.
(defun urb:road-generated-objects (parent-handle / ss index ename data objects)
  (setq ss (ssget "_X" '((-3 ("URB_VIA_GEN")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_VIA_GEN"))
        (if (and data (= (car data) parent-handle))
          (setq objects (cons (vlax-ename->vla-object ename) objects)))
        (setq index (1+ index)))))
  (reverse objects)
)

(defun urb:create-road-axis-display
  (boundary axis / data start span finish d step point coords poly handle via-id)
  ;; Copia grafica del tramo de eje dentro del bloque. El eje fuente se
  ;; conserva como referencia de calculo (puede pertenecer a un XREF),
  ;; mientras esta polilinea queda seleccionable junto con la via.
  (setq data (urb:get-xdata-strings boundary "URB_VIA")
        start (atof (urb:safe-string (nth 21 data) "0"))
        span (atof (urb:safe-string (nth 18 data) "0"))
        finish (+ start span)
        step (max 0.25 (min 2.0 (/ (max span 0.25) 40.0)))
        d start)
  (while (< d (- finish 1e-7))
    (setq point
      (vl-catch-all-apply 'vlax-curve-getPointAtDist (list axis d)))
    (if (and point (not (vl-catch-all-error-p point)))
      (setq coords (append coords (list (car point) (cadr point)))))
    (setq d (+ d step)))
  (setq point
    (vl-catch-all-apply 'vlax-curve-getPointAtDist (list axis finish)))
  (if (and point (not (vl-catch-all-error-p point)))
    (setq coords (append coords (list (car point) (cadr point)))))
  (if (>= (length coords) 4)
    (progn
      (setq poly
        (vla-AddLightWeightPolyline
          (urb:space) (urb:double-array-variant coords)))
      (vla-put-Layer poly "URB-VIA")
      (vla-put-Color poly 256)
      (if (vlax-property-available-p poly 'ConstantWidth T)
        (vla-put-ConstantWidth poly 0.04))
      (setq handle
        (vla-get-Handle (vlax-ename->vla-object boundary)))
      (urb:tag-road-generated poly handle)
      (setq via-id (urb:safe-string (nth 22 data) ""))
      (urb:set-xdata-strings
        (vlax-vla-object->ename poly) "URB_VIA_EJE"
        (list handle via-id "EJE_DENTRO_BLOQUE"))
      poly)))

(defun urb:create-road-display-hatch (boundary / obj hatch handle)
  (setq obj (vlax-ename->vla-object boundary))
  (setq hatch
    (vl-catch-all-apply
      'vla-AddHatch (list (urb:space) 1 "SOLID" :vlax-true)))
  (if (not (vl-catch-all-error-p hatch))
    (progn
      (if (vl-catch-all-error-p
            (vl-catch-all-apply 'vla-AppendOuterLoop
              (list hatch (urb:make-loop-array obj))))
        (progn (urb:safe-delete hatch) (setq hatch nil))
        (progn
          (vla-put-Layer hatch "URB-VIA")
          (vla-put-Color hatch 256)
          ;; COM acepta 0..90 como texto en versiones recientes; si una
          ;; version no expone la propiedad, el hatch sigue siendo valido.
          (if (vlax-property-available-p hatch 'EntityTransparency T)
            (vl-catch-all-apply 'vlax-put-property
              (list hatch 'EntityTransparency "75")))
          (vla-Evaluate hatch)
          (setq handle
            (vla-get-Handle (vlax-ename->vla-object boundary)))
          (urb:tag-road-generated hatch handle)))))
  hatch)

;; ename es un bloque de via ya empacado (mismo criterio que
;; urb:anden-block-p): referencia de bloque de primer nivel con xdata
;; URB_VIA valida.
(defun urb:road-block-p (ename / obj data)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (and
    (not (vl-catch-all-error-p obj))
    (= (vla-get-ObjectName obj) "AcDbBlockReference")
    (setq data (urb:get-xdata-strings ename "URB_VIA"))
    (urb:string-equal-p (car data) "VIA"))
)

;; Agrega una propiedad independiente por cada capa del perfil de pavimento.
;; Los atributos son invisibles en el dibujo, pero aparecen en la categoria
;; Atributos de la paleta Propiedades al seleccionar el bloque de la via.
(defun urb:attribute-tag-token (value / text index char code result previous-separator)
  (setq text (strcase (urb:safe-string value "MATERIAL")))
  (setq index 1 result "" previous-separator nil)
  (while (<= index (strlen text))
    (setq char (substr text index 1))
    (setq code (ascii char))
    (if (or (and (>= code 48) (<= code 57))
            (and (>= code 65) (<= code 90)))
      (progn
        (setq result (strcat result char))
        (setq previous-separator nil))
      (if (not previous-separator)
        (progn
          (setq result (strcat result "_"))
          (setq previous-separator T))))
    (setq index (1+ index)))
  (setq result (vl-string-trim "_" result))
  (if (= result "") "MATERIAL" result)
)

(defun urb:add-road-pavement-attributes
  (block point data / area road-length left right left-area right-area
   base-area profile layers layer layer-name layer-type layer-scope
   layer-area quantity unit index tag prompt-text)
  (setq area (atof (urb:safe-string (nth 17 data) "0")))
  (setq road-length (atof (urb:safe-string (nth 18 data) "0")))
  (setq left (atof (urb:safe-string (nth 14 data) "0")))
  (setq right (atof (urb:safe-string (nth 15 data) "0")))
  (setq left-area (min area (* road-length left)))
  (setq right-area (min (- area left-area) (* road-length right)))
  (setq base-area (max 0.0 (- area left-area right-area)))
  (setq profile (urb:road-profile-by-name (nth 4 data)))
  (setq layers (if profile (cadr profile) nil))
  (setq index 1)
  (foreach layer layers
    (setq layer-name
      (urb:budget-road-layer-name
        (urb:safe-string (nth 0 layer) "Capa")))
    (setq layer-type (urb:safe-string (nth 1 layer) "Volumen"))
    (setq layer-scope (urb:safe-string (nth 4 layer) "Total"))
    (setq layer-area
      (if (urb:string-equal-p layer-scope "Base") base-area area))
    (if (urb:string-equal-p layer-type "Volumen")
      (progn
        (setq quantity (* layer-area (atof (nth 2 layer))))
        (setq unit "m3"))
      (progn
        (setq quantity
          (* layer-area (+ 1.0 (/ (atof (nth 3 layer)) 100.0))))
        (setq unit "m2")))
    ;; La paleta Properties muestra el TAG, no el texto del prompt. Por eso
    ;; el tag debe contener el nombre real del material y no PAV_CAPA_1, 2...
    (setq tag (urb:attribute-tag-token layer-name))
    (setq prompt-text
      (strcat "Pavimento - " layer-name " (" unit ")"))
    (urb:add-invisible-attribute
      block point tag prompt-text (rtos quantity 2 2))
    (setq index (1+ index)))
  index
)

(defun urb:road-property-hidden-tag-p (tag)
  (member (strcase (urb:safe-string tag ""))
    '("VIA_PERFIL" "VIA_SUPERFICIE" "VIA_ESTADO"
      "VIA_ABSC_INICIAL" "VIA_MEMORIA" "PAV_ESPESOR_M"
      "VIA_METODO_RASANTE"))
)

(defun urb:road-material-property-tags (data / profile layer result)
  (setq profile (urb:road-profile-by-name (nth 4 data)))
  (foreach layer (if profile (cadr profile) nil)
    (setq result
      (append result
        (list
          (urb:attribute-tag-token
            (urb:budget-road-layer-name (nth 0 layer)))))))
  result
)

(defun urb:clean-road-property-object-list
  (objects material-tags / item tag victims material-index changed new-tag)
  (setq material-index 0 changed 0)
  (foreach item objects
    (setq tag
      (if (vlax-property-available-p item 'TagString)
        (strcase (vla-get-TagString item)) ""))
    (cond
      ((urb:road-property-hidden-tag-p tag)
        (setq victims (cons item victims)))
      ((and (urb:starts-with tag "PAV_")
            (< material-index (length material-tags)))
        (setq new-tag (nth material-index material-tags)
              material-index (1+ material-index))
        (if (and (/= new-tag tag)
                 (vlax-property-available-p item 'TagString T))
          (progn
            (vl-catch-all-apply 'vla-put-TagString (list item new-tag))
            (setq changed (1+ changed)))))))
  (foreach item victims
    (if (urb:safe-delete item) (setq changed (1+ changed))))
  changed
)

(defun urb:clean-existing-road-properties
  (/ ss index ename data obj blocks block-definition items item
   attributes material-tags changed block-result)
  ;; Migra inmediatamente las vias ya empacadas: retira los campos
  ;; administrativos marcados por el usuario y deja los tags de pavimento
  ;; con solo el material. Cada via tiene una definicion de bloque propia.
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_VIA"))))
        blocks (vla-get-Blocks (urb:doc)) index 0 changed 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index)
            data (urb:get-xdata-strings ename "URB_VIA"))
      (if (and data (urb:string-equal-p (car data) "VIA"))
        (progn
          (setq obj (vlax-ename->vla-object ename)
                material-tags (urb:road-material-property-tags data)
                attributes
                  (if (= (vla-get-HasAttributes obj) :vlax-true)
                    (vlax-invoke obj 'GetAttributes) nil))
          (setq changed
            (+ changed
              (urb:clean-road-property-object-list
                attributes material-tags)))
          (setq block-result
            (vl-catch-all-apply 'vla-Item
              (list blocks (vla-get-EffectiveName obj))))
          (if (not (vl-catch-all-error-p block-result))
            (progn
              (setq block-definition block-result items nil)
              (vlax-for item block-definition
                (if (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
                  (setq items (append items (list item)))))
              (setq changed
                (+ changed
                  (urb:clean-road-property-object-list
                    items material-tags)))))))
      (setq index (1+ index))))
  (if (> changed 0) (vla-Regen (urb:doc) 1))
  changed
)

(defun urb:upgrade-existing-road-properties
  (/ ss i road data mov obj blocks bdef bname tags item victims length-value
   left right area overarea added sync-result spec)
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_VIA"))))
        i 0 blocks (vla-get-Blocks (urb:doc)) added 0)
  (if ss
    (repeat (sslength ss)
      (setq road (ssname ss i) data (urb:get-xdata-strings road "URB_VIA")
            mov (urb:road-movement-data road)
            obj (vlax-ename->vla-object road)
            bname (vla-get-EffectiveName obj)
            bdef (vl-catch-all-apply 'vla-Item (list blocks bname))
            tags nil victims nil)
      (if (and data (not (vl-catch-all-error-p bdef)))
        (progn
          (vlax-for item bdef
            (cond
              ((= (vla-get-ObjectName item) "AcDbAttributeDefinition")
                (setq tags (cons (strcase (vla-get-TagString item)) tags)))
              ;; El antiguo cuadro MTEXT sobre la calzada ya no se usa.
              ((= (vla-get-ObjectName item) "AcDbMText")
                (setq victims (cons item victims)))))
          (foreach item victims (if (urb:safe-delete item) (setq added (1+ added))))
          (setq area (atof (urb:safe-string (nth 17 data) "0"))
                length-value (atof (urb:safe-string (nth 18 data) "0"))
                left (atof (urb:safe-string (nth 14 data) "0"))
                right (atof (urb:safe-string (nth 15 data) "0"))
                overarea (* length-value (+ left right)))
          (foreach spec
            (list
              (list "VIA_AREA_SOBREANCHO_M2" "Area con sobreancho m2" (rtos area 2 2))
              (list "VIA_SOBREANCHO_M2" "Area exclusiva de sobreancho m2" (rtos overarea 2 2))
              (list "MEMORIAS" "Memorias - use QMEMORIAVIA" "OCULTAS"))
            (if (not (member (car spec) tags))
              (progn
                (urb:add-invisible-attribute bdef '(0.0 0.0 0.0)
                  (car spec) (cadr spec) (caddr spec))
                (setq added (1+ added)))))
          (setq sync-result
            (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bname)))
          (urb:set-block-attribute obj "VIA_AREA_SOBREANCHO_M2" (rtos area 2 2))
          (urb:set-block-attribute obj "VIA_SOBREANCHO_M2" (rtos overarea 2 2))
          (if (= (urb:safe-string
                    (cdr (assoc "MEMORIAS" (urb:block-attribute-values obj))) "") "")
            (urb:set-block-attribute obj "MEMORIAS" "OCULTAS"))))
      (setq i (1+ i))))
  added)

;; Empaqueta el contorno + abscisado de una via en un BLOQUE con
;; atributos invisibles (mismo patron que urb:package-anden, linea
;; ~1403): la xdata URB_VIA nunca aparece en el panel
;; Properties de AutoCAD, pero los atributos de bloque si -- asi el
;; usuario ve los datos calculados con solo seleccionar la via, sin
;; correr ningun comando. El eje NO se copia dentro del bloque (puede
;; vivir en un xref); solo su handle sigue viviendo en la xdata, igual
;; que antes.
(defun urb:package-road
  (ename / boundary data mov handle objects point block-name blocks
   block-definition copy-result block-ref obj insert-result block-ename
   xdata-result road-length left right overwidth-area)
  (setq boundary (vlax-ename->vla-object ename))
  (urb:ensure-layer "URB-VIA" 2 T)
  (setq data (urb:get-xdata-strings ename "URB_VIA"))
  (setq mov (urb:road-movement-data ename))
  (setq handle (vla-get-Handle boundary))
  (setq objects (cons boundary (urb:road-generated-objects handle)))
  (setq point
    (if (urb:lwpoly-points ename)
      (car (urb:lwpoly-points ename))
      '(0.0 0.0 0.0)))
  (setq block-name
    (strcat "URB_VIA_" handle "_" (itoa (getvar "MILLISECS"))))
  (setq blocks (vla-get-Blocks (urb:doc)))
  (setq block-definition
    (vla-Add blocks (vlax-3d-point '(0.0 0.0 0.0)) block-name))
  (setq copy-result
    (vl-catch-all-apply
      'vla-CopyObjects
      (list (urb:doc) (urb:object-array-variant objects) block-definition)))
  (if (vl-catch-all-error-p copy-result)
    (progn
      (urb:safe-delete block-definition)
      (prompt
        (strcat "\nERROR al crear el bloque de la via: "
          (vl-catch-all-error-message copy-result)))
      nil)
    (progn
      (urb:add-invisible-attribute block-definition point
        "VIA_NOMBRE" "Nombre" (urb:safe-string (nth 1 data) ""))
      (urb:add-invisible-attribute block-definition point
        "VIA_ETAPA" "Etapa" (urb:safe-string (nth 2 data) ""))
      (urb:add-invisible-attribute block-definition point
        "VIA_SUBETAPA" "Subetapa" (urb:safe-string (nth 3 data) ""))
      (urb:add-road-pavement-attributes block-definition point data)
      (urb:add-invisible-attribute block-definition point
        "VIA_AREA_M2" "Area m2"
        (rtos (atof (urb:safe-string (nth 17 data) "0")) 2 2))
      (setq road-length (atof (urb:safe-string (nth 18 data) "0"))
            left (atof (urb:safe-string (nth 14 data) "0"))
            right (atof (urb:safe-string (nth 15 data) "0"))
            overwidth-area (* road-length (+ left right)))
      (urb:add-invisible-attribute block-definition point
        "VIA_AREA_SOBREANCHO_M2" "Area con sobreancho m2"
        (rtos (atof (urb:safe-string (nth 17 data) "0")) 2 2))
      (urb:add-invisible-attribute block-definition point
        "VIA_SOBREANCHO_M2" "Area exclusiva de sobreancho m2"
        (rtos overwidth-area 2 2))
      (urb:add-invisible-attribute block-definition point
        "VIA_LONGITUD_M" "Longitud tramo m"
        (rtos (atof (urb:safe-string (nth 18 data) "0")) 2 2))
      (urb:add-invisible-attribute block-definition point
        "VIA_CORTE_M3" "Corte m3"
        (if mov (urb:safe-string (nth 0 mov) "0") "0"))
      (urb:add-invisible-attribute block-definition point
        "VIA_RELLENO_M3" "Relleno m3"
        (if mov (urb:safe-string (nth 1 mov) "0") "0"))
      (urb:add-invisible-attribute block-definition point
        "MEMORIAS" "Memorias - use QMEMORIAVIA" "OCULTAS")
      (setq insert-result
        (vl-catch-all-apply
          'vla-InsertBlock
          (list (urb:space) (vlax-3d-point '(0.0 0.0 0.0))
            block-name 1.0 1.0 1.0 0.0)))
      (if (vl-catch-all-error-p insert-result)
        (progn
          (urb:safe-delete block-definition)
          (prompt
            (strcat "\nERROR al insertar el bloque de la via: "
              (vl-catch-all-error-message insert-result)))
          nil)
        (progn
          (setq block-ref insert-result block-ename (urb:as-ename block-ref))
          (if (not block-ename)
            (progn
              (urb:safe-delete block-ref)
              (urb:safe-delete block-definition)
              (prompt
                "\nERROR: AutoCAD no devolvio una referencia de bloque valida para la via.")
              nil)
            (progn
              (vla-put-Layer block-ref "URB-VIA")
              (setq xdata-result
                (urb:set-xdata-strings block-ename "URB_VIA" data))
              (if xdata-result
                (progn
                  (foreach obj objects (urb:safe-delete obj))
                  (vl-catch-all-apply
                    'urb:attach-memory-reactor-to-block (list block-ename))
                  block-ref)
                (progn
                  (urb:safe-delete block-ref)
                  (urb:safe-delete block-definition)
                  (prompt
                    "\nERROR: no fue posible guardar los datos del bloque de via.")
                  nil))))))))
)

;; Desempaca un bloque de via ya empacado: recupera el contorno crudo
;; (capa URB-VIA-CONTORNO) y le reaplica la xdata que tenia el bloque,
;; para que el resto del flujo de edicion siga funcionando igual que
;; con una via nunca empacada. El abscisado generado se descarta (se
;; reconstruye fresco despues); mismo patron que
;; urb:explode-anden-block-boundary.
(defun urb:explode-road-block-boundary
  (ename / obj data mov exploded objects item boundary)
  (setq data (urb:get-xdata-strings ename "URB_VIA"))
  (setq mov (urb:road-movement-data ename))
  (setq obj (vlax-ename->vla-object ename))
  (setq exploded (vl-catch-all-apply 'vla-Explode (list obj)))
  (if (vl-catch-all-error-p exploded)
    nil
    (progn
      (setq objects (urb:variant-object-list exploded))
      ;; 4.18.0: todas las capas de via se consolidaron en URB-VIA, asi que
      ;; la capa ya no distingue el contorno de las abscisas/datos/tabla
      ;; dentro del bloque explotado. El tipo de objeto si alcanza: el
      ;; contorno es la unica LWPOLYLINE (abscisas son LINE+TEXT, datos es
      ;; MTEXT, verificacion es TABLE) -- vale tanto para vias nuevas como
      ;; para vias viejas (capa URB-VIA-CONTORNO).
      (foreach item objects
        (if (= (vla-get-ObjectName item) "AcDbPolyline")
          (setq boundary item)))
      (foreach item objects
        (if (not (eq item boundary)) (urb:safe-delete item)))
      (if boundary
        (progn
          (setq boundary (vlax-vla-object->ename boundary))
          (if data (urb:set-xdata-strings boundary "URB_VIA" data))
          ;; Migra una via antigua que aun conserve URB_VIA_MOV al registro
          ;; principal. Las nuevas vias ya llevan el movimiento embebido.
          (if (and mov (< (length data) 32))
            (urb:set-road-movement-data boundary mov))
          boundary)
        nil)))
)

;; BUG (existia desde antes de esta sesion, nunca ejercitado hasta la
;; primera prueba real de una via completa): los parametros/locales se
;; llamaban "distance" y "length", ambos nombres de funciones nativas de
;; AutoLISP. Al llegar a (distance '(0.0 0.0 0.0) derivative), AutoLISP
;; encontraba el PARAMETRO "distance" (un numero, p.ej. 6.80273) en vez
;; de la funcion nativa, e intentaba "llamar" ese numero como funcion:
;; "bad function: 6.80273". Renombrados para no tapar los nativos.
(defun urb:add-road-station
  (axis dist-value station direction parent-handle
   / param point derivative seg-length tangent normal p1 p2 line text text-angle)
  (setq point (vlax-curve-getPointAtDist axis dist-value))
  (setq param (vlax-curve-getParamAtDist axis dist-value))
  (setq derivative (vlax-curve-getFirstDeriv axis param))
  (if (urb:string-equal-p direction "Final")
    (setq derivative (mapcar '- derivative)))
  (setq seg-length (distance '(0.0 0.0 0.0) derivative))
  (if (> seg-length 1e-9)
    (progn
      (setq tangent (mapcar '(lambda (item) (/ item seg-length)) derivative))
      (setq normal (list (- (cadr tangent)) (car tangent) 0.0))
      (setq p1 (mapcar '+ point (mapcar '(lambda (item) (* item 0.50)) normal)))
      (setq p2 (mapcar '- point (mapcar '(lambda (item) (* item 0.50)) normal)))
      (setq line (vla-AddLine (urb:space) (vlax-3d-point p1) (vlax-3d-point p2)))
      (vla-put-Layer line "URB-VIA")
      (urb:tag-road-generated line parent-handle)
      (setq text-angle (atan (cadr tangent) (car tangent)))
      (setq text
        (vla-AddText (urb:space) (urb:format-station station)
          (vlax-3d-point
            (mapcar '+ point (mapcar '(lambda (item) (* item 0.75)) normal)))
          0.45))
      (vla-put-Layer text "URB-VIA")
      (vla-put-Rotation text text-angle)
      (urb:tag-road-generated text parent-handle))))

;; axis-start = punto sobre el eje donde comienza el tramo de esta via
;; (0 si el eje seleccionado coincide con la via); span = longitud propia
;; del tramo (ya no la longitud total del eje, que puede ser mas largo
;; si el eje se comparte entre varias vias).
;;
;; Marcado alineado a una grilla de proyecto (2026-07-06): antes las
;; marcas salian equiespaciadas desde el inicio detectado (p.ej. 0+013,
;; 0+018, 0+023...), sin relacion con la grilla real de cotas del
;; usuario (cada 10 m: 0+010, 0+020, 0+030...). Ahora "interval" se
;; trata como el tamano de esa grilla: siempre se marca el INICIO real
;; y el FINAL real del tramo (aunque no caigan en un multiplo redondo),
;; y en el medio solo los multiplos redondos de interval que quedan
;; estrictamente entre los dos (0+013, 0+020, 0+030, 0+036.89, etc.).
(defun urb:generate-road-stations
  (axis parent-handle start interval direction axis-start span
   / end-label labels next-round label traveled distance-value)
  (urb:ensure-layer "URB-VIA" 7 T)
  (if (or (not (numberp interval)) (<= interval 1e-6))
    (setq interval 10.0))
  (setq end-label (+ start span))
  (setq labels (list start))
  (setq next-round (* interval (fix (1+ (/ start interval)))))
  (if (<= next-round (+ start 1e-6)) (setq next-round (+ next-round interval)))
  (while (< next-round (- end-label 1e-6))
    (setq labels (append labels (list next-round)))
    (setq next-round (+ next-round interval)))
  (setq labels (append labels (list end-label)))
  (foreach label labels
    (setq traveled (- label start))
    (setq distance-value
      (+ axis-start
        (if (urb:string-equal-p direction "Final")
          (- span traveled)
          traveled)))
    (urb:add-road-station axis distance-value label direction parent-handle))
  span)

(defun urb:pick-cota-value (msg / selected ename edata txt value)
  ;; Selecciona un texto/etiqueta de cota y devuelve su valor numerico REAL
  ;; (mp:last-decimal-number devuelve STRING -- se convierte con atof aqui
  ;; mismo; los consumidores hacen aritmetica/rtos directo y truenan con
  ;; un string). Enter u objeto ilegible -> pide digitarla.
  (setq selected (nentsel msg))
  (if selected
    (progn
      (setq ename (car selected) edata (entget ename))
      (setq txt (cdr (assoc 1 edata)))
      (if txt (setq value (mp:last-decimal-number txt)))
      (if value (setq value (atof value)))
      (if value
        (prompt (strcat "\nCota leida de la etiqueta: " (rtos value 2 3))))))
  (if (null value)
    (setq value (getreal "\nNo se pudo leer la cota; digitela (Enter omite): ")))
  value
)

(defun urb:selected-cota-number (selected / ename edata obj txt value)
  ;; Lee TEXT/MTEXT, etiquetas Civil y proxies seleccionados con NENTSEL,
  ;; incluidos los que viven dentro de un XREF. Se prueban tanto ActiveX
  ;; como DXF porque cada tipo de etiqueta expone el contenido distinto.
  (setq ename (if selected (car selected) nil)
        edata (if ename (entget ename) nil)
        obj
          (if ename
            (vl-catch-all-apply 'vlax-ename->vla-object (list ename))))
  (if (and obj (not (vl-catch-all-error-p obj)))
    (progn
      (setq txt (vl-catch-all-apply 'vla-get-TextString (list obj)))
      (if (vl-catch-all-error-p txt) (setq txt nil))))
  (if (or (null txt) (= (urb:safe-string txt "") ""))
    (setq txt (cdr (assoc 1 edata))))
  (if txt (setq value (mp:last-decimal-number txt)))
  (if value (atof value) nil)
)

(defun urb:road-design-grade-records (road data / mov records span c0 c1)
  ;; La rasante de diseno se puede consultar aunque no exista superficie
  ;; TN y, por tanto, aun no se haya calculado movimiento de tierras.
  (setq mov (urb:road-movement-data road))
  (if (and mov (> (length mov) 9))
    (setq records (urb:read-lisp-safe (nth 9 mov))))
  (if (not (urb:grade-records-valid-p records)) (setq records nil))
  (if (and (null records) (> (length data) 32))
    (setq records (urb:read-lisp-safe (nth 32 data))))
  (if (not (urb:grade-records-valid-p records)) (setq records nil))
  (setq span
    (atof (urb:safe-string (if (> (length data) 18) (nth 18 data) nil) "0")))
  (if (null records)
    (progn
      (setq c0
        (or
          (urb:parse-real
            (if (and mov (> (length mov) 7)) (nth 7 mov) ""))
          (urb:parse-real
            (if (> (length data) 30) (nth 30 data) ""))))
      (setq c1
        (or
          (urb:parse-real
            (if (and mov (> (length mov) 8)) (nth 8 mov) ""))
          (urb:parse-real
            (if (> (length data) 31) (nth 31 data) ""))))
      (if (and c0 c1 (> span 1e-6))
        (setq records (list (list 0.0 c0) (list span c1))))))
  records
)

(defun urb:cota-start-from-via (ename / road data records)
  ;; Para la PRIMERA cota del metodo Pendiente importa el inicio del tramo
  ;; de via, no el lugar accidental donde se hizo clic sobre su bloque.
  (setq road (urb:road-parent-from-entity ename))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq records (urb:road-design-grade-records road data))
      (if records (urb:cota-at-axis-distance 0.0 records) nil))
    nil)
)

(defun urb:cota-start-from-pick (selected / cands item value attempt)
  (setq cands (list (car selected)))
  (if (> (length selected) 3)
    (setq cands (append cands (nth 3 selected))))
  (foreach item cands
    (if (null value)
      (progn
        (setq attempt
          (vl-catch-all-apply 'urb:cota-start-from-via (list item)))
        (if (not (vl-catch-all-error-p attempt))
          (setq value attempt)))))
  value
)

;; Si lo seleccionado pertenece a una VIA ya creada por el plugin,
;; devuelve la cota de RASANTE de esa via en el punto del click
;; (proyectado a su eje, con los records de rasante guardados); nil si no
;; es una via o no tiene rasante calculada. (2026-08-12: para que el
;; picker de cotas reconozca automaticamente texto O via, sin preguntar.)
(defun urb:cota-from-via (ename point / road data mov records via-id
   axis-handle axis span axis-start direction c0 c1 closest d station)
  (setq road (urb:road-parent-from-entity ename))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq mov (urb:road-movement-data road))
      (setq records (urb:road-design-grade-records road data))
      (setq via-id (if (> (length data) 22) (nth 22 data) ""))
      ;; Si el handle del eje ya no existe, se busca por via-id/cache.
      ;; Nunca se fabrica un alineamiento nuevo al consultar una cota.
      (setq axis (urb:road-axis-recover road data via-id))
      (setq span
        (atof (urb:safe-string (if (> (length data) 18) (nth 18 data) nil) "0")))
      (setq axis-start
        (atof (urb:safe-string (if (> (length data) 21) (nth 21 data) nil) "0")))
      (setq direction
        (urb:safe-string (if (> (length data) 12) (nth 12 data) nil) "Inicio"))
      (if (and axis records)
        (progn
          (setq closest
            (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list axis point)))
          (if (vl-catch-all-error-p closest)
            nil
            (progn
              (setq d
                (vl-catch-all-apply 'vlax-curve-getDistAtPoint (list axis closest)))
              (if (vl-catch-all-error-p d)
                nil
                (progn
                  ;; records de rasante en coordenada LOCAL (0..span)
                  (setq station
                    (if (urb:string-equal-p direction "Final")
                      (- (+ axis-start span) d)
                      (- d axis-start)))
                  (urb:cota-at-axis-distance station records))))))
        (progn
          ;; se reconocio una via del programa pero no se puede dar cota:
          ;; explicar POR QUE en vez de fallar en silencio (reporte del
          ;; usuario: "no puede leer la cota cuando selecciono la via")
          (if (null records)
            (prompt
              (strcat "\nLa via seleccionada NO tiene rasante calculada"
                      " (el movimiento de tierras se omitio al crearla);"
                      " no se puede tomar su cota. Editela y asignele"
                      " cotas, o seleccione un texto de cota.")))
          nil)))
    nil))

;; Modo "Pendiente" generalizado a N cotas (2026-08-11, pedido del
;; usuario: pozos sobre la via). Devuelve una lista de (valor punto) --
;; con 2 cotas la rasante es lineal inicial/final (como antes); con 3 o
;; mas, cada cota se proyecta sobre el eje en el punto donde se clickeo
;; su etiqueta y la rasante queda por tramos. Enter tras 2 o mas cotas
;; termina; Enter antes de 2 cancela.
;; Localiza un eje YA existente por el identificador estable de la via.
;; Desde 4.21.2 URB_VIA_EJE guarda (handle-contorno via-id); el segundo
;; valor permite recuperar el mismo eje aunque el bloque de via cambie de
;; handle al editarse o el DWG se vuelva a abrir.
(defun urb:find-linked-road-axis (via-id / selection index candidate link axis)
  (setq via-id (urb:safe-string via-id ""))
  (if (/= via-id "")
    (setq selection (ssget "_X" '((-3 ("URB_VIA_EJE"))))))
  (setq index 0)
  (if selection
    (repeat (sslength selection)
      (setq candidate (ssname selection index)
            link (urb:get-xdata-strings candidate "URB_VIA_EJE"))
      (if (and (null axis)
               (> (length link) 1)
               (urb:string-equal-p (nth 1 link) via-id)
               (urb:curve-entity-p candidate))
        (setq axis candidate))
      (setq index (1+ index))))
  axis
)

(defun urb:remember-road-axis
  (road data via-id axis / axis-handle road-handle updated)
  ;; Registra una seleccion manual para que las siguientes operaciones de
  ;; ese anden/via no vuelvan a preguntar. En ejes de xref la escritura de
  ;; xdata puede no estar permitida; la cache de sesion sigue funcionando.
  (setq via-id (urb:safe-string via-id ""))
  (if (and axis (/= via-id ""))
    (urb:cache-road-axis via-id axis))
  (setq axis-handle
    (if axis
      (vl-catch-all-apply
        '(lambda () (vla-get-Handle (vlax-ename->vla-object axis))))
      nil))
  (if (vl-catch-all-error-p axis-handle) (setq axis-handle nil))
  (setq road-handle
    (if road
      (vl-catch-all-apply
        '(lambda () (vla-get-Handle (vlax-ename->vla-object road))))
      nil))
  (if (vl-catch-all-error-p road-handle) (setq road-handle ""))
  (if (and axis axis-handle (/= via-id ""))
    (vl-catch-all-apply
      'urb:set-xdata-strings
      (list axis "URB_VIA_EJE"
        (list (urb:safe-string road-handle "") via-id))))
  (if (and road data axis-handle)
    (progn
      (setq updated (urb:list-set-extended data 5 axis-handle))
      (vl-catch-all-apply
        'urb:set-xdata-strings (list road "URB_VIA" updated))))
  axis
)

(defun urb:find-axis-in-road-block (road via-id / obj blocks bdef result item link)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list road)))
  (if (and (not (vl-catch-all-error-p obj))
           (= (vla-get-ObjectName obj) "AcDbBlockReference"))
    (progn
      (setq blocks (vla-get-Blocks (urb:doc))
            bdef
              (vl-catch-all-apply 'vla-Item
                (list blocks (vla-get-EffectiveName obj))))
      (if (not (vl-catch-all-error-p bdef))
        (vlax-for item bdef
          (if (and (null result)
                   (urb:curve-entity-p (vlax-vla-object->ename item)))
            (progn
              (setq link
                (urb:get-xdata-strings
                  (vlax-vla-object->ename item) "URB_VIA_EJE"))
              (if (and link (> (length link) 1)
                       (urb:string-equal-p (nth 1 link) via-id))
                (setq result (vlax-vla-object->ename item))))))))
  result))

;; Resuelve el EJE de una via YA CREADA sin fabricar geometria nueva:
;; 1) handle guardado, 2) cache de sesion, 3) xdata URB_VIA_EJE/via-id.
;; Si los tres fallan, el flujo superior pide seleccionar el eje existente
;; y lo recuerda. Se retiro deliberadamente la reconstruccion desde el
;; contorno, que era la responsable de crear un alineamiento duplicado.
(defun urb:road-axis-recover (road data via-id / axis axis-handle cache-key)
  (setq axis-handle
    (if (> (length data) 5) (urb:safe-string (nth 5 data) "") ""))
  (setq via-id (urb:safe-string via-id ""))
  (setq cache-key
    (if (/= via-id "")
      via-id
      (vl-catch-all-apply
        '(lambda () (vla-get-Handle (vlax-ename->vla-object road))))))
  (if (vl-catch-all-error-p cache-key) (setq cache-key nil))
  (setq axis
    (or (if (/= axis-handle "") (handent axis-handle) nil)
        (if cache-key (urb:cached-road-axis cache-key) nil)
        (urb:find-linked-road-axis via-id)
        (urb:find-axis-in-road-block road via-id)))
  (if (and axis (not (urb:curve-entity-p axis))) (setq axis nil))
  (if (and axis cache-key) (urb:cache-road-axis cache-key axis))
  axis)

;; Prueba la entidad clickeada Y sus bloques contenedores: cuando el clic
;; cae dentro de un bloque o xref, nentsel devuelve la geometria ANIDADA
;; como (car sel) y los INSERT contenedores en el 4to elemento. Las vias
;; empacadas llevan la xdata URB_VIA en el INSERT -- por eso el picker no
;; reconocia una via ya creada al clickearla (reporte 2026-08-12).
(defun urb:cota-from-pick (sel / value cands item)
  (setq cands (list (car sel)))
  (if (> (length sel) 3)
    (setq cands (append cands (nth 3 sel))))
  (foreach item cands
    (if (and (null value) item)
      (progn
        (setq value
          (vl-catch-all-apply 'urb:cota-from-via (list item (cadr sel))))
        (if (vl-catch-all-error-p value) (setq value nil)))))
  value)

(defun urb:pick-road-cotas (/)
  (urb:pick-road-cotas-loop nil))

;; Bucle interno reutilizable (2026-08-12): seed-picks permite arrancar
;; con la primera cota ya capturada -- lo usa "Textos por capa" cuando el
;; primer clic resulta ser una VIA creada o una etiqueta con numero
;; (auto-detect) y el flujo continua pidiendo la cota final y las
;; intermedias, igual que el modo Pendiente.
(defun urb:pick-road-cotas-loop (picks / sel obj txt value point msg n done)
  (setq done nil)
  (while (not done)
    (setq n (length picks))
    (setq msg
      (cond
        ((= n 0) "\nSeleccione la COTA del extremo INICIAL de la via: ")
        ((= n 1) "\nSeleccione la COTA del extremo FINAL de la via: ")
        (T "\nSeleccione OTRA cota sobre la via (pozos, quiebres) o Enter para terminar: ")))
    (setq sel (nentsel msg))
    (cond
      ((null sel)
        (if (>= n 2)
          (setq done T)
          (progn
            (prompt "\nSe necesitan al menos 2 cotas; seleccion cancelada.")
            (setq done T picks nil))))
      (T
        ;; AUTO-DETECCION: el mismo click reconoce una VIA creada o un
        ;; TEXTO/etiqueta de cota de cualquier XREF. Se prueba primero la
        ;; via para que un atributo numerico anidado en su bloque no se
        ;; confunda con la cota de rasante.
        ;; La primera cota tambien se toma EN EL PUNTO DEL CLIC. Antes se
        ;; forzaba la abscisa local 0+000 de la via fuente; por eso una
        ;; conexion cerca de 0+210 heredaba 2560.96 en vez de interpolar
        ;; aproximadamente 2556.89 entre las cotas vecinas.
        (setq value (urb:cota-from-pick sel))
        (if value
          (prompt
            (strcat
              "\nCota interpolada de la RASANTE en el punto seleccionado: "
              (rtos value 2 3)))
          (progn
            (setq value (urb:selected-cota-number sel))
            (if value
              (prompt
                (strcat "\nCota leida de la etiqueta: "
                  (rtos value 2 3))))))
        (if (null value)
          (setq value
            (getreal "\nNo se pudo leer la cota; digitela (Enter omite): ")))
        (if value
          (progn
            (setq point (cadr sel))
            (setq picks (append picks (list (list value point)))))))))
  picks)

;; Proyecta cada cota seleccionada sobre el eje (en el punto del clic) y
;; devuelve records (distancia-en-el-eje cota) ordenados, listos para
;; urb:cota-at-axis-distance.
(defun urb:picked-cotas-to-stations (picks axis / result item point closest d)
  (foreach item picks
    (setq point (cadr item))
    (if point
      (progn
        (setq closest
          (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list axis point)))
        (if (not (vl-catch-all-error-p closest))
          (progn
            (setq d
              (vl-catch-all-apply 'vlax-curve-getDistAtPoint (list axis closest)))
            (if (not (vl-catch-all-error-p d))
              (setq result (cons (list d (car item)) result))))))))
  (vl-sort result '(lambda (a b) (< (car a) (car b)))))

(defun urb:road-cota-reference
  (mode / selected ename edata layer texts count obj txt via-cota picks)
  (cond
    ((urb:string-equal-p mode "Textos por capa")
      ;; nentsel (no entsel) para poder tomar un texto anidado en un xref.
      (setq selected
        (nentsel
          (strcat
            "\nSeleccione un texto de cota (cualquier capa/XREF)"
            " o una VIA ya creada como cota inicial: ")))
      (if selected
        (progn
          (setq ename (car selected) edata (entget ename))
          (if (member (cdr (assoc 0 edata)) '("TEXT" "MTEXT"))
            (progn
              (setq layer (cdr (assoc 8 edata)))
              ;; urb:collect-cota-texts ya sabe leer capas de xref (no
              ;; se usa ssget aqui: siempre da 0 en contenido anidado).
              (urb:clear-cota-calibration layer)
              (setq texts (urb:collect-cota-texts layer))
              (setq count (length texts))
              ;; El punto donde el usuario hizo clic es la unica coordenada
              ;; WCS fiable para ciertos proxies de etiquetas Civil 3D.
              ;; Se usa para calibrar el desfase de toda la capa/XREF.
              (urb:calibrate-cota-layer layer selected texts)
              (prompt
                (strcat "\nCotas detectadas en la capa " layer ": " (itoa count)))
              (list layer (itoa count) (if (> count 0) "DETECTADAS" "PENDIENTE")))
            ;; 2026-08-12 AUTO-DETECT (pedido del usuario): si el primer
            ;; clic no fue TEXT/MTEXT pero si una etiqueta con numero
            ;; (MLeader, etiqueta Civil 3D) o una VIA ya creada (toma su
            ;; RASANTE en el punto del clic), el flujo NO se cancela:
            ;; cambia a cotas seleccionadas (mismo picker del modo
            ;; Pendiente) y sigue pidiendo la cota final y las intermedias.
            (progn
              ;; Una via puede contener atributos numericos; su rasante
              ;; tiene prioridad sobre cualquier texto anidado.
              (setq via-cota (urb:cota-from-pick selected))
              (if via-cota
                (prompt
                  (strcat
                    "\nCota tomada de la RASANTE interpolada en el clic: "
                    (rtos via-cota 2 3)))
                (progn
                  (setq via-cota (urb:selected-cota-number selected))
                  (if via-cota
                    (prompt
                      (strcat "\nCota leida de la etiqueta: "
                        (rtos via-cota 2 3))))))
              (if via-cota
                (progn
                  (setq picks
                    (urb:pick-road-cotas-loop
                      (list (list via-cota (cadr selected)))))
                  (if picks
                    (list "PICKED" picks "DETECTADAS")
                    (progn
                      (prompt "\nSe necesitan al menos 2 cotas.")
                      (list "" "0" "PENDIENTE"))))
                (progn
                  (prompt
                    "\nEl objeto no es texto, etiqueta con numero ni via creada.")
                  (list "" "0" "PENDIENTE"))))))
        (list "" "0" "PENDIENTE")))
    ((urb:string-equal-p mode "Perfil Civil 3D")
      (setq selected (entsel "\nSeleccione el perfil Civil 3D: "))
      (if selected
        (list (cdr (assoc 5 (entget (car selected)))) "1" "DETECTADO")
        (list "" "0" "PENDIENTE")))
    (T (list "" "0" "PENDIENTE"))))

(defun urb:resolve-road-surface (surface / selected ename obj name)
  (if (not (urb:string-equal-p surface "Seleccionar en dibujo"))
    surface
    (progn
      ;; nentsel (no entsel) para poder tomar una superficie anidada en un xref.
      (setq selected
        (nentsel "\nSeleccione la superficie topografica de Civil 3D: "))
      (if selected
        (progn
          (setq ename (car selected))
          (setq obj
            (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
          (if (and obj (not (vl-catch-all-error-p obj)))
            (setq name (vl-catch-all-apply 'vla-get-Name (list obj))))
          (if (and name (not (vl-catch-all-error-p name)) (/= name ""))
            name
            (progn
              (prompt "\nEl objeto no es una superficie Civil 3D valida.")
              "NO SELECCIONADA")))
        "NO SELECCIONADA"))))

;; via-id (indice 22, opcional/agregado 2026-07-06): identificador
;; estable de la via, independiente de su handle -- el handle cambia
;; cada vez que la via se desempaca/empaca en un bloque al editarla
;; (ver urb:package-road/urb:explode-road-block-boundary), pero el
;; via-id se conserva igual, generado una sola vez en la creacion.
(defun urb:set-road-data
  (boundary name stage substage profile axis surface cota cota-reference cota-count
   station-start interval direction overwidth left-over right-over nominal-width
   area axis-length status alignment-mode axis-start via-id / old base extras)
  (setq old (urb:get-xdata-strings boundary "URB_VIA"))
  (setq base
    (list "VIA" name stage substage profile axis surface cota cota-reference
      cota-count station-start interval direction overwidth left-over right-over
      nominal-width area axis-length status alignment-mode axis-start via-id))
  ;; Editar una via no debe borrar su rasante/movimiento ya calculados.
  (if (> (length old) 23)
    (setq extras (nthcdr 23 old)))
  (urb:set-xdata-strings boundary "URB_VIA"
    (append base extras)))

(defun urb:road-data-defaults (data)
  (list
    (cons "name" (nth 1 data))
    (cons "stage" (nth 2 data))
    (cons "substage" (nth 3 data))
    (cons "profile" (nth 4 data))
    (cons "surface" (nth 6 data))
    (cons "cota" (nth 7 data))
    (cons "station_interval" (nth 11 data))
    (cons "alignment" (nth 20 data))
    (cons "overwidth" (nth 13 data))
    (cons "left_over" (nth 14 data))
    (cons "right_over" (nth 15 data))
    (cons "nominal_width" (nth 16 data))))

(defun urb:draw-road-boundary (/ ename obj area)
  (urb:ensure-layer "URB-VIA" 2 T)
  (setq ename
    (urb:draw-polyline
      "\nDibuje el contorno de la via. Enter termina y el programa lo cerrara: "
      "URB-VIA"))
  (if ename
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (if (vlax-property-available-p obj 'Closed T)
        (vla-put-Closed obj :vlax-true))
      (setq area (vl-catch-all-apply 'vla-get-Area (list obj)))
      (if (or (vl-catch-all-error-p area) (<= area 1e-8))
        (progn
          (prompt "\nEl contorno no genera un area valida.")
          nil)
        ename))))

;; 2026-08-11: eje central AUTOMATICO para via con alineamiento "Nuevo"
;; (pedido del usuario: dibujar el contorno primero y no tener que dibujar
;; el eje aparte). v2 (mismo dia): generalizado a contornos con ARCOS y
;; cualquier numero de vertices via cadenas laterales -- para 4 vertices
;; rectos los extremos se detectan solos; para el resto el usuario toca
;; los 2 bordes extremos y el eje es el promedio punto a punto de las 2
;; cadenas laterales. Los extremos usados quedan en *urb-road-end-edges*
;; para que los sardineles reutilicen las mismas cadenas sin repreguntar.
(defun urb:road-axis-from-boundary (boundary / ends axis)
  (setq *urb-road-end-edges* nil)
  (setq ends (urb:road-end-edges boundary))
  (if ends
    (progn
      (setq axis
        (urb:road-axis-from-chains boundary (car ends) (cadr ends)))
      (if axis (setq *urb-road-end-edges* ends))
      axis)
    nil))

;; Proyeccion escalar (clampeada) de un punto sobre el segmento pa->dir.
(defun urb:project-param-on-segment (pa dir len p / tt)
  (setq tt (+ (* (- (car p) (car pa)) (car dir))
              (* (- (cadr p) (cadr pa)) (cadr dir))))
  (max 0.0 (min len tt)))

;; ------------------------------------------------------------------
;; 2026-08-11 v2: infraestructura de CADENAS LATERALES de un contorno de
;; via (soporta arcos y cualquier numero de vertices). El contorno se
;; parte en 2 bordes EXTREMOS + 2 cadenas laterales; el eje automatico es
;; el promedio punto a punto de las cadenas y los sardineles se
;; construyen sobre ellas. Para cuadrilateros rectos los extremos se
;; detectan solos; para el resto el usuario los toca con 2 clics.
;; ------------------------------------------------------------------

;; vertices y bulges del LWPOLYLINE en orden (bulge i = arco del vertice
;; i al i+1)
(defun urb:lwpoly-vertex-bulges (ename / edata item pts bulges)
  (setq edata (entget ename))
  (foreach item edata
    (cond
      ((= (car item) 10)
        (setq pts (cons (cdr item) pts))
        (setq bulges (cons 0.0 bulges)))
      ((= (car item) 42)
        (setq bulges (cons (cdr item) (cdr bulges))))))
  (list (reverse pts) (reverse bulges)))

(defun urb:dist-point-seg (p a b / len dir tt proj)
  (setq p (list (car p) (cadr p)))
  (setq len (distance a b))
  (if (< len 1e-9)
    (distance p a)
    (progn
      (setq dir (mapcar '(lambda (x y) (/ (- y x) len)) a b))
      (setq tt
        (max 0.0
          (min len
            (+ (* (- (car p) (car a)) (car dir))
               (* (- (cadr p) (cadr a)) (cadr dir))))))
      (setq proj (mapcar '(lambda (x d) (+ x (* d tt))) a dir))
      (distance p proj))))

;; indice del borde (vertice i -> i+1) mas cercano al punto p
(defun urb:nearest-edge-index (pts p / n i best best-d d)
  (setq n (length pts) i 0)
  (while (< i n)
    (setq d (urb:dist-point-seg p (nth i pts) (nth (rem (1+ i) n) pts)))
    (if (or (null best-d) (< d best-d)) (setq best-d d best i))
    (setq i (1+ i)))
  best)

;; polilinea ABIERTA temporal con los vertices i-from..i-to (avance
;; circular), conservando los bulges de los bordes intermedios
(defun urb:make-chain-poly (pts bulges i-from i-to / n idx verts vb)
  (setq n (length pts) idx i-from verts nil vb nil)
  (while (/= idx i-to)
    (setq verts (cons (nth idx pts) verts))
    (setq vb (cons (nth idx bulges) vb))
    (setq idx (rem (1+ idx) n)))
  (setq verts (cons (nth i-to pts) verts))
  (setq vb (cons 0.0 vb))
  (setq verts (reverse verts) vb (reverse vb))
  (if (> (length verts) 1)
    (entmakex
      (append
        (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity")
              (cons 100 "AcDbPolyline") (cons 8 "URB-VIA")
              (cons 90 (length verts)) (cons 70 0))
        (apply 'append
          (mapcar '(lambda (pt b) (list (cons 10 pt) (cons 42 b)))
            verts vb))))
    nil))

;; Punto medio (por cuerda) del borde i del contorno.
(defun urb:edge-midpoint (pts i / n)
  (setq n (length pts))
  (mapcar '(lambda (a b) (* 0.5 (+ a b)))
    (nth i pts) (nth (rem (1+ i) n) pts)))

;; Bordes extremos del contorno, AUTOMATICO para cualquier forma
;; (2026-08-11 v5, "quiero que sea mas facil"): los extremos de una via
;; son el par de bordes NO adyacentes cuyos puntos medios quedan mas
;; lejos entre si -- funciona igual para el cuadrilatero recto y para
;; contornos con arcos, jogs de cruces o muchos vertices, sin pedirle
;; clics al usuario. e1 = el extremo mas cercano al PRIMER vertice
;; dibujado (direccion de abscisado predecible). Devuelve (e1 e2) o nil.
(defun urb:road-end-edges (boundary / vb pts n i j mi mj d best e1 e2 swap)
  (setq vb (urb:lwpoly-vertex-bulges boundary))
  (setq pts (car vb) n (length pts))
  (if (< n 4)
    nil
    (progn
      (setq i 0)
      (while (< i n)
        (setq mi (urb:edge-midpoint pts i))
        (setq j (1+ i))
        (while (< j n)
          ;; no adyacentes: comparten vertice si j=i+1 o (i=0 y j=n-1)
          (if (not (or (= j (1+ i)) (and (= i 0) (= j (1- n)))))
            (progn
              (setq mj (urb:edge-midpoint pts j))
              (setq d (distance mi mj))
              (if (or (null best) (> d best))
                (setq best d e1 i e2 j))))
          (setq j (1+ j)))
        (setq i (1+ i)))
      (if best
        (progn
          ;; e1 = extremo mas cercano al primer vertice dibujado
          (if (> (distance (nth 0 pts) (urb:edge-midpoint pts e1))
                 (distance (nth 0 pts) (urb:edge-midpoint pts e2)))
            (setq swap e1 e1 e2 e2 swap))
          (list e1 e2))
        nil))))

;; Cadenas laterales del contorno dados sus bordes extremos: lista
;; (chainA chainB) de polilineas TEMPORALES (el que llama las borra).
;; chainA va del extremo inicial al final; chainB en el mismo sentido
;; geometrico pero recorrida al reves (usar length-fraccion invertida).
(defun urb:road-side-chains (boundary e1 e2 / vb pts bulges n a b)
  (setq vb (urb:lwpoly-vertex-bulges boundary))
  (setq pts (car vb) bulges (cadr vb) n (length pts))
  (setq a (urb:make-chain-poly pts bulges (rem (1+ e1) n) e2))
  (setq b (urb:make-chain-poly pts bulges (rem (1+ e2) n) e1))
  (if (and a b)
    (list a b)
    (progn
      (if a (entdel a))
      (if b (entdel b))
      nil)))

;; Eje central por promedio punto a punto de las 2 cadenas laterales.
;; Devuelve el ename del eje (LWPOLYLINE en URB-VIA) o nil.
(defun urb:road-axis-from-chains (boundary e1 e2 / chains ca cb la lb k steps
   frac pa pb mids ename)
  (setq chains (urb:road-side-chains boundary e1 e2))
  (if chains
    (progn
      (setq ca (car chains) cb (cadr chains))
      (setq la (vlax-curve-getDistAtParam ca (vlax-curve-getEndParam ca)))
      (setq lb (vlax-curve-getDistAtParam cb (vlax-curve-getEndParam cb)))
      (setq steps (max 8 (min 60 (fix (/ (max la lb) 2.0)))))
      ;; 2026-08-11 v5: emparejamiento por PROYECCION PERPENDICULAR (punto
      ;; mas cercano de la otra cadena), no por fraccion de longitud -- con
      ;; cadenas asimetricas (jogs de cruces, esquinas redondeadas) el
      ;; emparejamiento por fraccion desalineaba las parejas y el eje salia
      ;; en zigzag (reporte del usuario: "eje super torcido").
      (setq k 0 mids nil)
      (while (<= k steps)
        (setq frac (/ (float k) steps))
        (setq pa (vlax-curve-getPointAtDist ca (* frac la)))
        (setq pb
          (if pa
            (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list cb pa))
            nil))
        (if (and pa pb (not (vl-catch-all-error-p pb)))
          (setq mids
            (cons
              (list (* 0.5 (+ (car pa) (car pb)))
                    (* 0.5 (+ (cadr pa) (cadr pb))))
              mids)))
        (setq k (1+ k)))
      (setq mids (reverse mids))
      ;; suavizado: promedio movil de 3 (extremos intactos) para limar el
      ;; residuo de los jogs
      (if (> (length mids) 4)
        (progn
          (setq k 1)
          (setq frac (list (car mids)))
          (while (< k (1- (length mids)))
            (setq frac
              (cons
                (mapcar
                  '(lambda (a b c) (/ (+ a b c) 3.0))
                  (nth (1- k) mids) (nth k mids) (nth (1+ k) mids))
                frac))
            (setq k (1+ k)))
          (setq frac (cons (nth (1- (length mids)) mids) frac))
          (setq mids (reverse frac))))
      (entdel ca)
      (entdel cb)
      (if (> (length mids) 1)
        (progn
          (urb:ensure-layer "URB-VIA" 3 T)
          (setq ename
            (entmakex
              (append
                (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity")
                      (cons 100 "AcDbPolyline") (cons 8 "URB-VIA")
                      (cons 90 (length mids)) (cons 70 0))
                (mapcar '(lambda (p) (cons 10 p)) mids))))
          ename)
        nil))
    nil))

;; Resalta una cadena (polilinea temporal) en pantalla con grdraw.
(defun urb:highlight-chain (chain / len d step p1 p2)
  (setq len (vlax-curve-getDistAtParam chain (vlax-curve-getEndParam chain)))
  (setq step (max 0.25 (/ len 80.0)))
  (setq d 0.0)
  (while (< d (- len 1e-6))
    (setq p1 (vlax-curve-getPointAtDist chain d))
    (setq p2 (vlax-curve-getPointAtDist chain (min len (+ d step))))
    (if (and p1 p2) (grdraw p1 p2 3 1))
    (setq d (+ d step)))
  len)

;; Sub-polilinea de una cadena entre las distancias d1..d2, muestreada
;; cada 0.25 m (sigue arcos con precision suficiente para el sardinel).
(defun urb:chain-subpoly (chain d1 d2 / len steps k d pt pts)
  (setq len (- d2 d1))
  (setq steps (max 1 (fix (/ len 0.25))))
  (setq k 0 pts nil)
  (while (<= k steps)
    (setq d (+ d1 (* len (/ (float k) steps))))
    (setq pt (vlax-curve-getPointAtDist chain d))
    (if pt (setq pts (cons (list (car pt) (cadr pt)) pts)))
    (setq k (1+ k)))
  (setq pts (reverse pts))
  (if (> (length pts) 1)
    (entmakex
      (append
        (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity")
              (cons 100 "AcDbPolyline") (cons 8 "URB-VIA")
              (cons 90 (length pts)) (cons 70 0))
        (mapcar '(lambda (p) (cons 10 p)) pts)))
    nil))

;; 2026-08-11 v2: SARDINELES AUTOMATICOS sobre las CADENAS laterales del
;; contorno (soporta arcos y cualquier numero de vertices, ya no solo
;; cuadrilateros -- reporte del usuario). Por cada costado: pregunta
;; [Si/No] (por si un costado ya tiene sardinel de otra via), resalta la
;; cadena en verde, y el usuario marca pares INICIO/FIN de los tramos SIN
;; sardinel (bocas de cruce); Enter sigue. Espesor fijo 0.20 (pedido del
;; usuario). Reutiliza los bordes extremos ya elegidos para el eje
;; automatico (*urb-road-end-edges*) sin repreguntar.
(defun urb:create-road-sardineles (boundary etapa subetapa
   / ends chains chain len kw pts centroid g1 g2 c1 c2 tt1 tt2 swap gaps
   kept prev item seg ename mid-pt deriv dlen normal side-point count)
  (setq ends
    (if (and (boundp '*urb-road-end-edges*) *urb-road-end-edges*)
      *urb-road-end-edges*
      (urb:road-end-edges boundary)))
  (if (null ends)
    (progn
      (prompt "\nSardineles automaticos: no se pudieron determinar los costados.")
      nil)
    (progn
      (setq chains (urb:road-side-chains boundary (car ends) (cadr ends)))
      (if (null chains)
        (progn
          (prompt "\nSardineles automaticos: no se pudieron construir los costados.")
          nil)
        (progn
          (setq pts (urb:lwpoly-points boundary))
          (setq centroid
            (list
              (/ (apply '+ (mapcar 'car pts)) (float (length pts)))
              (/ (apply '+ (mapcar 'cadr pts)) (float (length pts)))))
          (setq count 0)
          (foreach chain chains
            (setq len (urb:highlight-chain chain))
            (initget "Si No")
            (setq kw
              (getkword
                (strcat "\nSardinel en el costado resaltado ("
                        (rtos len 2 2) " m)? [Si/No] <Si>: ")))
            (if (not (= kw "No"))
              (progn
                (setq gaps nil g1 T)
                (while g1
                  (setq g1
                    (getpoint
                      "\n  INICIO de tramo SIN sardinel (cruce; Enter si no hay mas): "))
                  (if g1
                    (progn
                      (setq g2 (getpoint g1 "\n  FIN del tramo sin sardinel: "))
                      (if g2
                        (progn
                          (setq c1
                            (vl-catch-all-apply
                              'vlax-curve-getClosestPointTo (list chain g1)))
                          (setq c2
                            (vl-catch-all-apply
                              'vlax-curve-getClosestPointTo (list chain g2)))
                          (if (and (not (vl-catch-all-error-p c1))
                                   (not (vl-catch-all-error-p c2)))
                            (progn
                              (setq tt1 (vlax-curve-getDistAtPoint chain c1))
                              (setq tt2 (vlax-curve-getDistAtPoint chain c2))
                              (if (and tt1 tt2)
                                (progn
                                  (if (> tt1 tt2)
                                    (setq swap tt1 tt1 tt2 tt2 swap))
                                  (setq gaps (cons (list tt1 tt2) gaps)))))))))))
                (setq gaps (vl-sort gaps '(lambda (a b) (< (car a) (car b)))))
                (setq kept nil prev 0.0)
                (foreach item gaps
                  (if (> (- (car item) prev) 0.10)
                    (setq kept (cons (list prev (car item)) kept)))
                  (setq prev (max prev (cadr item))))
                (if (> (- len prev) 0.10)
                  (setq kept (cons (list prev len) kept)))
                (setq kept (reverse kept))
                (foreach seg kept
                  (setq ename (urb:chain-subpoly chain (car seg) (cadr seg)))
                  (if ename
                    (progn
                      ;; lado de crecimiento: hacia AFUERA de la via
                      (setq mid-pt
                        (vlax-curve-getPointAtDist chain
                          (* 0.5 (+ (car seg) (cadr seg)))))
                      (setq deriv
                        (vlax-curve-getFirstDeriv chain
                          (vlax-curve-getParamAtDist chain
                            (* 0.5 (+ (car seg) (cadr seg))))))
                      (setq dlen (distance '(0.0 0.0 0.0) deriv))
                      (setq normal
                        (if (> dlen 1e-9)
                          (list (- (/ (cadr deriv) dlen)) (/ (car deriv) dlen))
                          (list 0.0 1.0)))
                      (if (< (+ (* (car normal) (- (car mid-pt) (car centroid)))
                                (* (cadr normal) (- (cadr mid-pt) (cadr centroid))))
                             0.0)
                        (setq normal (mapcar '- normal)))
                      (setq side-point
                        (list (+ (car mid-pt) (car normal))
                              (+ (cadr mid-pt) (cadr normal))))
                      (if (urb:build-prefab-from-reference
                            ename side-point "Sardinel" 0.20 etapa subetapa
                            "Exterior")
                        (setq count (1+ count))))))))
            (redraw))
          (foreach chain chains (if (entget chain) (entdel chain)))
          (prompt (strcat "\nSardineles creados: " (itoa count) " tramo(s)."))
          count)))))

;; El eje puede ser mucho mas largo que el tramo (varias vias por etapa
;; comparten un mismo alineamiento). En vez de pedir al usuario que
;; digite donde empieza y cuanto mide su tramo, se proyecta cada vertice
;; del contorno ya dibujado sobre el eje y se toma el rango [min,max] de
;; esas distancias: eso es exactamente el tramo que el usuario dibujo.
(defun urb:axis-range-for-boundary
  (axis boundary-ename / points p closest dist minv maxv)
  (setq points (urb:lwpoly-points boundary-ename))
  (foreach p points
    (setq closest
      (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list axis p)))
    (if (not (vl-catch-all-error-p closest))
      (progn
        (setq dist
          (vl-catch-all-apply 'vlax-curve-getDistAtPoint (list axis closest)))
        (if (not (vl-catch-all-error-p dist))
          (progn
            (if (or (null minv) (< dist minv)) (setq minv dist))
            (if (or (null maxv) (> dist maxv)) (setq maxv dist))))))
  )
  (if (and minv maxv) (list minv (- maxv minv)) nil)
)

;; BUG (2026-07-06, mismo patron que distance/length): "type" es una
;; funcion nativa de AutoLISP (devuelve el tipo de un valor). Usarla
;; como variable local la tapa MIENTRAS ESTA ACTIVA -- y
;; urb:string-equal-p (via urb:safe-string) SI llama (type value)
;; internamente, asi que el foreach de abajo rompia con "no function
;; definition: TYPE" apenas se llegaba a la memoria final de una via
;; (primera vez que el flujo completo se ejecutaba de principio a fin).
;; Renombrado a layer-type.
(defun urb:road-profile-memory (profile-name area base-area left-area right-area / profile layers layer layer-type layer-scope layer-area quantity result)
  (setq profile (urb:road-profile-by-name profile-name))
  (setq layers (cadr profile))
  (setq result
    (strcat
      "Via - memoria de cantidades\n"
      "Perfil: " profile-name
      "\nArea total: " (rtos area 2 2) " m2"
      "\nArea base: " (rtos base-area 2 2) " m2"
      "\nSobreancho izquierdo: " (rtos left-area 2 2) " m2"
      "\nSobreancho derecho: " (rtos right-area 2 2) " m2\n"))
  (foreach layer layers
    (setq layer-type (nth 1 layer))
    (setq layer-scope (nth 4 layer))
    (setq layer-area (if (urb:string-equal-p layer-scope "Base") base-area area))
    (setq quantity
      (if (urb:string-equal-p layer-type "Volumen")
        (* layer-area (atof (nth 2 layer)))
        (* layer-area (+ 1.0 (/ (atof (nth 3 layer)) 100.0)))))
    (setq result
      (strcat result "\n"
        (urb:budget-road-layer-name (nth 0 layer)) ": "
        (rtos quantity 2 2)
        (if (urb:string-equal-p layer-type "Volumen") " m3" " m2"))))
  result)

(defun urb:road-memory-from-data
  (boundary data / area road-length left right over-area left-area right-area
   base-area mov result start-number end-label average-width)
  ;; *urb-memoria-stage*: rastro fino para cazar el "consp nil" reportado
  ;; en vivo (2026-08-11) que no se ha podido reproducir headless -- el
  ;; aviso blindado de urb:create-road lo imprime junto al error.
  (setq *urb-memoria-stage* "areas-17")
  (setq area (atof (urb:safe-string (nth 17 data) "0")))
  (setq *urb-memoria-stage* "areas-18")
  (setq road-length (atof (urb:safe-string (nth 18 data) "0")))
  (setq *urb-memoria-stage* "areas-14")
  (setq left (atof (urb:safe-string (nth 14 data) "0")))
  (setq *urb-memoria-stage* "areas-15")
  (setq right (atof (urb:safe-string (nth 15 data) "0")))
  (setq *urb-memoria-stage* "areas-aritmetica")
  (setq left-area (min area (* road-length left)))
  (setq right-area (min (- area left-area) (* road-length right)))
  (setq over-area (+ left-area right-area))
  (setq base-area (max 0.0 (- area over-area)))
  (setq average-width
    (if (> road-length 1e-9) (/ area road-length) 0.0))
  (setq *urb-memoria-stage* "abscisas")
  (setq start-number
    (urb:station-number (urb:safe-string (nth 10 data) "0+000")))
  (setq end-label (urb:format-station (+ start-number road-length)))
  (setq *urb-memoria-stage* "perfil")
  (setq result
    (urb:road-profile-memory (nth 4 data) area base-area left-area right-area))
  (setq *urb-memoria-stage* "geometria")
  (setq result
    (strcat result
      "\n\nGeometria del tramo:"
      "\nLongitud: " (rtos road-length 2 2) " m"
      "\nAncho medio real (area/longitud): " (rtos average-width 2 2) " m"
      "\nAbscisado: " (urb:safe-string (nth 10 data) "0+000")
      " a " end-label))
  (setq *urb-memoria-stage* "movimiento")
  (setq mov (urb:road-movement-data boundary))
  (if mov
    (setq result
      (strcat result
        "\n\nMovimiento de tierras (" (urb:safe-string (nth 2 mov) "") "):"
        "\nCORTE: " (urb:safe-string (nth 0 mov) "0") " m3"
        "\nRELLENO: " (urb:safe-string (nth 1 mov) "0") " m3"
        "\nSecciones evaluadas: " (urb:safe-string (nth 3 mov) "0")
        " | omitidas: " (urb:safe-string (nth 4 mov) "0")
        "\nAncho usado: " (urb:safe-string (nth 5 mov) "0") " m"
        " | profundidad: " (urb:safe-string (nth 6 mov) "0") " m")))
  (setq *urb-memoria-stage* "fin")
  result)

(defun urb:text-to-mtext (text / position result head)
  (setq text (urb:safe-string text ""))
  (setq result "")
  (while (setq position (vl-string-search "\n" text))
    (setq head (if (> position 0) (substr text 1 position) ""))
    (setq result (strcat result head "\\P"))
    (setq text (substr text (+ position 2))))
  (strcat result text)
)

(defun urb:road-summary-point (boundary / points centroid minx miny maxx maxy point)
  (setq points (urb:lwpoly-points boundary))
  (setq centroid (urb:polygon-centroid points))
  (if centroid
    (list (car centroid) (cadr centroid) 0.0)
    (progn
      ;; Respaldo para contornos degenerados: centro de su caja envolvente.
      (foreach point points
        (if (or (null minx) (< (car point) minx)) (setq minx (car point)))
        (if (or (null miny) (< (cadr point) miny)) (setq miny (cadr point)))
        (if (or (null maxx) (> (car point) maxx)) (setq maxx (car point)))
        (if (or (null maxy) (> (cadr point) maxy)) (setq maxy (cadr point))))
      (if (and minx miny maxx maxy)
        (list (/ (+ minx maxx) 2.0) (/ (+ miny maxy) 2.0) 0.0)
        '(0.0 0.0 0.0))))
)

;; Crea una memoria visible junto a la via. Se etiqueta como geometria
;; generada para que viaje dentro del bloque y se regenere al editar.
(defun urb:road-summary-angle (axis point / closest param derivative angle-value)
  (if axis
    (progn
      (setq closest
        (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list axis point)))
      (if (not (vl-catch-all-error-p closest))
        (progn
          (setq param
            (vl-catch-all-apply 'vlax-curve-getParamAtPoint (list axis closest)))
          (if (not (vl-catch-all-error-p param))
            (progn
              (setq derivative
                (vl-catch-all-apply 'vlax-curve-getFirstDeriv (list axis param)))
              (if (and (not (vl-catch-all-error-p derivative))
                       derivative
                       (> (distance '(0.0 0.0 0.0) derivative) 1e-9))
                (progn
                  (setq angle-value (atan (cadr derivative) (car derivative)))
                  ;; Mantiene el texto paralelo al eje pero siempre legible:
                  ;; si quedaria cabeza abajo, se gira 180 grados.
                  (if (> angle-value (/ pi 2.0))
                    (setq angle-value (- angle-value pi)))
                  (if (< angle-value (- (/ pi 2.0)))
                    (setq angle-value (+ angle-value pi)))
                  angle-value))))))))
)

(defun urb:create-road-summary
  (boundary axis / data content point textheight width mtext handle rotation)
  (setq data (urb:get-xdata-strings boundary "URB_VIA"))
  (if data
    (progn
      (urb:ensure-layer "URB-VIA" 2 T)
      (setq content
        (strcat
          "VIA: " (urb:safe-string (nth 1 data) "")
          "\nETAPA: " (urb:safe-string (nth 2 data) "")
          " | SUBETAPA: " (urb:safe-string (nth 3 data) "")
          "\nESTADO: " (urb:safe-string (nth 19 data) "")
          "\nCAPA DE COTAS: " (urb:safe-string (nth 8 data) "")
          "\n\n" (urb:road-memory-from-data boundary data)))
      (setq point (urb:road-summary-point boundary))
      (setq textheight (max 0.20 (getvar "TEXTSIZE")))
      (setq width (* textheight 55.0))
      (setq mtext
        (vla-AddMText
          (urb:space) (vlax-3d-point point) width
          (urb:text-to-mtext content)))
      ;; El punto calculado es el centro real del contorno; se usa tambien
      ;; como punto medio del cuadro de texto para que el resumen quede
      ;; centrado visualmente dentro de la via.
      (vl-catch-all-apply 'vla-put-AttachmentPoint (list mtext 5))
      (vl-catch-all-apply
        'vla-put-InsertionPoint (list mtext (vlax-3d-point point)))
      (setq rotation (urb:road-summary-angle axis point))
      (if rotation
        (vl-catch-all-apply 'vla-put-Rotation (list mtext rotation)))
      (vla-put-Layer mtext "URB-VIA")
      (vla-put-Color mtext 256)
      (vl-catch-all-apply 'vla-put-TextHeight (list mtext textheight))
      (vl-catch-all-apply 'vla-put-BackgroundFill (list mtext :vlax-true))
      (setq handle
        (vla-get-Handle (vlax-ename->vla-object boundary)))
      (urb:tag-road-generated mtext handle)
      mtext))
)

(defun urb:replace-nth (index value lst / i result item)
  (setq i 0 result nil)
  (foreach item lst
    (setq result (cons (if (= i index) value item) result))
    (setq i (1+ i)))
  (reverse result)
)

;; Desde 4.5.0 el movimiento vive dentro del mismo registro URB_VIA.
;; Indices 23..32: corte, relleno, metodo, secciones, omitidas, ancho,
;; profundidad, cota inicial, cota final y muestras compactas de rasante.
;; Esto evita la perdida observada
;; en Civil 3D al intentar conservar dos aplicaciones XDATA independientes.
(defun urb:road-movement-data (ename / data legacy)
  (setq data (urb:get-xdata-strings ename "URB_VIA"))
  (if (and data (> (length data) 31)
           (/= (urb:safe-string (nth 23 data) "") ""))
    (append (list
      (nth 23 data) (nth 24 data) (nth 25 data)
      (nth 26 data) (nth 27 data) (nth 28 data)
      (nth 29 data) (nth 30 data) (nth 31 data))
      (if (> (length data) 32) (list (nth 32 data)) nil))
    (progn
      ;; Compatibilidad de lectura con vias de versiones 4.4.x.
      (setq legacy (urb:get-xdata-strings ename "URB_VIA_MOV"))
      legacy))
)

(defun urb:set-road-movement-data (boundary mov / data index value)
  (setq data (urb:get-xdata-strings boundary "URB_VIA"))
  (if data
    (progn
      (while (< (length data) 33)
        (setq data (append data (list ""))))
      (setq data
        (urb:replace-nth 19 "MOVIMIENTO DE TIERRAS CALCULADO" data))
      (setq index 0)
      (foreach value mov
        (if (< index 10)
          (setq data
            (urb:replace-nth (+ 23 index)
              (urb:safe-string value "") data)))
        (setq index (1+ index)))
      (urb:set-xdata-strings boundary "URB_VIA" data)
      mov)
    nil)
)

(defun urb:store-selected-road-grade
  (boundary axis-start span direction
   / data records item local c0 c1)
  ;; Persiste la rasante escogida por el usuario ANTES de intentar leer la
  ;; superficie. Asi una via sin TN calculada sigue sirviendo como fuente
  ;; de cota inicial para otra via.
  (cond
    ((and *urb-road-picked-stations*
          (> (length *urb-road-picked-stations*) 1))
      (foreach item *urb-road-picked-stations*
        (setq local
          (if (urb:string-equal-p direction "Final")
            (- (+ axis-start span) (car item))
            (- (car item) axis-start)))
        (setq records (cons (list local (cadr item)) records)))
      (setq records
        (vl-sort records '(lambda (a b) (< (car a) (car b)))))
      (setq c0 (urb:cota-at-axis-distance 0.0 records)
            c1 (urb:cota-at-axis-distance span records)))
    ((and *urb-road-picked-cotas* (= (length *urb-road-picked-cotas*) 2))
      (setq c0 (car *urb-road-picked-cotas*)
            c1 (cadr *urb-road-picked-cotas*)
            records (list (list 0.0 c0) (list span c1)))))
  (if records
    (progn
      (setq data (urb:get-xdata-strings boundary "URB_VIA"))
      (while (< (length data) 33)
        (setq data (append data (list ""))))
      (setq data (urb:replace-nth 30 (rtos c0 2 8) data)
            data (urb:replace-nth 31 (rtos c1 2 8) data)
            data (urb:replace-nth 32 (urb:serialize-lisp records) data))
      (urb:set-xdata-strings boundary "URB_VIA" data)))
  records
)

(defun urb:set-road-status (boundary status / data)
  (setq data (urb:get-xdata-strings boundary "URB_VIA"))
  (if (and data (> (length data) 19))
    (urb:set-xdata-strings boundary "URB_VIA"
      (urb:replace-nth 19 status data)))
  status
)

(defun urb:create-road
  (/ dialog axis auto-axis direction surface cota-info boundary obj area range
   axis-start axis-length handle label start interval data status picks
   memoria-result via-id block-ref doc undo-open undo-result *error*)
  (setq doc (urb:doc))
  (defun *error* (message)
    ;; limpiar TAMBIEN los globales del flujo: si un error corta la
    ;; creacion, unas cotas/estaciones viejas no deben contaminar la
    ;; siguiente via (2026-08-11 v2)
    (setq *urb-road-picked-cotas* nil)
    (setq *urb-road-picked-stations* nil)
    (setq *urb-road-end-edges* nil)
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR AL CREAR VIA: " message)))
    (princ))
  (setq undo-result
    (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
  (setq undo-open (not (vl-catch-all-error-p undo-result)))
  (setq dialog
    (if (urb:confirm-meter-units)
      (urb:dialog-road nil)
      nil))
  (if dialog
    (progn
      ;; 2026-08-11: con alineamiento "Nuevo" ya NO se dibuja el eje antes
      ;; del contorno -- se dibuja el contorno primero y el eje central se
      ;; calcula solo (urb:road-axis-from-boundary); si el contorno no lo
      ;; permite (mas de 4 vertices o arcos), se dibuja a mano como antes.
      (setq auto-axis (urb:string-equal-p (nth 4 dialog) "Nuevo"))
      (setq axis
        (if auto-axis T (urb:select-or-draw-road-axis (nth 4 dialog))))
      (if axis
        (progn
          ;; 2026-08-11 v3: flujo REORDENADO a pedido del usuario ("esta
          ;; largo y no tiene orden"): 1) contorno, 2) eje, 3) sentido,
          ;; 4) superficie y cotas. Antes el sentido del abscisado y la
          ;; referencia de cotas se preguntaban antes de dibujar nada.
          (setq boundary (urb:draw-road-boundary))
          (if (and boundary auto-axis)
            (progn
              (setq axis (urb:road-axis-from-boundary boundary))
              (if axis
                (prompt "\nEje central calculado automaticamente del contorno.")
                (progn
                  (prompt
                    "\nNo se pudo calcular el eje central de este contorno.")
                  (setq axis (urb:select-or-draw-road-axis "Nuevo"))))))
          (if (and boundary (not (and axis (urb:curve-entity-p axis))))
            (progn
              (prompt "\nSin eje valido; via cancelada.")
              (setq boundary nil)))
          (if boundary
            (progn
              (setq direction (urb:road-axis-direction))
              (setq surface (urb:resolve-road-surface (nth 5 dialog)))
              (setq cota-info (urb:road-cota-reference (nth 6 dialog)))
              ;; modo Pendiente: PRIMERO el poligono (ya dibujado), y AHORA
              ;; las cotas -- 2 = pendiente lineal inicial/final; 3 o mas =
              ;; rasante por tramos proyectando cada clic sobre el eje
              (setq *urb-road-picked-cotas* nil)
              (setq *urb-road-picked-stations* nil)
              (setq picks nil)
              (if (urb:string-equal-p (nth 6 dialog) "Pendiente")
                (setq picks (urb:pick-road-cotas)))
              ;; auto-detect en "Textos por capa": el primer clic fue una
              ;; via creada o una etiqueta -> mismo camino que Pendiente
              (if (urb:string-equal-p
                    (urb:safe-string (car cota-info) "") "PICKED")
                (progn
                  (setq picks (cadr cota-info))
                  (setq cota-info (list "" "0" "PENDIENTE"))))
              (cond
                ((null picks) nil)
                ((= (length picks) 2)
                  (setq *urb-road-picked-cotas* (mapcar 'car picks)))
                (T
                  (setq *urb-road-picked-stations*
                    (urb:picked-cotas-to-stations picks axis))
                  (prompt
                    (strcat "\nRasante por tramos con "
                      (itoa (length *urb-road-picked-stations*))
                      " cotas proyectadas sobre el eje."))))
              (setq obj (vlax-ename->vla-object boundary))
              (setq area (vla-get-Area obj))
              ;; El eje puede ser mas largo que esta via (compartido entre
              ;; varias); axis-start/axis-length se detectan solos
              ;; proyectando el contorno recien dibujado sobre el eje.
              (setq range (urb:axis-range-for-boundary axis boundary))
              (if range
                (progn
                  (setq axis-start (car range))
                  (setq axis-length (cadr range)))
                (progn
                  (prompt
                    (strcat
                      "\nNo se pudo ubicar el contorno sobre el eje;"
                      " se usara el eje completo."))
                  (setq axis-start 0.0)
                  (setq axis-length
                    (vlax-curve-getDistAtParam axis (vlax-curve-getEndParam axis)))))
              (if (<= axis-length 0.01)
                (prompt
                  "\nEl contorno dibujado no genera un tramo valido sobre el eje.")
                (progn
                  (setq handle (vla-get-Handle obj))
                  ;; via-id: identificador estable de esta via (ver nota en
                  ;; urb:set-road-data) usado como llave de la cache de eje,
                  ;; en vez del handle (que cambiara cada vez que se edite).
                  (setq via-id (strcat handle "-" (itoa (getvar "MILLISECS"))))
                  (urb:cache-road-axis via-id axis)
                  (setq label (urb:prompt-station-start (urb:format-station axis-start)))
                  (setq start (urb:station-number label))
                  (setq interval (atof (nth 8 dialog)))
                  (setq status
                    (if (and (not (urb:string-equal-p surface "NO SELECCIONADA"))
                             (urb:string-equal-p (nth 2 cota-info) "DETECTADAS"))
                      "DATOS PRELIMINARES" "MOVIMIENTO DE TIERRAS PENDIENTE"))
                  (vl-catch-all-apply
                    'urb:set-xdata-strings
                    (list axis "URB_VIA_EJE" (list handle via-id)))
                  (urb:set-road-data boundary
                    (nth 0 dialog) (nth 1 dialog) (nth 2 dialog) (nth 3 dialog)
                    (vla-get-Handle (vlax-ename->vla-object axis))
                    surface (nth 6 dialog) (nth 0 cota-info) (nth 1 cota-info)
                    label (nth 8 dialog) direction (nth 9 dialog)
                    (nth 10 dialog) (nth 11 dialog) (nth 12 dialog)
                    (rtos area 2 6) (rtos axis-length 2 6) status (nth 4 dialog)
                    (rtos axis-start 2 6) via-id)
                  (urb:store-selected-road-grade
                    boundary axis-start axis-length direction)
                  (urb:generate-road-stations
                    axis handle start interval direction axis-start axis-length)
                  ;; Calculo automatico e integrado: si hay superficie y cotas
                  ;; de proyecto (o el usuario las digita), queda listo sin
                  ;; comandos adicionales.
                  ;; compute-road-earthworks guarda estado y movimiento en
                  ;; una sola escritura de URB_VIA.
                  (if (urb:try-road-earthworks boundary axis)
                    (setq status "MOVIMIENTO DE TIERRAS CALCULADO"))
                  ;; Representacion grafica ligera: eje dentro del bloque y
                  ;; hatch amarillo transparente. Los datos quedan solo en
                  ;; Propiedades, sin texto superpuesto a la calzada.
                  (urb:create-road-axis-display boundary axis)
                  (urb:create-road-display-hatch boundary)
                  ;; Sardineles a los costados (2026-08-11): antes de
                  ;; empaquetar, con el contorno todavia como polilinea.
                  (urb:create-road-sardineles
                    boundary (nth 1 dialog) (nth 2 dialog))
                  ;; Contorno + abscisado quedan empacados en un bloque con
                  ;; atributos invisibles: los datos calculados se ven en el
                  ;; panel Properties con solo seleccionar la via, sin correr
                  ;; ningun comando adicional (mismo patron que anden).
                  ;; 2026-08-12: la xdata se lee ANTES de empaquetar y se
                  ;; usa de respaldo -- en vivo el usuario recibio el aviso
                  ;; "etapa areas-17 | data: nil": tras empaquetar, la
                  ;; relectura sobre el bloque devolvio nil y la memoria
                  ;; se armaba con data vacia.
                  (setq data (urb:get-xdata-strings boundary "URB_VIA"))
                  (setq block-ref (urb:package-road boundary))
                  (setq boundary
                    (or (urb:as-ename block-ref) boundary))
                  (setq data
                    (or (urb:get-xdata-strings boundary "URB_VIA") data))
                  (vla-Regen (urb:doc) 1)
                  ;; blindado (2026-08-11 v2): un fallo al ARMAR la memoria
                  ;; no debe abortar la creacion (la via ya existe completa
                  ;; en este punto) -- el usuario reporto "bad argument
                  ;; type: consp nil" justo aqui y perdia el cierre limpio.
                  (setq memoria-result
                    (vl-catch-all-apply
                      '(lambda ()
                         (strcat (urb:road-memory-from-data boundary data)
                           "\n\nEstado: " status))))
                  (if (vl-catch-all-error-p memoria-result)
                    (progn
                      (prompt
                        (strcat
                          "\nAviso: la via quedo creada pero no se pudo armar la memoria: "
                          (vl-catch-all-error-message memoria-result)
                          " | etapa memoria: "
                          (urb:safe-string
                            (if (boundp '*urb-memoria-stage*)
                              *urb-memoria-stage* nil)
                            "desconocida")
                          " | data: "
                          (urb:safe-string
                            (vl-catch-all-apply
                              '(lambda () (substr (vl-princ-to-string data) 1 180)))
                            "(ilegible)")))
                      (alert (strcat "Via creada.\n\nEstado: " status)))
                    (alert memoria-result))))))))))
  (setq *urb-road-picked-cotas* nil)
  (setq *urb-road-picked-stations* nil)
  (setq *urb-road-end-edges* nil)
  (if undo-open
    (progn
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (setq undo-open nil)))
  (princ))

(defun urb:road-parent-from-entity (ename / data generated parent parent-data)
  (cond
    ((and
       (setq data (urb:get-xdata-strings ename "URB_VIA"))
       (urb:string-equal-p (car data) "VIA"))
      ename)
    ((setq generated (urb:get-xdata-strings ename "URB_VIA_GEN"))
      (setq parent
        (if (/= (urb:safe-string (car generated) "") "")
          (handent (car generated))
          nil))
      (setq parent-data
        (if parent (urb:get-xdata-strings parent "URB_VIA") nil))
      (if (and parent-data (urb:string-equal-p (car parent-data) "VIA"))
        parent
        nil))
    (T nil)))

(defun urb:selected-roads (selection / index ename parent result)
  (setq index 0)
  (if selection
    (repeat (sslength selection)
      (setq ename (ssname selection index))
      (setq parent (urb:road-parent-from-entity ename))
      (if (and parent (not (member parent result)))
        (setq result (cons parent result)))
      (setq index (1+ index))))
  (reverse result))

(defun urb:edit-road
  (boundary / old dialog axis surface data obj area range axis-start
   axis-length label start interval handle via-id block-ref original-block
   edit-completed cota-info)
  ;; Si la via ya esta empacada en un bloque (atributos visibles en
  ;; Properties), se desempaca primero: se recupera el contorno crudo
  ;; con su xdata intacta y se sigue el mismo flujo de siempre; al
  ;; final se vuelve a empacar con los datos nuevos.
  (if (urb:road-block-p boundary)
    (progn
      ;; Se conserva la referencia anterior hasta que el bloque nuevo haya
      ;; sido creado correctamente. vla-Explode NO elimina el bloque origen.
      (setq original-block boundary)
      (setq boundary (urb:explode-road-block-boundary boundary))))
  (if (not boundary)
    (prompt "\nNo se pudo desempacar el bloque de la via.")
    (progn
      (setq old (urb:get-xdata-strings boundary "URB_VIA"))
      (if old
        (progn
          (setq dialog (urb:dialog-road (urb:road-data-defaults old)))
          (if dialog
            (progn
              ;; via-id: identificador estable de esta via que sobrevive
              ;; al empacado/desempacado en bloque (a diferencia del
              ;; handle, que cambia cada vez que se explota y se vuelve a
              ;; crear la referencia). Se usa como llave de la cache de eje.
              (setq via-id
                (if (and (> (length old) 22) (/= (nth 22 old) ""))
                  (nth 22 old)
                  (strcat
                    (vla-get-Handle (vlax-ename->vla-object boundary))
                    "-" (itoa (getvar "MILLISECS")))))
              (setq axis (handent (nth 5 old)))
              ;; Si el eje vive en un xref, handent nunca lo resuelve; se
              ;; intenta primero la cache de sesion (misma via, mismo eje de
              ;; la ultima vez) antes de pedirle al usuario que lo seleccione
              ;; de nuevo.
              (if (not axis)
                (setq axis (urb:cached-road-axis via-id)))
              (if (not axis)
                (setq axis (urb:select-or-draw-road-axis (nth 4 dialog))))
              (if axis (urb:cache-road-axis via-id axis))
              (if axis
                (progn
                  (setq surface (urb:resolve-road-surface (nth 5 dialog)))
                  (setq cota-info
                    (if (urb:string-equal-p (nth 6 dialog) "Textos por capa")
                      (urb:road-cota-reference (nth 6 dialog))
                      (list (nth 8 old) (nth 9 old) "DETECTADAS")))
                  ;; auto-detect: el primer clic fue una via creada o una
                  ;; etiqueta -> cotas seleccionadas (como modo Pendiente)
                  (if (urb:string-equal-p
                        (urb:safe-string (car cota-info) "") "PICKED")
                    (progn
                      (setq *urb-road-picked-cotas* nil
                            *urb-road-picked-stations* nil)
                      (if (= (length (cadr cota-info)) 2)
                        (setq *urb-road-picked-cotas*
                          (mapcar 'car (cadr cota-info)))
                        (setq *urb-road-picked-stations*
                          (urb:picked-cotas-to-stations
                            (cadr cota-info) axis)))
                      (setq cota-info (list "" "0" "PENDIENTE"))))
                  (setq obj (vlax-ename->vla-object boundary))
                  (setq area (vla-get-Area obj))
                  ;; Se reproyecta el contorno (sin cambios) sobre el eje por
                  ;; si este se volvio a seleccionar durante la edicion.
                  (setq range (urb:axis-range-for-boundary axis boundary))
                  (if range
                    (progn
                      (setq axis-start (car range))
                      (setq axis-length (cadr range)))
                    (progn
                      (prompt
                        (strcat
                          "\nNo se pudo ubicar el contorno sobre el eje;"
                          " se usara el eje completo."))
                      (setq axis-start 0.0)
                      (setq axis-length
                        (vlax-curve-getDistAtParam axis (vlax-curve-getEndParam axis)))))
                  (if (<= axis-length 0.01)
                    (prompt
                      "\nEl contorno de la via no genera un tramo valido sobre el eje.")
                    (progn
                      (setq handle (vla-get-Handle obj))
                      (vl-catch-all-apply
                        'urb:set-xdata-strings
                        (list axis "URB_VIA_EJE" (list handle via-id)))
                      (urb:delete-road-generated handle)
                      (setq label
                        (urb:prompt-station-start
                          (urb:safe-string (nth 10 old) (urb:format-station axis-start))))
                      (setq start (urb:station-number label))
                      (urb:set-road-data boundary
                        (nth 0 dialog) (nth 1 dialog) (nth 2 dialog) (nth 3 dialog)
                        (vla-get-Handle (vlax-ename->vla-object axis))
                        surface (nth 6 dialog) (nth 0 cota-info) (nth 1 cota-info)
                        label (nth 8 dialog) (nth 12 old) (nth 9 dialog)
                        (nth 10 dialog) (nth 11 dialog) (nth 12 dialog)
                        (rtos area 2 6) (rtos axis-length 2 6) (nth 19 old)
                        (nth 4 dialog) (rtos axis-start 2 6) via-id)
                      (urb:store-selected-road-grade
                        boundary axis-start axis-length (nth 12 old))
                      (setq interval (atof (nth 8 dialog)))
                      (urb:generate-road-stations
                        axis handle start interval (nth 12 old)
                        axis-start axis-length)
                      ;; Recalcula el movimiento de tierras si la edicion agrego o
                      ;; cambio la superficie/cotas; si aun falta informacion,
                      ;; queda como estaba (no interrumpe la edicion).
                      ;; El calculo guarda estado y movimiento juntos.
                      (urb:try-road-earthworks boundary axis)
                      ;; Regenera el resumen visible con los datos editados.
                      (urb:create-road-axis-display boundary axis)
                      (urb:create-road-display-hatch boundary)
                      ;; Empaqueta de nuevo en un bloque con atributos: los
                      ;; datos recalculados quedan visibles en Properties
                      ;; con solo seleccionar la via, sin correr comandos.
                      (setq block-ref (urb:package-road boundary))
                      (if (and block-ref original-block)
                        (urb:copy-quantity-scope original-block block-ref))
                      (if block-ref
                        (if (and original-block
                                 (not (urb:delete-anden-block original-block)))
                          (progn
                            ;; Si la referencia anterior no se puede borrar,
                            ;; se descarta la nueva para no duplicar la via.
                            (urb:delete-anden-block (urb:as-ename block-ref))
                            (setq block-ref nil boundary nil)
                            (prompt
                              "\nNo se pudo reemplazar la via anterior; se conservo intacta."))
                          (progn
                            (setq edit-completed T)
                            (setq boundary (urb:as-ename block-ref))
                            (vla-Regen (urb:doc) 1)
                            (alert (urb:road-memory-from-data boundary
                              (urb:get-xdata-strings boundary "URB_VIA")))))
                        (progn
                          ;; Si el empaquetado falla, se descarta la copia de
                          ;; trabajo y se mantiene intacto el bloque anterior.
                          (urb:delete-road-generated handle)
                          (urb:safe-delete obj)
                          (prompt
                            "\nNo se pudo actualizar la via; se conservo el bloque anterior.")))))))))))))
  ;; Si se cancelo el dialogo o no se pudo resolver el eje, elimina
  ;; solamente la copia de trabajo producida por Explode. El bloque
  ;; original permanece intacto y no aparecen vias superpuestas.
  (if (and original-block boundary (not edit-completed))
    (progn
      (setq obj
        (vl-catch-all-apply 'vlax-ename->vla-object (list boundary)))
      (if (not (vl-catch-all-error-p obj)) (urb:safe-delete obj))))
  (princ))

;; Si el usuario ya tiene la via seleccionada (un clic selecciona todo
;; el grupo: contorno + abscisado), se usa esa seleccion directamente
;; en vez de pedirle que vuelva a hacer clic.
(defun urb:road-quantity-command (/ ss ename boundary data)
  (setq ss (ssget "_I"))
  (setq ename
    (if (and ss (> (sslength ss) 0))
      (ssname ss 0)
      (car (entsel "\nSeleccione el contorno o una abscisa de la via: "))))
  (if (and ename (setq boundary (urb:road-parent-from-entity ename)))
    (progn
      (setq data (urb:get-xdata-strings boundary "URB_VIA"))
      (alert (strcat (urb:road-memory-from-data boundary data)
        "\n\nEtapa: " (nth 2 data) " | Subetapa: " (nth 3 data)
        "\nSuperficie: " (nth 6 data)
        "\nEstado: " (nth 19 data))))
    (prompt "\nEl objeto seleccionado no pertenece a una via cuantificable."))
  (princ))

;; ============================================================
;; MOVIMIENTO DE TIERRAS INTEGRADO (4.1.0)
;; Se calcula automaticamente al crear o editar la via y queda
;; guardado dentro de URB_VIA (la memoria de via lo muestra).
;; Metodo de areas extremas: terreno muestreado en 7 ordenadas
;; por abscisa con FindElevationAtXY; rasante
;; tomada de los textos de cota de proyecto (el texto numerico
;; mas cercano a cada abscisa) o, si no alcanzan, cota inicial
;; + pendiente digitadas. Resultado aproximado para presupuesto;
;; el definitivo se obtiene en Civil 3D con corredor + superficie
;; de volumen. Se calcula solo, dentro de crear/editar via.
;; ============================================================

(defun urb:cache-surface-object (name object / key old)
  (setq key (strcase (urb:safe-string name "")))
  (if (and (/= key "") (urb:valid-vla-object-p object))
    (progn
      (if (setq old (assoc key *urb-surface-cache*))
        (setq *urb-surface-cache*
          (subst (cons key object) old *urb-surface-cache*))
        (setq *urb-surface-cache*
          (cons (cons key object) *urb-surface-cache*)))))
  object
)

(defun urb:surface-object-by-name (name / cached ss index ename obj found result)
  (setq cached (cdr (assoc (strcase (urb:safe-string name ""))
                           *urb-surface-cache*)))
  (if (urb:valid-vla-object-p cached) (setq found cached))
  (setq ss
    (if (not found)
      (ssget "_X"
        '((0 . "AECC_TIN_SURFACE,AECC_GRID_SURFACE,AECC_TIN_VOLUME_SURFACE")))))
  (if (and ss (not found))
    (progn
      (setq index 0)
      (while (and (< index (sslength ss)) (not found))
        (setq ename (ssname ss index))
        (setq obj (vlax-ename->vla-object ename))
        (setq result (vl-catch-all-apply 'vla-get-Name (list obj)))
        (if (and (not (vl-catch-all-error-p result))
                 (urb:string-equal-p result name))
          (setq found (urb:cache-surface-object name obj)))
        (setq index (1+ index)))))
  found
)

(defun urb:select-surface-object (stored-name / obj selected result)
  (if (and stored-name
           (/= stored-name "")
           (not (urb:string-equal-p stored-name "NO SELECCIONADA"))
           (not (urb:string-equal-p stored-name "Seleccionar en dibujo")))
    (setq obj (urb:surface-object-by-name stored-name)))
  (if obj
    (prompt
      (strcat "\nSuperficie seleccionada: "
        (urb:safe-string stored-name "")))
    (progn
      ;; nentsel (no entsel) para poder tomar una superficie anidada en un xref.
      (setq selected
        (nentsel "\nSeleccione la superficie topografica de Civil 3D: "))
      (if selected
        (progn
          (setq result
            (vl-catch-all-apply
              'vlax-ename->vla-object
              (list (car selected))))
          (if (not (vl-catch-all-error-p result))
            (progn
              (setq obj result)
              (urb:cache-surface-object
                (urb:safe-string
                  (vl-catch-all-apply 'vla-get-Name (list obj))
                  stored-name)
                obj)
              (if (/= (urb:safe-string stored-name "") "")
                (urb:cache-surface-object stored-name obj))))))))
  obj
)

(defun urb:surface-elevation (surface x y / result)
  (setq result
    (vl-catch-all-apply
      'vlax-invoke
      (list surface 'FindElevationAtXY x y)))
  (if (vl-catch-all-error-p result) nil result)
)

(defun urb:road-profile-depth (profile-name / profile total layer)
  (setq profile (urb:road-profile-by-name profile-name))
  (setq total 0.0)
  (foreach layer (if profile (cadr profile) nil)
    (if (urb:string-equal-p (nth 1 layer) "Volumen")
      (setq total (+ total (atof (nth 2 layer))))))
  total
)

(defun urb:collect-local-cota-texts (layer / ss index ename edata content value point source-id result)
  (setq ss
    (ssget "_X"
      (list '(0 . "TEXT,MTEXT") (cons 8 layer))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq edata (entget ename))
        (setq content (urb:safe-string (cdr (assoc 1 edata)) ""))
        (setq value (urb:parse-real content))
        (setq point (cdr (assoc 10 edata)))
        (setq source-id (urb:safe-string (cdr (assoc 5 edata)) "LOCAL"))
        (if (and (numberp value) (> value 0.0) point)
          (setq result (cons (list point value source-id) result)))
        (setq index (1+ index)))))
  result
)

;; ssget nunca alcanza contenido anidado en un xref, asi que para capas
;; con el patron "XREF|CAPA" (como entget las reporta) hay que ir por el
;; xref manualmente: localizar su INSERT en el dibujo actual (eso si es
;; un objeto de primer nivel, ssget lo encuentra bien), leer su punto de
;; insercion/rotacion/escala, y recorrer la DEFINICION del bloque del
;; xref (vlax-for si perfora dentro) buscando los textos de esa capa,
;; transformando cada punto local a coordenadas reales del dibujo.
(defun urb:xref-insert-transform (xref-name / ss ename obj)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 xref-name))))
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq ename (ssname ss 0))
      (setq obj (vlax-ename->vla-object ename))
      (list
        (vlax-get obj 'InsertionPoint)
        (vla-get-Rotation obj)
        (vla-get-XScaleFactor obj)
        (vla-get-YScaleFactor obj)
        (vla-get-ZScaleFactor obj)))
    nil)
)

;; Un mismo XREF puede estar insertado mas de una vez o existir tambien
;; en una presentacion. La version anterior tomaba siempre el primer INSERT
;; encontrado por ssget; si ese no era el que el usuario estaba viendo, las
;; 2641 cotas se transformaban con una insercion equivocada y ninguna quedaba
;; cerca del eje. Se devuelven todas las transformaciones y la proyeccion
;; posterior conserva automaticamente solo la instancia cercana al tramo.
(defun urb:xref-insert-transforms
  (xref-name / ss index ename obj transform result)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 xref-name))))
  (if ss
    (progn
      (setq index 0)
      (while (< index (sslength ss))
        (setq ename (ssname ss index))
        (setq obj
          (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
        (if (not (vl-catch-all-error-p obj))
          (progn
            (setq transform
              (vl-catch-all-apply 'urb:block-instance-transform (list obj)))
            (if (not (vl-catch-all-error-p transform))
              (setq result (cons transform result)))))
        (setq index (1+ index)))))
  (reverse result)
)

(defun urb:point3d-list (value / raw x y z tail tail2)
  (cond
    ((= (type value) 'VARIANT)
      (setq raw (vlax-variant-value value))
      (if (= (type raw) 'SAFEARRAY)
        (setq value (vlax-safearray->list raw))
        (setq value raw)))
    ((= (type value) 'SAFEARRAY)
      (setq value (vlax-safearray->list value))))
  ;; Admite tanto listas normales (x y z)/(x y) como pares punteados
  ;; devueltos por algunos proxies Civil 3D: (x . y).
  (if (= (type value) 'LIST)
    (progn
      (setq x (car value))
      (setq tail (cdr value))
      (cond
        ((numberp tail)
          (setq y tail z 0.0))
        ((= (type tail) 'LIST)
          (setq y (if tail (car tail) nil))
          (setq tail2 (if tail (cdr tail) nil))
          (cond
            ((numberp tail2) (setq z tail2))
            ((and (= (type tail2) 'LIST) tail2)
              (setq z (car tail2)))
            (T (setq z 0.0))))))
    (setq x nil y nil z nil))
  (if (and (numberp x) (numberp y))
    (list x y (if (numberp z) z 0.0))
    nil)
)

(defun urb:xref-local-to-world
  (local-point transform / pos rot xs ys zs cosine sine lx ly lz)
  (setq local-point (urb:point3d-list local-point))
  (setq pos (urb:point3d-list (nth 0 transform)) rot (nth 1 transform)
        xs (nth 2 transform) ys (nth 3 transform) zs (nth 4 transform))
  (if (and local-point pos)
    (progn
      (setq lx (* (car local-point) xs))
      (setq ly (* (cadr local-point) ys))
      (setq lz (* (caddr local-point) zs))
      (setq cosine (cos rot) sine (sin rot))
      (list
        (+ (car pos) (- (* lx cosine) (* ly sine)))
        (+ (cadr pos) (+ (* lx sine) (* ly cosine)))
        (+ (caddr pos) lz)))
    nil)
)

;; Transformacion (insercion/rotacion/escala) de CUALQUIER referencia de
;; bloque, sea el INSERT de un xref o una referencia anidada dentro de
;; otra definicion -- misma forma (pos rot xs ys zs) para las dos.
(defun urb:block-instance-transform (obj)
  (list
    (urb:point3d-list (vlax-get obj 'InsertionPoint))
    (vla-get-Rotation obj)
    (vla-get-XScaleFactor obj)
    (vla-get-YScaleFactor obj)
    (vla-get-ZScaleFactor obj))
)

;; Si item es un TEXT/MTEXT en layer con contenido numerico > 0,
;; devuelve (punto-local valor); nil si no aplica. layer va con el
;; prefijo completo del xref si aplica (ver nota mas abajo).
(defun urb:cota-text-value (item layer / content point value source-id)
  (if (and (member (vla-get-ObjectName item) '("AcDbText" "AcDbMText"))
           (urb:string-equal-p
             (urb:safe-string
               (vl-catch-all-apply 'vla-get-Layer (list item)) "")
             layer))
    (progn
      (setq content (vl-catch-all-apply 'vla-get-TextString (list item)))
          (setq point (vl-catch-all-apply 'vlax-get (list item 'InsertionPoint)))
      (if (or (vl-catch-all-error-p content) (vl-catch-all-error-p point))
        nil
        (progn
          (setq value (urb:parse-real content))
          (if (and value (> value 0.0))
            (progn
              (setq source-id
                (urb:safe-string
                  (vl-catch-all-apply 'vla-get-Handle (list item)) "TEXT"))
              (list (urb:point3d-list point) value source-id))
            nil))))
    nil)
)

;; Caso real de este proyecto: la etiqueta de cota no esta suelta
;; dentro del xref, sino un nivel mas adentro -- dentro de OTRO bloque
;; insertado dentro del xref (p.ej. un punto COGO de Civil 3D, con
;; nombre anonimo tipo "*U..."). Si item es esa clase de bloque, entra
;; a su definicion y devuelve la lista de (punto valor) que encuentre,
;; ya llevados al sistema LOCAL del CONTENEDOR (el xref), componiendo
;; la transformacion propia de item. nil si item no es un bloque o si
;; algo falla al resolverlo.
(defun urb:nested-block-cota-texts
  (item layer blks / inner-transform inner-origin inner-name inner-def
   sub found raw-point transformed-point value source-id result)
  (if (/= (vla-get-ObjectName item) "AcDbBlockReference")
    nil
    (progn
      (setq inner-transform
        (vl-catch-all-apply 'urb:block-instance-transform (list item)))
      (if (not (vl-catch-all-error-p inner-transform))
        (setq inner-origin (nth 0 inner-transform)))
      ;; El handle de la referencia COGO identifica una etiqueta fisica.
      ;; Sus varias geometrías candidatas conservan el mismo identificador,
      ;; lo que permite elegir despues una sola posicion representativa.
      (setq source-id
        (urb:safe-string
          (vl-catch-all-apply 'vla-get-Handle (list item)) "COGO"))
      (setq inner-name
        (vl-catch-all-apply 'vla-get-EffectiveName (list item)))
      (if (or (vl-catch-all-error-p inner-transform)
              (vl-catch-all-error-p inner-name))
        nil
        (progn
          (setq inner-def
            (vl-catch-all-apply 'vla-Item (list blks inner-name)))
          (if (vl-catch-all-error-p inner-def)
            nil
            (progn
              (vlax-for sub inner-def
                (setq found (urb:cota-text-value sub layer))
                (if found
                  (progn
                    (setq raw-point (urb:point3d-list (car found)))
                    (setq value (cadr found))
                    (setq transformed-point
                      (if raw-point
                        (urb:xref-local-to-world
                          raw-point inner-transform)))
                    ;; Los proxies/etiquetas COGO no son consistentes entre
                    ;; estilos: algunos guardan el texto respecto al bloque,
                    ;; otros respecto al dibujo fuente y otros solo conservan
                    ;; bien el anclaje del punto. Se entregan las tres posiciones
                    ;; candidatas; el filtro de distancia al eje conserva la
                    ;; representacion correcta y descarta las otras dos.
                    (if inner-origin
                      (setq result
                        (cons (list inner-origin value source-id) result)))
                    (if transformed-point
                      (setq result
                        (cons (list transformed-point value source-id) result)))
                    (if raw-point
                      (setq result
                        (cons (list raw-point value source-id) result))))))
              result))))))
)

;; Recorre blk (la definicion del xref) buscando textos de cota en
;; layer, ya sea sueltos o un nivel mas adentro (ver
;; urb:nested-block-cota-texts). Devuelve (punto valor) en el sistema
;; LOCAL de blk -- todavia falta llevarlo a coordenadas del dibujo.
(defun urb:collect-cota-in-block (blk layer blks / item found nested n result)
  (vlax-for item blk
    (setq found (urb:cota-text-value item layer))
    (if found
      (setq result (cons found result))
      (progn
        (setq nested (urb:nested-block-cota-texts item layer blks))
        (foreach n nested (setq result (cons n result))))))
  result
)

(defun urb:collect-xref-cota-texts
  (xref-name layer / transforms transform doc blks blk locals item result)
  (setq transforms (urb:xref-insert-transforms xref-name))
  (if transforms
    (progn
      (setq doc (urb:doc))
      (setq blks (vla-get-Blocks doc))
      (setq blk (vl-catch-all-apply 'vla-Item (list blks xref-name)))
      (if (not (vl-catch-all-error-p blk))
        (progn
          (setq locals (urb:collect-cota-in-block blk layer blks))
          (foreach transform transforms
            (foreach item locals
              (setq result
                (cons
                  (list
                    (urb:xref-local-to-world (car item) transform)
                    (cadr item)
                    (urb:safe-string (nth 2 item) "XREF"))
                  result))))))))
  result
)

;; Textos de la capa cuyo contenido sea un numero > 0: cotas de proyecto.
;; Los textos no numericos de la misma capa se descartan solos. Si la
;; capa llego con el patron "XREF|CAPA" (entget la reporta asi para
;; entidades anidadas), se usa el metodo de xref; si no, ssget normal.
;;
;; OJO: al recorrer un xref con vlax-for, ActiveX reporta la capa de
;; CUALQUIER entidad que pertenezca a ese xref con el prefijo completo
;; "XREF|CAPA" -- incluso viendola desde DENTRO de un bloque anidado un
;; nivel mas (confirmado en vivo: un MTEXT dentro de un bloque de punto
;; COGO, que a su vez esta dentro del xref, seguia reportando
;; "COTAS VIA|V-NODE-TEXT", no solo "V-NODE-TEXT"). Por eso se compara
;; contra la capa COMPLETA en todo el recorrido del xref, no la version
;; sin el prefijo.
(setq *urb-cota-layer-calibrations* nil)

(defun urb:clear-cota-calibration (layer / key entry)
  (setq key (strcase (urb:safe-string layer "")))
  (setq entry (assoc key *urb-cota-layer-calibrations*))
  (if entry
    (setq *urb-cota-layer-calibrations*
      (vl-remove entry *urb-cota-layer-calibrations*)))
  nil
)

(defun urb:set-cota-calibration (layer offset / key entry pair)
  (setq key (strcase (urb:safe-string layer "")))
  (setq pair (cons key offset))
  (setq entry (assoc key *urb-cota-layer-calibrations*))
  (if entry
    (setq *urb-cota-layer-calibrations*
      (subst pair entry *urb-cota-layer-calibrations*))
    (setq *urb-cota-layer-calibrations*
      (cons pair *urb-cota-layer-calibrations*)))
  offset
)

(defun urb:get-cota-calibration (layer / entry)
  (setq entry
    (assoc
      (strcase (urb:safe-string layer ""))
      *urb-cota-layer-calibrations*))
  (if entry (cdr entry) nil)
)

(defun urb:apply-cota-calibration
  (layer texts / offset item point value source-id result)
  (setq offset (urb:get-cota-calibration layer))
  (if offset
    (progn
      (foreach item texts
        (setq point (urb:point3d-list (car item)))
        (setq value (cadr item))
        (setq source-id (urb:safe-string (nth 2 item) "COTA"))
        (if (and point (numberp value))
          (setq result
            (cons (list (mapcar '+ point offset) value source-id) result))))
      (reverse result))
    texts)
)

(defun urb:calibrate-cota-layer
  (layer selected texts / ename edata obj raw-content content selected-value
   pick item point item-value dist best-distance best-point offset item-tail)
  (setq ename (if selected (car selected) nil))
  (setq pick
    (if (and selected (cadr selected))
      (urb:point3d-list (cadr selected))
      nil))
  (setq edata (if ename (entget ename) nil))
  (setq obj
    (if ename
      (vl-catch-all-apply 'vlax-ename->vla-object (list ename))))
  (setq raw-content
    (if (and obj (not (vl-catch-all-error-p obj)))
      (vl-catch-all-apply 'vla-get-TextString (list obj))))
  (setq content
    (urb:safe-string
      (if (and raw-content (not (vl-catch-all-error-p raw-content)))
        raw-content
        (cdr (assoc 1 edata)))
      ""))
  (setq selected-value (urb:parse-real content))
  (if (and pick (numberp selected-value) (> selected-value 0.0))
    (foreach item texts
      (setq point
        (if (= (type item) 'LIST)
          (urb:point3d-list (car item))
          nil))
      (setq item-tail (if (= (type item) 'LIST) (cdr item) nil))
      (setq item-value
        (cond
          ((numberp item-tail) item-tail)
          ((and (= (type item-tail) 'LIST) item-tail) (car item-tail))
          (T nil)))
      (if (and point (numberp item-value)
               (< (abs (- item-value selected-value)) 0.001))
        (progn
          (setq dist (distance pick point))
          (if (or (null best-distance) (< dist best-distance))
            (setq best-distance dist best-point point))))))
  (if best-point
    (progn
      (setq offset (mapcar '- pick best-point))
      (urb:set-cota-calibration layer offset)
      (prompt
        (strcat
          "\nCalibracion de cotas aplicada: desplazamiento "
          (rtos (car offset) 2 3) ", "
          (rtos (cadr offset) 2 3) " m."
          " Referencia seleccionada: " (rtos selected-value 2 3) "."))
      offset)
    (progn
      (prompt
        "\nNo se pudo calibrar la posicion visible de la cota seleccionada.")
      nil))
)

(defun urb:collect-cota-texts (layer / bar-pos xref-name result)
  (setq layer (urb:safe-string layer ""))
  (if (/= layer "")
    (progn
      (setq bar-pos (vl-string-search "|" layer))
      (setq result
        (if bar-pos
          (progn
            (setq xref-name (substr layer 1 bar-pos))
            (urb:collect-xref-cota-texts xref-name layer))
          (urb:collect-local-cota-texts layer)))))
  (urb:apply-cota-calibration layer result)
)

(defun urb:nearest-cota (point texts radius / best best-dist item dist)
  (setq best-dist radius)
  (foreach item texts
    (setq dist
      (distance
        (list (car point) (cadr point))
        (list (car (car item)) (cadr (car item)))))
    (if (< dist best-dist)
      (progn
        (setq best (cadr item))
        (setq best-dist dist))))
  best
)

;; Proyecta cada texto de cota sobre el eje seleccionado (aunque el eje y
;; los textos vivan en XREF diferentes). Solo conserva textos cercanos al
;; tramo real de la via y devuelve registros (distancia-eje cota desfase).
(defun urb:project-one-cota-on-axis
  (axis item / point item-tail value source-id closest station offset)
  (setq point
    (if (= (type item) 'LIST)
      (urb:point3d-list (car item))
      nil))
  (setq item-tail (if (= (type item) 'LIST) (cdr item) nil))
  (setq value
    (cond
      ((numberp item-tail) item-tail)
      ((and (= (type item-tail) 'LIST) item-tail) (car item-tail))
      (T nil)))
  (setq source-id
    (if (and (= (type item) 'LIST) (> (length item) 2))
      (urb:safe-string (nth 2 item) "COTA")
      "COTA"))
  (if (and point (numberp value))
    (progn
      (setq closest (vlax-curve-getClosestPointTo axis point))
      (setq closest (urb:point3d-list closest))
      (if closest
        (progn
          (setq station (vlax-curve-getDistAtPoint axis closest))
          (setq offset (distance point closest))
          (list station value offset source-id))
        nil))
    nil)
)

(defun urb:normalize-cota-projection-record
  (record / station tail value tail2 offset source-id)
  (if (= (type record) 'LIST)
    (progn
      (setq station (car record))
      (setq tail (cdr record))
      (if (and (= (type tail) 'LIST) tail)
        (progn
          (setq value (car tail))
          (setq tail2 (cdr tail))
          (if (and (= (type tail2) 'LIST) tail2)
            (progn
              (setq offset (car tail2))
              (if (> (length tail2) 1)
                (setq source-id
                  (urb:safe-string (cadr tail2) "COTA")))))))))
  (if (and (numberp station) (numberp value) (numberp offset))
    (list station value offset (urb:safe-string source-id "COTA"))
    nil)
)

(defun urb:insert-cota-record-sorted
  (record records / item result inserted)
  (foreach item records
    (if (and (not inserted) (< (car record) (car item)))
      (progn
        (setq result (cons record result))
        (setq inserted T)))
    (setq result (cons item result)))
  (if (not inserted) (setq result (cons record result)))
  (reverse result)
)

(defun urb:cota-stations-on-axis
  (axis texts axis-start span max-offset
   / axis-end item projected normalized station offset records
   failed error-message)
  (setq axis-end (+ axis-start span))
  (setq *urb-last-cota-min-offset* nil)
  (setq failed 0 error-message nil)
  (setq *urb-earthwork-stage*
    "proyeccion de cotas sobre el eje - evaluacion individual")
  (foreach item texts
    (setq projected
      (vl-catch-all-apply
        'urb:project-one-cota-on-axis
        (list axis item)))
    (if (vl-catch-all-error-p projected)
      (progn
        (setq failed (1+ failed))
        (setq error-message (vl-catch-all-error-message projected)))
      (progn
        (setq normalized
          (vl-catch-all-apply
            'urb:normalize-cota-projection-record
            (list projected)))
        (if (and (not (vl-catch-all-error-p normalized)) normalized)
        (progn
          (setq station (nth 0 normalized))
          (setq offset (nth 2 normalized))
          (if (or (null *urb-last-cota-min-offset*)
                  (< offset *urb-last-cota-min-offset*))
            (setq *urb-last-cota-min-offset* offset))
          (if (and
                (>= station (- axis-start 1e-6))
                (<= station (+ axis-end 1e-6))
                (<= offset max-offset))
            (setq records (cons normalized records))))
        (if (or (vl-catch-all-error-p normalized) (null normalized))
          (setq failed (1+ failed)))))))
  (setq *urb-last-cota-projection-failures* failed)
  (setq *urb-last-cota-projection-error* error-message)
  (setq *urb-earthwork-stage*
    "proyeccion de cotas sobre el eje - lista terminada")
  records
)

;; Una etiqueta COGO puede producir varias posiciones candidatas (anclaje,
;; texto transformado y proxy). Se conserva solamente la candidata de cada
;; etiqueta cuya distancia transversal al eje sea menor.
(defun urb:cota-best-per-source (records / choices record key entry result)
  (foreach record records
    (setq key (urb:safe-string (nth 3 record) "COTA"))
    (setq entry (assoc key choices))
    (if entry
      (if (< (nth 2 record) (nth 2 (cdr entry)))
        (setq choices (subst (cons key record) entry choices)))
      (setq choices (cons (cons key record) choices))))
  (foreach entry choices (setq result (cons (cdr entry) result)))
  result
)

;; Ajusta el anclaje proyectado a la grilla real del proyecto. Ejemplo:
;; una via que inicia en 0+015.33 se evalua en 0+020, 0+025... y no en
;; 0+020.33, 0+025.33. Solo se ajustan puntos ya cercanos a la grilla.
(defun urb:cota-snap-to-project-grid
  (records axis-start span station-start interval direction
   / record raw traveled project-station grid-station grid-traveled
   snapped-raw tolerance result)
  (setq tolerance (min 1.50 (* interval 0.35)))
  (foreach record records
    (setq raw (nth 0 record))
    (setq traveled
      (if (urb:string-equal-p direction "Final")
        (- (+ axis-start span) raw)
        (- raw axis-start)))
    (setq project-station (+ station-start traveled))
    (setq grid-station
      (* interval (fix (+ (/ project-station interval) 0.50))))
    (setq grid-traveled (- grid-station station-start))
    (if (and (<= (abs (- project-station grid-station)) tolerance)
             ;; Dos intervalos exteriores permiten interpolar contornos que
             ;; empiezan/terminan muy cerca, pero no antes, de la siguiente
             ;; abscisa redonda (p.ej. fin 0+054.12 necesita la cota 0+060).
             (>= grid-traveled (- (* 2.0 interval)))
             (<= grid-traveled (+ span (* 2.0 interval))))
      (setq snapped-raw
        (if (urb:string-equal-p direction "Final")
          (- (+ axis-start span) grid-traveled)
          (+ axis-start grid-traveled)))
      (setq snapped-raw raw))
    (setq result
      (cons (urb:replace-nth 0 snapped-raw record) result)))
  (reverse result)
)

(defun urb:cota-sort-records (records / record result)
  (foreach record records
    (setq result (urb:insert-cota-record-sorted record result)))
  result
)

;; Si varias etiquetas terminan en la misma estacion de proyecto, conserva
;; la que este mas cerca transversalmente del eje.
(defun urb:cota-deduplicate-stations
  (records tolerance / sorted record previous result)
  (setq sorted (urb:cota-sort-records records))
  (foreach record sorted
    (setq previous (car result))
    (if (and previous
             (<= (abs (- (nth 0 record) (nth 0 previous))) tolerance))
      (if (< (nth 2 record) (nth 2 previous))
        (setq result (cons record (cdr result))))
      (setq result (cons record result))))
  (reverse result)
)

(defun urb:cota-at-axis-distance
  (axis-distance records / lower upper item station span ratio)
  (foreach item records
    (setq station (car item))
    (if (<= station axis-distance)
      (if (or (null lower) (> station (car lower)))
        (setq lower item)))
    (if (>= station axis-distance)
      (if (or (null upper) (< station (car upper)))
        (setq upper item))))
  (cond
    ((and lower (< (abs (- axis-distance (car lower))) 0.01))
      (cadr lower))
    ((and upper (< (abs (- axis-distance (car upper))) 0.01))
      (cadr upper))
    ((and lower upper (> (- (car upper) (car lower)) 1e-9))
      (setq span (- (car upper) (car lower)))
      (setq ratio (/ (- axis-distance (car lower)) span))
      (+ (cadr lower) (* ratio (- (cadr upper) (cadr lower)))))
    ;; Si la primera/ultima etiqueta queda muy cerca del extremo, la
    ;; comprobacion de cobertura permite usarla como valor de borde.
    ;; Asi no queda una seccion extrema sin resolver por pocos centimetros.
    ((and (null lower) upper) (cadr upper))
    ((and lower (null upper)) (cadr lower))
    (T nil))
)

(defun urb:cota-stations-cover-p
  (records axis-start axis-end tolerance / item station min-station max-station)
  (if (>= (length records) 2)
    (progn
      (foreach item records
        (setq station (car item))
        (if (or (null min-station) (< station min-station))
          (setq min-station station))
        (if (or (null max-station) (> station max-station))
          (setq max-station station)))
      (and
        min-station max-station
        (> (- max-station min-station) 0.01)
        (<= min-station (+ axis-start tolerance))
        (>= max-station (- axis-end tolerance))))
    nil)
)

(defun urb:terrain-at-section
  (surface axis d half-width
   / point param deriv len normal fractions fraction offset z p profile
   rest first second integral width)
  ;; Siete ordenadas transversales, incluidas ambas orillas y el eje.
  ;; Devuelve (cota-media punto perfil), donde perfil contiene pares
  ;; (desfase cota). La cota media se integra por trapecios, no por el
  ;; promedio simple de tres puntos que usaban las versiones anteriores.
  (setq point
    (vl-catch-all-apply 'vlax-curve-getPointAtDist (list axis d)))
  (if (vl-catch-all-error-p point) (setq point nil))
  (if point
    (progn
      (setq param (vlax-curve-getParamAtDist axis d))
      (setq deriv (vlax-curve-getFirstDeriv axis param))
      (setq len (distance '(0.0 0.0 0.0) deriv))
      (setq normal
        (if (> len 1e-9)
          (list (- (/ (cadr deriv) len)) (/ (car deriv) len) 0.0)
          '(0.0 0.0 0.0)))
      (setq fractions '(-1.0 -0.6666666667 -0.3333333333 0.0
                         0.3333333333 0.6666666667 1.0))
      (foreach fraction fractions
        (setq offset (* fraction half-width)
              p (mapcar '+ point
                  (mapcar '(lambda (v) (* v offset)) normal)))
        (setq z (urb:surface-elevation surface (car p) (cadr p)))
        (if (numberp z)
          (setq profile (append profile (list (list offset z))))))
      ;; Una seccion parcial no se extrapola: se marca omitida para no
      ;; fabricar volumen fuera de la cobertura real de la superficie.
      (if (= (length profile) (length fractions))
        (progn
          (setq rest profile integral 0.0)
          (while (cadr rest)
            (setq first (car rest) second (cadr rest)
                  integral
                    (+ integral
                      (* 0.5 (+ (cadr first) (cadr second))
                        (- (car second) (car first))))
                  rest (cdr rest)))
          (setq width (* 2.0 half-width))
          (list (if (> width 1e-9) (/ integral width) (cadr (nth 3 profile)))
                point profile))
        nil))
    nil)
)

;; BUG (2026-07-06, pre-existente): antes esta funcion re-resolvia el eje
;; con (handent (nth 5 data)) -- pero handent solo busca en la tabla de
;; handles del dibujo ACTUAL, nunca dentro de un xref. Si el eje vive en
;; un xref (caso normal del usuario), handent siempre devolvia nil y la
;; funcion abortaba con "la via no tiene un eje valido" antes incluso de
;; preguntar la cota/pendiente manual. Ahora el eje llega ya resuelto
;; como parametro, tal como lo tiene create-road/edit-road recien
;; seleccionado (con nentsel, que si funciona sobre xrefs).
(defun urb:road-section-samples
  (surface axis axis-start span interval direction width-total
   cota-stations cota-coverage station-start
   / s d section terrain rasante profile result positions end-station next-grid)
  ;; Secciones en inicio/final reales y en las abscisas redondas de proyecto.
  ;; Para inicio 0+015.33: 15.33, 20, 25... 50, 54.12.
  (setq positions (list 0.0))
  (setq end-station (+ station-start span))
  (setq next-grid (* interval (fix (1+ (/ station-start interval)))))
  (if (<= next-grid (+ station-start 1e-6))
    (setq next-grid (+ next-grid interval)))
  (while (< next-grid (- end-station 1e-6))
    (setq positions
      (append positions (list (- next-grid station-start))))
    (setq next-grid (+ next-grid interval)))
  (if (> span 1e-6) (setq positions (append positions (list span))))
  (foreach s positions
    (setq d
      (+ axis-start
        (if (urb:string-equal-p direction "Final")
          (max 0.0 (- span s))
          (min span s))))
    (setq section
      (urb:terrain-at-section surface axis d (/ width-total 2.0)))
    (setq terrain (if section (car section) nil))
    (setq profile (if section (nth 2 section) nil))
    (setq rasante
      (if cota-coverage
        (urb:cota-at-axis-distance d cota-stations)
        nil))
    (setq result (cons (list s terrain rasante profile) result)))
  (reverse result)
)

(defun urb:road-apply-linear-grade
  (samples cota0 cota-final span / slope item result)
  (setq slope
    (if (> span 0.0)
      (* (/ (- cota-final cota0) span) 100.0)
      0.0))
  (foreach item samples
    (setq result
      (cons
        (list
          (nth 0 item)
          (nth 1 item)
          (+ cota0 (* (/ slope 100.0) (nth 0 item)))
          (nth 3 item))
        result)))
  (list (reverse result) slope)
)

(defun urb:road-resolve-grade
  (samples cota-coverage station-count old-cota0 old-cota-final span data
   / cota0 cota-final slope metodo start-num end-label grade)
  (cond
    (cota-coverage
      (list
        samples
        (if (and (boundp '*urb-road-picked-stations*)
                 *urb-road-picked-stations*)
          (strcat
            "rasante por tramos ("
            (itoa station-count) " cotas seleccionadas)")
          (strcat
            "cotas de proyecto interpoladas ("
            (itoa station-count) " textos)"))
        nil
        nil))
    ((and old-cota0 old-cota-final)
      (setq cota0 old-cota0)
      (setq cota-final old-cota-final)
      (setq grade
        (urb:road-apply-linear-grade samples cota0 cota-final span))
      (setq slope (cadr grade))
      (setq metodo
        (strcat
          "cota " (rtos cota0 2 2)
          " -> cota " (rtos cota-final 2 2)
          " (pendiente " (rtos slope 2 2)
          (if *urb-road-picked-cotas*
            "%, cotas seleccionadas en el dibujo)"
            "%, conservada de la edicion anterior)")))
      (list (car grade) metodo cota0 cota-final))
    (T
      (prompt "\nNo hay suficientes cotas de proyecto cerca del eje.")
      (setq start-num
        (urb:station-number (urb:safe-string (nth 10 data) "0+000")))
      (setq end-label (urb:format-station (+ start-num span)))
      (setq cota0
        (getreal
          (strcat
            "\nCota de rasante en la abscisa inicial "
            (urb:safe-string (nth 10 data) "0+000")
            " (Enter omite el calculo): ")))
      (if cota0
        (setq cota-final
          (getreal
            (strcat
              "\nCota de rasante en la abscisa final "
              end-label " (Enter omite el calculo): "))))
      (if (and cota0 cota-final)
        (progn
          (setq grade
            (urb:road-apply-linear-grade samples cota0 cota-final span))
          (setq slope (cadr grade))
          (setq metodo
            (strcat
              "cota " (rtos cota0 2 2)
              " -> cota " (rtos cota-final 2 2)
              " (pendiente " (rtos slope 2 2) "%)"))
          (list (car grade) metodo cota0 cota-final))
        nil)))
)

;; Calcula el aporte de UN intervalo con la misma regla usada por
;; urb:road-integrate-earthworks. Se separa para construir una tabla de
;; auditoria cuyos subtotales reproducen exactamente el total de la via.
(defun urb:road-earthwork-segment
  (delta1 delta2 width-total ds / cut fill average cross-ratio ds1 ds2)
  (setq cut 0.0 fill 0.0)
  (cond
    ((and (>= delta1 0.0) (>= delta2 0.0))
      (setq average (/ (+ delta1 delta2) 2.0))
      (setq cut (* average width-total ds)))
    ((and (<= delta1 0.0) (<= delta2 0.0))
      (setq average (/ (+ (- delta1) (- delta2)) 2.0))
      (setq fill (* average width-total ds)))
    (T
      (setq cross-ratio
        (/ (abs delta1) (+ (abs delta1) (abs delta2))))
      (setq ds1 (* ds cross-ratio))
      (setq ds2 (- ds ds1))
      (if (> delta1 0.0)
        (progn
          (setq cut (* 0.5 delta1 width-total ds1))
          (setq fill (* 0.5 (- delta2) width-total ds2)))
        (progn
          (setq fill (* 0.5 (- delta1) width-total ds1))
          (setq cut (* 0.5 delta2 width-total ds2)))))
  )
  (list cut fill)
)

(defun urb:road-section-earthwork-areas
  (profile terrain rasante width-total depth
   / rest first second design1 design2 delta1 delta2 segment dx cut fill delta)
  ;; Areas transversales separadas de corte/relleno. Cada intervalo entre
  ;; ordenadas se parte exactamente en el cruce por cero, evitando que el
  ;; corte de un costado cancele el relleno del otro.
  (setq cut 0.0 fill 0.0)
  (if (and profile (> (length profile) 1) (numberp rasante))
    (progn
      (setq rest profile)
      (while (cadr rest)
        (setq first (car rest)
              second (cadr rest)
              ;; Corona simetrica: la rasante almacenada corresponde al
              ;; eje; hacia cada borde baja abs(offset)*bombeo. El fondo
              ;; estructural conserva la misma pendiente transversal.
              design1 (- rasante
                         (* (abs (car first)) *urb-road-crossfall*) depth)
              design2 (- rasante
                         (* (abs (car second)) *urb-road-crossfall*) depth)
              delta1 (- (cadr first) design1)
              delta2 (- (cadr second) design2)
              dx (- (car second) (car first))
              segment
                (urb:road-earthwork-segment delta1 delta2 1.0 dx)
              cut (+ cut (car segment))
              fill (+ fill (cadr segment))
              rest (cdr rest)))
      (list cut fill))
    (if (and (numberp terrain) (numberp rasante))
      (progn
        ;; Compatibilidad con pruebas/muestras antiguas sin perfil.
        ;; Respaldo para registros antiguos sin siete ordenadas: compara
        ;; contra el fondo medio de la seccion coronada.
        (setq delta
          (- terrain
             (- rasante depth
                (* 0.25 width-total *urb-road-crossfall*))))
        (list
          (if (> delta 0.0) (* delta width-total) 0.0)
          (if (< delta 0.0) (* (- delta) width-total) 0.0)))
      nil))
)

(defun urb:road-integrate-earthworks
  (samples width-total depth / item prev-areas prev-s areas ds
   cut fill skipped)
  ;; Metodo de areas extremas sobre secciones de siete ordenadas.
  (setq cut 0.0 fill 0.0 skipped 0 prev-areas nil prev-s nil)
  (foreach item samples
    (setq areas
      (urb:road-section-earthwork-areas
        (nth 3 item) (nth 1 item) (nth 2 item) width-total depth))
    (if areas
      (progn
        (if (and prev-areas prev-s)
          (progn
            (setq ds (- (nth 0 item) prev-s))
            (setq cut
              (+ cut (* 0.5 (+ (car prev-areas) (car areas)) ds)))
            (setq fill
              (+ fill (* 0.5 (+ (cadr prev-areas) (cadr areas)) ds)))))
        (setq prev-areas areas
              prev-s (nth 0 item)))
      (progn
        (setq skipped (1+ skipped))
        (setq prev-areas nil prev-s nil))))
  (list cut fill skipped)
)

;; Cada registro:
;; (distancia TN rasante fondo delta area-corte area-relleno vol-corte vol-relleno)
(defun urb:road-earthwork-audit-rows
  (samples width-total depth / item terrain rasante fondo delta area-cut area-fill
   prev-areas prev-s ds areas vol-cut vol-fill result)
  (setq prev-areas nil prev-s nil result nil)
  (foreach item samples
    (setq terrain (nth 1 item))
    (setq rasante (nth 2 item))
    (setq areas
      (urb:road-section-earthwork-areas
        (nth 3 item) terrain rasante width-total depth))
    (if areas
      (progn
        (setq fondo (- rasante depth))
        (setq delta (- terrain fondo))
        (setq area-cut (car areas))
        (setq area-fill (cadr areas))
        (setq vol-cut 0.0 vol-fill 0.0)
        (if (and prev-areas prev-s)
          (progn
            (setq ds (- (nth 0 item) prev-s))
            (setq vol-cut
              (* 0.5 (+ (car prev-areas) area-cut) ds))
            (setq vol-fill
              (* 0.5 (+ (cadr prev-areas) area-fill) ds))))
        (setq result
          (cons
            (list (nth 0 item) terrain rasante fondo delta
              area-cut area-fill vol-cut vol-fill)
            result))
        (setq prev-areas areas prev-s (nth 0 item)))
      (setq prev-areas nil prev-s nil)))
  (reverse result)
)

(defun urb:road-audit-table-point
  (boundary / points point maxx maxy textheight)
  (setq points (urb:lwpoly-points boundary))
  (foreach point points
    (if (or (null maxx) (> (car point) maxx)) (setq maxx (car point)))
    (if (or (null maxy) (> (cadr point) maxy)) (setq maxy (cadr point))))
  (setq textheight (* 0.60 (max 0.20 (getvar "TEXTSIZE"))))
  (if (and maxx maxy)
    (list (+ maxx (* textheight 4.0)) maxy 0.0)
    '(0.0 0.0 0.0))
)

(defun urb:set-table-text-safe (table row column value)
  (vl-catch-all-apply
    'vla-SetText
    (list table row column (urb:safe-string value "")))
)

;; Tabla visible de comprobacion manual. Se etiqueta como objeto generado
;; para que se regenere al EDITAR y quede empacada junto con la via.
(defun urb:create-road-earthwork-audit
  (boundary axis samples width-total depth data cut fill metodo
   / audit point textheight rowheight colwidth rows-count table headers
   row item station-start row-index column handle rotation)
  (setq audit (urb:road-earthwork-audit-rows samples width-total depth))
  (if audit
    (progn
      ;; Capa PROPIA para la tabla de verificacion: permite apagarla o
      ;; congelarla sin ocultar la via (antes iba en URB-VIA junto con
      ;; todo lo demas y no se podia esconder por separado).
      (urb:ensure-layer "URB-VIA-TABLA" 4 T)
      ;; punto elegido por el usuario (comando de Cantidades) o, como
      ;; respaldo, la esquina superior derecha del contorno como antes
      (setq point
        (if (and (boundp '*urb-road-audit-point*) *urb-road-audit-point*)
          *urb-road-audit-point*
          (urb:road-audit-table-point boundary)))
      (setq textheight (* 0.60 (max 0.20 (getvar "TEXTSIZE"))))
      (setq rowheight (* textheight 2.20))
      (setq colwidth (* textheight 11.0))
      ;; Titulo + encabezado + muestras + total.
      (setq rows-count (+ (length audit) 3))
      (setq table
        (vla-AddTable
          (urb:space) (vlax-3d-point point)
          rows-count 9 rowheight colwidth))
      (vla-put-Layer table "URB-VIA-TABLA")
      (vla-put-Color table 256)
      (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed
        (list table :vlax-true))
      (vl-catch-all-apply 'vla-MergeCells (list table 0 0 0 8))
      (urb:set-table-text-safe table 0 0
        (strcat "VERIFICACION MOVIMIENTO DE TIERRAS - "
          (urb:safe-string (nth 1 data) "VIA")
          " | Metodo: " (urb:safe-string metodo "")))
      (setq headers
        '("Abscisa" "TN" "Rasante" "Fondo estr." "Delta"
          "A.corte" "A.relleno" "V.corte tramo" "V.relleno tramo"))
      (setq column 0)
      (foreach item headers
        (urb:set-table-text-safe table 1 column item)
        (setq column (1+ column)))
      (setq station-start
        (urb:station-number (urb:safe-string (nth 10 data) "0+000")))
      (setq row-index 2)
      (foreach row audit
        (urb:set-table-text-safe table row-index 0
          (urb:format-station (+ station-start (nth 0 row))))
        (setq column 1)
        (foreach item (cdr row)
          (urb:set-table-text-safe table row-index column (rtos item 2 2))
          (setq column (1+ column)))
        (setq row-index (1+ row-index)))
      (urb:set-table-text-safe table row-index 0 "TOTAL")
      (urb:set-table-text-safe table row-index 7 (rtos cut 2 2))
      (urb:set-table-text-safe table row-index 8 (rtos fill 2 2))
      (foreach item '(1 2 4)
        (vl-catch-all-apply 'vla-SetTextHeight
          (list table item textheight)))
      (setq rotation (urb:road-summary-angle axis point))
      (if rotation
        (vl-catch-all-apply 'vla-put-Rotation (list table rotation)))
      (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed
        (list table :vlax-false))
      (vl-catch-all-apply 'vla-RecomputeTableBlock (list table :vlax-true))
      (setq handle (vla-get-Handle (vlax-ename->vla-object boundary)))
      ;; 2026-08-11: etiqueta PROPIA (URB_VIA_TABLA), NO URB_VIA_GEN --
      ;; los objetos URB_VIA_GEN se empacan dentro del bloque de la via al
      ;; crear/editar (urb:package-road) y la tabla debe quedar SUELTA
      ;; donde el usuario la puso.
      (urb:set-xdata-strings
        (vlax-vla-object->ename table) "URB_VIA_TABLA" (list handle))
      (prompt
        (strcat
          "\nTabla de verificacion creada: " (itoa (length audit))
          " secciones | corte " (rtos cut 2 2)
          " m3 | relleno " (rtos fill 2 2) " m3."))
      table))
)

;; Borra las tablas de verificacion GENERADAS sueltas en el dibujo (nunca
;; toca tablas hechas a mano). Reconoce el tag nuevo URB_VIA_TABLA y el
;; viejo URB_VIA_GEN (tablas de versiones anteriores que aun no se hayan
;; empacado). parent-handle nil = todas (migracion); con handle, solo las
;; de esa via.
(defun urb:delete-road-audit-tables (parent-handle / ss index ename data count app)
  (setq count 0)
  (foreach app '("URB_VIA_TABLA" "URB_VIA_GEN")
    (setq ss (ssget "_X" (list '(0 . "ACAD_TABLE") (list -3 (list app)))))
    (if ss
      (progn
        (setq index 0)
        (repeat (sslength ss)
          (setq ename (ssname ss index))
          (setq data (urb:get-xdata-strings ename app))
          (if (and data (or (null parent-handle) (= (car data) parent-handle)))
            (if (urb:safe-delete (vlax-ename->vla-object ename))
              (setq count (1+ count))))
          (setq index (1+ index))))))
  count)

(defun urb:road-memory-table-point (road / obj minpt maxpt result textheight)
  (setq obj (vlax-ename->vla-object road)
        result
          (vl-catch-all-apply
            '(lambda ()
               (vla-GetBoundingBox obj 'minpt 'maxpt)
               (setq maxpt (vlax-safearray->list maxpt))
               maxpt)))
  (if (vl-catch-all-error-p result)
    '(0.0 0.0 0.0)
    (progn
      (setq textheight (* 0.60 (max 0.20 (getvar "TEXTSIZE"))))
      (list (+ (car result) (* textheight 4.0)) (cadr result) 0.0))))

(defun urb:road-memory-table-visible-p (parent-handle / ss index ename data found app)
  (foreach app '("URB_VIA_TABLA" "URB_VIA_GEN")
    (if (not found)
      (progn
        (setq ss (ssget "_X" (list '(0 . "ACAD_TABLE") (list -3 (list app))))
              index 0)
        (if ss
          (repeat (sslength ss)
            (setq ename (ssname ss index)
                  data (urb:get-xdata-strings ename app))
            (if (and data (= (car data) parent-handle)) (setq found T))
            (setq index (1+ index)))))))
  found)

(defun urb:set-road-memory-visibility
  (road show / data via-id axis handle created old-busy)
  ;; El atributo MEMORIAS se comporta como un control de dos estados en
  ;; Properties: MOSTRAR/VISIBLE crea la tabla y OCULTAR/OCULTAS la borra.
  ;; La escritura del valor normalizado se silencia para no reactivar el
  ;; reactor del propio atributo.
  (setq data (urb:get-xdata-strings road "URB_VIA")
        handle (cdr (assoc 5 (entget road))))
  (if (and data handle)
    (if show
      (progn
        (if (urb:road-memory-table-visible-p handle)
          (setq created T)
          (progn
            (setq via-id (urb:safe-string (nth 22 data) "")
                  axis (urb:road-axis-recover road data via-id))
            (if axis
              (progn
                (setq *urb-road-audit-point* (urb:road-memory-table-point road))
                (vl-catch-all-apply 'urb:try-road-earthworks (list road axis))
                (setq *urb-road-audit-point* nil)
                (setq created (urb:road-memory-table-visible-p handle)))
              (prompt
                "\nNo se encontro el eje vinculado; edite la via una vez para restablecer el enlace."))))
        (setq old-busy *urb-memory-reactor-busy*
              *urb-memory-reactor-busy* T)
        (mp:setatt-one road "MEMORIAS" (if created "VISIBLES" "OCULTAS"))
        (setq *urb-memory-reactor-busy* old-busy)
        created)
      (progn
        (urb:delete-road-audit-tables handle)
        (setq old-busy *urb-memory-reactor-busy*
              *urb-memory-reactor-busy* T)
        (mp:setatt-one road "MEMORIAS" "OCULTAS")
        (setq *urb-memory-reactor-busy* old-busy)
        T))
    nil))

(defun urb:toggle-road-memory-command
  (/ selected road data handle visible)
  (setq selected (entsel "\nSeleccione la via para mostrar/ocultar sus memorias: "))
  (setq road (if selected (urb:road-parent-from-entity (car selected)) nil))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq handle (cdr (assoc 5 (entget road)))
            visible (urb:road-memory-table-visible-p handle))
      (if visible
        (progn
          (urb:set-road-memory-visibility road nil)
          (prompt "\nMemorias de la via ocultas."))
        (progn
          (if (urb:set-road-memory-visibility road T)
            (prompt "\nMemorias de la via desplegadas.")))))
    (prompt "\nEl objeto seleccionado no es una via creada por el programa."))
  (princ))

(defun c:QMEMORIAVIA () (urb:toggle-road-memory-command))

(defun mp:delete-tramo-memory-tables (parent-handle / ss i en data count)
  (setq count 0
        ss (ssget "_X" '((0 . "ACAD_TABLE") (-3 ("MP_TRAMO_TABLA"))))
        i 0)
  (if ss
    (repeat (sslength ss)
      (setq en (ssname ss i)
            data (urb:get-xdata-strings en "MP_TRAMO_TABLA"))
      (if (and data (= (car data) parent-handle))
        (if (urb:safe-delete (vlax-ename->vla-object en))
          (setq count (1+ count))))
      (setq i (1+ i))))
  count)

(defun mp:create-tramo-memory-table
  (tramo / obj vals base reference p1 p2 length-value surface key0 key1
   diameter bedding width n i frac point tn key bottom depth area prev-area
   ds volume cumulative rows row table point-table textheight rowheight
   colwidth columns item col row-index handle)
  (setq obj (vlax-ename->vla-object tramo)
        vals (mp:att-alist tramo)
        base (mp:infer-base (vla-get-EffectiveName obj) vals)
        reference (mp:reference-plan-points obj)
        key0 (mp:numeric-real (mp:getval "COTA_CLAVE_INI" vals ""))
        key1 (mp:numeric-real (mp:getval "COTA_CLAVE_FIN" vals ""))
        surface (mp:current-terrain-surface))
  (cond
    ((not (mp:gravity-tramo-p base))
      (prompt "\nLa tabla detallada de excavacion aplica a tramos hidrosanitarios por gravedad.") nil)
    ((or (null key0) (null key1))
      (prompt
        "\nMemoria no disponible: faltan las cotas clave inicial y/o final; la excavacion mostrada como 0 no es confiable.") nil)
    ((or (null surface) (null reference))
      (prompt "\nMemoria no disponible: no se encontro SUP_TN o la geometria del tramo.") nil)
    (T
      (setq p1 (car reference) p2 (cadr reference)
            length-value (mp:distance-2d p1 p2)
            diameter (* 0.0254
              (mp:number-or (mp:getval "DIAMETRO" vals "0") 0.0))
            bedding (mp:number-or (mp:getval "ESPESOR_CAMA" vals "0.10") 0.10)
            width (mp:number-or (mp:getval "ANCHO_ZANJA" vals "0") 0.0)
            n (min 200 (max 2 (fix (+ 0.999999 (/ length-value 2.50)))))
            ds (/ length-value (float n))
            i 0 cumulative 0.0)
      (repeat (1+ n)
        (setq frac (/ (float i) (float n))
              point
                (list
                  (+ (car p1) (* frac (- (car p2) (car p1))))
                  (+ (cadr p1) (* frac (- (cadr p2) (cadr p1)))))
              tn (mp:terrain-elevation-at-point surface point)
              key (+ key0 (* frac (- key1 key0)))
              bottom (- key diameter bedding)
              depth (if tn (max 0.0 (- tn bottom)) nil)
              area (if depth (* width depth) nil)
              volume 0.0)
        (if (and area prev-area)
          (setq volume (* 0.5 (+ prev-area area) ds)
                cumulative (+ cumulative volume)))
        (setq rows
          (append rows
            (list (list (* frac length-value) tn key bottom depth area
                    volume cumulative))))
        (setq prev-area area i (1+ i)))
      (if (vl-some '(lambda (r) (null (nth 1 r))) rows)
        (progn
          (prompt "\nMemoria no creada: una o mas secciones estan fuera de la superficie TN.")
          nil)
        (progn
          (setq point-table (urb:road-memory-table-point tramo)
                textheight (* 0.60 (max 0.20 (getvar "TEXTSIZE")))
                rowheight (* textheight 2.20)
                colwidth (* textheight 11.0)
                table
                  (vla-AddTable (urb:space) (vlax-3d-point point-table)
                    (+ (length rows) 3) 8 rowheight colwidth))
          (urb:ensure-layer "PPTO-TABLAS-MEMORIA" 4 T)
          (vla-put-Layer table "PPTO-TABLAS-MEMORIA")
          (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed
            (list table :vlax-true))
          (vl-catch-all-apply 'vla-MergeCells (list table 0 0 0 7))
          (urb:set-table-text-safe table 0 0
            (strcat "MEMORIA MOVIMIENTO DE TIERRAS - "
              (mp:getval "POZO_INI" vals "?") " - "
              (mp:getval "POZO_FIN" vals "?")))
          (setq columns
            '("Distancia" "TN" "Cota clave" "Fondo zanja"
              "Profundidad" "Area exc." "Vol. tramo" "Vol. acum."))
          (setq col 0)
          (foreach item columns
            (urb:set-table-text-safe table 1 col item)
            (setq col (1+ col)))
          (setq row-index 2)
          (foreach row rows
            (setq col 0)
            (foreach item row
              (urb:set-table-text-safe table row-index col (rtos item 2 3))
              (setq col (1+ col)))
            (setq row-index (1+ row-index)))
          (urb:set-table-text-safe table row-index 0 "TOTAL EXCAVACION")
          (urb:set-table-text-safe table row-index 7 (rtos cumulative 2 3))
          (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed
            (list table :vlax-false))
          (vl-catch-all-apply 'vla-RecomputeTableBlock (list table :vlax-true))
          (setq handle (cdr (assoc 5 (entget tramo))))
          (urb:set-xdata-strings (vlax-vla-object->ename table)
            "MP_TRAMO_TABLA" (list handle))
          table)))))

(defun mp:tramo-memory-table-visible-p (parent-handle / ss i en data found)
  (setq ss (ssget "_X" '((0 . "ACAD_TABLE") (-3 ("MP_TRAMO_TABLA"))))
        i 0)
  (if ss
    (repeat (sslength ss)
      (setq en (ssname ss i)
            data (urb:get-xdata-strings en "MP_TRAMO_TABLA"))
      (if (and data (= (car data) parent-handle)) (setq found T))
      (setq i (1+ i))))
  found)

(defun mp:set-tramo-memory-visibility
  (tramo show / handle table created old-busy)
  (setq handle (cdr (assoc 5 (entget tramo))))
  (if handle
    (if show
      (progn
        (if (mp:tramo-memory-table-visible-p handle)
          (setq created T)
          (progn
            (setq table (mp:create-tramo-memory-table tramo)
                  created (if table T nil))))
        (setq old-busy *urb-memory-reactor-busy*
              *urb-memory-reactor-busy* T)
        (mp:setatt-one tramo "MEMORIAS" (if created "VISIBLES" "OCULTAS"))
        (setq *urb-memory-reactor-busy* old-busy)
        created)
      (progn
        (mp:delete-tramo-memory-tables handle)
        (setq old-busy *urb-memory-reactor-busy*
              *urb-memory-reactor-busy* T)
        (mp:setatt-one tramo "MEMORIAS" "OCULTAS")
        (setq *urb-memory-reactor-busy* old-busy)
        T))
    nil))

(defun mp:toggle-tramo-memory-command (/ pick tramo obj vals base handle visible)
  (setq pick (entsel "\nSeleccione el tramo para mostrar/ocultar sus memorias: ")
        tramo (if pick (car pick) nil))
  (if tramo
    (progn
      (setq obj (vlax-ename->vla-object tramo)
            vals (mp:att-alist tramo)
            base (mp:infer-base (vla-get-EffectiveName obj) vals))
      (if (mp:base-is-tramo base)
        (progn
          (setq handle (cdr (assoc 5 (entget tramo)))
                visible (mp:tramo-memory-table-visible-p handle))
          (if visible
            (progn
              (mp:set-tramo-memory-visibility tramo nil)
              (prompt "\nMemorias del tramo ocultas."))
            (progn
              (if (mp:set-tramo-memory-visibility tramo T)
                (prompt "\nMemorias del tramo desplegadas.")))))
        (prompt "\nEl objeto seleccionado no es un tramo de red."))))
  (princ))

(defun c:QMEMORIATRAMO () (mp:toggle-tramo-memory-command))

;; AutoCAD no permite crear un combo personalizado dentro de la paleta
;; Properties desde AutoLISP. Este reactor convierte el atributo editable
;; MEMORIAS en un control funcional: al escribir MOSTRAR/VISIBLE genera la
;; tabla y al escribir OCULTAR/OCULTAS la retira. SendCommand solo difiere
;; el trabajo; nunca se modifica la base de datos dentro de :vlr-modified.
(defun urb:memory-request-value (value / upper)
  (setq upper (strcase (vl-string-trim " " (mp:safe-str value))))
  (cond
    ((member upper '("MOSTRAR" "MOSTRARLAS" "VISIBLE" "VISIBLES" "SI" "S")) 1)
    ((member upper '("OCULTAR" "OCULTARLAS" "OCULTA" "OCULTAS" "NO" "N")) 0)
    (T nil)))

(defun urb:queue-memory-command (/ result)
  (if (and *urb-memory-pending* (not *urb-memory-command-scheduled*))
    (progn
      (setq *urb-memory-command-scheduled* T
            result
              (vl-catch-all-apply
                'vla-SendCommand
                (list (urb:doc) "ACTUALIZARMEMORIAS ")))
      (if (vl-catch-all-error-p result)
        (setq *urb-memory-command-scheduled* nil))))
  (princ))

(defun urb:on-memory-attribute-modified
  (notifier reactor parameters / data value request entry)
  (if (not *urb-memory-reactor-busy*)
    (progn
      (setq data (vlr-data reactor)
            value (vl-catch-all-apply 'vla-get-TextString (list notifier)))
      (if (not (vl-catch-all-error-p value))
        (progn
          (setq request (urb:memory-request-value value))
          (if (numberp request)
            (progn
              (setq entry (list (car data) (cadr data) request))
              (setq *urb-memory-pending*
                (cons entry
                  (vl-remove-if
                    '(lambda (item)
                       (and (= (car item) (car data))
                            (= (cadr item) (cadr data))))
                    *urb-memory-pending*)))
              (urb:queue-memory-command)))))))
  (princ))

(defun urb:process-memory-requests (/ pending entry ename shown hidden failed result)
  (setq pending *urb-memory-pending*
        *urb-memory-pending* nil
        *urb-memory-command-scheduled* nil)
  (if pending
    (progn
      (setq *urb-memory-reactor-busy* T)
      (foreach entry pending
        (setq ename (handent (cadr entry)))
        (if ename
          (progn
            (setq result
              (vl-catch-all-apply
                (if (= (car entry) "VIA")
                  'urb:set-road-memory-visibility
                  'mp:set-tramo-memory-visibility)
                (list ename (= (caddr entry) 1))))
            (if (or (vl-catch-all-error-p result) (not result))
              (setq failed (1+ (if failed failed 0)))
              (if (= (caddr entry) 1)
                (setq shown (1+ (if shown shown 0)))
                (setq hidden (1+ (if hidden hidden 0))))))))
      (setq *urb-memory-reactor-busy* nil)
      (if (or shown hidden failed)
        (prompt
          (strcat "\nMemorias actualizadas: "
            (itoa (if shown shown 0)) " visibles, "
            (itoa (if hidden hidden 0)) " ocultas"
            (if failed (strcat ", " (itoa failed) " sin datos suficientes") "")
            ".")))))
  (princ))

(defun urb:on-memory-command-finished (reactor command-data)
  (if (and *urb-memory-pending* (not *urb-memory-reactor-busy*))
    (urb:process-memory-requests))
  (princ))

(defun urb:attach-memory-reactor-to-block
  (ename / obj attrs attribute kind base handle reactor result bname callbacks)
  (if (and ename (= (cdr (assoc 0 (entget ename))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object ename)
            handle (cdr (assoc 5 (entget ename))))
      (if (urb:get-xdata-strings ename "URB_VIA")
        (setq kind "VIA")
        (progn
          (setq result
            (vl-catch-all-apply 'vla-get-EffectiveName (list obj)))
          (if (not (vl-catch-all-error-p result))
            (progn
              (setq bname result
                    base (mp:infer-base bname (mp:att-alist ename)))
              (if (mp:base-is-tramo base) (setq kind "TRAMO"))))))
      (if (and kind handle (= (vla-get-HasAttributes obj) :vlax-true))
        (progn
          (setq result
            (vl-catch-all-apply 'vlax-invoke (list obj 'GetAttributes)))
          (if (not (vl-catch-all-error-p result))
            (progn
              (setq attrs result
                    callbacks
                      (list
                        (cons :vlr-modified
                          'urb:on-memory-attribute-modified)))
              (foreach attribute attrs
                (if (= (strcase (vla-get-TagString attribute)) "MEMORIAS")
                  (progn
                    (setq result
                      (vl-catch-all-apply
                        'vlr-object-reactor
                        (list (list attribute) (list kind handle) callbacks)))
                    (if (not (vl-catch-all-error-p result))
                      (progn
                        (setq reactor result)
                        (setq *urb-memory-attribute-reactors*
                          (cons reactor *urb-memory-attribute-reactors*))))))))))))
  reactor))

(defun urb:install-memory-property-reactors (/ reactor ss i)
  (if (and (boundp '*urb-memory-attribute-reactors*)
           *urb-memory-attribute-reactors*)
    (foreach reactor *urb-memory-attribute-reactors*
      (vl-catch-all-apply 'vlr-remove (list reactor))))
  (if (and (boundp '*urb-memory-command-reactor*)
           *urb-memory-command-reactor*)
    (vl-catch-all-apply 'vlr-remove (list *urb-memory-command-reactor*)))
  (setq *urb-memory-attribute-reactors* nil
        *urb-memory-pending* nil
        *urb-memory-command-scheduled* nil
        ss (ssget "_X" '((0 . "INSERT") (66 . 1)))
        i 0)
  (if ss
    (repeat (sslength ss)
      (vl-catch-all-apply 'urb:attach-memory-reactor-to-block
        (list (ssname ss i)))
      (setq i (1+ i))))
  (setq *urb-memory-command-reactor*
    (vlr-command-reactor
      nil
      '((:vlr-commandEnded . urb:on-memory-command-finished)
        (:vlr-commandCancelled . urb:on-memory-command-finished)
        (:vlr-commandFailed . urb:on-memory-command-finished))))
  (length *urb-memory-attribute-reactors*))

(defun c:ACTUALIZARMEMORIAS ()
  (urb:process-memory-requests)
  (princ))

;; 2026-08-11 v2: las tablas de verificacion viejas NO estan sueltas en el
;; dibujo -- quedaron EMPACADAS dentro del bloque de cada via
;; (urb:package-road recoge todo lo etiquetado URB_VIA_GEN, tabla
;; incluida), por eso un ssget de primer nivel no las ve y la migracion
;; inicial no borro nada (reporte del usuario). Esta funcion las purga de
;; las DEFINICIONES de los bloques URB_VIA_*: dentro de esos bloques la
;; unica ACAD_TABLE posible es la de verificacion.
(defun urb:purge-road-block-tables (/ blocks bdef bname victims obj count)
  (setq blocks (vla-get-Blocks (urb:doc)) count 0)
  (vlax-for bdef blocks
    (setq bname (strcase (vla-get-Name bdef)))
    (if (and (urb:starts-with bname "URB_VIA_")
             (= (vla-get-IsLayout bdef) :vlax-false)
             (= (vla-get-IsXRef bdef) :vlax-false))
      (progn
        (setq victims nil)
        (vlax-for obj bdef
          (if (= (vla-get-ObjectName obj) "AcDbTable")
            (setq victims (cons obj victims))))
        (foreach obj victims
          (if (urb:safe-delete obj) (setq count (1+ count)))))))
  count)

;; 2026-08-11: tabla de verificacion BAJO DEMANDA (menu Cantidades). La
;; tabla ya no se crea sola al crear/editar la via (aparecia lejos del
;; contorno): aqui el usuario selecciona la via Y el punto donde quiere la
;; tabla. Recalcula el movimiento de tierras con los datos guardados de la
;; via (mismo camino que EDITAR) y borra la tabla anterior de esa via para
;; no duplicar.
(defun urb:road-audit-table-command
  (/ selected road data axis-handle via-id axis point *error*)
  (defun *error* (message)
    (setq *urb-road-audit-point* nil)
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nError en tabla de verificacion: " message)))
    (princ))
  (setq selected (entsel "\nSeleccione la via: "))
  (if selected (setq road (urb:road-parent-from-entity (car selected))))
  (if (and road (setq data (urb:get-xdata-strings road "URB_VIA")))
    (progn
      (setq via-id (if (> (length data) 22) (nth 22 data) ""))
      (setq axis-handle
        (if (> (length data) 5) (urb:safe-string (nth 5 data) "") ""))
      (setq axis
        (or
          (if (/= axis-handle "") (handent axis-handle) nil)
          (if (/= via-id "") (urb:cached-road-axis via-id) nil)))
      (if (and axis (not (urb:curve-entity-p axis))) (setq axis nil))
      (if (not axis) (setq axis (urb:select-or-draw-road-axis "Existente")))
      (setq point (getpoint "\nPunto de insercion de la tabla de verificacion: "))
      (if (and axis point)
        (progn
          (urb:delete-road-audit-tables (cdr (assoc 5 (entget road))))
          (setq *urb-road-audit-point* point)
          (urb:try-road-earthworks road axis)
          (setq *urb-road-audit-point* nil))
        (prompt "\nComando cancelado.")))
    (prompt "\nEl objeto seleccionado no es una via cuantificable."))
  (princ))

(defun urb:compute-road-earthworks
  (boundary data axis / surface depth area axis-length axis-start nominal
   left right width-total design-width geometry-width interval sample-interval direction texts radius span stations raw-stations
   station-start-number coverage
   samples old-mov old-cota0 old-cota-final grade-result totals metodo
   cota0 cota-final cut fill skipped audit-result)
  (setq *urb-earthwork-stage* "inicio del calculo")
  (setq old-mov (urb:road-movement-data boundary))
  (setq old-cota0
    (if (and old-mov (> (length old-mov) 7) (/= (nth 7 old-mov) ""))
      (atof (nth 7 old-mov))
      nil))
  (setq old-cota-final
    (if (and old-mov (> (length old-mov) 8) (/= (nth 8 old-mov) ""))
      (atof (nth 8 old-mov))
      nil))
  (if (and (null old-cota0) (> (length data) 30)
           (/= (urb:safe-string (nth 30 data) "") ""))
    (setq old-cota0 (atof (nth 30 data))))
  (if (and (null old-cota-final) (> (length data) 31)
           (/= (urb:safe-string (nth 31 data) "") ""))
    (setq old-cota-final (atof (nth 31 data))))
  ;; cotas seleccionadas en el flujo Pendiente (una por costado): tienen
  ;; prioridad como par inicial/final para la pendiente lineal
  (if *urb-road-picked-cotas*
    (setq old-cota0 (car *urb-road-picked-cotas*)
          old-cota-final (cadr *urb-road-picked-cotas*)))
  (setq surface (urb:select-surface-object (nth 6 data)))
  (setq depth (urb:road-profile-depth (nth 4 data)))
  (cond
    ((not axis)
      (prompt "\nMovimiento de tierras: la via no tiene un eje valido.")
      nil)
    ((not surface)
      (prompt "\nMovimiento de tierras: sin superficie topografica.")
      nil)
    ((<= depth 0.001)
      (prompt
        (strcat
          "\nMovimiento de tierras: el perfil "
          (urb:safe-string (nth 4 data) "")
          " no tiene capas volumetricas."))
      nil)
    (T
      (setq area (atof (nth 17 data)))
      (setq axis-length (atof (urb:safe-string (nth 18 data) "0")))
      (setq axis-start (atof (urb:safe-string (nth 21 data) "0")))
      (setq nominal (atof (nth 16 data)))
      (setq left (atof (nth 14 data)))
      (setq right (atof (nth 15 data)))
      (setq design-width (+ nominal left right)
            geometry-width
              (if (> axis-length 0.01) (/ area axis-length) 0.0))
      ;; El ancho medio geometrico hace que ancho x longitud reproduzca el
      ;; area real del contorno, incluso en curvas y sobreanchos variables.
      ;; El ancho nominal queda como respaldo y control de discrepancia.
      (setq width-total
        (if (> geometry-width 0.01) geometry-width design-width))
      (if (and (> design-width 0.01) (> geometry-width 0.01)
               (> (/ (abs (- geometry-width design-width)) design-width) 0.02))
        (prompt
          (strcat
            "\nControl de ancho: geometria " (rtos geometry-width 2 2)
            " m vs. diseno " (rtos design-width 2 2)
            " m. El movimiento usa el ancho geometrico.")))
      (setq interval (atof (nth 11 data)))
      (if (<= interval 0.01) (setq interval 10.0))
      (setq sample-interval
        (min interval (max 0.25 *urb-road-earthwork-interval*)))
      (setq direction (urb:safe-string (nth 12 data) "Inicio"))
      (setq station-start-number
        (urb:station-number (urb:safe-string (nth 10 data) "0+000")))
      (if (<= width-total 0.01)
        (progn
          (prompt "\nMovimiento de tierras: ancho de via indeterminado.")
          nil)
        (progn
          (setq *urb-earthwork-stage* "lectura de textos de cota")
          (setq texts (urb:collect-cota-texts (nth 8 data)))
          ;; Distancia TRANSVERSAL: antes se admitian 15 m y entraban
          ;; decenas de etiquetas ajenas o posiciones proxy. Se limita a
          ;; la franja de la propia via; el anclaje COGO correcto queda
          ;; normalmente sobre el eje.
          (setq radius (max 1.50 (min 4.00 (* width-total 0.45))))
          (setq span axis-length)
          (setq *urb-earthwork-stage* "proyeccion de cotas sobre el eje")
          ;; Se incluyen dos estaciones de margen en cada extremo. Un solo
          ;; intervalo no alcanzaba la cota 0+060 cuando el tramo terminaba
          ;; en 0+054.12, y la rasante quedaba plana desde 0+050.
          (setq raw-stations
            (urb:cota-stations-on-axis axis texts
              (- axis-start (* 2.0 interval))
              (+ span (* 4.0 interval)) radius))
          (setq stations (urb:cota-best-per-source raw-stations))
          (setq stations
            (urb:cota-snap-to-project-grid stations axis-start span
              station-start-number interval direction))
          (setq stations (urb:cota-deduplicate-stations stations 0.20))
          (setq coverage
            (urb:cota-stations-cover-p
              stations axis-start (+ axis-start span) interval))
          ;; 2026-08-11: cotas seleccionadas UNA A UNA en modo Pendiente
          ;; (3 o mas, p.ej. pozos sobre la via): reemplazan cualquier
          ;; texto detectado y definen la rasante por tramos completa.
          (if (and (boundp '*urb-road-picked-stations*)
                   *urb-road-picked-stations*)
            (progn
              (setq stations *urb-road-picked-stations*)
              (setq coverage T)))
          (if texts
            (prompt
              (strcat
                "\nTextos de cota leidos: " (itoa (length texts))
                " | candidatos cercanos: " (itoa (length raw-stations))
                " | cotas unicas usadas: " (itoa (length stations)) ".")))
          (if (and *urb-last-cota-projection-failures*
                   (> *urb-last-cota-projection-failures* 0))
            (prompt
              (strcat
                "\nCandidatos proxy descartados por geometria invalida: "
                (itoa *urb-last-cota-projection-failures*)
                (if *urb-last-cota-projection-error*
                  (strcat " | ultimo: " *urb-last-cota-projection-error*)
                  "") ".")))
          (if (and (null stations) *urb-last-cota-min-offset*)
            (prompt
              (strcat
                "\nDiagnostico de cotas: distancia minima texto-eje = "
                (rtos *urb-last-cota-min-offset* 2 3) " m"
                " | radio admitido = " (rtos radius 2 3) " m.")))
          (setq *urb-earthwork-stage* "muestreo de la superficie")
          (setq samples
            (urb:road-section-samples
              surface axis axis-start span sample-interval direction width-total
              stations coverage station-start-number))
          (setq *urb-earthwork-stage* "construccion de la rasante")
          (setq grade-result
            (urb:road-resolve-grade
              samples coverage (length stations) old-cota0 old-cota-final
              span data))
          (if (null grade-result)
            (progn
              (prompt "\nMovimiento de tierras omitido en esta via.")
              nil)
            (progn
              (setq samples (nth 0 grade-result))
              (setq metodo
                (strcat "AREAS_EXTREMAS_7_ORDENADAS_BOMBEO_"
                  (rtos (* 100.0 *urb-road-crossfall*) 2 2) "% - "
                  (urb:safe-string (nth 1 grade-result) "rasante")))
              (setq cota0 (nth 2 grade-result))
              (setq cota-final (nth 3 grade-result))
              (setq *urb-earthwork-stage* "integracion de corte y relleno")
              (setq totals
                (urb:road-integrate-earthworks samples width-total depth))
              (setq cut (nth 0 totals))
              (setq fill (nth 1 totals))
              (setq skipped (nth 2 totals))
              ;; Estado y movimiento se escriben juntos dentro de URB_VIA;
              ;; asi el bloque no depende de una segunda aplicacion XDATA.
              (urb:set-road-movement-data boundary
                (list
                  (rtos cut 2 2)
                  (rtos fill 2 2)
                  metodo
                  (itoa (length samples))
                  (itoa skipped)
                  (rtos width-total 2 2)
                  (rtos depth 2 2)
                  (if cota0 (rtos cota0 2 4) "")
                  (if cota-final (rtos cota-final 2 4) "")
                  (urb:serialize-lisp
                    (urb:compact-road-grade-samples samples))))
              ;; 2026-08-11: la tabla de verificacion YA NO se crea sola al
              ;; crear/editar la via (aparecia lejos del contorno y estorbaba).
              ;; Solo se crea cuando se pide desde Cantidades
              ;; (urb:road-audit-table-command), que deja el punto de
              ;; insercion elegido por el usuario en *urb-road-audit-point*.
              (if (and (boundp '*urb-road-audit-point*) *urb-road-audit-point*)
                (progn
                  (setq *urb-earthwork-stage* "creacion de tabla de verificacion")
                  (setq audit-result
                    (vl-catch-all-apply
                      'urb:create-road-earthwork-audit
                      (list boundary axis samples width-total depth data
                        cut fill metodo)))
                  (if (vl-catch-all-error-p audit-result)
                    (prompt
                      (strcat
                        "\nAviso: no se pudo crear la tabla de verificacion: "
                        (vl-catch-all-error-message audit-result))))))
              (prompt
                (strcat
                  "\nMovimiento de tierras (" metodo "): corte "
                  (rtos cut 2 2) " m3 | relleno "
                  (rtos fill 2 2) " m3."))
              (setq *urb-earthwork-stage* "calculo finalizado")
              (list cut fill))))))))

;; Se llama solo desde crear/editar via; nunca interrumpe el flujo.
;; Recibe el eje ya resuelto (no lo vuelve a buscar con handent, que no
;; funciona si el eje vive en un xref).
(defun urb:try-road-earthworks (boundary axis / data result)
  (setq data (urb:get-xdata-strings boundary "URB_VIA"))
  (if (and data
           (not (urb:string-equal-p (nth 6 data) "NO SELECCIONADA")))
    (progn
      (setq result
        (vl-catch-all-apply
          'urb:compute-road-earthworks
          (list boundary data axis)))
      (if (vl-catch-all-error-p result)
        (progn
          (prompt
            (strcat
              "\nERROR al calcular cortes y rellenos: "
              (vl-catch-all-error-message result)
              " | etapa: "
              (urb:safe-string *urb-earthwork-stage* "desconocida")))
          nil)
        result))
    nil)
)

(defun urb:ramp-local-point (base axis-angle side-sign u v)
  ;; u corre a lo largo del sardinel desde el punto base; v entra
  ;; perpendicular hacia el anden (side-sign decide hacia cual lado).
  (list
    (+ (car base)
       (* u (cos axis-angle))
       (* v side-sign (- (sin axis-angle))))
    (+ (cadr base)
       (* u (sin axis-angle))
       (* v side-sign (cos axis-angle))))
)

(defun urb:ramp-quad-poly (base axis-angle side-sign u1 v1 u2 v2 layer / p1 p2 p3 p4)
  (setq p1 (urb:ramp-local-point base axis-angle side-sign u1 v1)
        p2 (urb:ramp-local-point base axis-angle side-sign u2 v1)
        p3 (urb:ramp-local-point base axis-angle side-sign u2 v2)
        p4 (urb:ramp-local-point base axis-angle side-sign u1 v2))
  (entmake
    (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 100 "AcDbPolyline")
          (cons 8 layer) (cons 90 4) (cons 70 1)
          (cons 10 p1) (cons 10 p2) (cons 10 p3) (cons 10 p4)))
  (entlast)
)

(defun urb:ramp-line (base axis-angle side-sign u1 v1 u2 v2 layer color / p1 p2)
  (setq p1 (urb:ramp-local-point base axis-angle side-sign u1 v1)
        p2 (urb:ramp-local-point base axis-angle side-sign u2 v2))
  (entmake
    (list (cons 0 "LINE") (cons 8 layer) (cons 62 color)
          (cons 10 (list (car p1) (cadr p1) 0.0))
          (cons 11 (list (car p2) (cadr p2) 0.0))))
  (entlast)
)

(defun urb:create-ramp-command
  (/ *error* doc undo-open undo-result base-pt dir-pt side-pt width kw
   depth etapa subetapa axis-angle side-sign block-ref center-pt total-half done
   ext ext-pt ext-sel ext-cp vproj)
  ;; Rampa peatonal parametrica sobre el borde de la via, segun los
  ;; modulos de U-201: banda central lisa (2.00 o 3.00 m) + 2 aletas
  ;; laterales de 0.65 m con adoquin 20x10, fondo = ancho del anden
  ;; (3.50 / 4.00 / otro). Queda empaquetada en su propio bloque
  ;; URB_RAMPA_* con atributos y xdata para cantidades y para el cambio de
  ;; etapa/subetapa en lote.
  (setq doc (urb:doc))
  (defun *error* (message)
    (if undo-open
      (progn (vl-catch-all-apply 'vla-EndUndoMark (list doc)) (setq undo-open nil)))
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR EN RAMPA: " message)))
    (princ))
  (setq undo-result (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
  (setq undo-open (not (vl-catch-all-error-p undo-result)))
  ;; Flujo a pedido del usuario: punto inicial + eje + ancho + un CLICK
  ;; del lado hacia donde va la rampa (igual que el lado del toperol).
  ;; El fondo (3.50 default) es opcion del mismo prompt del ancho.
  ;; Etapa/subetapa arrancan en 1/1 (cambiables en lote).
  (setq depth *urb-anden-default-width*
        side-sign 1.0 width 2.00 etapa "1" subetapa "1" ext 0.0)
  ;; 2026-08-12 v6: FLUJO MANUAL DIRECTO (pedido del usuario -- el
  ;; selector de bordillo se elimino porque no reconocia el fondo hasta
  ;; el bordillo y tocaba digitarlo igual): punto inicial sobre el borde
  ;; de la via, direccion, ancho/fondo (el fondo se digita si el anden no
  ;; es de 3.50) y lado del anden.
  (setq base-pt
    (getpoint "\nPunto INICIAL de la rampa sobre el borde de la via: "))
  (if base-pt
    (setq dir-pt (getpoint base-pt "\nDireccion del borde (eje de la rampa): ")))
  (if dir-pt (setq axis-angle (angle base-pt dir-pt)))
  (if (and base-pt dir-pt axis-angle)
    (progn
      (setq done nil)
      (while (not done)
        (initget "2.00 3.00 Fondo")
        (setq kw
          (getkword
            (strcat "\nAncho de la rampa [2.00/3.00/Fondo]"
                    " (fondo " (rtos depth 2 2) ") <2.00>: ")))
        (cond
          ((= kw "Fondo")
            (setq depth
              (getreal
                (strcat "\nFondo (ancho del anden) en metros <"
                  (rtos *urb-anden-default-width* 2 2) ">: ")))
            (if (or (null depth) (< depth 0.5))
              (setq depth *urb-anden-default-width*)))
          ((= kw "3.00") (setq width 3.00) (setq done T))
          (T (setq width 2.00) (setq done T))))
      ;; 2026-08-12 v7 (pedido del usuario): el MISMO clic define el lado
      ;; del anden Y hasta donde llega el FONDO. Se clickea SOBRE el
      ;; BORDILLO donde termina la rampa (con osnap Nearest cae exacto);
      ;; la distancia perpendicular del clic al eje es el fondo. Sin
      ;; seleccionar entidades: solo el punto, asi funciona igual con
      ;; bordillos en bloques, xrefs o lineas sueltas. Un clic muy cerca
      ;; del eje (<0.5 m) solo define el lado y el fondo queda el
      ;; configurado (3.50 o el digitado con la opcion Fondo).
      (setq side-pt
        (getpoint base-pt
          (strcat "\nClic sobre el BORDILLO donde termina el fondo"
                  " (lado del anden; clic pegado al eje = fondo "
                  (rtos depth 2 2) " m): ")))
      (if side-pt
        (progn
          (setq vproj
            (+ (* (- (car side-pt) (car base-pt)) (- (sin axis-angle)))
               (* (- (cadr side-pt) (cadr base-pt)) (cos axis-angle))))
          (setq side-sign (if (>= vproj 0.0) 1.0 -1.0))
          (if (>= (abs vproj) 0.5)
            (progn
              (setq depth (abs vproj))
              (prompt
                (strcat "\nFondo tomado del clic sobre el bordillo: "
                        (rtos depth 2 2) " m."))))))
      ;; extension hasta el bordillo (2026-08-11, pedido del usuario): si el
      ;; punto inicial se marco sobre el borde del anden pero el bordillo de
      ;; la via queda mas alla, un click sobre ese borde extiende TODO el
      ;; modulo (rampa, A81, toperoles y bordillos verticales) hasta el
      ;; bordillo. Enter = sin extension (comportamiento anterior).
      ;; base-pt es el INICIO del modulo (u=0) SOBRE EL BORDILLO; el
      ;; modulo mide W+1.20 a lo largo del bordillo y crece hacia el anden
      (setq block-ref
        (urb:build-ramp base-pt axis-angle side-sign width depth etapa subetapa ext))
      (if block-ref
        (prompt
          (strcat "\nRampa creada: superficie " (rtos (+ width 0.6) 2 2)
                  "m en la via (central " (rtos width 2 2)
                  "m), modulo total " (rtos (+ width 1.2) 2 2)
                  "m x " (rtos depth 2 2) "m | Etapa " etapa
                  ". Cambie etapa/subetapa en lote desde el menu URBANISMO."))))
    (prompt "\nComando cancelado."))
  (if undo-open
    (progn (vl-catch-all-apply 'vla-EndUndoMark (list doc)) (setq undo-open nil)))
  (princ)
)

(defun urb:ramp-poly-pts (base-pt axis-angle side-sign lpts layer / wpts)
  ;; polilinea cerrada a partir de puntos LOCALES (u v) del marco de la rampa
  (setq wpts
    (mapcar
      '(lambda (p)
         (urb:ramp-local-point base-pt axis-angle side-sign (car p) (cadr p)))
      lpts))
  (entmake
    (append
      (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 100 "AcDbPolyline")
            (cons 8 layer) (cons 90 (length wpts)) (cons 70 1))
      (mapcar '(lambda (p) (cons 10 p)) wpts)))
  (entlast)
)

(defun urb:ramp-frame-uv (base-pt axis-angle side-sign lu lv / w)
  ;; coordenadas del marco rotado (las que esperan clip-stripe y los
  ;; simbolos) para un punto LOCAL (u v) de la rampa
  (setq w (urb:ramp-local-point base-pt axis-angle side-sign lu lv))
  (list
    (+ (* (car w) (cos axis-angle)) (* (cadr w) (sin axis-angle)))
    (+ (* (- (car w)) (sin axis-angle)) (* (cadr w) (cos axis-angle))))
)

(defun urb:build-ramp
  (base-pt axis-angle side-sign width depth etapa subetapa ext
   / doc objects obj hatch boundary area total v0 u1 ent trap treg breg forigin
   rorigin pair piece s e bw gray bp vlo vhi lu lv uvh corners
   block-name blocks block-definition copy-result insert-result block-ref
   block-ename)
  ;; Geometria segun los bloques B RAMPA T1/T2 reales de U-201 (disecados
  ;; 2026-08-09, espécimen sin rotar "T2 - 3.00MT - Anden 4.00MT"):
  ;;  - franjas laterales de 0.20 m a TODO el fondo del anden, con
  ;;    relleno solido (las columnas grises del plano)
  ;;  - superficie de rampa TRAPEZOIDAL: ancho W+0.60 contra la via
  ;;    (W=3.00 -> 3.60, la medida que el usuario senalo) cerrando a W al
  ;;    fondo de la rampa, con 1.10 m de desarrollo (v=0.20 a 1.30)
  ;;  - banda inferior v=1.30-1.50 y junta a v=1.70; el resto del fondo
  ;;    es anden normal (la rampa NO ocupa todo el fondo)
  ;; Ancho total del modulo = W + 1.20 (W=3.00 -> 4.20).
  ;; Componentes por capa segun el marcado del usuario sobre la foto del
  ;; plano (2026-08-09): AMARILLO superficie de rampa con el mismo patron
  ;; del anden (bandas gris/blanco + reticula); NARANJA toperol de 0.20 en
  ;; los dos costados a todo el fondo; VERDE vigas de confinamiento (0.10
  ;; junto a cada toperol + una horizontal de 0.20 entre rampa y anden);
  ;; MORADO prefabricado A81 (las 2 cunas inclinadas que flanquean la
  ;; rampa). Todo queda unido en el mismo bloque URB_RAMPA_*.
  (setq doc (urb:doc))
  (urb:ensure-layer "URB-RAMPA" 7 T)
  (urb:ensure-layer "URB-RAMPA-A81" 8 T)
  (urb:ensure-layer "URB-ANDEN-LOSETA-TOPEROL-20X20" 2 T)
  (if (not (tblsearch "APPID" "URB_ANDEN_GEN")) (regapp "URB_ANDEN_GEN"))
  (setq total (+ width 1.20))
  ;; v0: arranque del modulo hacia la via. Con ext > 0 (2026-08-11) todo el
  ;; modulo se extiende hasta el bordillo de la via (v0 = -ext); el resto de
  ;; la geometria (bordillo horizontal 1.3-1.5, fondo, etc.) no cambia.
  (setq v0 (- (max 0.0 (if ext ext 0.0))))
  (setq objects nil)
  ;; contorno total del modulo
  (setq boundary
    (urb:ramp-quad-poly base-pt axis-angle side-sign 0.0 v0 total depth "URB-RAMPA"))
  (setq objects (cons (vlax-ename->vla-object boundary) objects))
  ;; NARANJA: toperol 0.20 en cada costado, a todo el fondo, con puntos
  (foreach u1 (list 0.0 (+ width 1.0))
    (setq obj
      (vlax-ename->vla-object
        (urb:ramp-quad-poly base-pt axis-angle side-sign
          u1 v0 (+ u1 0.2) depth "URB-ANDEN-LOSETA-TOPEROL-20X20")))
    (setq objects (cons obj objects))
    (setq hatch
      (vl-catch-all-apply 'urb:add-solid-hatch
        (list obj "URB-ANDEN-LOSETA-TOPEROL-20X20" 8)))
    (if (not (vl-catch-all-error-p hatch)) (setq objects (cons hatch objects)))
    (setq lu (+ u1 0.025))
    (while (<= lu (+ u1 0.175 1e-6))
      (setq lv (+ v0 0.025))
      (while (<= lv (- depth 0.025))
        (setq uvh (urb:ramp-frame-uv base-pt axis-angle side-sign lu lv))
        (setq ent
          (urb:add-circle-symbol (car uvh) (cadr uvh) 0.008 axis-angle
            "URB-ANDEN-LOSETA-TOPEROL-20X20" "" 7))
        (setq objects (cons (vlax-ename->vla-object ent) objects))
        (setq lv (+ lv 0.05)))
      (setq lu (+ lu 0.05))))
  ;; VERDE (correccion del usuario: es BORDILLO, no viga): 2 verticales de
  ;; 0.10 junto a cada toperol + 1 horizontal de 0.20 entre rampa y anden,
  ;; en la capa existente de bordillo
  (if (not (tblsearch "LAYER" "URB-BORDILLO"))
    (urb:ensure-layer "URB-BORDILLO" 9 T))
  (foreach u1 (list 0.2 (+ width 0.9))
    (setq obj
      (vlax-ename->vla-object
        (urb:ramp-quad-poly base-pt axis-angle side-sign
          u1 v0 (+ u1 0.1) depth "URB-BORDILLO")))
    (setq objects (cons obj objects))
    (setq hatch (vl-catch-all-apply 'urb:add-solid-hatch (list obj "URB-BORDILLO" 9)))
    (if (not (vl-catch-all-error-p hatch)) (setq objects (cons hatch objects))))
  (setq obj
    (vlax-ename->vla-object
      (urb:ramp-quad-poly base-pt axis-angle side-sign
        0.3 1.3 (+ width 0.9) 1.5 "URB-BORDILLO")))
  (setq objects (cons obj objects))
  (setq hatch (vl-catch-all-apply 'urb:add-solid-hatch (list obj "URB-BORDILLO" 9)))
  (if (not (vl-catch-all-error-p hatch)) (setq objects (cons hatch objects)))
  ;; MORADO: prefabricado A81 -- rectangulo CON DIAGONAL (no triangulo),
  ;; flanqueando la rampa a cada lado
  (foreach corners
    (list
      (list 0.3 0.6 (list 0.3 v0) (list 0.6 1.3))
      (list (+ width 0.6) (+ width 0.9) (list (+ width 0.9) v0) (list (+ width 0.6) 1.3)))
    (setq obj
      (vlax-ename->vla-object
        (urb:ramp-quad-poly base-pt axis-angle side-sign
          (nth 0 corners) v0 (nth 1 corners) 1.3 "URB-RAMPA-A81")))
    (setq objects (cons obj objects))
    ;; la diagonal del cuadrado (el borde inclinado de la rampa)
    (setq ent
      (urb:ramp-line base-pt axis-angle side-sign
        (car (nth 2 corners)) (cadr (nth 2 corners))
        (car (nth 3 corners)) (cadr (nth 3 corners))
        "URB-RAMPA-A81" 8))
    (setq objects (cons (vlax-ename->vla-object ent) objects)))
  ;; AMARILLO: superficie de rampa RECTANGULAR entre los dos A81 (2026-08-11,
  ;; correccion del usuario sobre el PDF: la rampa NO invade los A81 -- antes
  ;; era un trapecio hasta el borde exterior y su textura pintaba encima de
  ;; ellos -- y lleva la MISMA modelacion del anden que el fondo: la textura
  ;; se aplica por banda mas abajo, en el mismo bucle de fase que el fondo)
  (setq trap
    (urb:ramp-quad-poly base-pt axis-angle side-sign
      0.6 v0 (+ width 0.6) 1.3 "URB-RAMPA"))
  (setq obj (vlax-ename->vla-object trap))
  (setq objects (cons obj objects))
  (setq rorigin (urb:ramp-local-point base-pt axis-angle side-sign 0.3 0.0))
  (setq treg
    (vl-catch-all-apply 'urb:add-region-from-object (list obj)))
  ;; ZONA POSTERIOR: el fondo del modulo (del bordillo horizontal hasta el
  ;; final) con la MISMA modelacion del anden real: banda por banda (gris
  ;; loseta 20x20 / blanco adoquin 0.10x0.20), NO una reticula uniforme --
  ;; la textura se aplica por banda mas abajo, en el mismo bucle de fase.
  (setq ent
    (urb:ramp-quad-poly base-pt axis-angle side-sign
      0.3 1.5 (+ width 0.9) depth "URB-RAMPA"))
  (setq obj (vlax-ename->vla-object ent))
  (setq objects (cons obj objects))
  (setq forigin (urb:ramp-local-point base-pt axis-angle side-sign 0.3 1.5))
  (setq breg
    (vl-catch-all-apply 'urb:add-region-from-object (list obj)))
  ;; bandas grises 0.80/1.00 compartidas (misma fase en rampa y fondo,
  ;; para que las bandas queden alineadas de corrido)
  (setq bp (+ (* (car base-pt) (cos axis-angle))
              (* (cadr base-pt) (sin axis-angle))))
  (setq vlo nil vhi nil)
  (foreach corners
    (list (list 0.3 v0) (list (+ width 0.9) v0)
          (list 0.3 depth) (list (+ width 0.9) depth))
    (setq uvh (urb:ramp-frame-uv base-pt axis-angle side-sign
                (car corners) (cadr corners)))
    (if (or (null vlo) (< (cadr uvh) vlo)) (setq vlo (cadr uvh)))
    (if (or (null vhi) (> (cadr uvh) vhi)) (setq vhi (cadr uvh))))
  (setq vlo (- vlo 0.5) vhi (+ vhi 0.5))
  ;; RAMPA y FONDO: la MISMA textura real del anden por banda (2026-08-11,
  ;; correccion del usuario sobre el PDF) -- gris = loseta 20x20 (solido
  ;; gris + reticula 0.20 doble, como urb:decorate-gray-stripe); blanco =
  ;; adoquin (solido blanco + juntas 0.10 al eje y 0.20 perpendicular, como
  ;; urb:decorate-white-stripe). Misma fase de bandas en las dos zonas (el
  ;; bucle de u es compartido) y mismo origen en u (0.3) para que las
  ;; columnas de adoquin queden alineadas de corrido entre rampa y fondo.
  (setq s 0.3 gray nil)
  (while (< s (+ width 0.9 -1e-6))
    (setq bw (if gray 0.80 1.00))
    (setq e (min (+ s bw) (+ width 0.9)))
    (foreach pair (list (list treg rorigin) (list breg forigin))
      (if (not (vl-catch-all-error-p (car pair)))
        (progn
          (setq piece
            (urb:clip-stripe (car pair) (+ bp s) (+ bp e) vlo vhi axis-angle))
          (if piece
            (progn
              (vla-put-Layer piece "URB-RAMPA")
              (setq objects (cons piece objects))
              (if gray
                (progn
                  (setq hatch
                    (vl-catch-all-apply 'urb:add-solid-hatch
                      (list piece "URB-RAMPA" 8)))
                  (if (not (vl-catch-all-error-p hatch))
                    (setq objects (cons hatch objects)))
                  (setq hatch
                    (vl-catch-all-apply 'urb:add-user-hatch
                      (list piece "URB-RAMPA" 0.20 axis-angle T 9 (cadr pair))))
                  (if (not (vl-catch-all-error-p hatch))
                    (setq objects (cons hatch objects))))
                (progn
                  (setq hatch
                    (vl-catch-all-apply 'urb:add-solid-hatch
                      (list piece "URB-RAMPA" 7)))
                  (if (not (vl-catch-all-error-p hatch))
                    (setq objects (cons hatch objects)))
                  (setq hatch
                    (vl-catch-all-apply 'urb:add-user-hatch
                      (list piece "URB-RAMPA" 0.10 axis-angle nil 8 (cadr pair))))
                  (if (not (vl-catch-all-error-p hatch))
                    (setq objects (cons hatch objects)))
                  (setq hatch
                    (vl-catch-all-apply 'urb:add-user-hatch
                      (list piece "URB-RAMPA" 0.20 (+ axis-angle (/ pi 2.0))
                        nil 8 (cadr pair))))
                  (if (not (vl-catch-all-error-p hatch))
                    (setq objects (cons hatch objects))))))))))
    (setq s e gray (not gray)))
  (if (not (vl-catch-all-error-p treg)) (urb:safe-delete treg))
  (if (not (vl-catch-all-error-p breg)) (urb:safe-delete breg))
  (setq objects (reverse objects))
  ;; area util = superficie rectangular de rampa (entre los dos A81),
  ;; incluida la extension hasta el bordillo si la hay
  (setq area (* width (- 1.3 v0)))
  (setq block-name (strcat "URB_RAMPA_" (itoa (getvar "MILLISECS"))))
  (setq blocks (vla-get-Blocks doc))
  (setq block-definition
    (vla-Add blocks (vlax-3d-point '(0.0 0.0 0.0)) block-name))
  (setq copy-result
    (vl-catch-all-apply
      'vla-CopyObjects
      (list doc (urb:object-array-variant objects) block-definition)))
  (if (vl-catch-all-error-p copy-result)
    (progn
      (urb:safe-delete block-definition)
      (prompt (strcat "\nERROR al crear el bloque de la rampa: "
                      (vl-catch-all-error-message copy-result)))
      nil)
    (progn
      (urb:add-invisible-attribute block-definition base-pt "TIPO" "Tipo" "RAMPA")
      (urb:add-invisible-attribute block-definition base-pt "ANCHO_RAMPA" "Ancho rampa m" (rtos width 2 2))
      (urb:add-invisible-attribute block-definition base-pt "FONDO_M" "Fondo m" (rtos depth 2 2))
      (urb:add-invisible-attribute block-definition base-pt "AREA_M2" "Area m2" (rtos area 2 2))
      (urb:add-invisible-attribute block-definition base-pt "TOPEROL_ML" "Toperol ml"
        (rtos (* 2.0 (- depth v0)) 2 2))
      (urb:add-invisible-attribute block-definition base-pt "BORDILLO_ML" "Bordillo ml"
        (rtos (+ (* 2.0 (- depth v0)) (+ width 0.6)) 2 2))
      (urb:add-invisible-attribute block-definition base-pt "A81_UND" "Prefabricado A81 und" "2")
      (urb:add-invisible-attribute block-definition base-pt "ETAPA" "Etapa" etapa)
      (urb:add-invisible-attribute block-definition base-pt "SUBETAPA" "Subetapa" subetapa)
      (setq insert-result
        (vl-catch-all-apply
          'vla-InsertBlock
          (list (urb:space) (vlax-3d-point '(0.0 0.0 0.0)) block-name 1.0 1.0 1.0 0.0)))
      (if (vl-catch-all-error-p insert-result)
        (progn
          (urb:safe-delete block-definition)
          (prompt (strcat "\nERROR al insertar el bloque de la rampa: "
                          (vl-catch-all-error-message insert-result)))
          nil)
        (progn
          (setq block-ref insert-result)
          (vla-put-Layer block-ref "URB-RAMPA")
          (setq block-ename (urb:as-ename block-ref))
          (if block-ename
            (urb:set-xdata-strings block-ename "URB_RAMPA_BLOCK"
              (list "RAMPA" etapa subetapa
                    (rtos width 2 8) (rtos depth 2 8) (rtos area 2 8))))
          (foreach obj objects (urb:safe-delete obj))
          block-ref))))
)

(defun urb:write-stage-dcl ()
  (urb:write-dialog-dcl
    "urbanismo_etapas"
    '*urb-stage-dcl-ok*
    (list
      "urbanismo_etapas : dialog { label = \"Cambiar etapa/subetapa\";"
      ": popup_list { label = \"Etapa\"; key = \"etapa\"; }"
      ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }"
      "ok_cancel; }"))
)

(defun urb:dialog-stage
  (current-etapa current-subetapa / filename dcl-id accepted subetapas result)
  (setq filename (urb:write-stage-dcl))
  (setq current-etapa (urb:safe-string current-etapa "1"))
  (setq current-subetapa (urb:safe-string current-subetapa current-etapa))
  (if (and filename
           (> (setq dcl-id (load_dialog filename)) 0)
           (new_dialog "urbanismo_etapas" dcl-id))
    (progn
      (urb:fill-popup
        "etapa" *urb-etapa-list*
        (urb:index-of current-etapa *urb-etapa-list*))
      (setq *urb-dialog-etapa*
        (nth (atoi (get_tile "etapa")) *urb-etapa-list*))
      (setq subetapas (urb:subetapas-for *urb-dialog-etapa*))
      (urb:fill-popup
        "subetapa" subetapas
        (urb:index-of current-subetapa subetapas))
      (action_tile "etapa" "(urb:dialog-update-subetapa)")
      (action_tile
        "accept"
        (strcat
          "(setq *urb-dialog-etapa-index* (atoi (get_tile \"etapa\"))"
          " *urb-dialog-subetapa-index* (atoi (get_tile \"subetapa\")))"
          "(done_dialog 1)"))
      (setq accepted (= 1 (start_dialog)))
      (unload_dialog dcl-id)
      (if accepted
        (progn
          (setq current-etapa
            (nth *urb-dialog-etapa-index* *urb-etapa-list*))
          (setq subetapas (urb:subetapas-for current-etapa))
          (setq current-subetapa
            (nth *urb-dialog-subetapa-index* subetapas))
          (setq result (list current-etapa current-subetapa)))))
  )
  result
)

(defun urb:apply-etapa-subetapa (ename etapa subetapa / obj data category)
  ;; Cambia SOLO etapa/subetapa de un elemento ya creado, sin reconstruir
  ;; geometria ni recalcular cantidades: la xdata del tipo correspondiente
  ;; (lo que leen las cantidades/Excel) + los atributos ETAPA/SUBETAPA si
  ;; el bloque los tiene (las redes mp: los llevan SOLO como atributos).
  ;; Devuelve el nombre del tipo reconocido, o nil si el objeto no es del
  ;; programa.
  (setq obj (urb:as-vla-object ename))
  (cond
    ((setq data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
      (urb:set-xdata-strings ename "URB_ANDEN_BLOCK"
        (urb:replace-nth 3 subetapa (urb:replace-nth 2 etapa data)))
      (setq category "Andenes"))
    ((setq data (urb:get-xdata-strings ename "URB_VIA"))
      (urb:set-xdata-strings ename "URB_VIA"
        (urb:replace-nth 3 subetapa (urb:replace-nth 2 etapa data)))
      (setq category "Vias"))
    ((setq data (urb:get-xdata-strings ename "URB_PREFAB_BLOCK"))
      (urb:set-xdata-strings ename "URB_PREFAB_BLOCK"
        (urb:replace-nth 2 subetapa (urb:replace-nth 1 etapa data)))
      (setq category "Prefabricados"))
    ((setq data (urb:get-xdata-strings ename "URB_GREEN_BLOCK"))
      (urb:set-xdata-strings ename "URB_GREEN_BLOCK"
        (urb:replace-nth 2 subetapa (urb:replace-nth 1 etapa data)))
      (setq category "Zonas verdes"))
    ((setq data (urb:get-xdata-strings ename "URB_RAMPA_BLOCK"))
      (urb:set-xdata-strings ename "URB_RAMPA_BLOCK"
        (urb:replace-nth 2 subetapa (urb:replace-nth 1 etapa data)))
      (setq category "Rampas"))
    ((and obj (assoc "ETAPA" (urb:block-attribute-values obj)))
      (setq category "Redes / otros bloques")))
  (if (and category obj)
    (progn
      (urb:set-block-attribute obj "ETAPA" etapa)
      (urb:set-block-attribute obj "SUBETAPA" subetapa)))
  category
)

(defun urb:batch-stage-command
  (/ data etapa subetapa ss index ename category counts entry total skipped)
  ;; Cambio rapido de etapa/subetapa en LOTE: primero se seleccionan los
  ;; elementos (mezcla de andenes, vias, redes, prefabricados, zonas
  ;; verdes) y DESPUES sale el dialogo con los desplegables de etapa y
  ;; subetapa (orden pedido por el usuario). Aplica sin redibujar nada --
  ;; editar via el comando EDITAR reconstruye la geometria completa
  ;; (minutos por anden); esto tarda segundos porque solo toca metadatos.
  (prompt
    "\nSeleccione los elementos a cambiar (andenes, vias, redes, prefabricados, zonas verdes): ")
  (setq ss (ssget))
  (if (null ss)
    (prompt "\nNo se selecciono ningun objeto.")
    (progn
      (setq data (urb:dialog-stage "1" "1"))
      (if (null data)
        (prompt "\nComando cancelado.")
        (progn
          (setq etapa (nth 0 data) subetapa (nth 1 data))
          (setq counts nil total 0 index 0)
          (repeat (sslength ss)
            (setq ename (ssname ss index))
            (setq category
              (vl-catch-all-apply
                'urb:apply-etapa-subetapa (list ename etapa subetapa)))
            (if (vl-catch-all-error-p category) (setq category nil))
            (if category
              (progn
                (setq total (1+ total))
                (setq entry (assoc category counts))
                (setq counts
                  (if entry
                    (subst (cons category (1+ (cdr entry))) entry counts)
                    (cons (cons category 1) counts)))))
            (setq index (1+ index)))
          (setq skipped (- (sslength ss) total))
          (prompt
            (strcat "\nEtapa " etapa " / Subetapa " subetapa
                    " aplicada a " (itoa total) " elemento(s)."))
          (foreach entry (reverse counts)
            (prompt (strcat "\n  " (car entry) ": " (itoa (cdr entry)))))
          (if (> skipped 0)
            (prompt
              (strcat "\n  Ignorados (no son elementos del programa): "
                      (itoa skipped))))))))
  (princ)
)

(defun urb:write-main-menu-dcl (/ filename)
  (setq filename (urb:temp-file "urbanismo_menu" ".dcl"))
  (if
    (urb:write-lines filename
      '("urb_main : dialog { label = \"Urbanismo\";"
        ": boxed_column { label = \"Seleccione una opcion\";"
        ": button { label = \"Crear\"; key = \"create\"; height = 2; width = 32; }"
        ": button { label = \"Editar\"; key = \"edit\"; height = 2; width = 32; }"
        ": button { label = \"Cambiar etapa/subetapa (lote)\"; key = \"stages\"; height = 2; width = 32; }"
        ": button { label = \"Cantidades\"; key = \"quantities\"; height = 2; width = 32; }"
        ": button { label = \"Configuracion\"; key = \"config\"; height = 2; width = 32; } }"
        "cancel_button; }"
        "urb_create : dialog { label = \"Crear elemento\";"
        ": boxed_column { label = \"Tipo de elemento\";"
        ": button { label = \"Via\"; key = \"road\"; height = 2; width = 32; }"
        ": button { label = \"Anden\"; key = \"sidewalk\"; height = 2; width = 32; }"
        ": button { label = \"Rampa peatonal\"; key = \"ramp\"; height = 2; width = 32; }"
        ": button { label = \"Zona verde\"; key = \"green\"; height = 2; width = 32; }"
        ": button { label = \"Prefabricado\"; key = \"precast\"; height = 2; width = 32; }"
        ": button { label = \"Red\"; key = \"network\"; height = 2; width = 32; } }"
        ": button { label = \"Volver\"; key = \"back\"; is_cancel = true; width = 14; } }"
        "urb_network_create : dialog { label = \"Crear red\";"
        ": row { : boxed_column { label = \"Tramos\";"
        ": button { label = \"Sanitario\"; key = \"segment_sanitary\"; height = 2; width = 38; }"
        ": button { label = \"Pluvial\"; key = \"segment_storm\"; height = 2; width = 38; }"
        ": button { label = \"Acueducto\"; key = \"segment_water\"; height = 2; width = 38; }"
        ": button { label = \"Media tension\"; key = \"segment_mt\"; height = 2; width = 38; }"
        ": button { label = \"Baja tension\"; key = \"segment_bt\"; height = 2; width = 38; }"
        ": button { label = \"Alumbrado publico\"; key = \"segment_ap\"; height = 2; width = 38; } }"
        ": boxed_column { label = \"Elementos puntuales\";"
        ": button { label = \"Pozo sanitario\"; key = \"sanitary_manhole\"; height = 2; width = 38; }"
        ": button { label = \"Pozo pluvial\"; key = \"storm_manhole\"; height = 2; width = 38; }"
        ": button { label = \"Sumidero\"; key = \"inlet\"; height = 2; width = 38; }"
        ": button { label = \"Camara electrica\"; key = \"electrical_chamber\"; height = 2; width = 38; }"
        ": button { label = \"Accesorio de acueducto\"; key = \"water_accessory\"; height = 2; width = 38; }"
        ": button { label = \"Luminaria\"; key = \"luminaire\"; height = 2; width = 38; } } }"
        ": button { label = \"Volver\"; key = \"back\"; is_cancel = true; width = 14; } }"
        "urb_config : dialog { label = \"Configuracion de urbanismo\";"
        ": boxed_column { label = \"Bibliotecas\";"
        ": button { label = \"Perfiles estratigraficos de vias\"; key = \"road_profiles\"; height = 2; width = 40; }"
        ": button { label = \"Tabla de anchos, bombeo e intervalo\"; key = \"geometry_table\"; height = 2; width = 40; }"
        ": button { label = \"Etapas y subetapas\"; key = \"etapas_config\"; height = 2; width = 40; } }"
        ": boxed_column { label = \"Movimiento de tierras\";"
        ": button { label = \"Referencia de relleno de tramos de red\"; key = \"network_fill_ref\"; height = 2; width = 40; }"
        ": button { label = \"Recalcular tramos existentes con la referencia actual\"; key = \"recalc_tramos\"; height = 2; width = 40; } }"
        ": boxed_column { label = \"Apariencia de redes\";"
        ": button { label = \"Espesor de linea y tamano de datos de tramos\"; key = \"tramo_appearance\"; height = 2; width = 40; } }"
        ": button { label = \"Volver\"; key = \"back\"; is_cancel = true; width = 14; } }"
        "urb_etapas : dialog { label = \"Etapas y subetapas\";"
        ": toggle { key = \"activo\"; label = \"Habilitadas (etapa/subetapa activas en los dialogos de creacion)\"; }"
        ": boxed_column { label = \"Catalogo\";"
        ": popup_list { key = \"etapa\"; label = \"Etapa\"; width = 22; }"
        ": edit_box { key = \"subs\"; label = \"Subetapas (separadas por coma)\"; edit_width = 30; }"
        ": row {"
        ": button { key = \"guardar\"; label = \"Guardar subetapas\"; width = 20; }"
        ": button { key = \"quitar\"; label = \"Quitar etapa\"; width = 16; } } }"
        ": boxed_column { label = \"Nueva etapa\";"
        ": edit_box { key = \"nueva\"; label = \"Nombre\"; edit_width = 12; }"
        ": edit_box { key = \"nuevasubs\"; label = \"Subetapas (separadas por coma)\"; edit_width = 30; }"
        ": button { key = \"agregar\"; label = \"Agregar etapa\"; width = 20; } }"
        ": row {"
        ": button { key = \"restaurar\"; label = \"Restaurar original\"; width = 20; }"
        "ok_only; } }"
        "urb_quantities : dialog { label = \"Cantidades\";"
        ": boxed_column { label = \"Seleccione una opcion\";"
        ": button { label = \"Cuadro en dibujo: andenes y prefabricados\"; key = \"table\"; height = 2; width = 44; }"
        ": button { label = \"Memoria de via\"; key = \"road\"; height = 2; width = 40; }"
        ": button { label = \"Tabla de verificacion de via (desplegar)\"; key = \"road_audit\"; height = 2; width = 44; }"
        ": button { label = \"Incluir o excluir seleccion\"; key = \"scope\"; height = 2; width = 44; }"
        ": button { label = \"Crear Excel independiente (tabla general)\"; key = \"excel\"; height = 2; width = 44; }"
        ": button { label = \"Vincular o cambiar Excel maestro\"; key = \"link_excel\"; height = 2; width = 44; }"
        ": button { label = \"Actualizar Excel vinculado\"; key = \"update_excel\"; height = 2; width = 44; }"
        ": button { label = \"Eliminar vinculo con Excel\"; key = \"unlink_excel\"; height = 2; width = 44; }"
        ": button { label = \"Exportar detalle tecnico de redes (CSV)\"; key = \"network\"; height = 2; width = 44; } }"
        ": button { label = \"Volver\"; key = \"back\"; is_cancel = true; width = 14; } }"))
    filename))

(defun urb:simple-menu-dialog
  (dialog-name buttons / filename load-result dcl dialog-result action button)
  (setq filename (urb:write-main-menu-dcl))
  (if (not filename)
    (alert "No fue posible crear el archivo temporal del menu URBANISMO.")
    (progn
      (setq load-result
        (vl-catch-all-apply 'load_dialog (list filename)))
      (if (or (vl-catch-all-error-p load-result) (<= load-result 0))
        (alert
          (strcat "No fue posible cargar el menu URBANISMO."
            (if (vl-catch-all-error-p load-result)
              (strcat "\n" (vl-catch-all-error-message load-result)) "")))
        (progn
          (setq dcl load-result
                dialog-result
                  (vl-catch-all-apply 'new_dialog
                    (list dialog-name dcl)))
          (if (or (vl-catch-all-error-p dialog-result)
                  (not dialog-result))
            (alert
              (strcat "No fue posible abrir el cuadro " dialog-name "."))
            (progn
              (foreach button buttons
                (action_tile (car button)
                  (strcat "(setq action \"" (cadr button)
                    "\")(done_dialog 1)")))
              (vl-catch-all-apply 'action_tile
                (list "back" "(setq action \"back\")(done_dialog 0)"))
              (vl-catch-all-apply 'action_tile
                (list "cancel" "(setq action nil)(done_dialog 0)"))
              (start_dialog)))
          (unload_dialog dcl)))))
  action)

(defun urb:create-network-segment-direct (action)
  (if (urb:confirm-meter-units)
    (cond
      ((= action "segment_sanitary")
        (mp:insert-tramo-forced "Aresidual"))
      ((= action "segment_storm")
        (mp:insert-tramo-forced "Alluvias"))
      ((= action "segment_water")
        (mp:insert-tramo-forced "Acueducto"))
      ((= action "segment_mt")
        (mp:insert-electrical-tramo
          "TRAMO_E_MT"
          "\nExtremo inicial tramo MT: "
          "\nExtremo final tramo MT: "
          'mp:dialog-tramo-mt "MT"))
      ((= action "segment_bt")
        (mp:insert-electrical-tramo
          "TRAMO_E_BT_AP"
          "\nExtremo inicial tramo BT: "
          "\nExtremo final tramo BT: "
          'mp:dialog-tramo-bt "BT"))
      ((= action "segment_ap")
        (mp:insert-electrical-tramo
          "TRAMO_E_BT_AP"
          "\nExtremo inicial tramo alumbrado: "
          "\nExtremo final tramo alumbrado: "
          'mp:dialog-tramo-bt "AP")))
    (prompt
      "\nCreacion de tramo cancelada: confirme primero las unidades del dibujo."))
  (princ)
)

(defun urb:network-create-menu (/ action)
  (setq action
    (urb:simple-menu-dialog "urb_network_create"
      '(("segment_sanitary" "segment_sanitary")
        ("segment_storm" "segment_storm")
        ("segment_water" "segment_water")
        ("segment_mt" "segment_mt")
        ("segment_bt" "segment_bt")
        ("segment_ap" "segment_ap")
        ("sanitary_manhole" "sanitary_manhole")
        ("storm_manhole" "storm_manhole")
        ("inlet" "inlet")
        ("electrical_chamber" "electrical_chamber")
        ("water_accessory" "water_accessory")
        ("luminaire" "luminaire"))))
  (cond
    ((or (null action) (= action "back")) "back")
    ((member action
       '("segment_sanitary" "segment_storm" "segment_water"
         "segment_mt" "segment_bt" "segment_ap"))
      (urb:create-network-segment-direct action))
    ((= action "sanitary_manhole")
      (if (urb:confirm-meter-units) (urb:create-sanitary-manhole)))
    ((= action "storm_manhole")
      (if (urb:confirm-meter-units) (urb:create-storm-manhole)))
    ((= action "inlet")
      (if (urb:confirm-meter-units) (urb:create-inlet)))
    ((= action "electrical_chamber")
      (if (urb:confirm-meter-units) (urb:create-electrical-chamber)))
    ((= action "water_accessory")
      (if (urb:confirm-meter-units) (urb:create-water-accessory)))
    ((= action "luminaire")
      (if (urb:confirm-meter-units) (urb:create-luminaire))))
  (if (or (null action) (= action "back")) "back" nil))

(defun urb:create-menu (/ action done result)
  (while (not done)
    (setq action
      (urb:simple-menu-dialog "urb_create"
        '(("road" "road") ("sidewalk" "sidewalk") ("ramp" "ramp")
          ("green" "green")
          ("precast" "precast") ("network" "network"))))
    (cond
      ((or (null action) (= action "back"))
        (setq done T result "back"))
      ((= action "road") (urb:create-road) (setq done T))
      ((= action "sidewalk") (urb:create-sidewalk-command) (setq done T))
      ((= action "ramp") (urb:create-ramp-command) (setq done T))
      ((= action "green") (urb:create-green-zone-command) (setq done T))
      ((= action "precast") (urb:create-precast-command) (setq done T))
      ((= action "network")
        (if (not
              (urb:string-equal-p
                (urb:network-create-menu) "back"))
          (setq done T)))))
  result)

;; ============================================================
;; EXPORTACION CONSOLIDADA A EXCEL (4.10.0)
;; Un registro normalizado tiene la forma:
;; (capitulo sistema elemento especificacion etapa subetapa unidad
;;  cantidad handle estado vinculo-id vinculo-nombre)
;; ============================================================

(defun urb:q-safe-nth (index values default)
  (if (and (listp values) (> (length values) index))
    (nth index values)
    default)
)

(defun urb:q-scope-included-p (ename / data value)
  (setq data
    (if (urb:valid-ename-p ename)
      (urb:get-xdata-strings ename "URB_Q_SCOPE") nil)
    value (strcase (urb:safe-string (if data (car data) "SI") "SI")))
  (not (member value '("NO" "EXCLUIR" "0")))
)

(defun urb:q-modelspace-p (ename / data layout space)
  ;; La extraccion contractual se limita a ModelSpace. ssget "_X" tambien
  ;; encuentra copias en layouts; sin este filtro esas copias se sumaban.
  (setq data (if (urb:valid-ename-p ename) (entget ename) nil)
        layout (urb:safe-string (cdr (assoc 410 data)) "")
        space (cdr (assoc 67 data)))
  (and
    (or (urb:string-equal-p layout "Model")
        (and (= layout "") (or (null space) (= space 0))))
    (urb:q-scope-included-p ename))
)

(defun urb:q-unscaled-reference-p (ename / object xscale yscale zscale)
  (setq object (urb:as-vla-object ename))
  (if (and object
           (urb:string-equal-p
             (urb:safe-string
               (vl-catch-all-apply 'vla-get-ObjectName (list object)) "")
             "AcDbBlockReference"))
    (progn
      (setq xscale
        (vl-catch-all-apply 'vla-get-XScaleFactor (list object))
        yscale (vl-catch-all-apply 'vla-get-YScaleFactor (list object))
        zscale (vl-catch-all-apply 'vla-get-ZScaleFactor (list object)))
      (and (numberp xscale) (numberp yscale) (numberp zscale)
           (equal (abs xscale) 1.0 1e-6)
           (equal (abs yscale) 1.0 1e-6)
           (equal (abs zscale) 1.0 1e-6)))
    T)
)

(defun urb:q-approved-status-p (status / normalized)
  (setq normalized (strcase (urb:safe-string status "")))
  (if (member normalized '("OK" "CALCULADO" "APROBADO")) T nil)
)

(defun urb:q-basic-status (stage substage valid-geometry)
  (if (and (/= (vl-string-trim " " (urb:safe-string stage "")) "")
           (/= (vl-string-trim " " (urb:safe-string substage "")) "")
           valid-geometry)
    "OK"
    "REVISAR")
)

(defun urb:q-number (value / parsed)
  (cond
    ((numberp value) (float value))
    ((= (type value) 'STR)
      (setq parsed (urb:parse-real value))
      (if parsed (float parsed) 0.0))
    (T 0.0))
)

(defun urb:q-handle (ename / obj result)
  (setq obj (urb:as-vla-object ename))
  (if obj
    (progn
      (setq result (vl-catch-all-apply 'vla-get-Handle (list obj)))
      (if (vl-catch-all-error-p result) "" result))
    "")
)

(defun urb:q-record
  (chapter system element specification stage substage unit quantity
   handle status link-id link-name)
  (list
    (urb:safe-string chapter "")
    (urb:safe-string system "")
    (urb:safe-string element "")
    (urb:safe-string specification "")
    (urb:safe-string stage "")
    (urb:safe-string substage "")
    (urb:safe-string unit "")
    (urb:q-number quantity)
    (urb:safe-string handle "")
    (urb:safe-string status "")
    (urb:safe-string link-id "")
    (urb:safe-string link-name ""))
)

(defun urb:q-record-key (record)
  (strcat
    (nth 0 record) "\t" (nth 1 record) "\t" (nth 2 record) "\t"
    (nth 3 record) "\t" (nth 4 record) "\t" (nth 5 record) "\t"
    (nth 6 record) "\t" (nth 9 record))
)

(defun urb:q-aggregate (records / result record key found)
  ;; Resultado:
  ;; (clave capitulo sistema elemento especificacion etapa subetapa
  ;;  unidad cantidad objetos estado)
  (foreach record records
    (setq key (urb:q-record-key record))
    (if (setq found (assoc key result))
      (setq result
        (subst
          (list key
            (nth 1 found) (nth 2 found) (nth 3 found) (nth 4 found)
            (nth 5 found) (nth 6 found) (nth 7 found)
            (+ (nth 8 found) (nth 7 record))
            (1+ (nth 9 found)) (nth 10 found))
          found result))
      (setq result
        (cons
          (list key
            (nth 0 record) (nth 1 record) (nth 2 record) (nth 3 record)
            (nth 4 record) (nth 5 record) (nth 6 record)
            (nth 7 record) 1 (nth 9 record))
          result))))
  (reverse result)
)

(defun urb:q-control-row (severity category handle element finding action)
  (list severity category handle element finding action)
)

(defun urb:q-collect-andenes
  (/ ss index ename data mov handle material stage substage area perimeter
   format guide toperol surface grade calculate smooth-area smooth-units
   guide-ml toperol-ml adoquin-area adoquin-units cut fill valid total
   coverage via-id via-name status quantity-status finish-status finish-area
   tactile-p records details controls layer layer-type
   thickness overlap quantity unit specification)
  (setq ss (ssget "_X" '((-3 ("URB_ANDEN_BLOCK")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_ANDEN_BLOCK"))
        (if (and (urb:q-modelspace-p ename)
                 data (urb:string-equal-p (car data) "ANDEN"))
          (progn
            (setq mov (urb:get-xdata-strings ename "URB_ANDEN_MOV"))
            (if (not (and mov (urb:string-equal-p (car mov) "ANDEN_MOV")))
              (setq mov nil))
            (setq handle (urb:q-handle ename)
                  material (strcase (urb:safe-string (urb:q-safe-nth 1 data "") ""))
                  stage (urb:safe-string (urb:q-safe-nth 2 data "") "")
                  substage (urb:safe-string (urb:q-safe-nth 3 data "") "")
                  area (urb:q-number (urb:q-safe-nth 4 data "0"))
                  perimeter (urb:q-number (urb:q-safe-nth 5 data "0"))
                  guide (urb:safe-string (urb:q-safe-nth 7 data "No") "No")
                  toperol (urb:safe-string (urb:q-safe-nth 8 data "No") "No")
                  format (urb:safe-string (urb:q-safe-nth 9 data "") "")
                  calculate (urb:safe-string (urb:q-safe-nth 10 data "No") "No")
                  surface (urb:safe-string (urb:q-safe-nth 11 data "") "")
                  grade (urb:safe-string (urb:q-safe-nth 12 data "") "")
                  smooth-area (urb:q-number (urb:q-safe-nth 13 data "0"))
                  smooth-units (urb:q-number (urb:q-safe-nth 14 data "0"))
                  guide-ml (urb:q-number (urb:q-safe-nth 15 data "0"))
                  toperol-ml (urb:q-number (urb:q-safe-nth 16 data "0"))
                  adoquin-area (urb:q-number (urb:q-safe-nth 17 data "0"))
                  adoquin-units (urb:q-number (urb:q-safe-nth 18 data "0"))
                  cut (urb:q-number (urb:q-safe-nth 2 mov "0"))
                  fill (urb:q-number (urb:q-safe-nth 3 mov "0"))
                  valid (fix (urb:q-number (urb:q-safe-nth 4 mov "0")))
                  total (fix (urb:q-number (urb:q-safe-nth 6 mov "0")))
                  coverage (urb:q-number (urb:q-safe-nth 7 mov "0"))
                  via-id (urb:safe-string (urb:q-safe-nth 8 mov "") "")
                  via-name (urb:safe-string (urb:q-safe-nth 9 mov "") ""))
            (setq quantity-status
              (urb:q-basic-status stage substage
                (and (> area 1e-9)
                     (member material '("LOSETA" "ADOQUIN"))
                     (urb:q-unscaled-reference-p ename))))
            (setq tactile-p
              (or (urb:yes-p guide) (urb:yes-p toperol))
                  finish-area
                    (if (= material "ADOQUIN")
                      (cond
                        ((> adoquin-area 1e-9) adoquin-area)
                        ((not tactile-p) area)
                        (T 0.0))
                      area)
                  finish-status
                    (if (and (= material "ADOQUIN") tactile-p
                             (<= adoquin-area 1e-9))
                      "REVISAR"
                      quantity-status))
            (setq status
              (cond
                (mov "CALCULADO")
                ((urb:yes-p calculate) "PENDIENTE")
                (T "NO SOLICITADO")))
            (setq details
              (cons
                (list handle material stage substage area perimeter format
                  guide toperol surface grade smooth-area smooth-units guide-ml
                  toperol-ml adoquin-area adoquin-units cut fill coverage
                  via-id via-name status)
                details))
            (setq specification
              (if (= material "LOSETA") format material))
            (setq records
              (cons
                (urb:q-record "ANDENES" "Acabados"
                  (if (= material "ADOQUIN")
                    "Suministro e instalacion de adoquin de arcilla color natural 20x10x6 cm"
                    "Suministro e instalacion de loseta prefabricada")
                  specification stage substage "M2" finish-area handle finish-status
                  via-id via-name)
                records))
            (setq records
              (cons
                (urb:q-record "ANDENES" "Descapote y nivelacion subrasante"
                  "Compactacion de subrasante (Incluye nivelacion)"
                  "Area modelada del anden" stage substage "M2" area
                  handle quantity-status via-id via-name)
                records))
            (setq records
              (cons
                (urb:q-record "ANDENES" "Descapote y nivelacion subrasante"
                  "Descapote mecanico de material vegetal (Incluye cargue y retiro externo)"
                  "Area modelada del anden" stage substage "M2" area
                  handle quantity-status via-id via-name)
                records))
            (if (> perimeter 1e-9)
              (setq records
                (cons
                    (urb:q-record "ANDENES" "Geometria" "Perimetro modelado"
                    material stage substage "ML" perimeter handle quantity-status
                    via-id via-name)
                  records)))
            (if (> smooth-units 1e-9)
              (setq records
                (cons
                   (urb:q-record "ANDENES" "Acabado" "Loseta lisa"
                    format stage substage "UND" smooth-units handle quantity-status
                    via-id via-name)
                  records)))
            (if (> guide-ml 1e-9)
              (setq records
                (cons
                   (urb:q-record "ANDENES" "Acabados"
                    "Cenefa lineal en loseta prefabricada guia color natural A-56 (0,40x0,40) m"
                    format stage substage "ML" guide-ml handle quantity-status
                    via-id via-name)
                  records)))
            (if (> toperol-ml 1e-9)
              (setq records
                (cons
                   (urb:q-record "ANDENES" "Accesibilidad" "Loseta toperol"
                    format stage substage "ML" toperol-ml handle quantity-status
                    via-id via-name)
                  records)))
            (if (and (= material "LOSETA") (> adoquin-units 1e-9))
              (setq records
                (cons
                  (urb:q-record "ANDENES" "Acabado"
                   "Adoquin blanco 20 x 10 cm" "20 x 10 cm"
                    stage substage "UND" adoquin-units handle quantity-status
                    via-id via-name)
                  records)))
            (foreach layer (cdr *urb-anden-structure*)
              (setq layer-type (nth 1 layer)
                    thickness (atof (nth 2 layer))
                    overlap (atof (nth 3 layer)))
              (if (urb:string-equal-p layer-type "Volumen")
                (setq quantity (* area thickness)
                      unit "M3"
                      specification
                        (strcat (rtos (* 100.0 thickness) 2 0) " cm"))
                (setq quantity (* area (+ 1.0 (/ overlap 100.0)))
                      unit "M2"
                      specification
                        (strcat "Traslapo " (rtos overlap 2 1) "%")))
              (setq records
                (cons
                  (urb:q-record "ANDENES" "Estructura" (car layer)
                    specification stage substage unit quantity handle quantity-status
                    via-id via-name)
                  records)))
            (if mov
              (progn
                (setq records
                  (cons
                    (urb:q-record "ANDENES" "Movimiento de tierras"
                      "Excavacion mecanica en material comun (Incluye cargue, transporte y disposicion)"
                      (urb:q-safe-nth 1 mov "")
                      stage substage "M3" cut handle
                      (if (= quantity-status "OK") "CALCULADO" "REVISAR")
                      via-id via-name)
                    records))
                (setq records
                  (cons
                    (urb:q-record "ANDENES" "Movimiento de tierras"
                      "Relleno con material seleccionado B-200"
                      (urb:q-safe-nth 1 mov "")
                      stage substage "M3" fill handle
                      (if (= quantity-status "OK") "CALCULADO" "REVISAR")
                      via-id via-name)
                    records)))
              (if (urb:yes-p calculate)
                (setq controls
                  (cons
                    (urb:q-control-row "ALTA" "ANDEN" handle material
                      "Movimiento de tierras pendiente."
                      "Editar el anden y completar superficie y rasante.")
                    controls))))
            (if (= quantity-status "REVISAR")
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "ANDEN" handle material
                    "El anden no tiene etapa, subetapa, geometria valida o fue escalado fuera de EDITAR."
                    "Completar o reconstruir mediante EDITAR; sus cantidades no se sumaran.")
                  controls)))
            (if (and (= material "ADOQUIN") tactile-p
                     (<= adoquin-area 1e-9))
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "ANDEN" handle material
                    "El anden tiene franjas tactiles pero no conserva el area neta de adoquin."
                    "Abrirlo con EDITAR y aceptar para recalcular las franjas con la version 4.15.1.")
                  controls)))
            (if (and (urb:string-equal-p grade "Via creada") (= via-id ""))
              (setq controls
                (cons
                  (urb:q-control-row "MEDIA" "VINCULO VIA-ANDEN" handle material
                    "El anden no conserva el ID de la via controladora."
                    "Editar y recalcular el anden con la version 4.10.0.")
                  controls)))))
        (setq index (1+ index)))))
  (list (reverse records) (reverse details) (reverse controls))
)

(defun urb:q-collect-vias
  (/ ss index ename data mov handle via-id name stage substage profile
   surface area road-length average-width status cut fill method sections
   skipped width depth records details controls road-profile layers layer
   layer-name layer-type layer-scope thickness overlap left right left-area
   right-area base-area layer-area quantity unit specification quantity-status)
  (setq ss (ssget "_X" '((-3 ("URB_VIA")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_VIA"))
        (if (and (urb:q-modelspace-p ename)
                 data (urb:string-equal-p (car data) "VIA"))
          (progn
            (setq mov (urb:road-movement-data ename)
                  handle (urb:q-handle ename)
                  via-id (urb:safe-string (urb:q-safe-nth 22 data handle) handle)
                  name (urb:safe-string (urb:q-safe-nth 1 data "VIA") "VIA")
                  stage (urb:safe-string (urb:q-safe-nth 2 data "") "")
                  substage (urb:safe-string (urb:q-safe-nth 3 data "") "")
                  profile (urb:safe-string (urb:q-safe-nth 4 data "") "")
                  surface (urb:safe-string (urb:q-safe-nth 6 data "") "")
                  area (urb:q-number (urb:q-safe-nth 17 data "0"))
                  road-length (urb:q-number (urb:q-safe-nth 18 data "0"))
                  average-width (if (> road-length 1e-9) (/ area road-length) 0.0)
                  status (urb:safe-string (urb:q-safe-nth 19 data "") "")
                  cut (urb:q-number (urb:q-safe-nth 0 mov "0"))
                  fill (urb:q-number (urb:q-safe-nth 1 mov "0"))
                  method (urb:safe-string (urb:q-safe-nth 2 mov "") "")
                  sections (fix (urb:q-number (urb:q-safe-nth 3 mov "0")))
                  skipped (fix (urb:q-number (urb:q-safe-nth 4 mov "0")))
                  width (urb:q-number (urb:q-safe-nth 5 mov "0"))
                  depth (urb:q-number (urb:q-safe-nth 6 mov "0")))
            (setq road-profile (urb:road-profile-by-name profile)
                  layers (if road-profile (cadr road-profile) nil)
                  quantity-status
                    (urb:q-basic-status stage substage
                      (and (> area 1e-9) (> road-length 1e-9) layers
                           (urb:q-unscaled-reference-p ename))))
            (setq details
              (cons
                (list handle via-id name stage substage profile surface area
                  road-length average-width
                  (urb:safe-string (urb:q-safe-nth 10 data "") "")
                  status cut fill method sections skipped width depth)
                details))
            (setq records
              (cons
                (urb:q-record "VIAS" "Geometria" "Longitud de via"
                  profile stage substage "ML" road-length handle quantity-status
                  via-id name)
                records))
            (setq records
              (cons
                (urb:q-record "VIAS" "Geometria" "Area vial modelada"
                  profile stage substage "M2" area handle quantity-status
                  via-id name)
                records))
            (setq records
              (cons
                (urb:q-record "VIAS" "Descapote y nivelacion subrasante"
                  "Compactacion de subrasante (Incluye nivelacion)"
                  "Area vial modelada" stage substage "M2" area
                  handle quantity-status via-id name)
                records))
            (setq records
              (cons
                (urb:q-record "VIAS" "Descapote y nivelacion subrasante"
                  "Descapote mecanico de material vegetal (Incluye cargue y retiro externo)"
                  "Area vial modelada" stage substage "M2" area
                  handle quantity-status via-id name)
                records))
            (setq left (urb:q-number (urb:q-safe-nth 14 data "0"))
                  right (urb:q-number (urb:q-safe-nth 15 data "0"))
                  left-area (min area (* road-length left))
                  right-area (min (- area left-area) (* road-length right))
                  base-area (max 0.0 (- area left-area right-area)))
            (if (null layers)
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "VIA" handle name
                    (strcat "No se encontro el perfil vial: " profile ".")
                    "Revisar la biblioteca de perfiles del dibujo.")
                  controls)))
            (foreach layer layers
              (setq layer-name (urb:safe-string (nth 0 layer) "Capa")
                    layer-type (urb:safe-string (nth 1 layer) "Volumen")
                    thickness (atof (nth 2 layer))
                    overlap (atof (nth 3 layer))
                    layer-scope (urb:safe-string (nth 4 layer) "Total")
                    layer-area
                      (if (urb:string-equal-p layer-scope "Base") base-area area))
              (if (urb:string-equal-p layer-type "Volumen")
                (setq quantity (* layer-area thickness)
                      unit "M3"
                      specification
                        (strcat profile " | "
                          (rtos (* 100.0 thickness) 2 1) " cm | " layer-scope))
                (setq quantity (* layer-area (+ 1.0 (/ overlap 100.0)))
                      unit "M2"
                      specification
                        (strcat profile " | traslapo "
                          (rtos overlap 2 1) "% | " layer-scope)))
              (setq records
                (cons
                  (urb:q-record "VIAS" "Pavimento" layer-name specification
                    stage substage unit quantity handle quantity-status via-id name)
                  records)))
            (if mov
              (progn
                (setq records
                  (cons
                    (urb:q-record "VIAS" "Excavaciones y rellenos"
                      "Excavacion mecanica en material comun (Incluye cargue, transporte y disposicion)"
                      method stage substage "M3" cut handle
                      (if (= quantity-status "OK") "CALCULADO" "REVISAR")
                      via-id name)
                    records))
                (setq records
                  (cons
                    (urb:q-record "VIAS" "Movimiento de tierras" "Relleno"
                      method stage substage "M3" fill handle
                      (if (= quantity-status "OK") "CALCULADO" "REVISAR")
                      via-id name)
                    records)))
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "VIA" handle name
                    "Movimiento de tierras pendiente."
                    "Editar la via y completar superficie y rasante.")
                  controls)))
            (if (= quantity-status "REVISAR")
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "VIA" handle name
                    "La via no tiene etapa, subetapa, geometria/perfil valido o fue escalada fuera de EDITAR."
                    "Completar o reconstruir mediante EDITAR; sus cantidades no se sumaran.")
                  controls)))))
        (setq index (1+ index)))))
  (list (reverse records) (reverse details) (reverse controls))
)

(defun urb:q-collect-prefabricados
  (/ ss index ename data handle prefab stage substage width length-value
   mode budget-name records details controls quantity-status)
  (setq ss (ssget "_X" '((-3 ("URB_PREFAB_BLOCK")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (setq data (urb:get-xdata-strings ename "URB_PREFAB_BLOCK"))
        (if (and (urb:q-modelspace-p ename) data)
          (progn
            (setq handle (urb:q-handle ename)
                  prefab (strcase (urb:safe-string (urb:q-safe-nth 0 data "") ""))
                  stage (urb:safe-string (urb:q-safe-nth 1 data "") "")
                  substage (urb:safe-string (urb:q-safe-nth 2 data "") "")
                  width (urb:q-number (urb:q-safe-nth 3 data "0"))
                  length-value (urb:q-number (urb:q-safe-nth 4 data "0"))
                  mode (urb:safe-string (urb:q-safe-nth 5 data "") "")
                  budget-name
                    (cond
                      ((= prefab "BORDILLO")
                        "Suministro e instalacion de bordillo A-80")
                      ((= prefab "SARDINEL")
                        "Suministro e instalacion de sardinel A-10")
                      ((= prefab "CANUELA")
                        "Suministro e instalacion de canuela")
                      (T prefab)))
            (setq quantity-status
              (urb:q-basic-status stage substage
                (and (> width 1e-9) (> length-value 1e-9)
                     (member prefab '("BORDILLO" "SARDINEL" "CANUELA"))
                     (urb:q-unscaled-reference-p ename))))
            (setq details
              (cons
                (list handle prefab stage substage width length-value mode
                  quantity-status)
                details))
            (setq records
              (cons
                (urb:q-record "PREFABRICADOS" "Acabados" budget-name
                  (strcat "Ancho " (rtos width 2 3) " m | " mode)
                  stage substage "ML" length-value handle quantity-status "" "")
                records))
            ;; Una entidad representa un tramo, no una pieza comercial. La
            ;; salida UND=1 se retiro porque inducía a contar tramos como piezas.
            (if (= quantity-status "REVISAR")
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "PREFABRICADO" handle prefab
                    "El prefabricado no tiene datos validos o fue escalado fuera de EDITAR."
                    "Completarlo o reconstruirlo mediante EDITAR; su longitud no se sumara.")
                  controls)))))
        (setq index (1+ index)))))
  (list (reverse records) (reverse details) (reverse controls))
)

(defun urb:q-collect-green-zones
  (/ ss index ename data handle stage substage area perimeter thickness
   volume quantity-status records details controls)
  (setq ss (ssget "_X" '((-3 ("URB_GREEN_BLOCK")))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index)
              data (urb:get-xdata-strings ename "URB_GREEN_BLOCK"))
        (if (and (urb:q-modelspace-p ename)
                 data
                 (urb:string-equal-p
                   (urb:q-safe-nth 0 data "") "ZONA_VERDE"))
          (progn
            (setq handle (urb:q-handle ename)
                  stage (urb:safe-string
                    (urb:q-safe-nth 1 data "") "")
                  substage (urb:safe-string
                    (urb:q-safe-nth 2 data "") "")
                  area (urb:q-number
                    (urb:q-safe-nth 3 data "0"))
                  perimeter (urb:q-number
                    (urb:q-safe-nth 4 data "0"))
                  thickness (urb:q-number
                    (urb:q-safe-nth 5 data "0"))
                  volume (urb:q-number
                    (urb:q-safe-nth 6 data "0"))
                  quantity-status
                    (urb:q-basic-status stage substage
                      (and (> area 1e-9)
                           (> thickness 1e-9)
                           (> volume 1e-9)
                           (urb:q-unscaled-reference-p ename))))
            (setq details
              (cons
                (list handle stage substage area perimeter
                  thickness volume quantity-status)
                details))
            (setq records
              (cons
                (urb:q-record "ZONAS VERDES" "Paisajismo"
                  "Conformacion de zona verde"
                  "Area neta modelada"
                  stage substage "M2" area handle quantity-status "" "")
                records))
            (setq records
              (cons
                (urb:q-record "ZONAS VERDES" "Paisajismo"
                  "Suministro y colocacion de tierra negra"
                  (strcat "Espesor " (rtos thickness 2 3) " m")
                  stage substage "M3" volume handle quantity-status "" "")
                records))
            (if (= quantity-status "REVISAR")
              (setq controls
                (cons
                  (urb:q-control-row "ALTA" "ZONA VERDE" handle
                    "Zona verde"
                    "Faltan etapa, subetapa, area o espesor valido; o el bloque fue escalado."
                    "Abra la zona con EDITAR y complete sus datos.")
                  controls)))))
        (setq index (1+ index)))))
  (list (reverse records) (reverse details) (reverse controls))
)

(defun urb:q-network-group (base)
  (cond
    ((= base "LUMINARIA_AP") "LUMINARIAS")
    ((member base
       '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO"
         "POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"
         "ACCESORIO_ACUEDUCTO"))
      "HIDROSANITARIAS")
    (T "ELECTRICAS"))
)

(defun urb:q-network-element (base atts)
  (cond
    ((= base "TRAMO_ARESIDUAL") "Tuberia sanitaria")
    ((= base "TRAMO_ALLUVIAS") "Tuberia pluvial")
    ((= base "TRAMO_ACUEDUCTO") "Tuberia de acueducto")
    ((= base "TRAMO_E_MT") "Canalizacion media tension")
    ((= base "TRAMO_E_BT_AP")
      (if (= (strcase (mp:getval "TIPO_RED" atts "BT")) "AP")
        "Canalizacion alumbrado publico"
        "Canalizacion baja tension"))
    ((= base "POZO_SANITARIO") "Pozo sanitario")
    ((= base "POZO_PLUVIAL") "Pozo pluvial")
    ((= base "SUMIDERO") "Sumidero")
    ((= base "ACCESORIO_ACUEDUCTO") "Accesorio de acueducto")
    ((= base "LUMINARIA_AP") "Luminaria")
    (T base))
)

(defun urb:q-network-detail-row
  (group base handle layer point atts)
  (list group base handle layer
    (urb:q-number (car point)) (urb:q-number (cadr point))
    (mp:getval "ETAPA" atts "")
    (mp:getval "SUBETAPA" atts "")
    (mp:getval "ID" atts "")
    (mp:getval "CODIGO" atts "")
    (mp:getval "RED" atts "")
    (mp:getval "TIPO_RED" atts "")
    (mp:getval "DESDE" atts "")
    (mp:getval "HASTA" atts "")
    (mp:getval "POZO_INI" atts "")
    (mp:getval "POZO_FIN" atts "")
    (mp:getval "TIPO_EXTREMO_INI" atts "")
    (mp:getval "TIPO_EXTREMO_FIN" atts "")
    (mp:getval "HANDLE_EXTREMO_INI" atts "")
    (mp:getval "HANDLE_EXTREMO_FIN" atts "")
    (mp:getval "DIAMETRO" atts "")
    (mp:getval "MATERIAL" atts "")
    (urb:q-number (mp:getval "LONGITUD" atts "0"))
    (urb:q-number (mp:getval "LONGITUD_2D" atts "0"))
    (urb:q-number (mp:getval "LONGITUD_3D" atts "0"))
    (mp:getval "MODO_LONGITUD" atts "")
    (urb:q-number (mp:getval "PENDIENTE" atts "0"))
    (urb:q-number (mp:getval "PENDIENTE_CALCULADA" atts "0"))
    (urb:q-number (mp:getval "COTA_TN_INI" atts "0"))
    (urb:q-number (mp:getval "COTA_TN_FIN" atts "0"))
    (urb:q-number (mp:getval "COTA_CLAVE_INI" atts "0"))
    (urb:q-number (mp:getval "COTA_CLAVE_FIN" atts "0"))
    (urb:q-number (mp:getval "PROFUNDIDAD_INI" atts "0"))
    (urb:q-number (mp:getval "PROFUNDIDAD_FIN" atts "0"))
    (urb:q-number (mp:getval "PROFUNDIDAD_MEDIA" atts "0"))
    (mp:getval "CONDUCTOR" atts (mp:getval "CONDUCTORES" atts ""))
    (urb:q-number (mp:getval "DUCTOS" atts "0"))
    (urb:q-number (mp:getval "LIBRES" atts "0"))
    (mp:getval "DIAM_DUCTO" atts "")
    (mp:getval "MATERIAL_DUCTO" atts "")
    (mp:getval "TIPO_CAJA" atts "")
    (mp:getval "TIPO_LUMINARIA" atts "")
    (mp:getval "FUENTE_LED" atts "")
    (mp:getval "CIRCUITO" atts "")
    (mp:getval "CIRCUITO_AP" atts "")
    (urb:q-number (mp:getval "PROFUNDIDAD" atts "0"))
    (urb:q-number (mp:getval "ANCHO_ZANJA" atts "0"))
    (urb:q-number (mp:getval "ESPESOR_CAMA" atts "0"))
    (urb:q-number (mp:getval "ANCHO_REPOSICION" atts "0"))
    (urb:q-number (mp:getval "EXCAVACION_M3" atts "0"))
    (urb:q-number (mp:getval "CAMA_M3" atts "0"))
    (urb:q-number (mp:getval "VOLUMEN_ELEMENTO_M3" atts "0"))
    (urb:q-number (mp:getval "RELLENO_M3" atts "0"))
    (urb:q-number (mp:getval "SOBRANTE_M3" atts "0"))
    (urb:q-number (mp:getval "REPOSICION_M2" atts "0"))
    (mp:getval "METODO_CANTIDADES" atts "")
    (mp:getval "CONTROL_ESTADO" atts "")
    (mp:getval "CONTROL_MENSAJES" atts "")
    (mp:getval "TIPO_ACCESORIO" atts "")
    (mp:getval "SERIE" atts "")
    (mp:getval "CD" atts "")
    (mp:getval "PF" atts ""))
)


(defun urb:q-network-linear-specification (group atts ducts conductor)
  (if (= group "HIDROSANITARIAS")
    (strcat
      "Diam. " (mp:getval "DIAMETRO" atts "-")
      " | " (mp:getval "MATERIAL" atts "-"))
    (strcat
      (rtos ducts 2 0) " ducto(s) "
      (mp:getval "DIAM_DUCTO" atts "-") " "
      (mp:getval "MATERIAL_DUCTO" atts "-")
      (if (/= conductor "") (strcat " | " conductor) "")))
)

(defun urb:q-network-point-specification (base atts)
  (cond
    ((= base "LUMINARIA_AP")
      (strcat
        (mp:getval "TIPO_LUMINARIA" atts "-")
        " | " (mp:getval "FUENTE_LED" atts "-")
        " | altura " (mp:getval "ALTURA" atts "-") " m"
        " | brazo " (mp:getval "BRAZO" atts "-") " m"
        " | avance " (mp:getval "AVANCE" atts "-") " m"))
    ((= base "ACCESORIO_ACUEDUCTO")
      (strcat
        (mp:getval "TIPO_ACCESORIO" atts "-")
        " | Diam. " (mp:getval "DIAMETRO" atts "-")
        " | salida " (mp:getval "DIAMETRO_SALIDA" atts "-")
        " | " (mp:getval "MATERIAL" atts "-")))
    ((member base '("POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"))
      (strcat
        (mp:getval "TIPO_RED" atts base)
        " | Diam. " (mp:getval "DIAMETRO" atts "-")
        " | profundidad " (mp:getval "PROFUNDIDAD" atts "-") " m"))
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
      (strcat
        (mp:getval "TIPO_CAJA" atts base)
        " | serie " (mp:getval "SERIE" atts "-")
        " | profundidad " (mp:getval "PROFUNDIDAD" atts "-") " m"))
    (T
      (mp:getval "TIPO_CAJA" atts
        (mp:getval "TIPO_RED" atts base))))
)

(defun urb:q-network-quantity-records
  (group element specification atts stage substage length-value ducts conductor
   handle status / records handle-ini handle-fin endpoint-ini endpoint-fin
   link-id link-name construction-spec quantity)
  (setq handle-ini (mp:getval "HANDLE_EXTREMO_INI" atts "")
        handle-fin (mp:getval "HANDLE_EXTREMO_FIN" atts "")
        endpoint-ini
          (mp:getval "DESDE" atts (mp:getval "POZO_INI" atts ""))
        endpoint-fin
          (mp:getval "HASTA" atts (mp:getval "POZO_FIN" atts ""))
        link-id
          (if (or (/= handle-ini "") (/= handle-fin ""))
            (strcat handle-ini " -> " handle-fin)
            "")
        link-name
          (if (or (/= endpoint-ini "") (/= endpoint-fin ""))
            (strcat endpoint-ini " -> " endpoint-fin)
            "")
        construction-spec
          (strcat
            "Metodo " (mp:getval "METODO_CANTIDADES" atts "-")
            " | ancho " (mp:getval "ANCHO_ZANJA" atts "-") " m"
            " | profundidad media "
            (mp:getval "PROFUNDIDAD_MEDIA" atts
              (mp:getval "PROFUNDIDAD" atts "-")) " m")
        records
          (list
            (urb:q-record group "Tramos" element specification
              stage substage "ML" length-value handle status
              link-id link-name)))
  (if (and (= group "ELECTRICAS") (> ducts 0.0))
    (setq records
      (append records
        (list
          (urb:q-record group "Ducteria" "Ducteria instalada"
            (strcat
              (mp:getval "DIAM_DUCTO" atts "-") " "
              (mp:getval "MATERIAL_DUCTO" atts "-"))
            stage substage "ML" (* length-value ducts)
            handle status link-id link-name)))))
  (if (and (= group "ELECTRICAS") (/= conductor ""))
    (setq records
      (append records
        (list
          (urb:q-record group "Conductores"
            "Tendido de conductor - longitud de ruta" conductor
            stage substage "ML" length-value handle status
            link-id link-name)))))
  (foreach item
    '(("EXCAVACION_M3" "Excavacion de zanja" "M3")
      ("CAMA_M3" "Cama de apoyo" "M3")
      ("RELLENO_M3" "Relleno de zanja" "M3")
      ("SOBRANTE_M3" "Retiro de sobrantes" "M3")
      ("REPOSICION_M2" "Reposicion superficial" "M2"))
    (setq quantity (urb:q-number (mp:getval (car item) atts "0")))
    (if (> quantity 1e-9)
      (setq records
        (append records
          (list
            (urb:q-record group "Movimiento de tierras" (cadr item)
              construction-spec stage substage (caddr item) quantity
              handle status link-id link-name))))))
  records
)

(defun urb:q-network-control-rows
  (group handle element stage base length-value atts
   / controls control-state control-messages substage identity)
  (setq substage (mp:getval "SUBETAPA" atts "")
        identity (mp:getval "ID" atts (mp:getval "CODIGO" atts "")))
  (if (= stage "")
    (setq controls
      (cons
        (urb:q-control-row "MEDIA" group handle element
          "El elemento no tiene etapa."
          "Completar los atributos mediante EDITAR.")
        controls)))
  (if (= substage "")
    (setq controls
      (cons
        (urb:q-control-row "MEDIA" group handle element
          "El elemento no tiene subetapa."
          "Completar los atributos mediante EDITAR.")
        controls)))
  (if (and (not (mp:base-is-tramo base)) (= identity ""))
    (setq controls
      (cons
        (urb:q-control-row "ALTA" group handle element
          "El elemento puntual no tiene ID o codigo."
          "Asignar una identidad mediante EDITAR; no se sumara hasta corregirlo.")
        controls)))
  (if (and (mp:base-is-tramo base) (<= length-value 1e-9))
    (setq controls
      (cons
        (urb:q-control-row "ALTA" group handle element
          "El tramo no tiene una longitud valida."
          "Usar EDITAR para revisar el tramo o reconstruirlo si su geometria es invalida.")
        controls)))
  (if (mp:base-is-tramo base)
    (progn
      (setq control-state (strcase (mp:getval "CONTROL_ESTADO" atts ""))
            control-messages (mp:getval "CONTROL_MENSAJES" atts ""))
      (cond
        ((= control-state "")
          (setq controls
            (cons
              (urb:q-control-row "ALTA" group handle element
                "El tramo no ha sido migrado al esquema constructivo vigente."
                "El bloque requiere migracion al esquema actual antes de exportar.")
              controls)))
        ((/= control-state "OK")
          (setq controls
            (cons
              (urb:q-control-row "ALTA" group handle element
                (if (= control-messages "")
                  "El tramo tiene observaciones de validacion."
                  control-messages)
                "Usar EDITAR para completar datos y revisar sus extremos vinculados.")
              controls))))))
  (reverse controls)
)

(defun urb:q-network-entity-package
  (ename / obj bname atts base group handle layer point stage substage
   element length-value ducts conductor status control-state detail specification records
   identity
   hydro electric lighting controls)
  (setq obj (urb:as-vla-object ename))
  (if (and obj (urb:q-modelspace-p ename))
    (progn
      (setq bname
        (urb:safe-string
          (vl-catch-all-apply 'vla-get-EffectiveName (list obj)) ""))
      (if (and (/= bname "") (mp:is-cant-blockname bname))
        (progn
          (setq atts (mp:att-alist ename)
                base
                  (strcase
                    (urb:safe-string (mp:infer-base bname atts) "")))
          (if (/= base "")
            (progn
              (setq group (urb:q-network-group base)
                    handle (urb:q-handle ename)
                    layer (urb:safe-string (vla-get-Layer obj) "")
                    point (vlax-get obj 'InsertionPoint)
                    stage (mp:getval "ETAPA" atts "")
                    substage (mp:getval "SUBETAPA" atts "")
                    identity
                      (mp:getval "ID" atts (mp:getval "CODIGO" atts ""))
                    element (urb:q-network-element base atts)
                    length-value
                      (urb:q-number (mp:getval "LONGITUD" atts "0"))
                    ducts (urb:q-number (mp:getval "DUCTOS" atts "0"))
                    conductor
                      (mp:getval "CONDUCTOR" atts
                        (mp:getval "CONDUCTORES" atts ""))
                    control-state
                      (strcase (mp:getval "CONTROL_ESTADO" atts ""))
                    status
                      (cond
                        ((and (mp:base-is-tramo base)
                              (<= length-value 1e-9)) "PENDIENTE")
                        ((not (mp:base-is-tramo base))
                          (urb:q-basic-status stage substage (/= identity "")))
                        ((= control-state "OK") "OK")
                        ((= control-state "") "MIGRAR")
                        (T "REVISAR"))
                    detail
                      (urb:q-network-detail-row
                        group base handle layer point atts))
              (cond
                ((= group "HIDROSANITARIAS") (setq hydro (list detail)))
                ((= group "LUMINARIAS") (setq lighting (list detail)))
                (T (setq electric (list detail))))
              (if (mp:base-is-tramo base)
                (progn
                  (setq specification
                    (urb:q-network-linear-specification
                      group atts ducts conductor))
                  (setq records
                    (urb:q-network-quantity-records
                      group element specification atts stage substage
                      length-value ducts conductor handle status)))
                (progn
                  (setq specification
                    (urb:q-network-point-specification base atts))
                  (setq records
                    (list
                      (urb:q-record group "Elementos puntuales"
                        element specification stage substage "UND" 1.0
                        handle status "" "")))))
              (setq controls
                (urb:q-network-control-rows
                  group handle element stage base length-value atts))
              (list records hydro electric lighting controls)))))))
)

(defun urb:q-network-duplicate-point-audit
  (details / counts detail base identity key found duplicate-keys handles controls)
  (foreach detail details
    (setq base (urb:safe-string (nth 1 detail) "")
          identity
            (urb:safe-string
              (if (/= (urb:safe-string (nth 8 detail) "") "")
                (nth 8 detail) (nth 9 detail)) ""))
    (if (and (not (mp:base-is-tramo base)) (/= identity ""))
      (progn
        (setq key (strcat (nth 0 detail) "|" base "|" (strcase identity)))
        (if (setq found (assoc key counts))
          (setq counts
            (subst (cons key (1+ (cdr found))) found counts))
          (setq counts (cons (cons key 1) counts))))))
  (foreach found counts
    (if (> (cdr found) 1)
      (setq duplicate-keys (cons (car found) duplicate-keys))))
  (foreach detail details
    (setq base (urb:safe-string (nth 1 detail) "")
          identity
            (urb:safe-string
              (if (/= (urb:safe-string (nth 8 detail) "") "")
                (nth 8 detail) (nth 9 detail)) "")
          key (strcat (nth 0 detail) "|" base "|" (strcase identity)))
    (if (and (/= identity "") (member key duplicate-keys))
      (progn
        (setq handles (cons (nth 2 detail) handles))
        (setq controls
          (cons
            (urb:q-control-row "ALTA" (nth 0 detail) (nth 2 detail) base
              (strcat "El ID/codigo " identity " esta repetido para " base ".")
              "Asignar identificadores unicos; el elemento no se sumara hasta corregirlo.")
            controls)))))
  (list handles (reverse controls))
)

(defun urb:q-collect-networks
  (/ ss index ename package records hydro electric lighting controls audit
   duplicate-handles adjusted result record)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (if ss
    (progn
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index)
              package (urb:q-network-entity-package ename))
        (if package
          (setq records
                  (append (reverse (nth 0 package)) records)
                hydro
                  (append (reverse (nth 1 package)) hydro)
                electric
                  (append (reverse (nth 2 package)) electric)
                lighting
                  (append (reverse (nth 3 package)) lighting)
                controls
                  (append (reverse (nth 4 package)) controls)))
        (setq index (1+ index)))))
  (setq audit
    (urb:q-network-duplicate-point-audit
      (append hydro electric lighting))
    duplicate-handles (nth 0 audit)
    controls (append controls (nth 1 audit)))
  (foreach record records
    (if (member (nth 8 record) duplicate-handles)
      (setq adjusted (urb:list-set-nth 9 "REVISAR" record))
      (setq adjusted record))
    (setq result (cons adjusted result)))
  (list
    (reverse result)
    (reverse hydro)
    (reverse electric)
    (reverse lighting)
    (reverse controls))
)

(defun urb:excel-column-name (index / result remainder)
  (setq result "")
  (while (> index 0)
    (setq remainder (rem (1- index) 26))
    (setq result (strcat (chr (+ 65 remainder)) result))
    (setq index (fix (/ (1- index) 26))))
  result
)

(defun urb:excel-matrix-variant
  (matrix / row-count col-count array row-index col-index row value)
  (setq row-count (length matrix)
        col-count (if matrix (length (car matrix)) 0))
  (if (and (> row-count 0) (> col-count 0))
    (progn
      (setq array
        (vlax-make-safearray
          vlax-vbVariant
          (cons 0 (1- row-count))
          (cons 0 (1- col-count))))
      (setq row-index 0)
      (foreach row matrix
        (setq col-index 0)
        (repeat col-count
          (setq value
            (if (> (length row) col-index) (nth col-index row) ""))
          (vlax-safearray-put-element array row-index col-index value)
          (setq col-index (1+ col-index)))
        (setq row-index (1+ row-index)))
      (vlax-make-variant array))
    nil)
)

(defun urb:excel-rgb (red green blue)
  (+ red (* 256 green) (* 65536 blue))
)

(defun urb:excel-release (object)
  (if (= (type object) 'VLA-OBJECT)
    (vl-catch-all-apply 'vlax-release-object (list object)))
  nil
)

(defun urb:excel-write-table
  (application sheet matrix numeric-columns
   / row-count col-count last-column address target header font interior
   columns column index width number-range window result)
  (setq row-count (length matrix)
        col-count (if matrix (length (car matrix)) 0))
  (if (and (> row-count 0) (> col-count 0))
    (progn
      (setq last-column (urb:excel-column-name col-count)
            address (strcat "A1:" last-column (itoa row-count))
            target (vlax-get-property sheet 'Range address))
      (vlax-put-property target 'Value2 (urb:excel-matrix-variant matrix))
      (setq header
        (vlax-get-property sheet 'Range
          (strcat "A1:" last-column "1")))
      (setq font (vlax-get-property header 'Font))
      (vlax-put-property font 'Bold :vlax-true)
      (vlax-put-property font 'Color (urb:excel-rgb 255 255 255))
      (setq interior (vlax-get-property header 'Interior))
      (vlax-put-property interior 'Color (urb:excel-rgb 31 78 121))
      (vlax-put-property header 'WrapText :vlax-true)
      (vlax-put-property header 'HorizontalAlignment -4108)
      (vlax-put-property header 'VerticalAlignment -4108)
      (vlax-put-property header 'RowHeight 30.0)
      (vl-catch-all-apply 'vlax-invoke-method (list target 'AutoFilter))
      (setq columns (vlax-get-property target 'Columns))
      (vl-catch-all-apply 'vlax-invoke-method (list columns 'AutoFit))
      (setq index 1)
      (repeat col-count
        (setq column
          (vl-catch-all-apply 'vlax-get-property (list columns 'Item index)))
        (if (not (vl-catch-all-error-p column))
          (progn
            (setq width (vlax-get-property column 'ColumnWidth))
            (if (> width 42.0) (vlax-put-property column 'ColumnWidth 42.0))
            (if (< width 9.0) (vlax-put-property column 'ColumnWidth 9.0))
            (urb:excel-release column)))
        (setq index (1+ index)))
      (foreach index numeric-columns
        (if (> row-count 1)
          (progn
            (setq number-range
              (vlax-get-property sheet 'Range
                (strcat (urb:excel-column-name index) "2:"
                        (urb:excel-column-name index) (itoa row-count))))
            (vlax-put-property number-range 'NumberFormatLocal "#.##0,00")
            (urb:excel-release number-range))))
      (vlax-invoke-method sheet 'Activate)
      (setq window
        (vl-catch-all-apply 'vlax-get-property (list application 'ActiveWindow)))
      (if (not (vl-catch-all-error-p window))
        (progn
          (vl-catch-all-apply 'vlax-put-property
            (list window 'SplitRow 1))
          (vl-catch-all-apply 'vlax-put-property
            (list window 'FreezePanes :vlax-true))
          (vl-catch-all-apply 'vlax-put-property
            (list window 'DisplayGridlines :vlax-false))
          (urb:excel-release window)))
      (urb:excel-release columns)
      (urb:excel-release interior)
      (urb:excel-release font)
      (urb:excel-release header)
      (urb:excel-release target)
      T)
    nil)
)

(defun urb:excel-format-column
  (sheet column-index row-count number-format / column-name number-range)
  (if (> row-count 1)
    (progn
      (setq column-name (urb:excel-column-name column-index)
            number-range
              (vlax-get-property sheet 'Range
                (strcat column-name "2:" column-name (itoa row-count))))
      (vlax-put-property number-range 'NumberFormatLocal number-format)
      (urb:excel-release number-range)))
  nil
)

(defun urb:excel-add-sheet (sheets name / sheet result)
  (setq result (vl-catch-all-apply 'vlax-invoke-method (list sheets 'Add)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq sheet result)
      (vlax-put-property sheet 'Name name)
      sheet))
)

(defun urb:q-summary-matrix (aggregated / matrix item)
  (setq matrix
    (list
      '("CAPITULO" "SISTEMA" "ELEMENTO" "ESPECIFICACION"
        "ETAPA" "SUBETAPA" "UND" "CANTIDAD" "OBJETOS" "ESTADO")))
  (foreach item aggregated
    (setq matrix
      (append matrix
        (list
          (list
            (nth 1 item) (nth 2 item) (nth 3 item) (nth 4 item)
            (nth 5 item) (nth 6 item) (nth 7 item) (nth 8 item)
            (nth 9 item) (nth 10 item))))))
  matrix
)

(defun urb:q-trace-matrix (records / matrix item)
  (setq matrix
    (list
      '("CAPITULO" "SISTEMA" "ELEMENTO" "ESPECIFICACION"
        "ETAPA" "SUBETAPA" "UND" "CANTIDAD" "HANDLE" "ESTADO"
        "VINCULO_ID" "VINCULO_NOMBRE")))
  (foreach item records
    (setq matrix (append matrix (list item))))
  matrix
)

(defun urb:q-control-matrix (controls / matrix item)
  (setq matrix
    (list '("SEVERIDAD" "CATEGORIA" "HANDLE" "ELEMENTO" "HALLAZGO" "ACCION")))
  (foreach item controls
    (setq matrix (append matrix (list item))))
  matrix
)

(defun urb:q-detail-matrix (headers rows / matrix row)
  (setq matrix (list headers))
  (foreach row rows (setq matrix (append matrix (list row))))
  matrix
)

(setq *urb-excel-general-sheet* "CANTIDADES_URBANISMO")
(setq *urb-excel-general-table* "tbl_urbanismo_cantidades")
(setq *urb-excel-link-key* "EXCEL_MASTER_PATH")
(setq *urb-excel-table-schema* "2")
(setq *urb-excel-general-headers*
  '("ID_REGISTRO" "TIPO_REGISTRO" "VERSION_ESQUEMA" "VERSION_LSP"
    "ID_DWG" "ARCHIVO_DWG" "RUTA_DWG" "FECHA_ACTUALIZACION" "CAPITULO"
    "SISTEMA" "ELEMENTO" "ESPECIFICACION" "ETAPA" "SUBETAPA"
    "UNIDAD" "CANTIDAD" "CANTIDAD_ORIGINAL" "INCLUIR_CANTIDAD"
    "HANDLE" "ESTADO" "VINCULO_ID"
    "VINCULO_NOMBRE" "OBSERVACION" "ACCION"))

(defun urb:excel-safe-text (value / text first-character)
  (setq text (urb:safe-string value ""))
  (if (> (strlen text) 0)
    (progn
      (setq first-character (substr text 1 1))
      (if (member first-character '("=" "+" "-" "@"))
        (strcat "'" text)
        text))
    text)
)

(defun urb:excel-display-timestamp ()
  (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD HH:MM:SS)")
)

(defun urb:excel-file-timestamp ()
  (menucmd "M=$(edtime,$(getvar,date),YYYYMODD_HHMMSS)")
)

(defun urb:q-duplicate-road-id-controls
  (records / counts record id found duplicates adjusted controls result)
  (foreach record records
    (if (and (urb:string-equal-p (nth 0 record) "VIAS")
             (urb:string-equal-p (nth 2 record) "Longitud de via")
             (/= (setq id (urb:safe-string (nth 10 record) "")) ""))
      (if (setq found (assoc id counts))
        (setq counts
          (subst (cons id (1+ (cdr found))) found counts))
        (setq counts (cons (cons id 1) counts)))))
  (foreach found counts
    (if (> (cdr found) 1)
      (setq duplicates (cons (car found) duplicates))))
  (foreach record records
    (setq id (urb:safe-string (nth 10 record) ""))
    (if (and (/= id "") (member id duplicates)
             (member (strcase (nth 0 record)) '("VIAS" "ANDENES")))
      (progn
        (setq adjusted (urb:list-set-nth 9 "REVISAR" record))
        (if (and (urb:string-equal-p (nth 0 record) "VIAS")
                 (urb:string-equal-p (nth 2 record) "Longitud de via"))
          (setq controls
            (cons
              (urb:q-control-row "ALTA" "VINCULO VIA-ANDEN"
                (nth 8 record) (nth 11 record)
                (strcat "El VIA_ID " id " esta repetido en varias vias.")
                "Editar o reconstruir la copia duplicada; sus cantidades y andenes vinculados no se sumaran.")
              controls))))
      (setq adjusted record))
    (setq result (cons adjusted result)))
  (list (reverse result) (reverse controls))
)

(defun urb:q-refresh-network-segments
  (/ ss index ename obj bname atts base result updated failed doc undo-open)
  (setq ss (ssget "_X" '((0 . "INSERT")))
        doc (urb:doc))
  (if ss
    (progn
      (if (not
            (vl-catch-all-error-p
              (vl-catch-all-apply 'vla-StartUndoMark (list doc))))
        (setq undo-open T))
      (setq index 0)
      (repeat (sslength ss)
        (setq ename (ssname ss index))
        (if (urb:q-modelspace-p ename)
          (progn
            (setq obj (urb:as-vla-object ename))
            (if obj
              (progn
                (setq bname
                  (urb:safe-string
                    (vl-catch-all-apply 'vla-get-EffectiveName (list obj)) ""))
                (if (and (/= bname "") (mp:is-cant-blockname bname))
                  (progn
                    (setq atts (mp:att-alist ename)
                          base (mp:infer-base bname atts))
                    (if (mp:base-is-tramo base)
                      (progn
                        (setq result
                          (vl-catch-all-apply
                            'mp:update-block-after-edit
                            (list ename nil)))
                        (if (vl-catch-all-error-p result)
                          (setq failed (1+ (if failed failed 0)))
                          (setq updated (1+ (if updated updated 0))))))))))))
        (setq index (1+ index)))
      (if undo-open
        (vl-catch-all-apply 'vla-EndUndoMark (list doc)))))
  (if (or updated failed)
    (prompt
      (strcat "\nPreactualizacion de redes: "
        (itoa (if updated updated 0)) " tramo(s) recalculados"
        " | " (itoa (if failed failed 0)) " con error.")))
  (list (if updated updated 0) (if failed failed 0))
)

(defun urb:q-scope-controls (/ ss index ename data entity-data layout handle layer result)
  (setq ss (ssget "_X" '((-3 ("URB_Q_SCOPE"))))
        index 0)
  (if ss
    (repeat (sslength ss)
      (setq ename (ssname ss index)
            data (urb:get-xdata-strings ename "URB_Q_SCOPE")
            entity-data (entget ename)
            layout (urb:safe-string (cdr (assoc 410 entity-data)) "")
            handle (urb:q-handle ename)
            layer (urb:safe-string (cdr (assoc 8 entity-data)) ""))
      (if (and (urb:string-equal-p layout "Model")
               data
               (member (strcase (urb:safe-string (car data) "SI"))
                 '("NO" "EXCLUIR" "0")))
        (setq result
          (cons
            (urb:q-control-row "INFO" "ALCANCE" handle layer
              "Elemento excluido manualmente de las cantidades."
              "Use Cantidades > Incluir o excluir seleccion para reincorporarlo.")
            result)))
      (setq index (1+ index))))
  (reverse result)
)

(defun urb:q-collect-all
  (/ anden via prefab green network records controls duplicates)
  (urb:q-refresh-network-segments)
  (setq anden (urb:q-collect-andenes)
        via (urb:q-collect-vias)
        prefab (urb:q-collect-prefabricados)
        green (urb:q-collect-green-zones)
        network (urb:q-collect-networks)
        records
          (append
            (nth 0 anden) (nth 0 via) (nth 0 prefab)
            (nth 0 green) (nth 0 network))
        controls
          (append
            (nth 2 anden) (nth 2 via) (nth 2 prefab)
            (nth 2 green) (nth 4 network)
            (urb:q-scope-controls)))
  (setq duplicates (urb:q-duplicate-road-id-controls records)
        records (nth 0 duplicates)
        controls (append controls (nth 1 duplicates)))
  (list records controls)
)

(defun urb:q-approved-record-count (records / count record)
  (setq count 0)
  (foreach record records
    (if (urb:q-approved-status-p (nth 9 record))
      (setq count (1+ count))))
  count
)

(defun urb:xref-definition-count (/ blocks block result is-xref)
  (setq result 0
        blocks (vla-get-Blocks (urb:doc)))
  (vlax-for block blocks
    (setq is-xref
      (vl-catch-all-apply 'vla-get-IsXRef (list block)))
    (if (and (not (vl-catch-all-error-p is-xref))
             (= is-xref :vlax-true))
      (setq result (1+ result))))
  (urb:excel-release blocks)
  result
)

(defun urb:q-preflight-report (records controls / approved blocked xrefs migrate record)
  (setq approved (urb:q-approved-record-count records)
        blocked (- (length records) approved)
        xrefs (urb:xref-definition-count))
  (foreach record records
    (if (urb:string-equal-p (nth 9 record) "MIGRAR")
      (setq migrate (1+ (if migrate migrate 0)))))
  (prompt
    (strcat
      "\nPrevalidacion de cantidades: " (itoa approved) " aprobadas"
      " | " (itoa blocked) " bloqueadas (se exportan con CANTIDAD=0)"
      " | " (itoa (length controls)) " controles."
      (if (and migrate (> migrate 0))
        (strcat " Hay " (itoa migrate)
          " registro(s) de red por migrar; use Configuracion > Diagnosticar y migrar redes.")
        "")
      (if (> xrefs 0)
        (strcat " Aviso: hay " (itoa xrefs)
          " XREF; sus elementos internos no se incluyen.")
        "")))
  (list approved blocked xrefs)
)

(defun urb:drawing-id (/ value seed)
  (setq value
    (vl-string-trim " "
      (urb:safe-string (urb:config-read "URB_DRAWING_ID") "")))
  (if (= value "")
    (progn
      (setq seed
        (strcat
          (menucmd "M=$(edtime,$(getvar,date),YYYYMODDHHMMSS)")
          "-" (itoa (getvar "MILLISECS"))
          "-" (urb:safe-string (getvar "DWGTITLED") "0")))
      (setq value (strcat "URB-DWG-" seed))
      (urb:config-write "URB_DRAWING_ID" value)))
  value
)

(defun urb:q-general-record-id (drawing-id record)
  (strcat
    drawing-id "|" (nth 8 record) "|" (nth 0 record) "|"
    (nth 1 record) "|" (nth 2 record) "|" (nth 3 record) "|"
    (nth 4 record) "|" (nth 5 record) "|" (nth 6 record))
)

(defun urb:q-general-matrix
  (records controls / drawing-id drawing-name drawing-path timestamp rows item
   index original-quantity approved)
  (setq drawing-id (urb:drawing-id)
        drawing-name (getvar "DWGNAME")
        drawing-path (strcat (getvar "DWGPREFIX") drawing-name)
        timestamp (urb:excel-display-timestamp)
        rows nil
        index 0)
  (foreach item records
    (setq index (1+ index))
    (setq rows
      (cons
        (list
          (urb:excel-safe-text
            (urb:q-general-record-id drawing-id item))
          "CANTIDAD" *urb-excel-table-schema* *urb-version*
          (urb:excel-safe-text drawing-id)
          (urb:excel-safe-text drawing-name)
          (urb:excel-safe-text drawing-path)
          timestamp
          (urb:excel-safe-text (nth 0 item))
          (urb:excel-safe-text (nth 1 item))
          (urb:excel-safe-text (nth 2 item))
          (urb:excel-safe-text (nth 3 item))
          (urb:excel-safe-text (nth 4 item))
          (urb:excel-safe-text (nth 5 item))
          (urb:excel-safe-text (nth 6 item))
          (setq original-quantity (urb:q-number (nth 7 item)))
          (setq approved (urb:q-approved-status-p (nth 9 item)))
          (if approved original-quantity 0.0)
          original-quantity
          (if approved "SI" "NO")
          (urb:excel-safe-text (nth 8 item))
          (urb:excel-safe-text (nth 9 item))
          (urb:excel-safe-text (nth 10 item))
          (urb:excel-safe-text (nth 11 item))
          "" "")
        rows)))
  (foreach item controls
    (setq index (1+ index))
    (setq rows
      (cons
        (list
          (urb:excel-safe-text
            (strcat drawing-id "|CONTROL|" (nth 2 item) "|"
              (nth 1 item) "|" (nth 3 item) "|" (nth 4 item)))
          "CONTROL" *urb-excel-table-schema* *urb-version*
          (urb:excel-safe-text drawing-id)
          (urb:excel-safe-text drawing-name)
          (urb:excel-safe-text drawing-path)
          timestamp
          "CONTROL_CALIDAD"
          (urb:excel-safe-text (nth 1 item))
          (urb:excel-safe-text (nth 3 item))
          "" "" "" "" 0.0 0.0 "NO"
          (urb:excel-safe-text (nth 2 item))
          (urb:excel-safe-text (nth 0 item))
          "" ""
          (urb:excel-safe-text (nth 4 item))
          (urb:excel-safe-text (nth 5 item)))
        rows)))
  (cons *urb-excel-general-headers* (reverse rows))
)

(defun urb:excel-item (collection key / result)
  (setq result
    (vl-catch-all-apply 'vlax-get-property (list collection 'Item key)))
  (if (vl-catch-all-error-p result)
    nil
    (urb:excel-variant-value result))
)

(defun urb:excel-fail (message)
  (setq *urb-excel-last-error*
    (urb:safe-string message "Error de Excel sin descripcion."))
  nil
)

(defun urb:excel-variant-value (value / result next guard)
  ;; Value2 puede devolver un VARIANT vacio en vez de nil. Normalizarlo
  ;; evita confundir una hoja nueva con una hoja que ya contiene datos.
  ;; Algunas propiedades de Excel tambien envuelven objetos COM en uno o
  ;; mas VARIANT; se desenvuelven hasta obtener el valor u objeto real.
  (setq result value guard 0)
  (while (and (= (type result) 'VARIANT) (< guard 8))
    (setq next
      (vl-catch-all-apply 'vlax-variant-value (list result)))
    (if (vl-catch-all-error-p next)
      (setq result nil guard 8)
      (setq result next guard (1+ guard))))
  result
)

(defun urb:excel-save-as-xlsx (workbook filename / empty windows-path)
  ;; Excel expone Workbook.SaveAs con doce parametros. Al invocarlo mediante
  ;; IDispatch desde AutoLISP algunas versiones de Office no completan los
  ;; opcionales y responden "too few actual parameters". Enviar los doce
  ;; conserva el formato XLSX (51) y aplica la configuracion local del Excel.
  (setq empty (vlax-make-variant)
        windows-path (vl-string-translate "/" "\\" filename))
  (vl-catch-all-apply 'vlax-invoke-method
    (list workbook 'SaveAs windows-path 51
      empty empty :vlax-false :vlax-false
      1 empty :vlax-false empty empty :vlax-true))
)

(defun urb:excel-sheet-blank-p (sheet / used count value blank)
  (setq *urb-excel-stage* "verificacion de hoja vacia")
  (setq used (vlax-get-property sheet 'UsedRange)
        count (vlax-get-property used 'Count)
        value
          (urb:excel-variant-value
            (vlax-get-property used 'Value2))
        blank
          (and (= count 1)
            (or (null value) (and (= (type value) 'STR) (= value "")))))
  (urb:excel-release used)
  blank
)

(defun urb:excel-find-table
  (sheets table-name / count index sheet tables candidate found)
  (setq count (vlax-get-property sheets 'Count)
        index 1)
  (while (and (<= index count) (null found))
    (setq sheet (urb:excel-item sheets index))
    (if sheet
      (progn
        (setq tables
                (urb:excel-variant-value
                  (vlax-get-property sheet 'ListObjects))
              candidate (urb:excel-item tables table-name))
        (urb:excel-release tables)
        (if candidate
          (setq found (list candidate sheet))
          (urb:excel-release sheet))))
    (setq index (1+ index)))
  found
)

(defun urb:excel-get-or-create-sheet
  (sheets name / sheet result created)
  (setq sheet (urb:excel-item sheets name))
  (if sheet
    (list sheet nil)
    (progn
      (setq result
        (vl-catch-all-apply 'vlax-invoke-method (list sheets 'Add)))
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (setq sheet (urb:excel-variant-value result) created T)
          (vlax-put-property sheet 'Name name)
          (list sheet created)))))
)

(defun urb:excel-table-column (table header / columns column)
  (setq columns
          (urb:excel-variant-value
            (vlax-get-property table 'ListColumns))
        column (urb:excel-item columns header))
  (urb:excel-release columns)
  column
)

(defun urb:excel-ensure-table-columns
  (table headers / columns header column result ok)
  (setq columns
          (urb:excel-variant-value
            (vlax-get-property table 'ListColumns))
        ok T)
  (while (and headers ok)
    (setq header (car headers)
          column (urb:excel-item columns header))
    (if (null column)
      (progn
        (setq result
          (vl-catch-all-apply 'vlax-invoke-method (list columns 'Add)))
        (if (vl-catch-all-error-p result)
          (progn
            (urb:excel-fail
              (strcat "No fue posible agregar la columna " header ": "
                (vl-catch-all-error-message result)))
            (setq ok nil))
          (progn
            (setq column (urb:excel-variant-value result))
            (vlax-put-property column 'Name header)))))
    (urb:excel-release column)
    (setq headers (cdr headers)))
  (urb:excel-release columns)
  ok
)

(defun urb:excel-create-general-table
  (sheet matrix / row-count col-count address target tables result table)
  (setq *urb-excel-stage* "preparacion del rango de la tabla general")
  (setq row-count (length matrix)
        col-count (length (car matrix))
        address
          (strcat "A1:" (urb:excel-column-name col-count) (itoa row-count))
        target
          (urb:excel-variant-value
            (vlax-get-property sheet 'Range address)))
  (vlax-put-property target 'Value2 (urb:excel-matrix-variant matrix))
  (setq *urb-excel-stage* "creacion del objeto tabla general")
  (setq tables
          (urb:excel-variant-value
            (vlax-get-property sheet 'ListObjects))
        result
          (vl-catch-all-apply 'vlax-invoke-method
            (list tables 'Add 1 target :vlax-false 1)))
  (if (vl-catch-all-error-p result)
    (progn
      (urb:excel-release tables)
      (urb:excel-release target)
      (urb:excel-fail
        (strcat "No fue posible crear la tabla general: "
          (vl-catch-all-error-message result))))
    (progn
      (setq table (urb:excel-variant-value result))
      (setq *urb-excel-stage* "asignacion del nombre de la tabla general")
      (vlax-put-property table 'Name *urb-excel-general-table*)
      (vl-catch-all-apply 'vlax-put-property
        (list table 'TableStyle "TableStyleMedium2"))
      (urb:excel-release tables)
      (urb:excel-release target)
      table))
)

(defun urb:excel-format-quantity-column (table / header column data-range)
  (foreach header '("CANTIDAD" "CANTIDAD_ORIGINAL")
    (setq column (urb:excel-table-column table header))
    (if column
      (progn
        (setq data-range
          (vl-catch-all-apply 'vlax-get-property
            (list column 'DataBodyRange)))
        (if (not (vl-catch-all-error-p data-range))
          (progn
            (setq data-range (urb:excel-variant-value data-range))
            (vlax-put-property data-range 'NumberFormatLocal "#.##0,00")
            (urb:excel-release data-range)))
        (urb:excel-release column))))
  nil
)

(defun urb:excel-format-date-column (table / column data-range)
  (setq column (urb:excel-table-column table "FECHA_ACTUALIZACION"))
  (if column
    (progn
      (setq data-range
        (vl-catch-all-apply 'vlax-get-property
          (list column 'DataBodyRange)))
      (if (not (vl-catch-all-error-p data-range))
        (progn
          (setq data-range (urb:excel-variant-value data-range))
          ;; NumberFormat usa codigos invariantes de Excel y evita que una
          ;; fecha colombiana termine mostrandose mes/dia en otro equipo.
          (vlax-put-property data-range 'NumberFormat "dd/mm/yyyy hh:mm:ss")
          (urb:excel-release data-range)))
      (urb:excel-release column)))
  nil
)

(defun urb:list-index-ci (value values / index found)
  (setq index 0)
  (while (and values (null found))
    (if (urb:string-equal-p value (car values))
      (setq found index)
      (setq index (1+ index)
            values (cdr values))))
  found
)

(defun urb:list-set-nth (index value values / cursor result item)
  (setq cursor 0 result nil)
  (foreach item values
    (setq result
      (cons (if (= cursor index) value item) result)
      cursor (1+ cursor)))
  (reverse result)
)

(defun urb:excel-cell-value (value / current next)
  (setq current value)
  (while (= (type current) 'VARIANT)
    (setq next (vl-catch-all-apply 'vlax-variant-value (list current)))
    (if (vl-catch-all-error-p next)
      (setq current nil)
      (setq current next)))
  (if (= (type current) 'SAFEARRAY)
    (setq current (vlax-safearray->list current)))
  (if (= (type current) 'LIST)
    (if current (urb:excel-cell-value (car current)) "")
    current)
)

(defun urb:excel-column-property-values
  (table header property / column range raw data result item)
  (setq column (urb:excel-table-column table header))
  (if column
    (progn
      (setq range
        (vl-catch-all-apply 'vlax-get-property
          (list column 'DataBodyRange)))
      (if (not (vl-catch-all-error-p range))
        (progn
          (setq range (urb:excel-variant-value range)
                raw
                  (vl-catch-all-apply 'vlax-get-property
                    (list range property)))
          (if (not (vl-catch-all-error-p raw))
            (progn
              (setq data (urb:excel-variant-value raw))
              (if (= (type data) 'SAFEARRAY)
                (setq data (vlax-safearray->list data)))
              (if (= (type data) 'LIST)
                (foreach item data
                  (setq result
                    (cons (urb:excel-cell-value item) result)))
                (setq result (list (urb:excel-cell-value data)))))
            (setq result nil))
          (urb:excel-release range)))
      (urb:excel-release column)))
  (reverse result)
)

(defun urb:excel-table-column-names
  (table / columns count index column name result)
  (setq columns
    (urb:excel-variant-value
      (vlax-get-property table 'ListColumns))
    count (vlax-get-property columns 'Count)
    index 1)
  (repeat count
    (setq column (urb:excel-item columns index))
    (if column
      (progn
        (setq name (urb:safe-string (vla-get-Name column) ""))
        (if (/= name "") (setq result (cons name result)))
        (urb:excel-release column)))
    (setq index (1+ index)))
  (urb:excel-release columns)
  (reverse result)
)

(defun urb:excel-table-required-rows
  (table headers / columns values max-count index row rows)
  (setq max-count 0 columns nil)
  (foreach header headers
    (setq values
      (urb:excel-column-property-values table header 'Value2))
    (setq columns (append columns (list values))
          max-count (max max-count (length values))))
  (setq index 0)
  (repeat max-count
    (setq row nil)
    (foreach values columns
      (setq row
        (append row
          (list (if (> (length values) index) (nth index values) "")))))
    (setq rows (append rows (list row))
          index (1+ index)))
  rows
)

(defun urb:excel-formula-template (values / found value)
  (foreach value values
    (if (and (null found) (= (type value) 'STR)
             (> (strlen value) 0) (= (substr value 1 1) "="))
      (setq found value)))
  found
)

(defun urb:excel-capture-extra-columns
  (table required-headers / ids required-rows names name values mapping index
   template result id row)
  (setq ids
    (urb:excel-column-property-values table "ID_REGISTRO" 'Value2)
    required-rows (urb:excel-table-required-rows table required-headers)
    names (urb:excel-table-column-names table))
  (foreach name names
    (if (null (urb:list-index-ci name required-headers))
      (progn
        (setq values
          (urb:excel-column-property-values table name 'Formula)
          mapping nil
          index 0)
        (foreach id ids
          (setq row
            (if (> (length required-rows) index)
              (nth index required-rows) nil))
          (if (and (/= (urb:safe-string id "") "")
                   (> (length values) index))
            (setq mapping
              (cons
                (cons (strcat "ID:" (urb:safe-string id ""))
                  (nth index values))
                mapping)))
          (if (and row (> (length values) index))
            (setq mapping
              (cons
                (cons
                  (strcat "SIG:"
                    (urb:excel-row-signature row required-headers))
                  (nth index values))
                mapping)))
          (setq index (1+ index)))
        (setq template (urb:excel-formula-template values)
              result (cons (list name mapping template) result)))))
  (reverse result)
)

(defun urb:excel-row-signature (row headers / fields index result)
  (setq fields
    '("TIPO_REGISTRO" "RUTA_DWG" "CAPITULO" "SISTEMA" "ELEMENTO"
      "ESPECIFICACION" "ETAPA" "SUBETAPA" "UNIDAD" "HANDLE")
    result "")
  (foreach field fields
    (setq index (urb:list-index-ci field headers)
          result
            (strcat result "|"
              (strcase
                (urb:safe-string
                  (if index (nth index row) "") "")))))
  result
)

(defun urb:excel-merge-master-matrix
  (table matrix / headers new-rows old-rows id-index type-index dwg-index
   path-index observation-index action-index quantity-index original-index
   include-index status-index schema-index current-dwg current-path
   current-map preserved row row-id same-drawing found adjusted value approved)
  (setq headers (car matrix)
        new-rows (cdr matrix)
        old-rows (urb:excel-table-required-rows table headers)
        id-index (urb:list-index-ci "ID_REGISTRO" headers)
        type-index (urb:list-index-ci "TIPO_REGISTRO" headers)
        dwg-index (urb:list-index-ci "ID_DWG" headers)
        path-index (urb:list-index-ci "RUTA_DWG" headers)
        observation-index (urb:list-index-ci "OBSERVACION" headers)
        action-index (urb:list-index-ci "ACCION" headers)
        quantity-index (urb:list-index-ci "CANTIDAD" headers)
        original-index (urb:list-index-ci "CANTIDAD_ORIGINAL" headers)
        include-index (urb:list-index-ci "INCLUIR_CANTIDAD" headers)
        status-index (urb:list-index-ci "ESTADO" headers)
        schema-index (urb:list-index-ci "VERSION_ESQUEMA" headers)
        current-dwg
          (urb:safe-string
            (if (and new-rows dwg-index) (nth dwg-index (car new-rows)) "") "")
        current-path
          (urb:safe-string
            (if (and new-rows path-index) (nth path-index (car new-rows)) "") ""))
  (foreach row old-rows
    (setq same-drawing
      (if (and dwg-index
               (/= current-dwg "")
               (/= (urb:safe-string (nth dwg-index row) "") ""))
        (urb:string-equal-p current-dwg (nth dwg-index row))
        (and path-index
             (urb:string-equal-p current-path (nth path-index row)))))
    (if same-drawing
      (progn
        (setq row-id (urb:safe-string (nth id-index row) ""))
        (if (/= row-id "")
          (setq current-map
            (cons (cons (strcat "ID:" row-id) row) current-map)))
        (setq current-map
          (cons
            (cons
              (strcat "SIG:" (urb:excel-row-signature row headers))
              row)
            current-map)))
      (progn
        ;; Los registros de otros DWG se conservan, pero al migrar una tabla
        ;; antigua también se neutralizan cantidades con estado no aprobado.
        (setq adjusted row)
        (if (urb:string-equal-p (nth type-index row) "CANTIDAD")
          (progn
            (setq value (urb:q-number (nth quantity-index row))
                  approved
                    (urb:q-approved-status-p (nth status-index row))
                  adjusted
                    (urb:list-set-nth original-index
                      (if (> (abs (urb:q-number (nth original-index row))) 1e-12)
                        (urb:q-number (nth original-index row))
                        value)
                      adjusted)
                  adjusted
                    (urb:list-set-nth include-index
                      (if approved "SI" "NO") adjusted)
                  adjusted
                    (urb:list-set-nth quantity-index
                      (if approved value 0.0) adjusted)))
          (setq adjusted
            (urb:list-set-nth include-index "NO"
              (urb:list-set-nth quantity-index 0.0 adjusted))))
        (setq adjusted
          (urb:list-set-nth schema-index *urb-excel-table-schema* adjusted)
          preserved (append preserved (list adjusted))))))
  (foreach row new-rows
    (setq row-id (urb:safe-string (nth id-index row) "")
          found
            (or
              (assoc (strcat "ID:" row-id) current-map)
              (assoc
                (strcat "SIG:" (urb:excel-row-signature row headers))
                current-map))
          adjusted row)
    (if (and found
             (urb:string-equal-p (nth type-index row) "CANTIDAD"))
      (progn
        (setq value (nth observation-index (cdr found)))
        (if (/= (urb:safe-string value "") "")
          (setq adjusted
            (urb:list-set-nth observation-index value adjusted)))
        (setq value (nth action-index (cdr found)))
        (if (/= (urb:safe-string value "") "")
          (setq adjusted
            (urb:list-set-nth action-index value adjusted)))))
    (setq preserved (append preserved (list adjusted))))
  (cons headers preserved)
)

(defun urb:excel-restore-extra-columns
  (table matrix extra-state / headers rows id-index state name mapping
   template values id found column range result row)
  (setq headers (car matrix)
        rows (cdr matrix)
        id-index (urb:list-index-ci "ID_REGISTRO" headers))
  (foreach state extra-state
    (setq name (nth 0 state)
          mapping (nth 1 state)
          template (nth 2 state)
          values nil)
    (foreach row rows
      (setq id (urb:safe-string (nth id-index row) "")
            found
              (or
                (assoc (strcat "ID:" id) mapping)
                (assoc
                  (strcat "SIG:" (urb:excel-row-signature row headers))
                  mapping)))
      (setq values
        (append values
          (list
            (list
              (cond
                (found (cdr found))
                (template template)
                (T "")))))))
    (setq column (urb:excel-table-column table name))
    (if column
      (progn
        (setq range
          (vl-catch-all-apply 'vlax-get-property
            (list column 'DataBodyRange)))
        (if (not (vl-catch-all-error-p range))
          (progn
            (setq range (urb:excel-variant-value range)
                  result
                    (vl-catch-all-apply 'vlax-put-property
                      (list range 'Formula
                        (urb:excel-matrix-variant values))))
            (urb:excel-release range)))
        (urb:excel-release column))))
  nil
)

(defun urb:excel-update-general-table
  (sheet table matrix
   / headers rows new-data-count table-range start-row start-column
    old-data-range old-data-rows old-data-count table-columns column-count header column
    data-range new-address new-range tail-address tail-range index values row
    extra-state)
  (setq headers (car matrix))
  (if (= (length (cdr matrix)) 0)
    (urb:excel-fail
      "La tabla general no contiene registros para actualizar.")
    (if (not (urb:excel-ensure-table-columns table headers))
      nil
      (progn
  (setq extra-state (urb:excel-capture-extra-columns table headers)
        matrix (urb:excel-merge-master-matrix table matrix)
        headers (car matrix)
        rows (cdr matrix)
        new-data-count (length rows))
  (setq table-range
          (urb:excel-variant-value
            (vlax-get-property table 'Range))
        start-row (vlax-get-property table-range 'Row)
        start-column (vlax-get-property table-range 'Column)
        table-columns
          (urb:excel-variant-value
            (vlax-get-property table-range 'Columns))
        column-count (vlax-get-property table-columns 'Count))
  (setq old-data-range
    (vl-catch-all-apply 'vlax-get-property (list table 'DataBodyRange)))
  (if (or (vl-catch-all-error-p old-data-range) (null old-data-range))
    (setq old-data-count 0)
    (progn
      (setq old-data-range (urb:excel-variant-value old-data-range)
            old-data-rows
              (urb:excel-variant-value
                (vlax-get-property old-data-range 'Rows))
            old-data-count (vlax-get-property old-data-rows 'Count))
      (urb:excel-release old-data-rows)
      (urb:excel-release old-data-range)))
  (urb:excel-release table-columns)
  (foreach header headers
    (setq column (urb:excel-table-column table header))
    (if column
      (progn
        (setq data-range
          (vl-catch-all-apply 'vlax-get-property
            (list column 'DataBodyRange)))
        (if (not (vl-catch-all-error-p data-range))
          (progn
            (setq data-range (urb:excel-variant-value data-range))
            (vl-catch-all-apply 'vlax-invoke-method
              (list data-range 'ClearContents))
            (urb:excel-release data-range)))
        (urb:excel-release column))))
  (setq new-address
    (strcat
      (urb:excel-column-name start-column) (itoa start-row) ":"
      (urb:excel-column-name (+ start-column column-count -1))
      (itoa (+ start-row new-data-count)))
    new-range
      (urb:excel-variant-value
        (vlax-get-property sheet 'Range new-address)))
  (vlax-invoke-method table 'Resize new-range)
  (if (< new-data-count old-data-count)
    (progn
      (setq tail-address
        (strcat
          (urb:excel-column-name start-column)
          (itoa (+ start-row new-data-count 1)) ":"
          (urb:excel-column-name (+ start-column column-count -1))
          (itoa (+ start-row old-data-count)))
        tail-range
          (urb:excel-variant-value
            (vlax-get-property sheet 'Range tail-address)))
      (vl-catch-all-apply 'vlax-invoke-method
        (list tail-range 'ClearContents))
      (urb:excel-release tail-range)))
  (setq index 0)
  (foreach header headers
    (setq values nil)
    (foreach row rows
      (setq values (cons (list (nth index row)) values)))
    (setq values (reverse values)
          column (urb:excel-table-column table header))
    (if column
      (progn
        (setq data-range
          (urb:excel-variant-value
            (vlax-get-property column 'DataBodyRange)))
        (vlax-put-property data-range 'Value2
          (urb:excel-matrix-variant values))
        (urb:excel-release data-range)
        (urb:excel-release column)))
    (setq index (1+ index)))
  (urb:excel-format-quantity-column table)
  (urb:excel-format-date-column table)
  (urb:excel-restore-extra-columns table matrix extra-state)
  (urb:excel-release new-range)
  (urb:excel-release table-range)
  T
      ))
  )
)

(defun urb:excel-format-new-general-table
  (application sheet table
   / table-range header columns column index count width window header-name
   column-range data-range table-rows)
  (setq *urb-excel-stage* "formato de la tabla general")
  (setq table-range
          (urb:excel-variant-value
            (vlax-get-property table 'Range))
        header
          (urb:excel-variant-value
            (vlax-get-property table 'HeaderRowRange))
        columns
          (urb:excel-variant-value
            (vlax-get-property table-range 'Columns)))
  (vlax-put-property header 'WrapText :vlax-true)
  (vlax-put-property header 'HorizontalAlignment -4108)
  (vlax-put-property header 'VerticalAlignment -4108)
  (vlax-put-property header 'RowHeight 32.0)
  (vl-catch-all-apply 'vlax-invoke-method (list columns 'AutoFit))
  (setq count (vlax-get-property columns 'Count)
        index 1)
  (repeat count
    (setq column (urb:excel-item columns index))
    (if column
      (progn
        (setq width
          (urb:excel-variant-value
            (vlax-get-property column 'ColumnWidth)))
        (if (> width 42.0) (vlax-put-property column 'ColumnWidth 42.0))
        (if (< width 9.0) (vlax-put-property column 'ColumnWidth 9.0))
        (urb:excel-release column)))
    (setq index (1+ index)))
  (foreach header-name '("ID_REGISTRO" "OBSERVACION" "ACCION")
    (setq column (urb:excel-table-column table header-name))
    (if column
      (progn
        (setq column-range
          (urb:excel-variant-value
            (vlax-get-property column 'Range)))
        (vlax-put-property column-range 'ColumnWidth 42.0)
        (if (member header-name '("OBSERVACION" "ACCION"))
          (progn
            (setq data-range
              (urb:excel-variant-value
                (vlax-get-property column 'DataBodyRange)))
            (vlax-put-property data-range 'WrapText :vlax-true)
            (urb:excel-release data-range)))
        (urb:excel-release column-range)
        (urb:excel-release column))))
  (setq table-rows
    (urb:excel-variant-value
      (vlax-get-property table-range 'Rows)))
  (vl-catch-all-apply 'vlax-invoke-method (list table-rows 'AutoFit))
  (urb:excel-release table-rows)
  (urb:excel-format-quantity-column table)
  (urb:excel-format-date-column table)
  (vlax-invoke-method sheet 'Activate)
  (setq window
    (vl-catch-all-apply 'vlax-get-property (list application 'ActiveWindow)))
  (if (not (vl-catch-all-error-p window))
    (progn
      (setq window (urb:excel-variant-value window))
      (vlax-put-property window 'SplitRow 1)
      (vlax-put-property window 'FreezePanes :vlax-true)
      (vlax-put-property window 'DisplayGridlines :vlax-false)
      (urb:excel-release window)))
  (urb:excel-release columns)
  (urb:excel-release header)
  (urb:excel-release table-range)
  nil
)

(defun urb:excel-prepare-general-table
  (application sheets matrix / found table sheet sheet-info created updated)
  (setq *urb-excel-stage* "busqueda de tabla general existente")
  (setq found (urb:excel-find-table sheets *urb-excel-general-table*))
  (if found
    (progn
      (setq table (car found)
            sheet (cadr found)
            updated (urb:excel-update-general-table sheet table matrix))
      (if updated
        (list table sheet nil)
        (progn
          (urb:excel-release table)
          (urb:excel-release sheet)
          nil)))
    (progn
      (setq *urb-excel-stage* "obtencion de la hoja de cantidades")
      (setq sheet-info
        (urb:excel-get-or-create-sheet sheets *urb-excel-general-sheet*))
      (cond
        ((null sheet-info)
          (urb:excel-fail
            "No fue posible obtener la hoja CANTIDADES_URBANISMO."))
        (T
          (setq sheet (car sheet-info)
                created (cadr sheet-info))
          (setq *urb-excel-stage* "validacion de la hoja de cantidades")
          (if (and (not created) (not (urb:excel-sheet-blank-p sheet)))
            (progn
              (urb:excel-fail
                (strcat "La hoja " *urb-excel-general-sheet*
                  " ya contiene datos pero no la tabla "
                  *urb-excel-general-table*
                  ". Cambie el nombre de esa hoja o dejela vacia."))
              (urb:excel-release sheet)
              nil)
            (progn
              (setq *urb-excel-stage* "creacion de la tabla general")
              (setq table (urb:excel-create-general-table sheet matrix))
              (if table
                (progn
                  (urb:excel-format-new-general-table
                    application sheet table)
                  (list table sheet created))
                (progn
                  (urb:excel-release sheet)
                  nil))))))))
)

(defun urb:excel-delete-extra-new-sheets (sheets / count index sheet)
  (setq count (vlax-get-property sheets 'Count)
        index count)
  (while (> index 1)
    (setq sheet (urb:excel-item sheets index))
    (if sheet
      (progn
        (vlax-invoke-method sheet 'Delete)
        (urb:excel-release sheet)))
    (setq index (1- index)))
  nil
)

(defun urb:excel-backup-path (filename / directory base extension name)
  (setq directory (vl-filename-directory filename)
        base (vl-filename-base filename)
        extension (urb:safe-string (vl-filename-extension filename) ".xlsx")
        name
          (strcat base "_backup_" (urb:excel-file-timestamp) "_"
            (itoa (getvar "MILLISECS")) extension))
  (if directory (urb:join-path directory name) name)
)

(defun urb:excel-create-backup (filename / backup copied)
  (setq backup (urb:excel-backup-path filename)
        copied (vl-catch-all-apply 'vl-file-copy (list filename backup)))
  (if (or (vl-catch-all-error-p copied) (null copied)) nil backup)
)

(defun urb:excel-linked-path (/ value)
  (setq value (urb:safe-string (urb:config-read *urb-excel-link-key*) ""))
  (vl-string-trim " \t\r\n" value)
)

(defun urb:excel-save-linked-path (filename)
  (urb:config-write *urb-excel-link-key* filename)
)

(defun urb:excel-supported-master-p (filename / extension)
  (setq extension
    (strcase (urb:safe-string (vl-filename-extension filename) "")))
  (if (member extension '(".XLSX" ".XLSM")) T nil)
)

(defun urb:excel-calculation-ready-p (application / result state)
  (setq result
    (vl-catch-all-apply 'vlax-get-property
      (list application 'CalculationState)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq state (urb:excel-variant-value result))
      (= state 0)))
)

(defun urb:write-general-excel
  (filename linked
   / collected records controls matrix backup app-result application
   workbooks workbook-result workbook sheets first-sheet prepared table sheet
   read-only refresh-result wait-result refresh-ok refresh-message save-result
   *error*)
  (defun *error* (message)
    (if workbook
      (vl-catch-all-apply 'vlax-invoke-method
        (list workbook 'Close :vlax-false)))
    (if application
      (vl-catch-all-apply 'vlax-invoke-method (list application 'Quit)))
    (urb:excel-release table)
    (urb:excel-release sheet)
    (urb:excel-release sheets)
    (urb:excel-release workbook)
    (urb:excel-release workbooks)
    (urb:excel-release application)
    (if (and message
             (not (member message '("Function cancelled" "quit / exit abort"))))
      (prompt (strcat "\nERROR AL ACTUALIZAR EXCEL: " message)))
    nil)
  (setq *urb-excel-last-error* nil
        *urb-excel-stage* "recoleccion de cantidades"
        collected (urb:q-collect-all)
        records (nth 0 collected)
        controls (nth 1 collected)
        matrix (urb:q-general-matrix records controls))
  (if records (urb:q-preflight-report records controls))
  (cond
    ((null records)
      (prompt "\nNo se encontraron cantidades cuantificables en el dibujo.")
      nil)
    ((and linked (not (findfile filename)))
      (prompt (strcat "\nNo se encontro el Excel vinculado: " filename))
      nil)
    ((and linked (null (setq backup (urb:excel-create-backup filename))))
      (prompt
        "\nNo fue posible crear el respaldo. El Excel no fue modificado.")
      nil)
    (T
      (setq app-result
        (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
      (if (vl-catch-all-error-p app-result)
        (progn
          (prompt
            (strcat "\nNo fue posible iniciar Microsoft Excel: "
              (vl-catch-all-error-message app-result)))
          nil)
        (progn
          (setq application app-result)
          (vlax-put-property application 'Visible :vlax-false)
          (vlax-put-property application 'DisplayAlerts :vlax-false)
          (vlax-put-property application 'ScreenUpdating :vlax-false)
          (vlax-put-property application 'DecimalSeparator ",")
          (vlax-put-property application 'ThousandsSeparator ".")
          (vlax-put-property application 'UseSystemSeparators :vlax-false)
          (setq workbooks (vlax-get-property application 'Workbooks)
                workbook-result
                  (if linked
                    (vl-catch-all-apply 'vlax-invoke-method
                      (list workbooks 'Open filename))
                    (vl-catch-all-apply 'vlax-invoke-method
                      (list workbooks 'Add))))
          (if (vl-catch-all-error-p workbook-result)
            (*error* (vl-catch-all-error-message workbook-result))
            (progn
              (setq workbook workbook-result
                    read-only (vlax-get-property workbook 'ReadOnly))
              (if (and linked (= read-only :vlax-true))
                (*error*
                  "El Excel esta abierto o bloqueado y solo se pudo abrir en modo lectura. Cierrelo y vuelva a intentar.")
                (progn
                  (setq sheets (vlax-get-property workbook 'Worksheets))
                  (if (not linked)
                    (progn
                      (urb:excel-delete-extra-new-sheets sheets)
                      (setq first-sheet (urb:excel-item sheets 1))
                      (vlax-put-property first-sheet 'Name
                        *urb-excel-general-sheet*)
                      (urb:excel-release first-sheet)))
                  (setq *urb-excel-stage* "preparacion de la tabla general")
                  (setq prepared
                    (urb:excel-prepare-general-table
                      application sheets matrix))
                  (if (null prepared)
                    (*error*
                      (urb:safe-string *urb-excel-last-error*
                        "No fue posible preparar la tabla general."))
                    (progn
                  (setq table (nth 0 prepared)
                        sheet (nth 1 prepared))
                  (vlax-invoke-method sheet 'Activate)
                  (setq refresh-ok T refresh-message "")
                  (if linked
                    (progn
                      (setq refresh-result
                        (vl-catch-all-apply 'vlax-invoke-method
                          (list workbook 'RefreshAll)))
                      (if (vl-catch-all-error-p refresh-result)
                        (setq refresh-ok nil
                              refresh-message
                                (vl-catch-all-error-message refresh-result))
                        (progn
                          (setq wait-result
                            (vl-catch-all-apply 'vlax-invoke-method
                              (list application 'CalculateUntilAsyncQueriesDone)))
                           (if (vl-catch-all-error-p wait-result)
                             (setq refresh-ok nil
                                   refresh-message
                                     (vl-catch-all-error-message wait-result)))
                           (vl-catch-all-apply 'vlax-invoke-method
                             (list application 'CalculateFull))
                           (if (and refresh-ok
                                    (not (urb:excel-calculation-ready-p application)))
                             (setq refresh-ok nil
                                   refresh-message
                                     "Excel no confirmo el estado de calculo finalizado."))))))
                  (setq *urb-excel-stage* "guardado del libro Excel")
                  (setq save-result
                    (if linked
                      (vl-catch-all-apply 'vlax-invoke-method
                        (list workbook 'Save))
                      (urb:excel-save-as-xlsx workbook filename)))
                  (if (vl-catch-all-error-p save-result)
                    (*error* (vl-catch-all-error-message save-result))
                    (progn
                      (vlax-put-property application 'ScreenUpdating :vlax-true)
                      (vlax-put-property application 'DisplayAlerts :vlax-true)
                      (vlax-put-property application 'Visible :vlax-true)
                      (urb:excel-release table)
                      (urb:excel-release sheet)
                      (urb:excel-release sheets)
                      (urb:excel-release workbook)
                      (urb:excel-release workbooks)
                      (urb:excel-release application)
                      (prompt
                        (strcat
                          "\nTabla " *urb-excel-general-table* " actualizada: "
                          filename
                          " | Cantidades: " (itoa (length records))
                          " | Controles: " (itoa (length controls))
                          (if linked (strcat " | Respaldo: " backup) "")
                          (if refresh-ok
                            " | Consultas actualizadas."
                            (strcat
                              " | ADVERTENCIA: datos guardados, pero Excel no confirmo la actualizacion de consultas: "
                              refresh-message))))
                      T)))))))))))))

(defun urb:export-quantities-excel (filename)
  (urb:write-general-excel filename nil)
)

(defun urb:update-linked-quantities-excel (filename)
  (urb:write-general-excel filename T)
)

(setq *urb-excel-network-headers*
  '("GRUPO" "BLOQUE" "HANDLE" "CAPA" "X" "Y" "ETAPA" "SUBETAPA"
    "ID" "CODIGO" "RED" "TIPO_RED" "DESDE" "HASTA" "POZO_INI"
    "POZO_FIN" "TIPO_EXTREMO_INI" "TIPO_EXTREMO_FIN"
    "HANDLE_EXTREMO_INI" "HANDLE_EXTREMO_FIN" "DIAMETRO" "MATERIAL"
    "LONGITUD" "LONGITUD_2D" "LONGITUD_3D" "MODO_LONGITUD"
    "PENDIENTE" "PENDIENTE_CALCULADA" "COTA_TN_INI" "COTA_TN_FIN"
    "SUPERFICIE_TN" "ESTADO_COTA_TN"
    "COTA_CLAVE_INI" "COTA_CLAVE_FIN" "PROFUNDIDAD_INI"
    "PROFUNDIDAD_FIN" "PROFUNDIDAD_MEDIA" "CONDUCTOR" "DUCTOS" "LIBRES"
    "DIAM_DUCTO" "MATERIAL_DUCTO" "TIPO_CAJA" "TIPO_LUMINARIA"
    "FUENTE_LED" "CIRCUITO" "CIRCUITO_AP" "PROFUNDIDAD" "ANCHO_ZANJA"
    "ESPESOR_CAMA" "ANCHO_REPOSICION" "EXCAVACION_M3" "CAMA_M3"
    "VOLUMEN_ELEMENTO_M3" "RELLENO_M3" "SOBRANTE_M3" "REPOSICION_M2"
    "METODO_CANTIDADES" "CONTROL_ESTADO" "CONTROL_MENSAJES"
    "TIPO_ACCESORIO" "SERIE" "CD" "PF"))

(defun urb:excel-export-command (/ filename result)
  (if (urb:confirm-meter-units)
    (progn
      (setq filename
        (getfiled "Guardar todas las cantidades en Excel"
          (strcat (getvar "DWGPREFIX") "cantidades_urbanismo.xlsx")
          "xlsx" 1))
      (if filename
        (progn
          (if (not (urb:ends-with (strcase filename) ".XLSX"))
            (setq filename (strcat filename ".xlsx")))
          (setq result
            (vl-catch-all-apply 'urb:export-quantities-excel (list filename)))
          (if (vl-catch-all-error-p result)
            (prompt
              (strcat "\nNo se completo la exportacion: "
                (vl-catch-all-error-message result)
                " | etapa: "
                (urb:safe-string *urb-excel-stage* "desconocida")))))
        (prompt "\nExportacion cancelada.")))
    (prompt "\nExportacion a Excel cancelada: confirme primero las unidades del dibujo."))
  (princ)
)

(defun urb:excel-link-command (/ current filename)
  (setq current (urb:excel-linked-path)
        filename
          (getfiled "Seleccionar Excel maestro existente"
            (if (> (strlen current) 0) current (getvar "DWGPREFIX"))
            "" 0))
  (if filename
    (if (urb:excel-supported-master-p filename)
      (progn
        (urb:excel-save-linked-path filename)
        (prompt
          (strcat "\nExcel maestro vinculado al dibujo: " filename
            "\nGuarde el DWG para conservar el vinculo."))
        (urb:excel-update-linked-command))
      (prompt
        "\nArchivo no compatible. Seleccione un libro .xlsx o .xlsm."))
    (prompt "\nVinculacion cancelada."))
  (princ)
)

(defun urb:excel-update-linked-command (/ filename result)
  (setq filename (urb:excel-linked-path))
  (cond
    ((= filename "")
      (prompt "\nEste dibujo aun no tiene un Excel maestro vinculado.")
      (urb:excel-link-command))
    ((not (findfile filename))
      (prompt
        (strcat "\nNo se encontro el Excel vinculado: " filename
          "\nUse URBANISMO > Cantidades > Vincular o cambiar Excel maestro para seleccionar su nueva ubicacion.")))
    ((not (urb:excel-supported-master-p filename))
      (prompt
        "\nEl vinculo no apunta a un libro .xlsx o .xlsm. Cambielo desde URBANISMO > Cantidades."))
    ((urb:confirm-meter-units)
      (setq result
        (vl-catch-all-apply 'urb:update-linked-quantities-excel
          (list filename)))
      (if (vl-catch-all-error-p result)
        (prompt
          (strcat "\nNo se completo la actualizacion: "
            (vl-catch-all-error-message result)))))
    (T
      (prompt
        "\nActualizacion de Excel cancelada: confirme primero las unidades del dibujo.")))
  (princ)
)

(defun urb:excel-unlink-command (/ filename response)
  (setq filename (urb:excel-linked-path))
  (if (= filename "")
    (prompt "\nEste dibujo no tiene un Excel maestro vinculado.")
    (progn
      (initget "Si No")
      (setq response
        (getkword
          (strcat "\nEliminar el vinculo con " filename "? [Si/No] <No>: ")))
      (if (= response "Si")
        (progn
          (urb:excel-save-linked-path "")
          (prompt "\nVinculo eliminado. Guarde el DWG para conservar el cambio."))
        (prompt "\nEl vinculo se conservo."))))
  (princ)
)

(defun urb:unique-enames (entities / result ename)
  (foreach ename entities
    (if (and (urb:valid-ename-p ename) (not (member ename result)))
      (setq result (cons ename result))))
  (reverse result)
)

(defun urb:quantity-scope-command
  (/ selection entities index ename choice value updated)
  (prompt
    "\nSeleccione elementos cuantificables para incluir o excluir del presupuesto: ")
  (setq selection (ssget))
  (if selection
    (progn
      (setq entities
        (urb:unique-enames
          (append
            (urb:selected-roads selection)
            (urb:selected-anden-parents selection)
            (urb:selected-prefabs selection)
            (urb:selected-green-zones selection)
            (urb:selected-mp-entities selection))))
      ;; Si la seleccion no pertenece a una categoria conocida, no se marca:
      ;; evita aplicar alcance por accidente a textos o geometria auxiliar.
      (if entities
        (progn
          (initget "Incluir Excluir")
          (setq choice
            (getkword
              "\nEstado de cantidades [Incluir/Excluir] <Excluir>: "))
          (if (null choice) (setq choice "Excluir"))
          (setq value (if (= choice "Incluir") "SI" "NO"))
          (foreach ename entities
            (urb:set-xdata-strings ename "URB_Q_SCOPE" (list value))
            (setq updated (1+ (if updated updated 0))))
          (prompt
            (strcat "\nAlcance actualizado: " (itoa updated)
              " elemento(s) quedaron "
              (if (= value "SI") "incluidos." "excluidos."))))
        (prompt
          "\nLa seleccion no contiene vias, andenes, zonas verdes, prefabricados ni elementos de red reconocidos.")))
    (prompt "\nNo se seleccionaron elementos."))
  (princ)
)

(defun urb:quantities-menu (/ action)
  (setq action
    (urb:simple-menu-dialog "urb_quantities"
      '(("table" "table") ("road" "road") ("road_audit" "road_audit")
        ("scope" "scope")
        ("excel" "excel") ("link_excel" "link_excel")
        ("update_excel" "update_excel")
        ("unlink_excel" "unlink_excel") ("network" "network"))))
  (cond
    ((or (null action) (= action "back")) "back")
    ((= action "table") (urb:insert-quantities-table-command))
    ((= action "road") (urb:road-quantity-command))
    ((= action "road_audit") (urb:road-audit-table-command))
    ((= action "scope") (urb:quantity-scope-command))
    ((= action "excel") (urb:excel-export-command))
    ((= action "link_excel") (urb:excel-link-command))
    ((= action "update_excel") (urb:excel-update-linked-command))
    ((= action "unlink_excel") (urb:excel-unlink-command))
    ((= action "network") (urb:export-networks-csv-command)))
  (if (or (null action) (= action "back")) "back" nil))

(defun urb:configuration-menu (/ action)
  ;; 2026-08-11: "Cargar perfiles base faltantes" y "Diagnosticar y migrar
  ;; redes" salieron del menu a pedido del usuario (las funciones siguen
  ;; existiendo por codigo); entro "Etapas y subetapas".
  (setq action
    (urb:simple-menu-dialog "urb_config"
      '(("road_profiles" "road_profiles")
        ("geometry_table" "geometry_table")
        ("etapas_config" "etapas_config")
        ("network_fill_ref" "network_fill_ref")
        ("recalc_tramos" "recalc_tramos")
        ("tramo_appearance" "tramo_appearance"))))
  (cond
    ((or (null action) (= action "back")) "back")
    ((= action "road_profiles") (urb:manage-road-profiles))
    ((= action "geometry_table") (urb:geometric-settings-command))
    ((= action "etapas_config") (urb:etapas-manager-command))
    ((= action "network_fill_ref")
      (mp:network-fill-reference-command))
    ((= action "recalc_tramos")
      (mp:recalc-tramos-earthworks-command))
    ((= action "tramo_appearance")
      (mp:tramo-appearance-command)))
  (if (or (null action) (= action "back")) "back" nil))

(defun c:URBANISMO (/ action done result)
  (vl-catch-all-apply 'urb:migrate-current-drawing nil)
  (while (not done)
    (setq action
      (urb:simple-menu-dialog "urb_main"
        '(("create" "create") ("edit" "edit") ("stages" "stages")
          ("quantities" "quantities") ("config" "config"))))
    (cond
      ((null action) (setq done T))
      ((= action "create")
        (if (not (urb:string-equal-p (urb:create-menu) "back"))
          (setq done T)))
      ((= action "edit") (c:EDITAR) (setq done T))
      ((= action "stages") (urb:batch-stage-command) (setq done T))
      ((= action "quantities")
        (if (not (urb:string-equal-p (urb:quantities-menu) "back"))
          (setq done T)))
      ((= action "config")
        (if (not (urb:string-equal-p (urb:configuration-menu) "back"))
          (setq done T)))))
  (princ))

(defun urb:prune-properties-v4230
  (/ ss i en obj atts base bname blocks bdef item victims defs rec allowed
   changed sync-result refs doc)
  (setq *urb-prune-stage* "inicio")
  (setq allowed
    '("ETIQUETA" "PENDIENTE_VIS" "ETAPA" "SUBETAPA" "RED" "TIPO_RED"
      "SERIE" "CIRCUITO" "CIRCUITO_AP" "DESDE" "HASTA" "POZO_INI"
      "POZO_FIN" "DIAMETRO" "MATERIAL" "PENDIENTE" "CONDUCTORES"
      "CONDUCTOR" "DUCTOS" "DIAM_DUCTO" "MATERIAL_DUCTO" "LIBRES"
      "PROFUNDIDAD" "COTA_TN_INI" "COTA_TN_FIN" "COTA_CLAVE_INI"
      "COTA_CLAVE_FIN" "LONGITUD" "ANCHO_ZANJA" "EXCAVACION_M3"
      "CAMA_M3" "VOLUMEN_ELEMENTO_M3" "RELLENO_M3" "SOBRANTE_M3"
      "REPOSICION_M2" "MEMORIAS"))
  (setq doc (vl-catch-all-apply 'urb:doc nil))
  (if (or (vl-catch-all-error-p doc) (/= (type doc) 'VLA-OBJECT))
    (setq doc nil blocks nil ss nil)
    (setq blocks (vla-get-Blocks doc)
          ss (ssget "_X" '((0 . "INSERT")))))
  (setq i 0)
  ;; Respaldar primero la totalidad de datos de cada tramo en XDATA.
  (if ss
    (repeat (sslength ss)
      (setq *urb-prune-stage* (strcat "lectura tramo indice " (itoa i)))
      (setq en (ssname ss i)
            obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
      (if (and obj (not (vl-catch-all-error-p obj))
               (urb:valid-vla-object-p obj))
        (progn
          (setq atts (vl-catch-all-apply 'mp:att-alist (list en))
                bname (vl-catch-all-apply 'vla-get-EffectiveName (list obj)))
          (if (or (vl-catch-all-error-p atts)
                  (vl-catch-all-error-p bname))
            (setq atts nil bname nil base nil)
            (setq base (mp:infer-base bname atts)))
          (if (and bname (mp:base-is-tramo base))
            (progn
              (setq *urb-prune-stage* (strcat "respaldo " bname))
              (mp:store-cant-data en atts)
              (setq refs (cons (list en bname base atts) refs))
              (if (not (assoc (strcase bname) defs))
                (setq defs
                  (cons (cons (strcase bname) (list bname base)) defs)))))))
      (setq i (1+ i))))
  ;; Limpiar definiciones compartidas y agregar solo el esquema publico.
  (foreach rec defs
    (setq bname (car (cdr rec)) base (cadr (cdr rec))
          bdef (vl-catch-all-apply 'vla-Item (list blocks bname))
          victims nil)
    (if (not (vl-catch-all-error-p bdef))
      (progn
        (setq *urb-prune-stage* (strcat "definicion " bname))
        (vlax-for item bdef
          (if (and (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
                   (not (member (strcase (vla-get-TagString item)) allowed)))
            (setq victims (cons item victims))))
        (foreach item victims
          (if (urb:safe-delete item) (setq changed (1+ (if changed changed 0)))))
        (vl-catch-all-apply 'mp:ensure-block-schema (list bname base T))
        (setq sync-result
          (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bname))))))
  ;; Restaurar valores publicos y mantener la copia tecnica completa.
  (foreach rec refs
    (setq en (car rec) atts (nth 3 rec))
    (setq *urb-prune-stage* "restauracion referencias")
    (if (entget en)
      (progn (mp:setatts en atts) (mp:store-cant-data en atts))))
  ;; Andenes: sus datos tecnicos ya estan en URB_ANDEN_BLOCK/MOV.
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_ANDEN_BLOCK")))) i 0)
  (if ss
    (repeat (sslength ss)
      (setq *urb-prune-stage* (strcat "anden indice " (itoa i)))
      (setq en (ssname ss i)
            obj (vl-catch-all-apply 'vlax-ename->vla-object (list en))
            victims nil bdef nil)
      (if (and obj (not (vl-catch-all-error-p obj))
               (urb:valid-vla-object-p obj))
        (setq bdef (vl-catch-all-apply 'vla-Item
          (list blocks (vla-get-EffectiveName obj)))))
      (if (and bdef (not (vl-catch-all-error-p bdef)))
        (progn
          (vlax-for item bdef
            (if (and (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
                     (member (strcase (vla-get-TagString item))
                       '("PERIMETRO_M" "ANDEN_ELEVACION" "ANDEN_SENTIDO"
                         "MATERIAL" "FORMATO_LOSETA" "ANDEN_SUPERFICIE"
                         "ANDEN_RASANTE" "ANDEN_PEND_LONG" "ANDEN_PEND_TRANS"
                         "ANDEN_PEND_TOTAL" "ANDEN_METODO" "ANDEN_MUESTRAS"
                         "ANDEN_COBERTURA" "ANDEN_VIA_ID" "ANDEN_VIA_NOMBRE")))
              (setq victims (cons item victims))))
          (foreach item victims
            (if (urb:safe-delete item) (setq changed (1+ (if changed changed 0)))))
          (vl-catch-all-apply 'vl-cmdf
            (list "_.ATTSYNC" "_N" (vla-get-EffectiveName obj)))))
      (setq i (1+ i))))
  (if changed changed 0))

(defun urb:migrate-current-drawing (/ ss i count hydro-rings road-properties road-upgrade pruned)
  ;; MIGRACIONES AUTOMATICAS de dibujos hechos con versiones anteriores.
  ;; Corre al cargar el .lsp y al abrir el menu URBANISMO, y es idempotente
  ;; (si no hay nada que migrar, no toca nada). Patron establecido a
  ;; pedido del usuario: cada cambio de capas/estructura futuro agrega
  ;; aqui su migracion para que lo ya creado se actualice solo.
  ;; 1) Tablas de verificacion de vias: de URB-VIA a URB-VIA-TABLA
  ;;    (para poder apagarlas sin ocultar la via).
  (if (setq ss (ssget "_X" '((0 . "ACAD_TABLE") (8 . "URB-VIA"))))
    (progn
      (urb:ensure-layer "URB-VIA-TABLA" 4 T)
      (setq i 0 count 0)
      (repeat (sslength ss)
        (if (not (vl-catch-all-error-p
                   (vl-catch-all-apply
                     '(lambda ()
                        (vla-put-Layer
                          (vlax-ename->vla-object (ssname ss i))
                          "URB-VIA-TABLA")))))
          (setq count (1+ count)))
        (setq i (1+ i)))
      (if (> count 0)
        (prompt
          (strcat "\nMigracion automatica: " (itoa count)
                  " tabla(s) de verificacion movida(s) a URB-VIA-TABLA.")))))
  ;; 2) (2026-08-11) La tabla de verificacion ya no vive pegada a la via:
  ;;    se despliega bajo demanda desde Cantidades donde el usuario la
  ;;    quiera. Se retiran las tablas generadas por versiones anteriores,
  ;;    tanto las sueltas como las EMPACADAS dentro de los bloques
  ;;    URB_VIA_* (ahi es donde realmente quedaron; las hechas a mano no
  ;;    se tocan).
  (setq count
    (urb:purge-road-block-tables))
  ;; barrido extra por CAPA (2026-08-11 v2): las tablas mas viejas no
  ;; tienen xdata (se creaban sin etiquetar); la capa URB-VIA-TABLA solo
  ;; la usan las tablas de verificacion generadas, asi que todo ACAD_TABLE
  ;; suelto en esa capa tambien se retira. Reporte del usuario: la
  ;; migracion anterior solo borro 1 de varias.
  (if (and nil (setq ss (ssget "_X" '((0 . "ACAD_TABLE") (8 . "URB-VIA-TABLA")))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (if (not (vl-catch-all-error-p
                   (vl-catch-all-apply
                     '(lambda ()
                        (vla-Delete (vlax-ename->vla-object (ssname ss i)))))))
          (setq count (1+ count)))
        (setq i (1+ i)))))
  (if (> count 0)
    (progn
      (vl-catch-all-apply
        '(lambda () (vla-Regen (urb:doc) 1)))
      (prompt
        (strcat "\nMigracion automatica: " (itoa count)
                " tabla(s) de verificacion retirada(s);"
                " despliegalas desde Cantidades cuando las necesites."))))
  ;; 3) Los pozos reales permanecen como bloques puntuales unicos y
  ;; compartibles. Se retiran de los bloques de tramo los circulos de
  ;; extremo que los hacian parecer duplicados.
  (setq hydro-rings
    (vl-catch-all-apply 'mp:repair-hydro-tramo-definitions nil))
  (if (and (numberp hydro-rings) (> hydro-rings 0))
    (progn
      (vla-Regen (urb:doc) 1)
      (prompt
        (strcat
          "\nMigracion automatica: " (itoa hydro-rings)
          " circulo(s) de extremo duplicado retirado(s) de tramos"
          " hidrosanitarios; los pozos unicos se conservaron."))))
  ;; 4) Propiedades compactas de vias existentes: conserva cantidades,
  ;; geometria y corte/relleno; retira los campos administrativos pedidos
  ;; y sustituye las frases contractuales por el nombre corto del material.
  (setq road-properties
    (vl-catch-all-apply 'urb:clean-existing-road-properties nil))
  (if (and (numberp road-properties) (> road-properties 0))
    (prompt
      (strcat
        "\nMigracion automatica: " (itoa road-properties)
        " propiedad(es) de via simplificada(s).")))
  (setq road-upgrade
    (vl-catch-all-apply 'urb:upgrade-existing-road-properties nil))
  (if (and (numberp road-upgrade) (> road-upgrade 0))
    (prompt
      (strcat "\nMigracion automatica: " (itoa road-upgrade)
        " ajuste(s) visual(es/de propiedades) aplicado(s) a vias.")))
  ;; 5) Una sola vez por dibujo: propiedades tecnicas de tramos/andenes se
  ;; respaldan en XDATA y se retiran de la paleta, conservando cantidades.
  (if (/= (urb:safe-string (urb:config-read "URB_MIGRATE_4230_PROPS") "") "OK")
    (progn
      (setq pruned (vl-catch-all-apply 'urb:prune-properties-v4230 nil))
      (if (not (vl-catch-all-error-p pruned))
        (progn
          (urb:config-write "URB_MIGRATE_4230_PROPS" "OK")
          (if (> pruned 0)
            (prompt
              (strcat "\nMigracion automatica: " (itoa pruned)
                " propiedad(es) tecnica(s) ocultada(s); datos respaldados.")))))))
  (princ))

(defun urb:remove-legacy-commands (/ command-symbol)
  ;; Al recargar el LSP, AutoCAD conserva en memoria las funciones C: que
  ;; desaparecieron del archivo. Se retiran expresamente. OJO (2026-08-11):
  ;; varios nombres viejos (c:VIA, c:ANDEN, c:PREFABRICADO, c:SUMIDERO,
  ;; c:LUMINARIA) SALIERON de esta lista porque volvieron a ser comandos
  ;; publicos oficiales -- son los puntos de enlace del RIBBON (ver bloque
  ;; "COMANDOS PUBLICOS DEL RIBBON" abajo).
  (foreach command-symbol
    '(c:CANTIDADES
      c:ACT_ETIQUETAS_CANTIDAD
      c:QREDES_CSV
      c:ACTUALIZAR
      c:MP_REPARAR_VISIBILIDAD
      c:MAIPORE_BLOQUES_REDES_ELECT
      c:PERFILES_BASE
      c:URBVERSION
      c:QVINCULAREXCEL
      c:QACTUALIZAREXCEL
      c:QDESVINCULAREXCEL
      c:TRAMO
      c:POZO_SANITARIO
      c:POZO_PLUVIAL
      c:CAMARA_ELECTRICA
      c:ACCESORIO_ACUEDUCTO)
    (vl-acad-undefun command-symbol))
  (princ))

;;; ============================================================
;;; COMANDOS PUBLICOS DEL RIBBON (2026-08-11)
;;; Cada boton de la pestana CANTIDADES dispara uno de estos. Son
;;; envoltorios de 1 linea: TODA la logica sigue en las funciones
;;; internas de siempre -- el ribbon depende del lsp, nunca al reves.
;;; Tambien sirven escritos a mano (VIA, ANDEN, QCUADRO...).
;;; ============================================================
;; Crear
(defun c:VIA () (urb:create-road) (princ))
(defun c:ANDEN () (urb:create-sidewalk-command) (princ))
(defun c:RAMPA () (urb:create-ramp-command) (princ))
(defun c:ZONAVERDE () (urb:create-green-zone-command) (princ))
(defun c:PREFABRICADO () (urb:create-precast-command) (princ))
;; Redes
(defun c:TSANITARIO () (urb:create-network-segment-direct "segment_sanitary") (princ))
(defun c:TPLUVIAL () (urb:create-network-segment-direct "segment_storm") (princ))
(defun c:TACUEDUCTO () (urb:create-network-segment-direct "segment_water") (princ))
(defun c:TMT () (urb:create-network-segment-direct "segment_mt") (princ))
(defun c:TBT () (urb:create-network-segment-direct "segment_bt") (princ))
(defun c:TAP () (urb:create-network-segment-direct "segment_ap") (princ))
(defun c:POZOSAN () (if (urb:confirm-meter-units) (urb:create-sanitary-manhole)) (princ))
(defun c:POZOPLU () (if (urb:confirm-meter-units) (urb:create-storm-manhole)) (princ))
(defun c:SUMIDERO () (if (urb:confirm-meter-units) (urb:create-inlet)) (princ))
(defun c:CAMARA () (if (urb:confirm-meter-units) (urb:create-electrical-chamber)) (princ))
(defun c:ACCESORIO () (if (urb:confirm-meter-units) (urb:create-water-accessory)) (princ))
(defun c:LUMINARIA () (if (urb:confirm-meter-units) (urb:create-luminaire)) (princ))
;; Editar
(defun c:ETAPAS () (urb:batch-stage-command) (princ))
;; Cantidades
(defun c:QCUADRO () (urb:insert-quantities-table-command) (princ))
(defun c:QMEMORIA () (urb:road-quantity-command) (princ))
(defun c:QVERIFICACION () (urb:road-audit-table-command) (princ))
(defun c:QALCANCE () (urb:quantity-scope-command) (princ))
(defun c:QCSV () (urb:export-networks-csv-command) (princ))
;; Excel
(defun c:QEXCEL () (urb:excel-export-command) (princ))
(defun c:QVINCULAR () (urb:excel-link-command) (princ))
(defun c:QACTUALIZAR () (urb:excel-update-linked-command) (princ))
(defun c:QDESVINCULAR () (urb:excel-unlink-command) (princ))
;; Configuracion
(defun c:PERFILES () (urb:manage-road-profiles) (princ))
(defun c:AJUSTES () (urb:configuration-menu) (princ))

;; Carga automatica de la pestana CANTIDADES del ribbon (cui parcial).
;; Busca primero la copia instalada por el bundle (existe en cualquier
;; maquina donde corrio INSTALAR.bat) y como respaldo el cui del repo via
;; findfile. Se carga por COM (MenuGroups.Load), que no necesita contexto
;; de comando -- funciona durante la carga automatica del autoloader.
(defun urb:ensure-ribbon (/ candidates path found result)
  (if (not (menugroup "CANTIDADES"))
    (progn
      ;; SIEMPRE el .cuix empaquetado (2026-08-11 v2): el convertidor de
      ;; .cui monoliticos es anterior al ribbon y descartaba los paneles
      ;; en silencio -- el .cui del repo es solo la FUENTE legible; lo que
      ;; se carga es el .cuix armado por armar_cuix.ps1.
      (setq candidates
        (list
          (strcat (urb:safe-string (getenv "APPDATA") "")
            "\\Autodesk\\ApplicationPlugins\\UrbanismoCantidades.bundle\\Contents\\cantidades.cuix")
          (findfile "cantidades.cuix")))
      (foreach path candidates
        (if (and path
                 (not (menugroup "CANTIDADES"))
                 (setq found (findfile path)))
          (progn
            (setq result
              (vl-catch-all-apply
                '(lambda ()
                   (vla-Load
                     (vla-get-MenuGroups (vlax-get-acad-object))
                     found))))
            (if (vl-catch-all-error-p result)
              (prompt
                (strcat "\nAviso: no se pudo cargar el ribbon CANTIDADES: "
                        (vl-catch-all-error-message result)))))))))
  (princ))

;; Auto-reparacion de TRUSTEDPATHS (2026-08-11): AutoCAD reescribe esa
;; variable al cerrar con lo que tenia en memoria, asi que agregarla por
;; registro desde afuera se pierde si habia una sesion abierta. Aqui, ya
;; ADENTRO de AutoCAD, se agrega la carpeta del bundle a la variable viva
;; (persiste al cerrar). Tras el primer "Always Load"/"Load Once" del
;; usuario, ninguna sesion futura vuelve a preguntar.
(defun urb:ensure-trusted-path (/ target current)
  (setq target
    (strcat (urb:safe-string (getenv "APPDATA") "")
      "\\Autodesk\\ApplicationPlugins\\UrbanismoCantidades.bundle\\Contents"))
  (setq current (urb:safe-string (getvar "TRUSTEDPATHS") ""))
  (if (not (vl-string-search (strcase target) (strcase current)))
    (setvar "TRUSTEDPATHS"
      (if (= current "") target (strcat current ";" target))))
  (princ))

;; Rescate manual de la pestana (2026-08-11 v3): CUILOAD por comando SI
;; fusiona la pestana del parcial a la cinta (a diferencia de
;; MenuGroups.Load por COM, que solo registra el menugroup). Se usa solo
;; si la pestana no aparecio tras reiniciar: escribir CARGARCINTA.
(defun c:CARGARCINTA (/ path old-filedia)
  (setq path
    (strcat (urb:safe-string (getenv "APPDATA") "")
      "\\Autodesk\\ApplicationPlugins\\UrbanismoCantidades.bundle\\Contents\\cantidades.cuix"))
  (if (not (findfile path))
    (prompt "\nNo se encontro cantidades.cuix en el bundle instalado; corra INSTALAR.bat.")
    (progn
      (setq old-filedia (getvar "FILEDIA"))
      (setvar "FILEDIA" 0)
      (if (menugroup "CANTIDADES")
        (command "_.CUIUNLOAD" "CANTIDADES"))
      (command "_.CUILOAD" path)
      (setvar "FILEDIA" old-filedia)
      (prompt
        (strcat "\nPestana CANTIDADES cargada."
          " Si no se ve: clic derecho sobre la cinta > Show Tabs > CANTIDADES."))))
  (princ))

(urb:remove-legacy-commands)
(mp:install-network-erase-reactor)
(vl-catch-all-apply 'urb:ensure-trusted-path nil)
(vl-catch-all-apply 'urb:refresh-etapas-catalog nil)
(vl-catch-all-apply 'mp:load-tramo-appearance-settings nil)
(vl-catch-all-apply 'urb:load-geometric-settings nil)
(vl-catch-all-apply 'urb:migrate-current-drawing nil)
(vl-catch-all-apply 'urb:install-memory-property-reactors nil)
;; OJO (2026-08-11 v3): urb:ensure-ribbon YA NO se llama automaticamente.
;; Si el lsp carga el cuix por COM ANTES que el Autoloader, el Autoloader
;; encuentra el menugroup ya cargado, no lo procesa, y la pestana queda
;; SIN fusionar a la cinta (auto-sabotaje detectado en la prueba en vivo).
;; En sesiones frescas el Autoloader (PackageContents) carga el cuix y
;; fusiona la pestana solo; si algo falla, el usuario tiene CARGARCINTA.

(princ
  (strcat
    "\nUrbanismo " *urb-version* " listo."
    " Comandos: URBANISMO, EDITAR y la pestana CANTIDADES del ribbon."))
(princ)
