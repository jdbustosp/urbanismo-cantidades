;; Vertices reales de los bloques de rampa/paso. SOLO LECTURA sobre copia.
(setq *o* (open (strcat (getenv "URB_TEST_LAB") "/vertices.txt") "w"))
(defun w (s) (write-line s *o*) (princ s) (princ "\n"))

(defun dump-poly (en pref / ed pts cerr capa)
  (setq ed (entget en) pts nil)
  (foreach it ed
    (if (= (car it) 10)
      (setq pts (cons (list (cadr it) (caddr it)) pts))))
  (setq pts (reverse pts))
  (setq cerr (if (= 1 (logand 1 (cdr (assoc 70 ed)))) "cerrada" "abierta"))
  (setq capa (cdr (assoc 8 ed)))
  (w (strcat pref "LWPOLYLINE [" capa "] " cerr " " (itoa (length pts)) " vert:"))
  (setq s "")
  (foreach p pts
    (setq s (strcat s "(" (rtos (car p) 2 3) "," (rtos (cadr p) 2 3) ") ")))
  (w (strcat pref "  " s)))

(defun dump-block (nombre pref nivel / bd en ed t0)
  (setq bd (tblsearch "BLOCK" nombre))
  (if (null bd)
    (w (strcat pref "(no existe " nombre ")"))
    (progn
      (setq en (cdr (assoc -2 bd)))
      (while en
        (setq ed (entget en) t0 (cdr (assoc 0 ed)))
        (cond
          ((= t0 "LWPOLYLINE") (dump-poly en pref))
          ((= t0 "LINE")
            (w (strcat pref "LINE [" (cdr (assoc 8 ed)) "] "
                 (rtos (car (cdr (assoc 10 ed))) 2 3) ","
                 (rtos (cadr (cdr (assoc 10 ed))) 2 3) " -> "
                 (rtos (car (cdr (assoc 11 ed))) 2 3) ","
                 (rtos (cadr (cdr (assoc 11 ed))) 2 3))))
          ((= t0 "CIRCLE")
            (w (strcat pref "CIRCLE r=" (rtos (cdr (assoc 40 ed)) 2 4) " en "
                 (rtos (car (cdr (assoc 10 ed))) 2 3) ","
                 (rtos (cadr (cdr (assoc 10 ed))) 2 3))))
          ((= t0 "HATCH")
            (w (strcat pref "HATCH [" (cdr (assoc 8 ed)) "] patron "
                 (urb-safe (cdr (assoc 2 ed))) " esc "
                 (rtos (urb-num (cdr (assoc 41 ed))) 2 3))))
          ((= t0 "INSERT")
            (w (strcat pref "INSERT " (cdr (assoc 2 ed)) " en "
                 (rtos (car (cdr (assoc 10 ed))) 2 3) ","
                 (rtos (cadr (cdr (assoc 10 ed))) 2 3)
                 " rot " (rtos (/ (* 180.0 (urb-num (cdr (assoc 50 ed)))) pi) 2 1)))
            (if (< nivel 2)
              (dump-block (cdr (assoc 2 ed)) (strcat pref "    ") (1+ nivel)))))
        (setq en (entnext en))))))

(defun urb-safe (v) (if (= (type v) 'STR) v "?"))
(defun urb-num (v) (if (numberp v) v 0.0))

(foreach nombre (list "B-RAMPA VEHICULAR" "B CEBRA" "B-Bolardo"
                      "B-TABLETA 20X20 TÁCTIL ALERTA" "B-Bordillo A80")
  (w "")
  (w (strcat "########## " nombre " ##########"))
  (dump-block nombre "  " 0))

(w "DONE")
(close *o*)
