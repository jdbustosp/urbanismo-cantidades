;;; fix0907c.lsp - ADOPTAR la numeracion oficial del plano aprobado:
;;; REPOSACC3 empareja cada accesorio nuestro con el nodo del DISENO por
;;; POSICION EXACTA (<=0.10 m; ya validado que las posiciones coinciden)
;;; y de ese par confiable toma: ID = NODO oficial, DIAMETRO y
;;; DIAMETRO_SALIDA del diseno. NO mueve nada. La leccion de la pasada
;;; 2 (2026-09-07): nuestra numeracion vieja AC-### NO era el nodo del
;;; plano -- emparejar por numero movio 548 accesorios mal y se revirtio
;;; con backup; el par por posicion es el unico 1:1 confiable.
(defun fc3:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/pdf0907/ronda4c.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun fc3:familia (nm / up)
  (setq up (strcase nm))
  (cond
    ((vl-string-search "TEE" up) "TEE")
    ((vl-string-search "11.25" up) "C11")
    ((vl-string-search "22.5" up) "C22")
    ((vl-string-search "CODO90" up) "C90")
    ((vl-string-search "CODO 45" up) "C45")
    ((and (vl-string-search "CODO" up) (vl-string-search "45" up)) "C45")
    ((vl-string-search "TAPON" up) "TAP")
    ((vl-string-search "BUJE" up) "RDC")
    ((vl-string-search "VALVULA HIDRANTE" up) "VPH")
    ((vl-string-search "HIDRANTE" up) "HID")
    ((vl-string-search "VENTOSA" up) "VEN")
    ((vl-string-search "VALVULA PROY" up) "VAL")
    ((vl-string-search "UNION" up) "UNI")
    ((= up "VCP") "VCP")
    (T nil)))

(defun fc3:att-de (atxt tag / pos fin sub)
  (setq pos (vl-string-search (strcat tag "=") atxt))
  (if pos
    (progn
      (setq sub (substr atxt (+ pos (strlen tag) 2)))
      (setq fin (vl-string-search ";" sub))
      (if fin (substr sub 1 fin) sub))
    ""))

(defun fc3:parse-tsv (linea / out pos)
  (setq out nil)
  (while (setq pos (vl-string-search "\t" linea))
    (setq out (cons (substr linea 1 pos) out))
    (setq linea (substr linea (+ pos 2))))
  (reverse (cons linea out)))

;; diseno: lista (x y nodo fam d1 d2)
(defun fc3:cargar (/ f linea c fam nodo diam d1 d2 xpos plan)
  (setq plan nil)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/pdf0907/acu_diseno_atts.tsv" "r"))
  (if f
    (progn
      (read-line f)
      (while (setq linea (read-line f))
        (setq c (fc3:parse-tsv linea))
        (setq fam (fc3:familia (car c)))
        (if fam
          (progn
            (setq nodo (strcase (fc3:att-de (nth 3 c) "NODO")))
            (setq diam (fc3:att-de (nth 3 c) "DIAMETRO"))
            (if (= diam "") (setq diam (fc3:att-de (nth 3 c) "DIAM")))
            (setq d1 diam d2 "")
            (setq xpos (vl-string-search "X" (strcase diam)))
            (if xpos
              (setq d1 (substr diam 1 xpos)
                    d2 (substr diam (+ 2 xpos))))
            (setq plan (cons (list (distof (nth 1 c)) (distof (nth 2 c))
              nodo fam d1 d2) plan)))))
      (close f)))
  plan)

