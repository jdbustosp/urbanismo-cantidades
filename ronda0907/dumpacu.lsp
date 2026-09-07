;;; dumpacu.lsp - volcar del DWG de diseno ACU: inserts (bloques de
;;; accesorio) y textos (numeros de nodo) a TSV. Corre en accoreconsole.
(defun c:DUMPACU (/ f ss i en ed nm p rot txt lay)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/pdf0907/acu_diseno.tsv" "w"))
  (write-line "CLASE\tNOMBRE_O_TEXTO\tX\tY\tROT\tCAPA" f)
  (setq ss (ssget "_X" '((0 . "INSERT"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i) ed (entget en))
      (setq nm (cdr (assoc 2 ed))
            p (cdr (assoc 10 ed))
            rot (cdr (assoc 50 ed))
            lay (cdr (assoc 8 ed)))
      (write-line (strcat "INSERT\t" nm "\t"
        (rtos (car p) 2 3) "\t" (rtos (cadr p) 2 3) "\t"
        (rtos (if rot rot 0.0) 2 4) "\t" lay) f)
      (setq i (1+ i))))
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i) ed (entget en))
      (setq txt (cdr (assoc 1 ed))
            p (cdr (assoc 10 ed))
            lay (cdr (assoc 8 ed)))
      (write-line (strcat "TEXT\t" (vl-string-translate "\t" " " txt) "\t"
        (rtos (car p) 2 3) "\t" (rtos (cadr p) 2 3) "\t0\t" lay) f)
      (setq i (1+ i))))
  (write-line "FIN-DUMP" f)
  (close f)
  (princ))
