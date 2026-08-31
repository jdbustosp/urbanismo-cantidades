;;; CRUCEPPTO: cruce EN SECO actividades del modelo vs presupuesto del
;;; libro vinculado. Genera todas las filas CAD, hace el match contra el
;;; vocabulario del libro (equivalencias guardadas + cascada) y reporta
;;; que quedo HUERFANO (sin actividad del ppto). NO escribe en el libro.
(defun c:CRUCEPPTO (/ f path attach app wb propia lo vocab raw final dwg
                      n-total n-ok item calc)
  (vl-load-com)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/cruce_ppto.txt" "w"))
  (setq path (urb:ppto-config-read))
  (write-line (strcat "libro: " path) f)
  (if (or (= path "") (null (findfile path)))
    (progn (write-line "SIN LIBRO CONFIGURADO O NO EXISTE" f) (close f) (exit)))
  (setq attach (urb:ppto-attach-excel path)
        app (nth 0 attach) wb (nth 1 attach) propia (nth 2 attach))
  (if (null wb)
    (progn (write-line (strcat "NO SE PUDO ABRIR: " (vl-princ-to-string (nth 2 attach))) f)
           (close f) (exit)))
  (setq lo (urb:ppto-memorias-table wb))
  (setq vocab (if lo (urb:ppto-read-vocab wb) nil))
  (if (null vocab)
    (progn (write-line "SIN VOCABULARIO/TABLA EN EL LIBRO" f))
    (progn
      (setq *urb-ppto-vocab* vocab *urb-ppto-wb* wb
            *urb-ppto-param* (urb:ppto-param-read wb)
            *urb-ppto-param-dirty* nil)
      (setq raw
        (append
          (urb:ppto-rows-vias) (urb:ppto-rows-andenes)
          (urb:ppto-rows-prefabs) (urb:ppto-rows-rampas)
          (urb:ppto-rows-tramos) (urb:ppto-rows-puntos)
          (urb:ppto-rows-mobiliario) (urb:ppto-rows-senderos)
          (urb:ppto-rows-bioswale)))
      (setq dwg (vl-filename-base (getvar "DWGNAME")))
      (setq *urb-ppto-equiv* (urb:ppto-equiv-read wb))
      (setq final (urb:ppto-match-all raw vocab dwg))
      (write-line (strcat "actividades del presupuesto (vocab): "
        (itoa (length vocab))) f)
      (write-line (strcat "filas generadas del modelo: " (itoa (length raw))) f)
      (write-line (strcat "filas cruzadas OK: " (itoa (length final))) f)
      (write-line (strcat "HUERFANAS (sin actividad en el ppto): "
        (itoa (length *urb-ppto-huerfanas*))) f)
      (foreach item *urb-ppto-huerfanas*
        (write-line (strcat "  " (vl-princ-to-string item)) f))))
  ;; cerrar SIN guardar
  (vl-catch-all-apply '(lambda () (vlax-invoke-method wb 'Close :vlax-false)))
  (if propia
    (vl-catch-all-apply '(lambda () (vlax-invoke-method app 'Quit))))
  (write-line "FIN-CRUCEPPTO" f)
  (close f)
  (princ))
(princ "\nCRUCEPPTO listo")(princ)
