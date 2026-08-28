;;; regen_acc.lsp (2026-08-28) — regenera los 704 accesorios de
;;; acueducto del master con la simbologia del plano por tipo:
;;;   1. lee cada insert MP_PUNTO_ACC_ACU (def compartida vieja = circulo)
;;;   2. crea la def nueva por tipo (mp:make-cant-punto-block del plugin
;;;      v4.61.0, simbolo replicado del plano) si no existe
;;;   3. cambia el insert a la def nueva (vla-put-Name) y le copia la
;;;      ROTACION del insert mas cercano del plano original (mismo tipo)
;;;   4. ATTSYNC por def (recolectar->mutar) y reescribe ETIQUETA corta
;;; Requiere el plugin cargado (correr con acad.exe /b, no accoreconsole).
(defun acc:tipo->plan (tipo)
  (cdr (assoc tipo
    '(("TEE" . "A Tee") ("CODO_11_5" . "A Codo11.25")
      ("CODO_22_5" . "A Codo22.5") ("CODO_45" . "codo 45")
      ("CODO_90" . "CODO90") ("HIDRANTE_TORRE" . "A Hidrante")
      ("VALVULA_PIE_HIDRANTE" . "Valvula HIDRANTE")
      ("VALVULA_RED_MENOR" . "VALVULA PROY")
      ("VALVULA_VENTOSA" . "VENTOSA")
      ("VALVULA_CIERRE_PERMANENTE" . "VCP")
      ("TAPON" . "A Tapon") ("REDUCCION" . "A Buje")
      ("OTRO" . "Union")))))

;; insert del plano (mismo bloque) mas cercano a p; (rot escala dist) o nil
(defun acc:plan-match (plan-name p / best bd d item)
  (setq best nil bd 1e9)
  (foreach item acc:plan-ins
    (if (= (car item) plan-name)
      (progn
        (setq d (distance (list (nth 1 item) (nth 2 item))
                          (list (car p) (cadr p))))
        (if (< d bd) (setq bd d best item)))))
  (if best (list (nth 3 best) (nth 4 best) bd) nil))

(defun acc:log (msg)
  (if *acc-f* (write-line msg *acc-f*))
  (princ (strcat "\n" msg)) (princ))

(defun c:REGENACC (/ doc ss i en ed obj atts tipo blkname p match rot scl
                     n-ok n-far n-rot defs d name lay ent-count blkrec cnt
                     old-defs)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq *acc-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/acc_acu/regen_result.txt" "w"))
  (setq n-ok 0 n-far 0 n-rot 0 defs nil)
  ;; 1) RECOLECTAR los inserts de accesorios (enames en lista plana)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU*"))))
  (if (null ss) (progn (acc:log "ERROR: no hay accesorios") (exit)))
  (setq i 0 ents nil)
  (while (< i (sslength ss))
    (setq ents (cons (ssname ss i) ents))
    (setq i (1+ i)))
  (acc:log (strcat "Accesorios encontrados: " (itoa (length ents))))
  ;; 2) MUTAR uno a uno
  (foreach en ents
    (setq obj (vlax-ename->vla-object en))
    (setq atts (mp:att-alist en))
    (setq tipo (mp:getval "TIPO_ACCESORIO" atts ""))
    (setq blkname (mp:acc-block-name atts))
    (if (not (tblsearch "BLOCK" blkname))
      (mp:make-cant-punto-block blkname "ACCESORIO_ACUEDUCTO" atts))
    (if (not (member blkname defs)) (setq defs (cons blkname defs)))
    (vla-put-Name obj blkname)
    ;; rotacion desde el plano
    (setq p (vlax-safearray->list
              (vlax-variant-value (vla-get-InsertionPoint obj))))
    (setq match (acc:plan-match (acc:tipo->plan tipo) p))
    (cond
      ((and match (< (caddr match) 1.5))
        (vla-put-Rotation obj (* pi (/ (car match) 180.0)))
        ;; escala negativa en el plano = simbolo espejado
        (if (< (cadr match) 0.0)
          (vla-put-XScaleFactor obj -1.0))
        (setq n-rot (1+ n-rot)))
      (match (setq n-far (1+ n-far))))
    (setq n-ok (1+ n-ok)))
  (acc:log (strcat "Migrados: " (itoa n-ok)
    " | con rotacion del plano: " (itoa n-rot)
    " | sin match cercano (<1.5m): " (itoa n-far)))
  ;; 3) ATTSYNC por definicion nueva (fuera de todo vlax-for)
  (foreach d defs
    (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" d)))
  (acc:log (strcat "ATTSYNC en " (itoa (length defs)) " definiciones"))
  ;; 4) reescribir ETIQUETA corta (attsync conserva el valor viejo largo)
  (setq cnt 0)
  (foreach en ents
    (if (entget en)
      (progn
        (setq atts (mp:att-alist en))
        (mp:setatts en (list (cons "ETIQUETA"
          (mp:label-point "ACCESORIO_ACUEDUCTO" atts))))
        (setq cnt (1+ cnt)))))
  (acc:log (strcat "Etiquetas reescritas: " (itoa cnt)))
  ;; 5) purgar la definicion compartida vieja si quedo huerfana
  (setq old-defs '("MP_PUNTO_ACC_ACU"))
  (foreach d old-defs
    (if (tblsearch "BLOCK" d)
      (if (vl-catch-all-error-p
            (vl-catch-all-apply
              '(lambda (nm) (vla-Delete (vla-Item (vla-get-Blocks doc) nm)))
              (list d)))
        (acc:log (strcat "Def vieja " d " sigue referenciada (no purgada)"))
        (acc:log (strcat "Def vieja " d " purgada")))))
  ;; 6) verificacion: conteo de inserts por def nueva
  (foreach d (vl-sort defs '<)
    (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 d))))
    (acc:log (strcat "  " d ": "
      (if ss (itoa (sslength ss)) "0") " inserts")))
  (acc:log "LISTO-REGENACC")
  (close *acc-f*)
  (setq *acc-f* nil)
  (princ))
(princ "\nREGENACC listo")
(princ)
