;; Reconocimiento de SEÑALIZACION.dwg. SOLO LECTURA sobre una copia.
(setq *o* (open (strcat (getenv "URB_TEST_LAB") "/senal.txt") "w"))
(defun w (s) (write-line s *o*) (princ s) (princ "\n"))
(w (strcat "DWG = " (getvar "DWGNAME")))

(setq ss (ssget "_X"))
(w (strcat "entidades = " (if ss (itoa (sslength ss)) "0")))
(setq tipos nil capas nil i 0)
(if ss
  (repeat (sslength ss)
    (setq ed (entget (ssname ss i)) i (1+ i))
    (setq t0 (cdr (assoc 0 ed)) c0 (cdr (assoc 8 ed)))
    (setq e (assoc t0 tipos))
    (setq tipos (if e (subst (cons t0 (1+ (cdr e))) e tipos) (cons (cons t0 1) tipos)))
    (setq e (assoc c0 capas))
    (setq capas (if e (subst (cons c0 (1+ (cdr e))) e capas) (cons (cons c0 1) capas)))))
(w "--- tipos ---")
(foreach e (vl-sort tipos '(lambda (a b) (> (cdr a) (cdr b))))
  (w (strcat "  " (car e) " = " (itoa (cdr e)))))
(w "--- capas ---")
(foreach e (vl-sort capas '(lambda (a b) (> (cdr a) (cdr b))))
  (w (strcat "  " (car e) " = " (itoa (cdr e)))))

;; bloques con nombre y cuantas veces se usan
(w "--- bloques usados en el modelo ---")
(setq bn (tblnext "BLOCK" T) usados nil)
(while bn
  (setq nm (cdr (assoc 2 bn)))
  (if (not (wcmatch nm "`**"))
    (progn
      (setq ss2 (ssget "_X" (list '(0 . "INSERT") (cons 2 nm))))
      (if ss2 (setq usados (cons (cons nm (sslength ss2)) usados)))))
  (setq bn (tblnext "BLOCK")))
(foreach e (vl-sort usados '(lambda (a b) (> (cdr a) (cdr b))))
  (w (strcat "  " (car e) " x" (itoa (cdr e)))))
(w (strcat "bloques distintos usados = " (itoa (length usados))))

;; textos (rotulos de la senalizacion)
(w "--- textos (primeros 80) ---")
(setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))) i 0 n 0)
(if ss
  (repeat (sslength ss)
    (setq ed (entget (ssname ss i)) i (1+ i))
    (setq s (cdr (assoc 1 ed)))
    (if (and s (/= (vl-string-trim " " s) "") (< n 80))
      (progn
        (setq n (1+ n))
        (w (strcat "  [" (cdr (assoc 8 ed)) "] "
             (vl-string-translate "\n" " " s)))))))
(w "DONE")
(close *o*)
