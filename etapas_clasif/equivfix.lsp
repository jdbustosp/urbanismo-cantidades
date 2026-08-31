;;; EQUIVFIX: escribe en el libro (hoja oculta URB_EQUIVALENCIAS) las
;;; equivalencias accesorio-modelo -> actividad-libro, buscando la
;;; actividad por (capitulo, UM, patron wcmatch normalizado, firma de
;;; numeros). FIXDIAMACC: hereda el DIAMETRO faltante de accesorios
;;; desde el tramo ACU que los toca.
(defun eq:log (msg)
  (if *eq-f* (write-line msg *eq-f*))
  (princ (strcat "\n" msg)) (princ))

(defun eq:digits (s / i c out cur)
  (setq i 1 out nil cur "")
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (wcmatch c "#")
      (setq cur (strcat cur c))
      (progn (if (/= cur "") (setq out (cons cur out))) (setq cur "")))
    (setq i (1+ i)))
  (if (/= cur "") (setq out (cons cur out)))
  (reverse out))

(defun eq:find (vocab caps um patron firma / item out norm)
  (setq out nil)
  (foreach item vocab
    (if (and (urb:ppto-cap-match-p (nth 0 item) caps)
             (= (nth 1 item) (strcase um)))
      (progn
        (setq norm (strcase (urb:ppto-normalize (nth 2 item))))
        (if (and (wcmatch norm (strcase patron))
                 (or (null firma) (equal (eq:digits norm) firma)))
          (if (not (member (nth 2 item) out))
            (setq out (cons (nth 2 item) out)))))))
  (if (= (length out) 1) (car out) (list (quote AMBIGUO) (length out))))

