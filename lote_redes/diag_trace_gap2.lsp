;; TRAZA v3 (2026-08-26): SIN wrapper -- solo reconstruye un tramo y
;; verifica, confiando en el diagnostico INLINE ya insertado dentro de
;; mp:make-cant-tramo-block (diag_inline.txt) para eliminar cualquier
;; interferencia del mecanismo de wrapping externo.
(vl-load-com)
(setq pf (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/diag_trace_gap2.txt" "w"))
(defun tg (m) (write-line m pf) (princ (strcat "\n" m)))

(tg (strcat "Version motor: " (if (boundp '*urb-version*) *urb-version* "?")))

(setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_MT_*"))))
(setq n (if ss (sslength ss) 0) i 0 e nil)
(while (and (< i n) (null e))
  (setq cand (ssname ss i))
  (setq atts (mp:att-alist cand))
  (if (and (cdr (assoc "POZO_INI" atts)) (cdr (assoc "POZO_FIN" atts)))
    (setq e cand))
  (setq i (1+ i)))
(if e
  (progn
    (setq atts (mp:att-alist e))
    (setq pini (cdr (assoc "POZO_INI" atts)) pfin (cdr (assoc "POZO_FIN" atts)))
    (tg (strcat "Tramo de prueba: " pini "-" pfin " handle=" (cdr (assoc 5 (entget e)))))
    (setq ss2 (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CAMARA_CS276,MP_PUNTO_CAMARA_CS280"))))
    (setq n2 (sslength ss2) j 0 p1 nil p2 nil)
    (while (< j n2)
      (setq e2 (ssname ss2 j))
      (setq a2 (mp:att-alist e2))
      (setq id2 (cdr (assoc "ID" a2)))
      (cond
        ((= id2 pini) (setq p1 (cdr (assoc 10 (entget e2)))))
        ((= id2 pfin) (setq p2 (cdr (assoc 10 (entget e2))))))
      (setq j (1+ j)))
    (if (and p1 p2)
      (progn
        (tg (strcat "p1=" (rtos (car p1) 2 3) "," (rtos (cadr p1) 2 3)
          " p2=" (rtos (car p2) 2 3) "," (rtos (cadr p2) 2 3)))
        (entdel e)
        (setq resu (vl-catch-all-apply 'mp:insert-cant-tramo
          (list "TRAMO_E_MT" (list (car p1) (cadr p1) 0.0)
            (list (car p2) (cadr p2) 0.0) atts)))
        (if (vl-catch-all-error-p resu)
          (tg (strcat "ERROR: " (vl-catch-all-error-message resu)))
          (progn
            (tg "Reconstruccion de prueba OK")
            (setq nb (cdr (assoc 2 (entget (entlast)))))
            (tg (strcat "Nombre de bloque creado: " nb))
            (setq blkrec (tblsearch "BLOCK" nb))
            (setq be (cdr (assoc -2 blkrec)) x0 nil x1 nil ncirc 0)
            (while be
              (setq bd (entget be))
              (cond
                ((= (cdr (assoc 0 bd)) "LWPOLYLINE")
                  (setq pts nil)
                  (foreach p bd (if (= (car p) 10) (setq pts (cons (cadr p) pts))))
                  (setq x0 (apply 'min pts) x1 (apply 'max pts)))
                ((= (cdr (assoc 0 bd)) "CIRCLE") (setq ncirc (1+ ncirc))))
              (setq be (entnext be)))
            (tg (strcat "VERIF geometria " nb ": x0=" (rtos x0 2 3)
              " x1=" (rtos x1 2 3) " circulos=" (itoa ncirc))))))
      (tg "No se encontraron ambas cajas")))
  (tg "No se encontro tramo de prueba con pozo_ini/fin"))
(tg "DIAGTRACE2-OK")
(close pf)
(princ)