(defun c:REPOSACC3 (/ plan ss i en obj tok atts ed ip item best bd d n-id
                    n-diam n-sal n-sin n-dup usados cambios)
  (setq plan (fc3:cargar))
  (fc3:log (strcat "REPOSACC3: " (itoa (length plan))
    " nodos del diseno"))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU_*")))
        i 0 n-id 0 n-diam 0 n-sal 0 n-sin 0 n-dup 0 usados nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            obj (vlax-ename->vla-object en)
            tok (substr (strcase (vla-get-EffectiveName obj)) 18)
            atts (mp:att-alist en)
            ed (entget en)
            ip (cdr (assoc 10 ed)))
      ;; par por POSICION exacta y MISMA familia (una valvula pegada a
      ;; una tee a <10cm no debe adoptar el nodo de la otra)
      (setq best nil bd 1e9)
      (foreach item plan
        (if (= (nth 3 item) tok)
          (progn
            (setq d (distance (list (car ip) (cadr ip))
                              (list (car item) (cadr item))))
            (if (< d bd) (setq bd d best item)))))
      (if (and best (<= bd 0.10) (member best usados))
        (progn (setq n-dup (1+ n-dup)) (setq best nil)))
      (if (and best (<= bd 0.10)) (setq usados (cons best usados)))
      (if (or (null best) (> bd 0.10))
        (setq n-sin (1+ n-sin))
        (progn
          ;; OJO: mp:setatts -> mp:store-cant-data REEMPLAZA el XDATA con
          ;; el alist recibido; hay que pasar el registro COMPLETO mergeado
          ;; (mp:alist-set), nunca solo los pares cambiados.
          (setq cambios nil)
          ;; ID oficial del plano (solo numero, como el plano)
          (if (and (/= (nth 2 best) "")
                   (/= (strcase (mp:getval "ID" atts "")) (nth 2 best)))
            (progn
              (setq atts (mp:alist-set atts "ID" (nth 2 best)))
              (setq cambios T n-id (1+ n-id))))
          ;; diametros del diseno mandan
          (if (and (/= (nth 4 best) "")
                   (/= (strcase (mp:getval "DIAMETRO" atts ""))
                       (strcase (nth 4 best))))
            (progn
              (setq atts (mp:alist-set atts "DIAMETRO" (nth 4 best)))
              (setq cambios T n-diam (1+ n-diam))))
          (if (and (/= (nth 5 best) "")
                   (/= (strcase (mp:getval "DIAMETRO_SALIDA" atts ""))
                       (strcase (nth 5 best))))
            (progn
              (setq atts (mp:alist-set atts "DIAMETRO_SALIDA" (nth 5 best)))
              (setq cambios T n-sal (1+ n-sal))))
          (if cambios (mp:setatts en atts))))
      (setq i (1+ i))))
  (fc3:log (strcat "REPOSACC3: IDs adoptados del plano " (itoa n-id)
    " | diametros corregidos " (itoa n-diam)
    " | salidas corregidas " (itoa n-sal)
    " | sin par exacto " (itoa n-sin)
    " | nodo repetido " (itoa n-dup)))
  (princ))

;; re-etiquetado: usar c:RELABELACC de fix0907.lsp (mismo scr), que ya
;; pone ETIQUETA = solo numero + re-centrado (mp:level-etiqueta-atts).

;; censo de cabezales: que diametros hay en el modelo (el cruce por
;; numeros solo pega con 8/10/12/16/18/24 literales en el libro; un
;; O30 o intermedio caeria huerfano y hay que sumar fila de rango)
(defun c:CENSOCAB (/ ss i en atts d n lst par)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CABEZAL*")))
        i 0 lst nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            d (mp:getval "DIAMETRO" atts "(vacio)"))
      (setq par (assoc d lst))
      (if par
        (setq lst (subst (cons d (1+ (cdr par))) par lst))
        (setq lst (cons (cons d 1) lst)))
      (setq i (1+ i))))
  (setq n (if ss (sslength ss) 0))
  (fc3:log (strcat "CENSOCAB: " (itoa n) " cabezales"))
  (foreach par lst
    (fc3:log (strcat "  DIAMETRO [" (car par) "] x" (itoa (cdr par)))))
  (princ))
