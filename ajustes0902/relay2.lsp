;;; relay2.lsp - barre TODO lo que siga en PPTO-ACCESORIOS-ACUEDUCTO:
;;; attribs de inserts, entidades top-level y entidades dentro de
;;; CUALQUIER definicion de bloque; luego purga.
(defun c:RELAYACC2 (/ f ss i en a ed n bd bn lst tot)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/relay2_done.txt" "w"))
  (setq tot 0)
  ;; 1) attribs de todos los inserts del modelo
  (setq ss (ssget "_X" (list (cons 0 "INSERT"))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq a (entnext (ssname ss i)))
      (while (and a (= (cdr (assoc 0 (setq ed (entget a)))) "ATTRIB"))
        (if (= (strcase (cdr (assoc 8 ed))) "PPTO-ACCESORIOS-ACUEDUCTO")
          (progn
            (entmod (subst (cons 8 "PPTO-ACUEDUCTO") (assoc 8 ed) ed))
            (setq n (1+ n))))
        (setq a (entnext a)))
      (setq i (1+ i))))
  (write-line (strcat "attribs re-capa: " (itoa n)) f)
  (setq tot (+ tot n))
  ;; 2) cualquier entidad top-level restante
  (setq ss (ssget "_X" (list (cons 8 "PPTO-ACCESORIOS-ACUEDUCTO"))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq ed (entget (ssname ss i)))
      (entmod (subst (cons 8 "PPTO-ACUEDUCTO") (assoc 8 ed) ed))
      (setq n (1+ n))
      (setq i (1+ i))))
  (write-line (strcat "top-level re-capa: " (itoa n)) f)
  (setq tot (+ tot n))
  ;; 3) dentro de TODAS las definiciones de bloque (y sus attdefs)
  (setq bd (tblnext "BLOCK" T) lst nil)
  (while bd
    (setq lst (cons (cdr (assoc 2 bd)) lst))
    (setq bd (tblnext "BLOCK")))
  (setq n 0)
  (foreach bn lst
    (if (not (wcmatch bn "`**"))  ;; saltar bloques anonimos raros
      (progn
        (setq en (cdr (assoc -2 (entget (tblobjname "BLOCK" bn)))))
        (while en
          (setq ed (entget en))
          (if (and (assoc 8 ed)
                   (= (strcase (cdr (assoc 8 ed))) "PPTO-ACCESORIOS-ACUEDUCTO"))
            (progn
              (entmod (subst (cons 8 "PPTO-ACUEDUCTO") (assoc 8 ed) ed))
              (setq n (1+ n))))
          (setq en (entnext en))))))
  (write-line (strcat "en defs re-capa: " (itoa n)) f)
  (setq tot (+ tot n))
  (command "_.-PURGE" "_LA" "PPTO-ACCESORIOS-ACUEDUCTO" "_N")
  (write-line
    (if (tblsearch "LAYER" "PPTO-ACCESORIOS-ACUEDUCTO")
      "CAPA SIGUE" "CAPA PURGADA") f)
  (write-line (strcat "TOTAL " (itoa tot)) f)
  (close f)
  (princ))
