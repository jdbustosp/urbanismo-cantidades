;;; limpiar_capas_viejas.lsp (2026-08-28) — migra TODO lo que quede en
;;; las capas viejas de redes a su capa canonica PPTO-* y purga las
;;; capas viejas. Independiente (no usa mp:*). Regla anti-crash del
;;; proyecto: recolectar primero, mutar despues (nunca mutar dentro de
;;; un vlax-for sobre la coleccion que se itera).
;;;
;;; Mapa fijo (capas con destino 1:1):
;;;   REDES-ACUEDUCTO        -> PPTO-ACUEDUCTO
;;;   ACCESORIOS-ACUEDUCTO   -> PPTO-ACCESORIOS-ACUEDUCTO
;;;   RED-ELECTRICA-MT       -> PPTO-ELECTRICA-MT
;;;   RED-ELECTRICA-BT-AP    -> PPTO-ELECTRICA-BT-AP
;;;   TEXTOS-CANTIDADES      -> PPTO-TEXTOS-CANTIDADES
;;; Mapa por bloque contenedor (capas ambiguas):
;;;   REDES-ALCANTARILLADO   -> PPTO-ALC-SANITARIO o PPTO-ALC-PLUVIAL
;;;                             segun el bloque (ARESIDUAL/POZO_SAN ->
;;;                             sanitario; ALLUVIAS/POZO_PLU/SUMIDERO ->
;;;                             pluvial; suelto -> sanitario)
;;;   EQUIPOS-ELECTRICOS y PPTO-EQUIPOS-ELECTRICOS ->
;;;                             PPTO-ELECTRICA-MT o -BT-AP segun bloque
;;;                             (misma regla de mp:point-layer 08-26)

(defun lcv:log (msg)
  (princ (strcat "\n[LCV] " msg))
  (if *lcv-file* (write-line msg *lcv-file*))
  (princ))

(defun lcv:fixed-target (layer)
  (cdr (assoc (strcase layer)
    '(("REDES-ACUEDUCTO" . "PPTO-ACUEDUCTO")
      ("ACCESORIOS-ACUEDUCTO" . "PPTO-ACCESORIOS-ACUEDUCTO")
      ("RED-ELECTRICA-MT" . "PPTO-ELECTRICA-MT")
      ("RED-ELECTRICA-BT-AP" . "PPTO-ELECTRICA-BT-AP")
      ("TEXTOS-CANTIDADES" . "PPTO-TEXTOS-CANTIDADES")))))