;; CABDIAM: los 67 cabezales del modelo tienen DIAMETRO vacio -> el
;; concepto desagregado no puede elegir fila de rango (censo ronda4c).
;; Heredar el DIAMETRO del extremo de tramo pluvial mas cercano (<=1 m);
;; usa f7:tramo-ends de fix0907.lsp (posicion+rotacion+longitud).
(defun c:CABDIAM (/ ss i en atts item pc best bd d ends n-fix n-vacio n-sin)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_PLU_*")))
        i 0 ends nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            d (mp:getval "DIAMETRO" atts ""))
      (setq item (f7:tramo-ends en))
      (setq ends (cons (list (nth 0 item) (nth 1 item) d) ends))
      (setq ends (cons (list (nth 2 item) (nth 3 item) d) ends))
      (setq i (1+ i))))
  (fc3:log (strcat "CABDIAM: " (itoa (length ends)) " extremos de tramo PLU"))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CABEZAL*")))
        i 0 n-fix 0 n-vacio 0 n-sin 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            pc (cdr (assoc 10 (entget en))))
      (if (= (mp:getval "DIAMETRO" atts "") "")
        (progn
          (setq best nil bd 1e9)
          (foreach item ends
            (setq d (distance (list (car pc) (cadr pc))
                              (list (car item) (cadr item))))
            (if (< d bd) (setq bd d best item)))
          (cond
            ((and best (<= bd 1.0) (/= (caddr best) ""))
              (mp:setatt-one en "DIAMETRO" (caddr best))
              (setq n-fix (1+ n-fix)))
            ((and best (<= bd 1.0)) (setq n-vacio (1+ n-vacio)))
            (T (setq n-sin (1+ n-sin))))))
      (setq i (1+ i))))
  (fc3:log (strcat "CABDIAM: heredados " (itoa n-fix)
    " | tramo sin diametro " (itoa n-vacio)
    " | sin tramo a <=1m " (itoa n-sin)))
  (princ))
;; NORMACC: normaliza DIAMETRO/DIAMETRO_SALIDA de los accesorios ACU
;; adoptados del plano: "06" -> "6" (el cero inicial rompe el match por
;; digitos del export) y "6 EMPATE LINEA" -> "6" (anotacion del plano al
;; log; el numero es lo unico que cruza con el libro).
(defun fe:diam-limpio (s / toks t1 resto)
  ;; devuelve (nuevo . anotacion) o nil si no hay que tocar
  (setq s (vl-string-trim " " s))
  (if (= s "") nil
    (progn
      (setq toks (fc3:parse-espacios s))
      (setq t1 (car toks))
      (if (fe:solo-digitos t1)
        (progn
          (while (and (> (strlen t1) 1) (= (substr t1 1 1) "0"))
            (setq t1 (substr t1 2)))
          (setq resto (fe:join-espacios (cdr toks)))
          (if (and (= t1 (car toks)) (= resto ""))
            nil                      ;; ya estaba limpio
            (cons t1 resto)))
        nil))))                      ;; no numerico: no tocar

(defun fe:solo-digitos (s / i ok)
  (setq i 1 ok (> (strlen s) 0))
  (while (and ok (<= i (strlen s)))
    (if (not (wcmatch (substr s i 1) "#")) (setq ok nil))
    (setq i (1+ i)))
  ok)

(defun fc3:parse-espacios (s / out pos)
  (setq out nil)
  (while (setq pos (vl-string-search " " s))
    (if (> pos 0) (setq out (cons (substr s 1 pos) out)))
    (setq s (substr s (+ pos 2))))
  (if (/= s "") (setq out (cons s out)))
  (reverse out))

(defun fe:join-espacios (toks / out)
  (setq out "")
  (foreach x toks
    (setq out (if (= out "") x (strcat out " " x))))
  out)

