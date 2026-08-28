;;; extraer_geom.lsp — vuelca la geometria de los bloques de accesorios
;;; del plano ACUEDUCTO.dwg (para replicarla en el plugin) + todos los
;;; inserts con posicion/rotacion/escala (para orientar los del master).
;;; Solo DXF/entget (accoreconsole).
(setq ext:blocks '("A Tee" "A Codo11.25" "A Hidrante" "Valvula HIDRANTE"
                   "A Tapon" "A Buje" "VALVULA PROY" "codo 45" "A Codo22.5"
                   "VENTOSA" "CODO90" "Union" "VCP" "VRP" "A$C6B1C283F"))

(defun ext:n (v) (rtos v 2 4))
(defun ext:pt (p) (strcat "(" (ext:n (car p)) " " (ext:n (cadr p)) ")"))

(defun ext:dump-ent (ed f / ty pts e10 w)
  (setq ty (cdr (assoc 0 ed)))
  (cond
    ((= ty "LINE")
      (write-line (strcat "  LINE " (ext:pt (cdr (assoc 10 ed))) " -> "
        (ext:pt (cdr (assoc 11 ed)))) f))
    ((= ty "CIRCLE")
      (write-line (strcat "  CIRCLE c=" (ext:pt (cdr (assoc 10 ed)))
        " r=" (ext:n (cdr (assoc 40 ed)))) f))
    ((= ty "ARC")
      (write-line (strcat "  ARC c=" (ext:pt (cdr (assoc 10 ed)))
        " r=" (ext:n (cdr (assoc 40 ed)))
        " a=" (ext:n (cdr (assoc 50 ed))) ".." (ext:n (cdr (assoc 51 ed)))) f))
    ((= ty "LWPOLYLINE")
      (setq pts "" w (cdr (assoc 43 ed)))
      (foreach g ed
        (if (= 10 (car g)) (setq pts (strcat pts " " (ext:pt (cdr g))))))
      (write-line (strcat "  LWPOLY closed=" (itoa (logand (cdr (assoc 70 ed)) 1))
        " w=" (if w (ext:n w) "?") " :" pts) f))
    ((= ty "SOLID")
      (write-line (strcat "  SOLID " (ext:pt (cdr (assoc 10 ed))) " "
        (ext:pt (cdr (assoc 11 ed))) " " (ext:pt (cdr (assoc 12 ed))) " "
        (ext:pt (cdr (assoc 13 ed)))) f))
    ((= ty "HATCH")
      (write-line "  HATCH (patron omitido)" f))
    ((member ty '("TEXT" "MTEXT"))
      (write-line (strcat "  " ty " \"" (cdr (assoc 1 ed)) "\" @"
        (ext:pt (cdr (assoc 10 ed))) " h=" (ext:n (cdr (assoc 40 ed)))) f))
    ((= ty "INSERT")
      (write-line (strcat "  INSERT-ANIDADO " (cdr (assoc 2 ed)) " @"
        (ext:pt (cdr (assoc 10 ed))) " s=" (ext:n (cdr (assoc 41 ed)))) f))
    (T (write-line (strcat "  " ty " (no volcado)") f))))

(defun c:EXTGEOM (/ f bn tb e ed ss i ins scl rot cnt)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/acc_acu/plano_geom.txt" "w"))
  (foreach bn ext:blocks
    (setq tb (tblobjname "BLOCK" bn))
    (if tb
      (progn
        (write-line (strcat "=== BLOQUE: " bn " ===") f)
        (setq e (cdr (assoc -2 (entget tb))))
        (while e
          (setq ed (entget e))
          (ext:dump-ent ed f)
          (setq e (entnext e)))
        (write-line "" f))
      (write-line (strcat "=== BLOQUE: " bn " NO EXISTE ===") f)))
  ;; inserts: posicion/rotacion/escala para orientar los del master
  (write-line "=== INSERTS (nombre|x|y|rot_grados|escala) ===" f)
  (setq ss (ssget "_X" '((0 . "INSERT"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq ins (entget (ssname ss i)))
      (if (member (cdr (assoc 2 ins)) ext:blocks)
        (write-line (strcat (cdr (assoc 2 ins)) "|"
          (ext:n (cadr (assoc 10 ins))) "|" (ext:n (caddr (assoc 10 ins))) "|"
          (ext:n (* 180.0 (/ (cdr (assoc 50 ins)) pi))) "|"
          (ext:n (cdr (assoc 41 ins)))) f))
      (setq i (1+ i))))
  (write-line "FIN-EXTGEOM" f)
  (close f)
  (princ))
(princ "\nEXTGEOM listo")
(princ)