(defun lcv:ambiguous-p (layer)
  (member (strcase layer)
    '("REDES-ALCANTARILLADO" "EQUIPOS-ELECTRICOS" "PPTO-EQUIPOS-ELECTRICOS")))

;; destino de una capa ambigua segun el nombre del bloque que la contiene
;; (owner = nombre de la definicion de bloque, o nil si esta suelta)
(defun lcv:ambiguous-target (layer owner / o)
  (setq o (if owner (strcase owner) ""))
  (cond
    ((= (strcase layer) "REDES-ALCANTARILLADO")
      (cond
        ((wcmatch o "*ALLUVIAS*,*POZO_PLUVIAL*,*SUMIDERO*") "PPTO-ALC-PLUVIAL")
        (T "PPTO-ALC-SANITARIO")))
    (T ;; EQUIPOS-ELECTRICOS / PPTO-EQUIPOS-ELECTRICOS
      (cond
        ((wcmatch o "*CS276*,*CS280*,*CS281*,*SUBESTACION_E*,*CDMT_E*,*PUNTO_CONEXION_E*,*TRAMO_E_MT*")
          "PPTO-ELECTRICA-MT")
        (T "PPTO-ELECTRICA-BT-AP")))))

(defun lcv:target (layer owner)
  (cond
    ((lcv:fixed-target layer))
    ((lcv:ambiguous-p layer) (lcv:ambiguous-target layer owner))
    (T nil)))

(defun lcv:old-layer-p (layer)
  (or (lcv:fixed-target layer) (lcv:ambiguous-p layer)))

(defun lcv:ensure-layer (doc name color / layers lay)
  (setq layers (vla-get-Layers doc))
  (if (not (tblsearch "LAYER" name))
    (progn
      (setq lay (vla-Add layers name))
      (vla-put-Color lay color)))
  name)

;; re-capa una entidad si esta en capa vieja; tambien sus atributos si
;; es un INSERT (los ATTRIB tienen capa propia). Devuelve cuantas migró.
(defun lcv:fix-entity (ent owner / n lay tgt atts att alay atgt)
  (setq n 0)
  (setq lay (vl-catch-all-apply 'vla-get-Layer (list ent)))
  (if (and (not (vl-catch-all-error-p lay)) (lcv:old-layer-p lay))
    (progn
      (setq tgt (lcv:target lay owner))
      (if (and tgt
            (not (vl-catch-all-error-p
              (vl-catch-all-apply 'vla-put-Layer (list ent tgt)))))
        (setq n (1+ n)))))
  ;; atributos de los INSERT (referencias, no definiciones)
  (if (= "AcDbBlockReference" (vlax-get-property ent 'ObjectName))
    (progn
      (setq atts (vl-catch-all-apply 'vlax-invoke (list ent 'GetAttributes)))
      (if (not (vl-catch-all-error-p atts))
        (foreach att atts
          (setq alay (vl-catch-all-apply 'vla-get-Layer (list att)))
          (if (and (not (vl-catch-all-error-p alay)) (lcv:old-layer-p alay))
            (progn
              (setq atgt (lcv:target alay owner))
              (if (and atgt
                    (not (vl-catch-all-error-p
                      (vl-catch-all-apply 'vla-put-Layer (list att atgt)))))
                (setq n (1+ n)))))))))
  n)

(defun c:LIMPIARCAPASVIEJAS (/ doc blocks blk-names bname blk ent total
                               cnt layers lay-del old dead purged fails owner)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq *lcv-file*
    (open "C:/Users/jdbus/Documents/URBANISMO/work/limpiar_capas_result.txt" "w"))
  (setq total 0)

  ;; capas destino garantizadas
  (lcv:ensure-layer doc "PPTO-ACUEDUCTO" 5)
  (lcv:ensure-layer doc "PPTO-ALC-SANITARIO" 1)
  (lcv:ensure-layer doc "PPTO-ALC-PLUVIAL" 3)
  (lcv:ensure-layer doc "PPTO-ELECTRICA-MT" 6)
  (lcv:ensure-layer doc "PPTO-ELECTRICA-BT-AP" 2)
  (lcv:ensure-layer doc "PPTO-ACCESORIOS-ACUEDUCTO" 4)
  (lcv:ensure-layer doc "PPTO-TEXTOS-CANTIDADES" 7)

  ;; 1) RECOLECTAR nombres de todas las definiciones de bloque (sin
  ;;    mutar dentro del vlax-for sobre Blocks)
  (setq blocks (vla-get-Blocks doc) blk-names nil)
  (vlax-for blk blocks
    (setq blk-names (cons (vla-get-Name blk) blk-names)))
  (lcv:log (strcat "Definiciones de bloque a revisar: "
             (itoa (length blk-names))))

  ;; 2) MUTAR: por cada definicion (incluye *Model_Space y *Paper_Space*
  ;;    porque tambien son items de Blocks), re-capar sus entidades.
  ;;    owner = nombre del bloque para resolver capas ambiguas; para
  ;;    model/paper space el owner es nil (entidades sueltas).
  (foreach bname blk-names
    (setq blk (vl-catch-all-apply 'vla-Item (list blocks bname)))
    (if (not (vl-catch-all-error-p blk))
      (progn
        (setq owner (if (wcmatch (strcase bname) "`*MODEL_SPACE*,`*PAPER_SPACE*")
                      nil bname))
        (setq cnt 0)
        (vlax-for ent blk
          (setq cnt (+ cnt (lcv:fix-entity ent owner))))
        (if (> cnt 0)
          (lcv:log (strcat "  " bname ": " (itoa cnt) " entidad(es) migradas")))
        (setq total (+ total cnt)))))
  (lcv:log (strcat "TOTAL entidades/atributos migrados: " (itoa total)))

  ;; 3) PURGAR las capas viejas (recolectar -> mutar)
  (setq old '("REDES-ACUEDUCTO" "ACCESORIOS-ACUEDUCTO" "REDES-ALCANTARILLADO"
              "RED-ELECTRICA-MT" "RED-ELECTRICA-BT-AP" "EQUIPOS-ELECTRICOS"
              "PPTO-EQUIPOS-ELECTRICOS" "TEXTOS-CANTIDADES"))
  (setq layers (vla-get-Layers doc) dead nil purged nil fails nil)
  (foreach lay-del old
    (if (tblsearch "LAYER" lay-del)
      (setq dead (cons lay-del dead))))
  (foreach lay-del dead
    (if (vl-catch-all-error-p
          (vl-catch-all-apply
            '(lambda (nm) (vla-Delete (vla-Item layers nm))) (list lay-del)))
      (setq fails (cons lay-del fails))
      (setq purged (cons lay-del purged))))
  (lcv:log (strcat "Capas purgadas: "
             (if purged (apply 'strcat
               (mapcar '(lambda (x) (strcat x " ")) purged)) "(ninguna)")))
  (if fails
    (lcv:log (strcat "NO se pudieron purgar (siguen referenciadas): "
               (apply 'strcat (mapcar '(lambda (x) (strcat x " ")) fails))))
    (lcv:log "Todas las capas viejas quedaron eliminadas."))
  (lcv:log "LISTO-LCV")
  (close *lcv-file*)
  (setq *lcv-file* nil)
  (princ))
(princ "\nlimpiar_capas_viejas cargado. Comando: LIMPIARCAPASVIEJAS")
(princ)
