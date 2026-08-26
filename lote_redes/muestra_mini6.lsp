;; MUESTRA v6 (2026-08-26): version limpia con los ajustes de la revision
;; del usuario -- textos de caja chicos (0.60) pegados al simbolo, texto
;; de tramo acotado (0.90), panel de propiedades depurado, ARENA/BASE
;; GRANULAR como en el presupuesto. Reparacion en sitio anti-zombi.
(vl-load-com)
(defun mr:log6 (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/muestra_log6.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun mm:hh (base)
  (cond ((= base "CAMARA_CS280") 1.0)
        ((member base '("CAMARA_CS274" "CAMARA_CS275")) 0.54)
        (T 0.85)))

(defun mm:caja (base pt rot id / obj a hh)
  (mp:insert-cant-point base pt
    (list (cons "ID" id) (cons "TIPO_CAJA" (mp:tipo-caja-de base))))
  (setq obj (vlax-ename->vla-object (entlast)))
  (setq hh (mm:hh base))
  (vla-put-Rotation obj rot)
  (foreach a (vlax-invoke obj 'GetAttributes)
    (cond
      ((= (strcase (vla-get-TagString a)) "ETIQUETA")
        (vla-put-Rotation a 0.0)
        (vl-catch-all-apply 'vla-put-TextAlignmentPoint
          (list a (mp:3d (list (car pt) (+ (cadr pt) hh 0.45) 0.0)))))
      ((= (strcase (vla-get-TagString a)) "NUM_VIS")
        (vla-put-Rotation a 0.0)
        (vl-catch-all-apply 'vla-put-TextAlignmentPoint
          (list a (mp:3d (list (car pt) (- (cadr pt) hh 0.5) 0.0))))))))

(defun mm:dist-de-nombre (nombre / pos sub)
  (setq pos (vl-string-search "BTAP_" nombre))
  (if pos
    (setq sub (substr nombre (+ pos 6)))
    (progn
      (setq pos (vl-string-search "MT_" nombre))
      (setq sub (substr nombre (+ pos 4)))))
  (atof (vl-string-translate "_" "." sub)))

(defun mm:verif-y-repara (nombre / ed be pl w x0 dist blks blk e on borrar mal)
  (setq dist (mm:dist-de-nombre nombre) mal nil)
  (setq ed (tblsearch "BLOCK" nombre))
  (if ed
    (progn
      (setq be (cdr (assoc -2 ed)))
      (while be
        (setq pl (entget be))
        (cond
          ((= (cdr (assoc 0 pl)) "LWPOLYLINE")
            (setq w (if (assoc 43 pl) (cdr (assoc 43 pl)) 0.0)
                  x0 (cadr (assoc 10 pl)))
            (mr:log6 (strcat "  VERIF " nombre ": ancho=" (rtos w 2 3)
              " x-ini=" (rtos x0 2 3)))
            (if (or (> w 0.25) (> (abs x0) 0.01)) (setq mal T)))
          ((= (cdr (assoc 0 pl)) "CIRCLE") (setq mal T)))
        (setq be (entnext be)))
      (if mal
        (progn
          (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
          (setq blk (vla-Item blks nombre) borrar nil)
          (vlax-for e blk
            (setq on (vla-get-ObjectName e))
            (cond
              ((= on "AcDbCircle") (setq borrar (cons e borrar)))
              ((= on "AcDbPolyline")
                (vl-catch-all-apply 'vla-put-ConstantWidth (list e 0.20))
                (setq pl (entget (vlax-vla-object->ename e)))
                (setq pl (subst (cons 10 (list 0.0 0.0)) (assoc 10 pl) pl))
                (entmod
                  (reverse
                    (subst (cons 10 (list dist 0.0))
                      (assoc 10 (reverse pl)) (reverse pl)))))))
          (foreach e borrar (vl-catch-all-apply 'vla-Delete (list e)))
          (mr:log6 (strcat "  def " nombre " reparada (zombi)"))))))
  (princ))

(defun mm:def-de-ultimo-tramo (patron / ss)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 patron))))
  (if ss (cdr (assoc 2 (entget (ssname ss 0)))) nil))

(defun c:MINI6 (/ ss i vps izq der v nb)
  (mr:log6 (strcat "Motor: " (if (boundp '*urb-version*) *urb-version* "?")))
  (mp:ensure-layers)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_*"))))
  (setq i 0)
  (repeat (if ss (sslength ss) 0) (entdel (ssname ss i)) (setq i (1+ i)))
  (command "_.-PURGE" "_B" "MP_TRAMO_*,MP_PUNTO_*,TEST_MT_*" "_N")
  (command "_.-PURGE" "_B" "MP_TRAMO_*,MP_PUNTO_*,TEST_MT_*" "_N")
  ;; --- MT
  (mm:caja "CAMARA_CS276" '(83520.4345 96035.9669 0.0) 3.1662 "C276-1")
  (mm:caja "CAMARA_CS276" '(83537.1309 96036.2184 0.0) 3.1662 "C276-2")
  (mp:insert-cant-tramo "TRAMO_E_MT"
    '(83520.4345 96035.9669 0.0) '(83537.1309 96036.2184 0.0)
    (list (cons "RED" "ELECTRICA-MT") (cons "TIPO_RED" "MT")
          (cons "UBICACION" "ANDEN O ZONA VERDE")
          (cons "DUCTOS" "6") (cons "DIAM_DUCTO" "6")
          (cons "MATERIAL_DUCTO" "PVC") (cons "LIBRES" "3")
          (cons "POZO_INI" "C276-1") (cons "POZO_FIN" "C276-2")))
  (setq nb (mm:def-de-ultimo-tramo "MP_TRAMO_MT_*"))
  (if nb (mm:verif-y-repara nb))
  ;; --- AP real (bloque CR T1 de SERIE 6)
  (mm:caja "CAMARA_CS274" '(83142.3168 95971.8578 0.0) 1.2217 "C274-1")
  (mm:caja "CAMARA_CS274" '(83091.0162 95985.1677 0.0) 1.2217 "C274-2")
  (mp:insert-cant-tramo "TRAMO_E_BT_AP"
    '(83142.3168 95971.8578 0.0) '(83091.0162 95985.1677 0.0)
    (list (cons "RED" "ELECTRICA-BT-AP") (cons "TIPO_RED" "AP")
          (cons "UBICACION" "ANDEN O ZONA VERDE")
          (cons "DUCTOS" "2") (cons "DIAM_DUCTO" "3")
          (cons "MATERIAL_DUCTO" "PVC") (cons "CONDUCTOR" "3x4+4 THW")
          (cons "POZO_INI" "C274-1") (cons "POZO_FIN" "C274-2")))
  (setq nb (mm:def-de-ultimo-tramo "MP_TRAMO_BTAP_*"))
  (if nb (mm:verif-y-repara nb))
  (mp:insert-cant-point "POSTE_ELEC" '(83139.6447 95971.5156 0.0)
    (list (cons "ID" "P-1") (cons "TIPO_RED" "AP")
          (cons "LUMINARIAS" "2") (cons "TIPO_LUMINARIA" "192-93")))
  (mp:insert-cant-point "POSTE_ELEC" '(83088.3440 95984.8256 0.0)
    (list (cons "ID" "P-2") (cons "TIPO_RED" "AP")
          (cons "LUMINARIAS" "2") (cons "TIPO_LUMINARIA" "192-93")))
  ;; --- dos ventanas
  (setq v (vl-catch-all-apply
    '(lambda ()
      (command "_.-VPORTS" "_SI")
      (command "_.-VPORTS" "2" "_V")
      (setq izq nil der nil)
      (foreach v (vports)
        (if (< (car (cadr v)) 0.1) (setq izq (car v)) (setq der (car v))))
      (if (and izq der)
        (progn
          (setvar "CVPORT" izq)
          (command "_.ZOOM" "_W" "83080,95958" "83152,95996")
          (setvar "CVPORT" der)
          (command "_.ZOOM" "_W" "83512,96026" "83546,96046"))))
    nil))
  (if (vl-catch-all-error-p v)
    (command "_.ZOOM" "_W" "83512,96026" "83546,96046"))
  (mr:log6 "MINI6-TERMINADA"))
(c:MINI6)
