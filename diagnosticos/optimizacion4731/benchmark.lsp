(load "C:/Users/jdbus/Documents/URBANISMO/work/maipore4740/motor.lsp")
(defun vt:aggregate-old (records / result record key found)
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


(setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/maipore4740/benchmark.txt" "w"))
(defun vt:fail () (exit))
(defun vt:empty () nil)
(setq caught (vl-catch-all-apply 'urb:rows-timed (list "Fallo inyectado" 'vt:fail)))
(write-line (strcat "COLLECTOR FAILURE " (if (vl-catch-all-error-p caught) "ABORT OK" "FAIL")) f)
(write-line (strcat "COLLECTOR EMPTY " (if (null (urb:rows-timed "Vacio" 'vt:empty)) "OK" "FAIL")) f)
(foreach n '(0 1 100 1000 5000)
 (setq rows nil i 0)
 (repeat n
  (setq rows (cons (urb:q-record "T" "S" (itoa (rem i 1703)) "E" "1" "A" "M3" (/ (float i) 7.0) "H" "OK" "" "") rows) i (1+ i)))
 (setq t0 (getvar "MILLISECS") expected (vt:aggregate-old rows) t1 (getvar "MILLISECS") actual (urb:q-aggregate rows) t2 (getvar "MILLISECS"))
 (write-line (strcat "N=" (itoa n) " MATCH=" (if (equal expected actual) "YES" "NO") " OLD_MS=" (itoa (- t1 t0)) " NEW_MS=" (itoa (- t2 t1))) f))
(setq ss (ssget "_X" '((0 . "INSERT"))))
(write-line (strcat "HANDLE " (if (and ss (= (urb:q-handle (ssname ss 0)) (cdr (assoc 5 (entget (ssname ss 0)))))) "OK" "FAIL")) f)
(write-line (strcat "HANDLE INVALID " (if (= "" (urb:q-handle nil)) "OK" "FAIL")) f)
(close f)
(princ)
