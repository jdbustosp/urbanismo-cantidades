;; REPARACION MT DEL MASTER (2026-08-26, pedido del usuario: "corrige
;; media tension en el plano original, solo MT; deja solo las
;; PROYECTADAS y borra las existentes").
;; FASE A: borrar los elementos MT del plugin que correspondan a red
;;   EXISTENTE del plano (caja con etiqueta "CS27x (E)" mas cercana;
;;   postes junto a texto "(E)"). Los tramos vienen todos de la capa
;;   "0_0 TUBERIA PROY" (proyectada) y se conservan.
;; FASE B: simbologia nueva EN SITIO (regla anti-zombi: nunca purgar y
;;   recrear el mismo nombre): cajas replica del plano + "276"/numero,
;;   tramos franja 0.20 borde a borde + ducteria/L=, capa unica MT.
;; Todo con actualizaciones ligeras por instancia y UN solo regen final
;; (regla de tiempos 2026-08-26).
(vl-load-com)
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")

(defun rm:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/reparar_mt_master_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun rm:att-set (obj tag val rot pt / a done)
  ;; escribe un atributo por tag; opcionalmente rot/punto (nil = no tocar)
  (setq done nil)
  (foreach a (vlax-invoke obj 'GetAttributes)
    (if (and (not done) (= (strcase (vla-get-TagString a)) tag))
      (progn
        (if val (vla-put-TextString a val))
        (if rot (vla-put-Rotation a rot))
        (if pt
          (progn
            (vl-catch-all-apply 'vla-put-TextAlignmentPoint (list a (mp:3d pt)))
            (vl-catch-all-apply 'vla-put-InsertionPoint (list a (mp:3d pt)))))
        (setq done T))))
  done)

(defun rm:att-get (obj tag / a out)
  (setq out "")
  (foreach a (vlax-invoke obj 'GetAttributes)
    (if (= (strcase (vla-get-TagString a)) tag)
      (setq out (vla-get-TextString a))))
  out)

(defun rm:solo-dig (s / i c out)
  (setq out "" i 1 s (if s s ""))
  (repeat (strlen s)
    (setq c (substr s i 1))
    (if (wcmatch c "#") (setq out (strcat out c)))
    (setq i (1+ i)))
  out)

(defun rm:num-de-id (id / p)
  (setq p (vl-string-position (ascii "-") id 0 T))
  (if p (substr id (+ p 2)) id))

(defun rm:dist-de-nombre (nombre / pos sub)
  (setq pos (vl-string-search "MT_" nombre))
  (setq sub (substr nombre (+ pos 4)))
  (atof (vl-string-translate "_" "." sub)))

(defun c:REPARARMTMASTER (/ f lin parts p txt etqs rots e-txts ss n i e obj ip
                          best bd d marca borradas conservadas sinetq
                          post-borr blks nb blk on borrar r cnt pos att th
                          distv nombres capa hh tipo cajas cj)
  (rm:log "== REPARAR MT MASTER: inicio ==")
  (setq capa "PPTO-ELECTRICA-MT")
  ;; ---------- datos del plano: etiquetas de caja (E/P) y rotaciones
  (setq etqs nil rots nil e-txts nil)
  (setq f (open (strcat lr:dir "data_SRC_SERIE1.txt") "r"))
  (while (setq lin (read-line f))
    (cond
      ((wcmatch lin "TXT|*")
        (setq parts (lr:split lin "|"))
        (setq txt (nth 3 parts))
        (if (null txt) (setq txt ""))
        (setq p (lr:parse-pt (nth 2 parts)))
        (if p
          (progn
            (if (wcmatch txt "*CS27*,*CS28*")
              (setq etqs
                (cons (list (car p) (cadr p)
                  (cond ((vl-string-search "(E)" txt) "E")
                        ((vl-string-search "(P)" txt) "P")
                        (T nil)))
                  etqs)))
            ;; rotulos de POSTE existente: MTEXT con codigos de formato,
            ;; el texto real va tras un ';' -> "...;P5(E)\PLA-202"
            (if (wcmatch txt "*;P#(E)*,*;P##(E)*,P#(E)*,P##(E)*")
              (setq e-txts (cons p e-txts))))))
      ((wcmatch lin "BLK|0_0 CAJAS|*")
        (setq parts (lr:split lin "|"))
        (setq p (lr:parse-pt (nth 3 parts)))
        (if p (setq rots (cons (list (car p) (cadr p) (atof (nth 4 parts))) rots))))))
  (close f)
  (rm:log (strcat "Etiquetas de caja: " (itoa (length etqs))
    " | textos (E): " (itoa (length e-txts))
    " | rotaciones: " (itoa (length rots))))
  ;; ---------- FASE A: borrar cajas EXISTENTES
  ;; direccion correcta (v2): cada ETIQUETA del plano se asigna a su caja
  ;; mas cercana (radio 8 m) -- la etiqueta esta retirada del simbolo y el
  ;; barrido caja->etiqueta con radio corto dejaba 234 cajas "sin etiqueta"
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CAMARA*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (setq cajas nil)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ip (cdr (assoc 10 (entget e))))
    ;; (ename x y marca-asignada dist-marca)
    (setq cajas (cons (list e (car ip) (cadr ip) nil 1e9) cajas))
    (setq i (1+ i)))
  (foreach r etqs
    (if (caddr r)
      (progn
        (setq best nil bd 8.0)
        (foreach cj cajas
          (setq d (sqrt (+ (expt (- (car r) (cadr cj)) 2)
                           (expt (- (cadr r) (caddr cj)) 2))))
          (if (< d bd) (setq bd d best cj)))
        (if (and best (< bd (nth 4 best)))
          (setq cajas
            (subst
              (list (car best) (cadr best) (caddr best) (caddr r) bd)
              best cajas))))))
  (setq borradas 0 conservadas 0 sinetq 0)
  (foreach cj cajas
    (cond
      ((= (nth 3 cj) "E") (entdel (car cj)) (setq borradas (1+ borradas)))
      ((null (nth 3 cj)) (setq sinetq (1+ sinetq) conservadas (1+ conservadas)))
      (T (setq conservadas (1+ conservadas)))))
  (rm:log (strcat "Cajas: " (itoa borradas) " EXISTENTES borradas, "
    (itoa conservadas) " conservadas (" (itoa sinetq) " sin etiqueta asignada)"))
  ;; postes con rotulo "P#(E)" cercano (radio 10) -> existentes -> borrar
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_POSTE*"))))
  (setq n (if ss (sslength ss) 0) i 0 post-borr 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ip (cdr (assoc 10 (entget e))))
    (setq bd 10.0 best nil)
    (foreach p e-txts
      (setq d (sqrt (+ (expt (- (car p) (car ip)) 2)
                       (expt (- (cadr p) (cadr ip)) 2))))
      (if (< d bd) (setq bd d best p)))
    (if best (progn (entdel e) (setq post-borr (1+ post-borr))))
    (setq i (1+ i)))
  (rm:log (strcat "Postes: " (itoa post-borr) " existentes borrados de " (itoa n)))
  ;; ---------- FASE B1: definiciones de caja -> simbologia del plano
  (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
  (foreach nb '(("MP_PUNTO_CAMARA_CS276" "CAMARA_CS276" 0.85)
                ("MP_PUNTO_CAMARA_CS280" "CAMARA_CS280" 1.0))
    (setq r (vl-catch-all-apply 'vla-Item (list blks (car nb))))
    (if (not (vl-catch-all-error-p r))
      (progn
        (setq blk r borrar nil hh (caddr nb))
        (vlax-for e blk
          (setq on (vla-get-ObjectName e))
          (cond
            ((member on '("AcDbPolyline" "AcDbCircle"))
              (setq borrar (cons e borrar)))
            ((= on "AcDbAttributeDefinition")
              (vla-put-Layer e capa)
              (if (= (strcase (vla-get-TagString e)) "ETIQUETA")
                (progn
                  (vla-put-Height e 0.6)
                  (mp:center-visible-att e (list 0.0 (+ hh 0.45) 0.0) 0.6))))))
        (foreach e borrar (vl-catch-all-apply 'vla-Delete (list e)))
        (mp:caja-plan-geom blk (cadr nb) capa 6)
        ;; NUM_VIS solo si no existe ya
        (setq att nil)
        (vlax-for e blk
          (if (and (= (vla-get-ObjectName e) "AcDbAttributeDefinition")
                   (= (strcase (vla-get-TagString e)) "NUM_VIS"))
            (setq att e)))
        (if (null att)
          (mp:center-visible-att
            (mp:vla-add-att blk "NUM_VIS" "Numero de caja" ""
              (list 0.0 (- (+ hh 0.5)) 0.0) 0.6 nil capa 6)
            (list 0.0 (- (+ hh 0.5)) 0.0) 0.6))
        (vl-cmdf "_.ATTSYNC" "_N" (car nb))
        (rm:log (strcat "def " (car nb) " re-simbolizada + ATTSYNC")))))
  ;; ---------- FASE B2: definiciones de tramo MT -> franja delgada al borde
  (setq nombres nil)
  (vlax-for blk blks
    (setq nb (vla-get-Name blk))
    (if (wcmatch nb "MP_TRAMO_MT_*") (setq nombres (cons nb nombres))))
  (setq cnt 0)
  (foreach nb nombres
    (setq blk (vla-Item blks nb))
    (setq distv (rm:dist-de-nombre nb))
    (setq att nil)
    (vlax-for e blk
      (setq on (vla-get-ObjectName e))
      (cond
        ((= on "AcDbPolyline")
          (vl-catch-all-apply 'vla-put-ConstantWidth (list e 0.20))
          ;; 2026-08-26 FIX: x0=-1.0/x1=distv+1.0 sumaba una extension
          ;; EXTRA de 1.0 m en cada lado, encima del gap=1.0 que
          ;; mp:insert-cant-tramo YA aplica en la insercion -- daba
          ;; 2.0 m de hueco real en vez de 1.0 (medido exacto en el
          ;; master, ver fix_mt_gap.lsp). La convencion correcta es
          ;; 0.0/distv (igual que fix_ap_defs.lsp, que nunca tuvo el bug).
          (setq r (entget (vlax-vla-object->ename e)))
          (setq r (subst (cons 10 (list 0.0 0.0)) (assoc 10 r) r))
          (entmod
            (reverse
              (subst (cons 10 (list distv 0.0))
                (assoc 10 (reverse r)) (reverse r)))))
        ((= on "AcDbAttributeDefinition")
          (setq th (vla-get-Height e))
          (if (> th 0.9) (vla-put-Height e 0.9))
          (if (= (strcase (vla-get-TagString e)) "NUM_VIS") nil)
          (if (= (strcase (vla-get-TagString e)) "LONG_VIS") (setq att e)))))
    (if (null att)
      (mp:center-visible-att
        (mp:vla-add-att blk "LONG_VIS" "Longitud visible" ""
          (list (/ distv 2.0) -1.25 0.0) 0.9 nil capa 6)
        (list (/ distv 2.0) -1.25 0.0) 0.9))
    (vl-cmdf "_.ATTSYNC" "_N" nb)
    (setq cnt (1+ cnt)))
  (rm:log (strcat "Defs de tramo MT reparadas: " (itoa cnt)))
  ;; ---------- FASE B3: instancias de caja (rotacion, etiquetas, capa)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CAMARA*"))))
  (setq n (if ss (sslength ss) 0) i 0 cnt 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq obj (vlax-ename->vla-object e))
    (setq ip (cdr (assoc 10 (entget e))))
    (setq hh (if (wcmatch (cdr (assoc 2 (entget e))) "*280*") 1.0 0.85))
    (setq best nil bd 0.5)
    (foreach r rots
      (setq d (sqrt (+ (expt (- (car r) (car ip)) 2)
                       (expt (- (cadr r) (cadr ip)) 2))))
      (if (< d bd) (setq bd d best (caddr r))))
    (if best (vla-put-Rotation obj best))
    (vla-put-Layer obj capa)
    (setq tipo (rm:solo-dig (rm:att-get obj "TIPO_CAJA")))
    (if (= tipo "")
      (setq tipo (if (= hh 1.0) "280" "276")))
    (rm:att-set obj "ETIQUETA" tipo 0.0
      (list (car ip) (+ (cadr ip) hh 0.45) 0.0))
    (rm:att-set obj "NUM_VIS" (rm:num-de-id (rm:att-get obj "ID")) 0.0
      (list (car ip) (- (cadr ip) hh 0.5) 0.0))
    (foreach att (vlax-invoke obj 'GetAttributes) (vla-put-Layer att capa))
    (setq cnt (1+ cnt))
    (setq i (1+ i)))
  (rm:log (strcat "Instancias de caja actualizadas: " (itoa cnt)))
  ;; subestaciones/trafos: solo capa unica
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_SUBESTACION*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (vla-put-Layer obj capa)
    (foreach att (vlax-invoke obj 'GetAttributes) (vla-put-Layer att capa))
    (setq i (1+ i)))
  (rm:log (strcat "Subestaciones/trafos a capa unica: " (itoa n)))
  ;; ---------- FASE B4: instancias de tramo (etiquetas nuevas)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_MT_*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (setq txt (vl-string-right-trim "\"" (rm:att-get obj "DIAM_DUCTO")))
    (rm:att-set obj "ETIQUETA"
      (strcat (rm:att-get obj "DUCTOS") "%%c" txt "\" "
        (rm:att-get obj "MATERIAL_DUCTO"))
      nil nil)
    (rm:att-set obj "LONG_VIS"
      (strcat "L=" (rm:att-get obj "LONGITUD")) nil nil)
    (setq i (1+ i)))
  (rm:log (strcat "Instancias de tramo MT re-etiquetadas: " (itoa n)))
  ;; ---------- verificacion + UN solo regen
  (setq blk (tblsearch "BLOCK" (car nombres)))
  (if blk
    (progn
      (setq e (cdr (assoc -2 blk)))
      (while e
        (setq r (entget e))
        (if (= (cdr (assoc 0 r)) "LWPOLYLINE")
          (rm:log (strcat "VERIF def " (car nombres) ": ancho="
            (rtos (cdr (assoc 43 r)) 2 3)
            " x-ini=" (rtos (cadr (assoc 10 r)) 2 3)
            " (esperado 0.20 / -1.00)")))
        (setq e (entnext e)))))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (rm:log "== REPARAR MT MASTER: TERMINADO =="))
(c:REPARARMTMASTER)