(setq eq:tabla (list
  (list "ACUEDUCTO" "UN" "TEE 6" "TEE*" (list "6" "6"))
  (list "ACUEDUCTO" "UN" "TEE 8" "TEE*" (list "8" "8"))
  (list "ACUEDUCTO" "UN" "TEE 12" "TEE*" (list "12" "12"))
  (list "ACUEDUCTO" "UN" "TEE 2" "TEE*" (list "8" "2"))
  (list "ACUEDUCTO" "UN" "TEE 6 6" "TEE*" (list "6" "6"))
  (list "ACUEDUCTO" "UN" "TEE 8 8" "TEE*" (list "8" "8"))
  (list "ACUEDUCTO" "UN" "TEE 12 12" "TEE*" (list "12" "12"))
  (list "ACUEDUCTO" "UN" "REDUCCION 8 8" "REDUCCION*" (list "8" "6"))
  (list "ACUEDUCTO" "UN" "TEE 8 6" "TEE*" (list "8" "6"))
  (list "ACUEDUCTO" "UN" "TEE 8 4" "TEE*" (list "8" "4"))
  (list "ACUEDUCTO" "UN" "TEE 8 2" "TEE*" (list "8" "2"))
  (list "ACUEDUCTO" "UN" "TEE 6 4" "TEE*" (list "6" "4"))
  (list "ACUEDUCTO" "UN" "TEE 6 2" "TEE*" (list "6" "2"))
  (list "ACUEDUCTO" "UN" "TEE 6 1" "TEE*" (list "6" "1"))
  (list "ACUEDUCTO" "UN" "TEE 10 8" "TEE*" (list "10" "8"))
  (list "ACUEDUCTO" "UN" "TEE 12 8" "TEE*" (list "12" "8"))
  (list "ACUEDUCTO" "UN" "TEE 12 6" "TEE*" (list "12" "6"))
  (list "ACUEDUCTO" "UN" "TEE 12 4" "TEE*" (list "12" "4"))
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 6 4" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 8 4" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 12 4" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 8 2" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 12 2" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_CIERRE_PERMANENTE 8 8" "*CIERRE PERMANENTE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_CIERRE_PERMANENTE 12 12" "*CIERRE PERMANENTE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 4 4" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 4 4" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "REDUCCION 12 6" "REDUCCION*" (list "12" "8"))
  (list "ACUEDUCTO" "UN" "REDUCCION 10 8" "REDUCCION*" (list "12" "8"))
  (list "ACUEDUCTO" "UN" "TEE 4" "TEE*" (list "8" "4"))
  (list "ACUEDUCTO" "UN" "CODO_11_5 4" "CODO*" (list "11" "25" "4"))
  (list "ACUEDUCTO" "UN" "CODO_11_5 6" "CODO*" (list "11" "25" "6"))
  (list "ACUEDUCTO" "UN" "CODO_11_5 8" "CODO*" (list "11" "25" "8"))
  (list "ACUEDUCTO" "UN" "CODO_11_5 12" "CODO*" (list "11" "25" "12"))
  (list "ACUEDUCTO" "UN" "CODO_22_5 6" "CODO*" (list "22" "5" "6"))
  (list "ACUEDUCTO" "UN" "CODO_22_5 8" "CODO*" (list "22" "5" "8"))
  (list "ACUEDUCTO" "UN" "CODO_22_5 12" "CODO*" (list "22" "5" "12"))
  (list "ACUEDUCTO" "UN" "CODO_45 6" "CODO*" (list "45" "6"))
  (list "ACUEDUCTO" "UN" "CODO_45 8" "CODO*" (list "45" "8"))
  (list "ACUEDUCTO" "UN" "CODO_45 12" "CODO*" (list "45" "12"))
  (list "ACUEDUCTO" "UN" "CODO_90 6" "CODO*" (list "90" "6"))
  (list "ACUEDUCTO" "UN" "CODO_90 8" "CODO*" (list "90" "8"))
  (list "ACUEDUCTO" "UN" "CODO_90 12" "CODO*" (list "90" "12"))
  (list "ACUEDUCTO" "UN" "TAPON 2" "TAPON*" (list "2"))
  (list "ACUEDUCTO" "UN" "TAPON 3" "TAPON*" (list "3"))
  (list "ACUEDUCTO" "UN" "TAPON 4" "TAPON*" (list "4"))
  (list "ACUEDUCTO" "UN" "TAPON 6" "TAPON*" (list "6"))
  (list "ACUEDUCTO" "UN" "TAPON 8" "TAPON*" (list "8"))
  (list "ACUEDUCTO" "UN" "TAPON 12" "TAPON*" (list "12"))
  (list "ACUEDUCTO" "UN" "VALVULA_RED_MENOR 4" "VALVULA DE COMPUERTA*" (list "4"))
  (list "ACUEDUCTO" "UN" "VALVULA_RED_MENOR 6" "VALVULA DE COMPUERTA*" (list "6"))
  (list "ACUEDUCTO" "UN" "VALVULA_RED_MENOR 8" "VALVULA DE COMPUERTA*" (list "8"))
  (list "ACUEDUCTO" "UN" "VALVULA_RED_MENOR 12" "VALVULA DE COMPUERTA*" (list "12"))
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 2" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 6" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 8" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_VENTOSA 12" "VALVULA VENTOSA*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_CIERRE_PERMANENTE" "*CIERRE PERMANENTE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_CIERRE_PERMANENTE 8" "*CIERRE PERMANENTE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_CIERRE_PERMANENTE 12" "*CIERRE PERMANENTE*" nil)
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 3" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 4" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 6" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 8" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "HIDRANTE_TORRE 12" "HIDRANTE DE TORRE*" (list "4"))
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 3" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 4" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 6" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 8" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "VALVULA_PIE_HIDRANTE 12" "VALVULA DE PIE*" nil)
  (list "ACUEDUCTO" "UN" "OTRO" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 10" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 10 2" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 2" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 8 6" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 12 8" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 4" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 6" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 8" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "OTRO 12" "UNION DE REPARACION*" nil)
  (list "ACUEDUCTO" "UN" "REDUCCION 12" "REDUCCION*" (list "12" "8"))
  (list "ACUEDUCTO" "UN" "REDUCCION 8" "REDUCCION*" (list "8" "6"))
  (list "ACUEDUCTO" "UN" "REDUCCION 6" "REDUCCION*" (list "6" "4"))
  (list "ACUEDUCTO" "UN" "REDUCCION 4" "REDUCCION*" (list "4" "3"))
  (list "ACUEDUCTO" "UN" "REDUCCION 2" "REDUCCION*" (list "4" "2"))
  (list "VIA" "M3" "Subbase granular SBG-A" "SUBBASE GRANULAR SBG" nil)
  (list "VIA" "M3" "Base Asfaltica MD-20" "*CAPA INTERMEDIA*" (list "25"))))

