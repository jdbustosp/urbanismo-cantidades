;;; perf5 - cual ruta corre el escritor y cuanto tarda cada una
(defun p5:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/perf0903/perf5.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))
(defun c:PERF5 (/ t0 path attach app wb propia lo vocab raw dwg final res)
  (vl-load-com)
  (setq path (urb:ppto-config-read))
  (setq attach (urb:ppto-attach-excel path)
        app (nth 0 attach) wb (nth 1 attach) propia (nth 2 attach))
  (if (null wb) (progn (p5:log "NO ABRIO") (exit)))
  (setq lo (urb:ppto-memorias-table wb))
  (setq vocab (urb:ppto-read-vocab wb))
  (setq *urb-ppto-vocab* vocab *urb-ppto-wb* wb
        *urb-ppto-param* (urb:ppto-param-read wb)
        *urb-ppto-param-dirty* nil
        *urb-ppto-equiv* (urb:ppto-equiv-read wb))
  (setq raw (append (urb:ppto-rows-vias) (urb:ppto-rows-andenes)
    (urb:ppto-rows-prefabs) (urb:ppto-rows-rampas) (urb:ppto-rows-tramos)
    (urb:ppto-rows-puntos) (urb:ppto-rows-mobiliario)
    (urb:ppto-rows-senderos) (urb:ppto-rows-bioswale)))
  (setq dwg (vl-filename-base (getvar "DWGNAME")))
  (setq final (urb:ppto-match-all raw vocab dwg))
  (p5:log (strcat "filas listas: " (itoa (length final))))
  ;; calculo en manual como hace el export real
  (vl-catch-all-apply '(lambda () (vlax-put-property
    (urb:ppto-obj (vlax-get-property wb 'Application)) 'Calculation -4135)))
  ;; RUTA RAPIDA directa, con el error VISIBLE
  (setq t0 (getvar "MILLISECS"))
  (setq res (vl-catch-all-apply 'urb:ppto-write-rows-fast (list lo final dwg)))
  (if (vl-catch-all-error-p res)
    (p5:log (strcat "RUTA RAPIDA FALLO: " (vl-catch-all-error-message res)))
    (p5:log (strcat "RUTA RAPIDA OK: borradas " (itoa res) " en "
      (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 1) " s")))
  ;; agregada + guardar
  (setq t0 (getvar "MILLISECS"))
  (setq res (vl-catch-all-apply 'urb:ppto-write-agg (list wb final)))
  (if (vl-catch-all-error-p res)
    (p5:log (strcat "AGG FALLO: " (vl-catch-all-error-message res)))
    (p5:log (strcat "AGG OK (" (vl-princ-to-string res) ") en "
      (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 1) " s")))
  (vl-catch-all-apply '(lambda () (vlax-invoke-method
    (urb:ppto-obj (vlax-get-property wb 'Application)) 'CalculateFull)))
  (setq t0 (getvar "MILLISECS"))
  (vl-catch-all-apply '(lambda () (vlax-invoke-method wb 'Save)))
  (p5:log (strcat "SAVE en " (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 1) " s"))
  (vl-catch-all-apply '(lambda () (vlax-invoke-method wb 'Close :vlax-false)))
  (if propia (vl-catch-all-apply '(lambda () (vlax-invoke-method app 'Quit))))
  (p5:log "FIN-PERF5")
  (princ))
(princ "\nperf5 listo")(princ)
