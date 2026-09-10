;; Como se usa B CEBRA en el plano: posiciones para deducir el PASO entre
;; franjas. SOLO LECTURA sobre copia.
(setq *o* (open (strcat (getenv "URB_TEST_LAB") "/cebra.txt") "w"))
(defun w (s) (write-line s *o*) (princ s) (princ "\n"))

;; 1) en el modelo
(setq ss (ssget "_X" '((0 . "INSERT") (2 . "B CEBRA"))))
(w (strcat "B CEBRA en el modelo = " (if ss (itoa (sslength ss)) "0")))
(setq i 0)
(if ss
  (repeat (min 30 (sslength ss))
    (setq ed (entget (ssname ss i)) i (1+ i))
    (w (strcat "  en " (rtos (car (cdr (assoc 10 ed))) 2 3) ","
         (rtos (cadr (cdr (assoc 10 ed))) 2 3)
         "  rot " (rtos (/ (* 180.0 (cdr (assoc 50 ed))) pi) 2 1)
         "  esc " (rtos (cdr (assoc 41 ed)) 2 3)))))

;; 2) anidado dentro de cualquier definicion de bloque
(w "--- B CEBRA anidada en otros bloques ---")
(setq bn (tblnext "BLOCK" T))
(while bn
  (setq nm (cdr (assoc 2 bn)) en (cdr (assoc -2 bn)) n 0 pts nil)
  (while en
    (setq ed (entget en))
    (if (and (= (cdr (assoc 0 ed)) "INSERT")
             (= (cdr (assoc 2 ed)) "B CEBRA"))
      (progn (setq n (1+ n))
        (if (< (length pts) 12)
          (setq pts (cons (cdr (assoc 10 ed)) pts)))))
    (setq en (entnext en)))
  (if (> n 0)
    (progn
      (w (strcat "  " nm " -> " (itoa n) " franjas"))
      (foreach p (reverse pts)
        (w (strcat "      " (rtos (car p) 2 3) "," (rtos (cadr p) 2 3))))))
  (setq bn (tblnext "BLOCK")))

;; 3) contenido de los grupos de tableta de la rampa vehicular, para
;;    confirmar cuantas filas y de que tipo
(w "--- filas de tableta de B-RAMPA VEHICULAR ---")
(foreach nm (list "*U2210" "*U2212" "*U2214" "*U2216")
  (setq bd (tblsearch "BLOCK" nm))
  (if bd
    (progn
      (setq en (cdr (assoc -2 bd)) n 0 tipo "")
      (while en
        (setq ed (entget en))
        (if (= (cdr (assoc 0 ed)) "INSERT")
          (progn
            (setq n (1+ n))
            (setq sub (tblsearch "BLOCK" (cdr (assoc 2 ed))))
            (if sub
              (progn
                (setq e2 (cdr (assoc -2 sub)))
                (while e2
                  (if (= (cdr (assoc 0 (entget e2))) "INSERT")
                    (setq tipo (cdr (assoc 2 (entget e2)))))
                  (setq e2 (entnext e2)))))))
        (setq en (entnext en)))
      (w (strcat "  " nm " -> " (itoa n) " x " tipo)))))

(w "DONE")
(close *o*)