(defun c:EQUIVFIX (/ path attach app wb propia lo vocab fila red um
                     concepto patron firma caps target n-ok n-fail ekey
                     equiv nuevos)
  (vl-load-com)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "w"))
  (setq path (urb:ppto-config-read))
  (setq attach (urb:ppto-attach-excel path)
        app (nth 0 attach) wb (nth 1 attach) propia (nth 2 attach))
  (if (null wb) (progn (eq:log "SIN EXCEL") (close *eq-f*) (exit)))
  (setq lo (urb:ppto-memorias-table wb))
  (setq vocab (if lo (urb:ppto-read-vocab wb) nil))
  (setq equiv (urb:ppto-equiv-read wb) nuevos 0 n-ok 0 n-fail 0)
  (foreach fila eq:tabla
    (setq red (nth 0 fila) um (nth 1 fila) concepto (nth 2 fila)
          patron (nth 3 fila) firma (nth 4 fila))
    (setq caps (urb:ppto-caps-de red))
    (setq target (eq:find vocab caps um patron firma))
    (if (listp target)
      (progn
        (setq n-fail (1+ n-fail))
        (eq:log (strcat "  SIN DESTINO UNICO: " concepto " ("
          (itoa (cadr target)) " candidatas)")))
      (progn
        (setq ekey (urb:ppto-equiv-key red concepto))
        (if (not (assoc ekey equiv))
          (progn
            (setq equiv (cons (cons ekey target) equiv))
            (setq nuevos (1+ nuevos))))
        (setq n-ok (1+ n-ok))
        (eq:log (strcat "  " concepto " -> " target)))))
  (urb:ppto-equiv-write wb equiv)
  (vl-catch-all-apply (quote (lambda () (vlax-invoke-method wb (quote Save)))))
  (eq:log (strcat "EQUIVFIX: " (itoa n-ok) " resueltas (" (itoa nuevos)
    " nuevas escritas al libro), " (itoa n-fail) " sin destino"))
  (vl-catch-all-apply (quote (lambda () (vlax-invoke-method wb (quote Close) :vlax-false))))
  (if propia (vl-catch-all-apply (quote (lambda () (vlax-invoke-method app (quote Quit))))))
  (eq:log "FIN-EQUIVFIX")
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

;; hereda DIAMETRO del tramo ACU cuyo extremo toca el accesorio (<1 m)
(defun c:FIXDIAMACC (/ ss i en ed p atts d ts best bid n ents tramos tr)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 tramos nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq atts (mp:att-alist en))
      (setq d (mp:getval "DIAMETRO" atts ""))
      (if (/= d "")
        (progn
          (setq ts (cr:tramo-ends en))
          (setq tramos (cons (list (nth 0 ts) (nth 1 ts) d) tramos))
          (setq tramos (cons (list (nth 2 ts) (nth 3 ts) d) tramos))))
      (setq i (1+ i))))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0 n 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "DIAMETRO" atts "") "")
      (progn
        (setq p (cdr (assoc 10 (entget en))) best 1e9 bid "")
        (foreach tr tramos
          (setq d (distance (list (car tr) (cadr tr)) (list (car p) (cadr p))))
          (if (< d best) (setq best d bid (caddr tr))))
        (if (< best 1.0)
          (progn
            (mp:setatts en (list (cons "DIAMETRO" bid)
              (cons "ETIQUETA" (mp:label-point "ACCESORIO_ACUEDUCTO"
                (mp:alist-set atts "DIAMETRO" bid)))))
            (setq n (1+ n)))))))
  (eq:log (strcat "FIXDIAMACC: " (itoa n) " accesorios heredaron diametro del tramo"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))
(princ "\nEQUIVFIX / FIXDIAMACC listos")
(princ)

