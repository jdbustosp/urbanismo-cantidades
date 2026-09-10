;; Composicion real de los bloques de rampa/paso del plano de detalles.
;; SOLO LECTURA sobre una copia.
(setq *o* (open (strcat (getenv "URB_TEST_LAB") "/bloques.txt") "w"))
(defun w (s) (write-line s *o*) (princ s) (princ "\n"))

(setq objetivos
  (list "B-RAMPA VEHICULAR" "B CEBRA"
        "B RAMPA T1 - 2.00MT - Andén 4.00MT"
        "B RAMPA T2 - 3.00MT - Separador"
        "B-Módulo Rampa 2.00MT - 4.00MT Andén"
        "B-TABLETA 20X20 TÁCTIL ALERTA" "B-TABLETA 20X20 TÁCTIL"
        "B-TABLETA 20X20 TONO 1" "B-TABLETA 20X20 TONO 2"
        "B-TABLETA 20X10 TONO 2"
        "B-Bordillo A80" "B-Sardinel A10"))

;; extremos de una entidad, sin ActiveX
(defun ext (en / p mn mx)
  (setq mn nil mx nil)
  (foreach it (entget en)
    (if (member (car it) '(10 11))
      (progn
        (setq p (cdr it))
        (if (and (listp p) (numberp (car p)) (numberp (cadr p)))
          (progn
            (if (null mn) (setq mn (list (car p) (cadr p)) mx (list (car p) (cadr p))))
            (setq mn (list (min (car mn) (car p)) (min (cadr mn) (cadr p))))
            (setq mx (list (max (car mx) (car p)) (max (cadr mx) (cadr p)))))))))
  (if mn (list mn mx)))

(foreach nombre objetivos
  (w "")
  (w (strcat "===== " nombre " ====="))
  (setq bd (tblsearch "BLOCK" nombre))
  (if (null bd)
    (w "  (no existe)")
    (progn
      (setq en (cdr (assoc -2 bd)))
      (setq n 0 tipos nil gmn nil gmx nil inserts nil)
      (while en
        (setq ed (entget en) n (1+ n))
        (setq t0 (cdr (assoc 0 ed)))
        (setq e (assoc t0 tipos))
        (setq tipos (if e (subst (cons t0 (1+ (cdr e))) e tipos)
                      (cons (cons t0 1) tipos)))
        (if (= t0 "INSERT")
          (progn
            (setq nm (cdr (assoc 2 ed)) p (cdr (assoc 10 ed)))
            (setq inserts
              (cons (strcat "    " nm "  en "
                      (rtos (car p) 2 3) "," (rtos (cadr p) 2 3)
                      "  esc " (rtos (cdr (assoc 41 ed)) 2 3)
                      "  rot " (rtos (/ (* 180.0 (cdr (assoc 50 ed))) pi) 2 1))
                inserts))))
        (setq bb (ext en))
        (if bb
          (progn
            (if (null gmn) (setq gmn (car bb) gmx (cadr bb)))
            (setq gmn (list (min (car gmn) (car (car bb))) (min (cadr gmn) (cadr (car bb)))))
            (setq gmx (list (max (car gmx) (car (cadr bb))) (max (cadr gmx) (cadr (cadr bb)))))))
        (setq en (entnext en)))
      (w (strcat "  entidades = " (itoa n)))
      (foreach e tipos (w (strcat "    " (car e) " = " (itoa (cdr e)))))
      (if gmn
        (w (strcat "  extension = " (rtos (- (car gmx) (car gmn)) 2 3)
             " x " (rtos (- (cadr gmx) (cadr gmn)) 2 3)
             "   (min " (rtos (car gmn) 2 3) "," (rtos (cadr gmn) 2 3) ")")))
      (if inserts
        (progn
          (w "  bloques anidados:")
          (setq lim 0)
          (foreach s (reverse inserts)
            (if (< lim 25) (w s))
            (setq lim (1+ lim)))
          (if (> lim 25) (w (strcat "    ... y " (itoa (- lim 25)) " mas"))))))))

;; y los INSERT de esos bloques en el modelo, para ver a que escala se usan
(w "")
(w "===== usos en el modelo =====")
(foreach nombre objetivos
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 nombre))))
  (if ss
    (progn
      (setq ed (entget (ssname ss 0)))
      (w (strcat "  " nombre " x" (itoa (sslength ss))
           "  esc " (rtos (cdr (assoc 41 ed)) 2 3)
           "  en " (rtos (car (cdr (assoc 10 ed))) 2 1)
           "," (rtos (cadr (cdr (assoc 10 ed))) 2 1))))))

(w "DONE")
(close *o*)
