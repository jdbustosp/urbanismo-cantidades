;; Reconocimiento de Detalles_Rampas.dwg (Claude, 2026-09-10).
;; SOLO LECTURA sobre una COPIA. Objetivo: sacar la composicion real de la
;; rampa vehicular y del paso peatonal (capas, textos rotulados, bloques y
;; medidas de las polilineas) para poder redibujarlas con las medidas del
;; plano en vez de deducirlas de una foto.

(setq *o* (open (strcat (getenv "URB_TEST_LAB") "/survey.txt") "w"))
(defun w (s) (write-line s *o*) (princ s) (princ "\n"))

(w (strcat "DWG = " (getvar "DWGNAME")))

;; ---- 1) inventario por tipo y capa ----
(setq ss (ssget "_X"))
(w (strcat "entidades en modelo = " (if ss (itoa (sslength ss)) "0")))
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
(w "--- capas (top 40 por cantidad) ---")
(setq n 0)
(foreach e (vl-sort capas '(lambda (a b) (> (cdr a) (cdr b))))
  (if (< n 40) (w (strcat "  " (car e) " = " (itoa (cdr e)))))
  (setq n (1+ n)))
(w (strcat "capas totales = " (itoa (length capas))))

;; ---- 2) definiciones de bloque ----
(w "--- bloques ---")
(setq bn (tblnext "BLOCK" T) nb 0)
(while bn
  (setq nm (cdr (assoc 2 bn)))
  (if (not (wcmatch nm "`**"))
    (progn (setq nb (1+ nb)) (w (strcat "  " nm))))
  (setq bn (tblnext "BLOCK")))
(w (strcat "bloques con nombre = " (itoa nb)))

;; ---- 3) TODOS los textos con su punto ----
(w "--- textos ---")
(setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
(setq i 0 nt 0)
(if ss
  (repeat (sslength ss)
    (setq ed (entget (ssname ss i)) i (1+ i))
    (setq s (cdr (assoc 1 ed)))
    (setq p (cdr (assoc 10 ed)))
    (if (and s (/= (vl-string-trim " " s) ""))
      (progn
        (setq nt (1+ nt))
        (w (strcat "  [" (cdr (assoc 8 ed)) "] "
             (rtos (car p) 2 2) "," (rtos (cadr p) 2 2) "  "
             (vl-string-translate "\n" " " s)))))))
(w (strcat "textos = " (itoa nt)))

(w "DONE")
(close *o*)
