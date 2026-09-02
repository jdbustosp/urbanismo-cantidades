;;; relay.lsp - entidades internas de los defs MP_PUNTO_ACC_ACU* que
;;; esten en PPTO-ACCESORIOS-ACUEDUCTO -> PPTO-ACUEDUCTO (DXF puro),
;;; luego purga de la capa vieja.
(defun c:RELAYACC (/ f bd en ed n tot bn lst)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/relay_done.txt" "w"))
  (setq tot 0)
  (setq bd (tblnext "BLOCK" T) lst nil)
  (while bd
    (setq bn (cdr (assoc 2 bd)))
    (if (wcmatch (strcase bn) "MP_PUNTO_ACC_ACU*")
      (setq lst (cons bn lst)))
    (setq bd (tblnext "BLOCK")))
  (foreach bn lst
    (setq en (cdr (assoc -2 (entget (tblobjname "BLOCK" bn)))) n 0)
    (while en
      (setq ed (entget en))
      (if (= (strcase (cdr (assoc 8 ed))) "PPTO-ACCESORIOS-ACUEDUCTO")
        (progn
          (entmod (subst (cons 8 "PPTO-ACUEDUCTO") (assoc 8 ed) ed))
          (setq n (1+ n))))
      (setq en (entnext en)))
    (setq tot (+ tot n))
    (write-line (strcat bn ": " (itoa n)) f))
  (write-line (strcat "TOTAL re-capa: " (itoa tot)) f)
  (command "_.-PURGE" "_LA" "PPTO-ACCESORIOS-ACUEDUCTO" "_N")
  (write-line
    (if (tblsearch "LAYER" "PPTO-ACCESORIOS-ACUEDUCTO")
      "CAPA SIGUE" "CAPA PURGADA") f)
  (close f)
  (princ))
