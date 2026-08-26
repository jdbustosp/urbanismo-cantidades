;; CRUCE ELECTRICAS vs PRESUPUESTO REAL (2026-08-26, pedido del usuario:
;; "verifica que todas las actividades se esten cruzando con presupuesto
;; las de alumbrado y media tension"). Corre sobre el master (copia):
;; genera las filas CAD de tramos+puntos, filtra ELECTRICA-*, corre el
;; match real contra el vocabulario del libro (mismas funciones del
;; comando Presupuesto) y reporta concepto por concepto su vinculo.
;; SOLO LECTURA del libro (no exporta nada).
(vl-load-com)
(defun cx:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/cruce_elec.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c:CRUCEELEC (/ path attach app wb propia vocab raw elec dwg m
                    tot okc pend r)
  (cx:log "== CRUCE ELECTRICAS vs PRESUPUESTO ==")
  ;; libro CORRECTO indicado por el usuario 2026-08-26
  (setq path "D:\\Drive\\Mi unidad\\TRABAJO\\COLSUBSIDIO\\URBANISMO MAIPORE\\urbanismo maipore.xlsx")
  (if (null (findfile path)) (setq path (urb:ppto-config-read)))
  (cx:log (strcat "Libro: " (if path path "NINGUNO")))
  (if (or (null path) (= path "") (null (findfile path)))
    (cx:log "ERROR: libro no encontrado -- abortado")
    (progn
      (setq attach (urb:ppto-attach-excel path)
            app (nth 0 attach) wb (nth 1 attach) propia (nth 2 attach))
      (if (null wb)
        (cx:log (strcat "ERROR abriendo Excel: "
          (urb:safe-string (nth 2 attach) "?")))
        (progn
          (setq vocab (urb:ppto-read-vocab wb))
          (cx:log (strcat "Vocabulario del libro: "
            (itoa (length vocab)) " actividades"))
          ;; volcado de las actividades del libro relevantes a electricas,
          ;; para calibrar la redaccion exacta de nuestras filas
          (cx:log "---- ACTIVIDADES DEL LIBRO (electricas) ----")
          (foreach r vocab
            (setq m (strcase (vl-princ-to-string r)))
            (if (or (vl-string-search "MEDIA TENSION" m)
                    (vl-string-search "ALUMBRADO" m)
                    (vl-string-search "OBRAS ELECTRICAS" m)
                    (vl-string-search "ELECTRICA" m))
              (cx:log (strcat "  LIBRO: " (vl-princ-to-string r)))))
          (cx:log "---- FIN ACTIVIDADES ----")
          (setq *urb-ppto-vocab* vocab
                *urb-ppto-wb* wb
                *urb-ppto-param* (urb:ppto-param-read wb)
                *urb-ppto-equiv* (urb:ppto-equiv-read wb))
          (setq raw (append (urb:ppto-rows-tramos) (urb:ppto-rows-puntos)))
          (setq elec
            (vl-remove-if-not
              '(lambda (r) (wcmatch (urb:safe-string (nth 0 r) "") "ELECTRICA*"))
              raw))
          (cx:log (strcat "Filas CAD electricas: " (itoa (length elec))
            " (de " (itoa (length raw)) " totales)"))
          (setq dwg (vl-filename-base (getvar "DWGNAME")))
          (urb:ppto-match-all elec vocab dwg)
          ;; volcado: (clave red concepto um origen espec cantidad)
          (setq tot 0 okc 0 pend 0)
          (foreach m (reverse *urb-ppto-matches*)
            (setq tot (1+ tot))
            (if (= (urb:safe-string (nth 4 m) "") "PENDIENTE")
              (setq pend (1+ pend))
              (setq okc (1+ okc)))
            (cx:log (strcat
              (urb:safe-string (nth 1 m) "?") " | "
              (urb:safe-string (nth 2 m) "?") " | "
              (urb:safe-string (nth 3 m) "?") " | "
              (urb:safe-string (nth 4 m) "?") " | -> "
              (urb:safe-string (nth 5 m) "(sin actividad)")
              " | cant=" (rtos (nth 6 m) 2 2))))
          (cx:log (strcat "RESUMEN: " (itoa tot) " conceptos electricos, "
            (itoa okc) " vinculados, " (itoa pend) " PENDIENTES"))
          (if (> (length *urb-ppto-item-errs*) 0)
            (progn
              (cx:log (strcat "ERRORES de match: "
                (itoa (length *urb-ppto-item-errs*))))
              (foreach r *urb-ppto-item-errs*
                (cx:log (strcat "  ERR " (urb:safe-string (nth 1 r) "?")
                  ": " (urb:safe-string (nth 2 r) "?"))))))
          ;; cierre limpio del Excel propio (sin guardar nada)
          (if propia
            (progn
              (vl-catch-all-apply
                '(lambda () (vlax-invoke-method wb 'Close :vlax-false)))
              (vl-catch-all-apply '(lambda () (vlax-invoke-method app 'Quit)))
              (vlax-release-object wb)
              (vlax-release-object app)))))))
  (cx:log "CRUCE-TERMINADO")
  (princ))
(c:CRUCEELEC)