;; descoles creados 2026-08-28: material NOVAFORT 12 (el plan pluvial es
;; NOVAFORT; quedaron PVC sin diametro al crearse)
(defun c:FIXDESCOLES (/ ss i en atts n ents)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_PLU_*"))) i 0 n 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "ORIGEN_CREACION" atts "") "LOTE_DESCOLES_20260828")
      (progn
        (mp:setatts en (list (cons "MATERIAL" "NOVAFORT")
          (cons "DIAMETRO"
            (if (= (mp:getval "DIAMETRO" atts "") "")
              "12" (mp:getval "DIAMETRO" atts "12")))))
        (setq n (1+ n)))))
  (eq:log (strcat "FIXDESCOLES: " (itoa n) " descoles a NOVAFORT 12"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

;; diametros REALES desde los atributos del plano ACU ("12x4" = diam y
;; salida). Refresca TODOS los accesorios (el dato del plano manda) y
;; luego los tramos ACU sin diametro heredan del accesorio que tocan.
(defun fp:parse (v / runs r)
  ;; extrae las corridas numericas: "12x12"->(12 12); "2 Collarin"->(2);
  ;; "06"->(6); "6 EMPATE LINEA"->(6). Devuelve (diam salida|nil)
  (setq runs (eq:digits v))
  (setq runs (mapcar (quote (lambda (x) (itoa (atoi x)))) runs))
  (list (if runs (car runs) "")
        (if (> (length runs) 1) (cadr runs) nil)))
(defun c:FIXDIAMPLAN (/ ss i en atts p best bd item d n-acc n-tr ents accs
                        par diam sal tr)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  ;; accesorios: refrescar diametro/salida desde el plano
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (setq n-acc 0 accs nil)
  (foreach en ents
    (setq p (cdr (assoc 10 (entget en))) best nil bd 1e9)
    (foreach item att:plan
      (setq d (distance (list (cadr item) (caddr item)) (list (car p) (cadr p))))
      (if (< d bd) (setq bd d best item)))
    (if (and best (< bd 1.5))
      (progn
        (setq par (fp:parse (nth 3 best)))
        (setq diam (car par) sal (cadr par))
        (setq atts (mp:att-alist en))
        (mp:setatts en
          (append
            (list (cons "DIAMETRO" diam))
            (if sal (list (cons "DIAMETRO_SALIDA" sal)) nil)
            (list (cons "ETIQUETA"
              (mp:label-point "ACCESORIO_ACUEDUCTO"
                (mp:alist-set atts "DIAMETRO" diam))))))
        (setq n-acc (1+ n-acc))
        ;; guardar posicion+diam para heredar a tramos
        (setq accs (cons (list (car p) (cadr p) diam) accs)))))
  (eq:log (strcat "FIXDIAMPLAN: " (itoa n-acc) " accesorios con diametro del plano"))
  ;; tramos ACU sin diametro: heredar del accesorio tocante
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (setq n-tr 0)
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "DIAMETRO" atts "") "")
      (progn
        (setq tr (cr:tramo-ends en) best nil bd 1e9)
        (foreach item accs
          (setq d (min (distance (list (car item) (cadr item))
                         (list (nth 0 tr) (nth 1 tr)))
                       (distance (list (car item) (cadr item))
                         (list (nth 2 tr) (nth 3 tr)))))
          (if (< d bd) (setq bd d best item)))
        (if (and best (< bd 1.5))
          (progn
            (mp:setatts en (list (cons "DIAMETRO" (caddr best))
              (cons "ETIQUETA" (mp:label-tramo "TRAMO_ACUEDUCTO"
                (mp:alist-set atts "DIAMETRO" (caddr best))))))
            (setq n-tr (1+ n-tr)))))))
  (eq:log (strcat "FIXDIAMPLAN: " (itoa n-tr) " tramos ACU heredaron diametro"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

;; pluvial: el plan es NOVAFORT -- tramos PLU con MATERIAL PVC pasan a
;; NOVAFORT (los descoles ya estaban, esto cubre el resto)
(defun c:FIXPLUMAT (/ ss i en atts n ents)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_PLU_*"))) i 0 n 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (strcase (mp:getval "MATERIAL" atts "")) "PVC")
      (progn
        (mp:setatts en (list (cons "MATERIAL" "NOVAFORT")))
        (setq n (1+ n)))))
  (eq:log (strcat "FIXPLUMAT: " (itoa n) " tramos PLU de PVC a NOVAFORT"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))


;; propagacion en cadena: tramo sin diametro hereda del accesorio o del
;; tramo vecino que comparte extremo (3 pasadas)
(defun c:FIXDIAMCHAIN (/ pasada ss i en atts ents con-d sin-d tr item best d2
                          bd d n-tot n)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq n-tot 0 pasada 0)
  (repeat 3
    (setq pasada (1+ pasada))
    ;; fuentes: extremos de tramos ACU con diametro + accesorios con diametro
    (setq con-d nil sin-d nil)
    (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0)
    (if ss
      (while (< i (sslength ss))
        (setq en (ssname ss i) atts (mp:att-alist en))
        (setq d (mp:getval "DIAMETRO" atts ""))
        (setq tr (cr:tramo-ends en))
        (if (/= d "")
          (setq con-d (cons (list (nth 0 tr) (nth 1 tr) d) 
                        (cons (list (nth 2 tr) (nth 3 tr) d) con-d)))
          (setq sin-d (cons (list en tr) sin-d)))
        (setq i (1+ i))))
    (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0)
    (if ss
      (while (< i (sslength ss))
        (setq en (ssname ss i) atts (mp:att-alist en))
        (setq d (mp:getval "DIAMETRO" atts ""))
        (if (/= d "")
          (progn
            (setq tr (cdr (assoc 10 (entget en))))
            (setq con-d (cons (list (car tr) (cadr tr) d) con-d))))
        (setq i (1+ i))))
    (setq n 0)
    (foreach item sin-d
      (setq en (car item) tr (cadr item) best nil bd 1e9)
      (foreach d con-d
        (setq bd
          (min bd
            (progn
              (setq d2 (min (distance (list (car d) (cadr d))
                              (list (nth 0 tr) (nth 1 tr)))
                            (distance (list (car d) (cadr d))
                              (list (nth 2 tr) (nth 3 tr)))))
              (if (< d2 bd) (setq best d))
              d2))))
      (if (and best (< bd 0.8))
        (progn
          (setq atts (mp:att-alist en))
          (mp:setatts en (list (cons "DIAMETRO" (caddr best))
            (cons "ETIQUETA" (mp:label-tramo "TRAMO_ACUEDUCTO"
              (mp:alist-set atts "DIAMETRO" (caddr best))))))
          (setq n (1+ n) n-tot (1+ n-tot)))))
    (eq:log (strcat "FIXDIAMCHAIN pasada " (itoa pasada) ": " (itoa n) " tramos")))
  (eq:log (strcat "FIXDIAMCHAIN total: " (itoa n-tot)))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

;; diametros pluviales desde los MULTILEADER/textos del plano PLUVIAL
;; (se corre con el plano ABIERTO como xref? no: se lee el DWG del plano
;; con ObjectDBX para no cambiar de dibujo)
(defun c:FIXDIAMPLU (/ dbx doc ss ent txt num p labels i en atts tr best bd
                       d item n mid odbx-ok)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  ;; abrir el plano por ObjectDBX
  (setq dbx (vlax-create-object
    (strcat "ObjectDBX.AxDbDocument."
      (substr (getvar "ACADVER") 1 2))))
  (setq odbx-ok
    (not (vl-catch-all-error-p
      (vl-catch-all-apply 'vlax-invoke-method
        (list dbx 'Open "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\02_REDES_HUMEDAS\TOTALES\PLUVIAL.dwg")))))
  (setq labels nil)
  (if odbx-ok
    (vlax-for ent (vlax-get dbx 'ModelSpace)
      (if (member (vlax-get ent 'ObjectName)
            '("AcDbMLeader" "AcDbText" "AcDbMText"))
        (progn
          (setq txt (vl-catch-all-apply 'vlax-get (list ent 'TextString)))
          (if (and (not (vl-catch-all-error-p txt)) txt (/= txt ""))
            (progn
              (setq num (dp2:num txt))
              (if num
                (progn
                  (setq p (vl-catch-all-apply 'dp2:pos (list ent)))
                  (if (and (not (vl-catch-all-error-p p)) p)
                    (setq labels (cons (list (car p) (cadr p) num) labels))))))))))
    (eq:log "FIXDIAMPLU: no se pudo abrir el plano por ObjectDBX"))
  (vl-catch-all-apply 'vlax-release-object (list dbx))
  (eq:log (strcat "FIXDIAMPLU: " (itoa (length labels)) " etiquetas de diametro en el plano"))
  ;; asignar a tramos PLU sin diametro (etiqueta a <10 m del punto medio)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_PLU_*"))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq atts (mp:att-alist en))
      (if (= (mp:getval "DIAMETRO" atts "") "")
        (progn
          (setq tr (cr:tramo-ends en))
          (setq mid (list (/ (+ (nth 0 tr) (nth 2 tr)) 2.0)
                          (/ (+ (nth 1 tr) (nth 3 tr)) 2.0)))
          (setq best nil bd 1e9)
          (foreach item labels
            (setq d (distance (list (car item) (cadr item)) mid))
            (if (< d bd) (setq bd d best item)))
          (if (and best (< bd 10.0))
            (progn
              (mp:setatts en (list (cons "DIAMETRO" (caddr best))))
              (setq n (1+ n))))))
      (setq i (1+ i))))
  (eq:log (strcat "FIXDIAMPLU: " (itoa n) " tramos PLU con diametro del plano"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

(defun dp2:num (txt / i c run last)
  ;; ultimo numero antes de una comilla o de %%34; rango sensato 8..48
  (setq i 1 run "" last nil)
  (while (<= i (strlen txt))
    (setq c (substr txt i 1))
    (cond
      ((wcmatch c "#") (setq run (strcat run c)))
      ((and (= c "\"") (/= run "")) (setq last run) (setq run ""))
      (T (setq run "")))
    (setq i (1+ i)))
  (if (and last (>= (atoi last) 8) (<= (atoi last) 48))
    (itoa (atoi last)) nil))

(defun dp2:pos (ent / p)
  ;; posicion representativa: insercion o primer vertice de leader
  (setq p (vl-catch-all-apply 'vlax-get (list ent 'InsertionPoint)))
  (if (and (not (vl-catch-all-error-p p)) p (listp p))
    p
    (cdr (assoc 10 (entget (vlax-vla-object->ename ent))))))

;; ultimo tramo del barrido: diametros faltantes por REGLA DE ID y
;; defaults documentados --
;;   PLU: POZO CAB-* (descole) -> 12 ; TRAT-* (efluente tratado, lote
;;        residual 2026-08-21) -> 24 ; DOM* -> 12 ; resto -> 12 (minimo
;;        pluvial del libro; SUPUESTO, corregible por elemento)
;;   ACU: -> 8 (red menor dominante; SUPUESTO)
;;   SAN: -> 8 (colector minimo; SUPUESTO)
;; ademas PLU sin material -> NOVAFORT
(defun c:FIXDIAMFALT (/ ss i en atts pini pfin d n-plu n-acu n-san ents red)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq n-plu 0 n-acu 0 n-san 0)
  ;; PLU
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_PLU_*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "DIAMETRO" atts "") "")
      (progn
        (setq pini (strcase (mp:getval "POZO_INI" atts ""))
              pfin (strcase (mp:getval "POZO_FIN" atts "")))
        (setq d
          (cond
            ((or (wcmatch pini "*TRAT*") (wcmatch pfin "*TRAT*")) "24")
            (T "12")))
        (mp:setatts en (list (cons "DIAMETRO" d)
          (cons "MATERIAL"
            (if (= (mp:getval "MATERIAL" atts "") "")
              "NOVAFORT" (mp:getval "MATERIAL" atts "NOVAFORT")))))
        (setq n-plu (1+ n-plu)))))
  ;; ACU
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "DIAMETRO" atts "") "")
      (progn
        (mp:setatts en (list (cons "DIAMETRO" "8")
          (cons "ETIQUETA" (mp:label-tramo "TRAMO_ACUEDUCTO"
            (mp:alist-set atts "DIAMETRO" "8")))))
        (setq n-acu (1+ n-acu)))))
  ;; SAN
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_SAN_*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (mp:getval "DIAMETRO" atts "") "")
      (progn
        (mp:setatts en (list (cons "DIAMETRO" "8")))
        (setq n-san (1+ n-san)))))
  (eq:log (strcat "FIXDIAMFALT: PLU " (itoa n-plu) " (CAB/DOM=12, TRAT=24, resto=12) | ACU "
    (itoa n-acu) " a 8 | SAN " (itoa n-san) " a 8 -- SUPUESTOS documentados"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))

;; subetapa vacia -> el codigo de la etapa (el SUMIFS del libro solo
;; mira SUBETAPA contra el encabezado de columna; "4" es una columna
;; valida junto a 4A..4E)
(defun c:FIXSUBVACIA (/ ss i en atts n ents)
  (setq *eq-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/equivfix.txt" "a"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT")
             (cons 2 "MP_TRAMO_*,MP_PUNTO_*,URB_VIA_*,URB_SENDERO_*"))) i 0 n 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (and (/= (mp:getval "ETAPA" atts "") "")
             (= (mp:getval "SUBETAPA" atts "") ""))
      (progn
        (mp:setatts en (list (cons "SUBETAPA" (mp:getval "ETAPA" atts ""))))
        (setq n (1+ n)))))
  (eq:log (strcat "FIXSUBVACIA: " (itoa n) " elementos con SUBETAPA=ETAPA"))
  (close *eq-f*) (setq *eq-f* nil)
  (princ))
