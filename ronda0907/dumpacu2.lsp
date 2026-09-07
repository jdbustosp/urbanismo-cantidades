;;; dumpacu2 - inserts del diseno ACU CON sus atributos (para diametros
;;; de ventosas/valvulas/tees) -- accoreconsole
(defun c:DUMPACU2 (/ f ss i en ed nm p a aed atxt)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/pdf0907/acu_diseno_atts.tsv" "w"))
  (write-line "NOMBRE\tX\tY\tATTS" f)
  (setq ss (ssget "_X" '((0 . "INSERT"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i) ed (entget en))
      (setq nm (cdr (assoc 2 ed))
            p (cdr (assoc 10 ed))
            atxt "")
      (setq a (entnext en))
      (while (and a (= (cdr (assoc 0 (setq aed (entget a)))) "ATTRIB"))
        (setq atxt (strcat atxt (cdr (assoc 2 aed)) "="
          (vl-string-translate "\t" " " (cdr (assoc 1 aed))) ";"))
        (setq a (entnext a)))
      (write-line (strcat nm "\t" (rtos (car p) 2 3) "\t"
        (rtos (cadr p) 2 3) "\t" atxt) f)
      (setq i (1+ i))))
  (close f)
  (princ))