(defun c:NORMACC (/ ss i en atts d par cambio n-norm n-anot)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU_*")))
        i 0 n-norm 0 n-anot 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            cambio nil)
      (foreach tag '("DIAMETRO" "DIAMETRO_SALIDA")
        (setq d (mp:getval tag atts ""))
        (setq par (fe:diam-limpio d))
        (if par
          (progn
            (setq atts (mp:alist-set atts tag (car par)))
            (setq cambio T n-norm (1+ n-norm))
            (if (/= (cdr par) "")
              (progn
                (setq n-anot (1+ n-anot))
                (fc3:log (strcat "NORMACC anotacion del plano [" d
                  "] -> [" (car par) "] en "
                  (mp:getval "ID" atts "?") " ("
                  (mp:getval "TIPO_ACCESORIO" atts "?") ")")))))))
      (if cambio (mp:setatts en atts))
      (setq i (1+ i))))
  (fc3:log (strcat "NORMACC: " (itoa n-norm) " diametros normalizados ("
    (itoa n-anot) " con anotacion del plano)"))
  (princ))

;; CABDIAM2: solo cabezales que SIGUEN sin diametro, tolerancia 3 m
(defun c:CABDIAM2 (/ ss i en atts item pc best bd d ends n-fix n-sin)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_PLU_*")))
        i 0 ends nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            d (mp:getval "DIAMETRO" atts ""))
      (setq item (f7:tramo-ends en))
      (setq ends (cons (list (nth 0 item) (nth 1 item) d) ends))
      (setq ends (cons (list (nth 2 item) (nth 3 item) d) ends))
      (setq i (1+ i))))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CABEZAL*")))
        i 0 n-fix 0 n-sin 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            pc (cdr (assoc 10 (entget en))))
      (if (= (mp:getval "DIAMETRO" atts "") "")
        (progn
          (setq best nil bd 1e9)
          (foreach item ends
            (setq d (distance (list (car pc) (cadr pc))
                              (list (car item) (cadr item))))
            (if (< d bd) (setq bd d best item)))
          (if (and best (<= bd 3.0) (/= (caddr best) ""))
            (progn
              (mp:setatt-one en "DIAMETRO" (caddr best))
              (fc3:log (strcat "CABDIAM2: heredado [" (caddr best)
                "] a " (rtos bd 2 2) " m (handle "
                (cdr (assoc 5 (entget en))) ")"))
              (setq n-fix (1+ n-fix)))
            (progn
              (setq n-sin (1+ n-sin))
              (fc3:log (strcat "CABDIAM2: SIN tramo a <=3m (handle "
                (cdr (assoc 5 (entget en))) ", mas cercano "
                (if best (rtos bd 2 2) "n/a") " m)"))))))
      (setq i (1+ i))))
  (fc3:log (strcat "CABDIAM2: heredados " (itoa n-fix)
    " | sin par " (itoa n-sin)))
  (princ))
;; TIPOFIX: los 8 nodos que el plano anota como EMPATE (log NORMACC de
;; ronda4e) hoy tienen TIPO_ACCESORIO=OTRO/TEE y por las equivalencias
;; viejas caian a "Union de reparacion" / "Tee 6x6". El plano manda:
;; TIPO = "Empate a red existente" (OTRO) / "Empate en tee" (TEE).
;; El libro ya tiene la familia de filas de empate; las equivalencias
;; nuevas las siembra empates_cabezales_0907.ps1.
(defun c:TIPOFIX (/ mapa ss i en atts idv tipo par n)
  (setq mapa '(("144" . "Empate a red existente")
               ("114" . "Empate a red existente")
               ("183" . "Empate a red existente")
               ("79"  . "Empate a red existente")
               ("75A" . "Empate a red existente")
               ("1"   . "Empate a red existente")
               ("199" . "Empate en tee")
               ("217" . "Empate en tee")))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU_*")))
        i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            idv (strcase (mp:getval "ID" atts ""))
            tipo (strcase (mp:getval "TIPO_ACCESORIO" atts "")))
      (setq par (assoc idv mapa))
      (if (and par (member tipo '("OTRO" "TEE")))
        (progn
          (mp:setatt-one en "TIPO_ACCESORIO" (cdr par))
          (fc3:log (strcat "TIPOFIX nodo " idv ": " tipo " -> " (cdr par)))
          (setq n (1+ n))))
      (setq i (1+ i))))
  (fc3:log (strcat "TIPOFIX: " (itoa n) " accesorios de empate"))
  (princ))
(princ "\nfix0907c listo")(princ)
