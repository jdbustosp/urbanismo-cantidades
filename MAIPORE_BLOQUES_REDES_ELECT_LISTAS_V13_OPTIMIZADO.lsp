;;; MAIPORE_BLOQUES_REDES_ELECT_LISTAS_V13_OPTIMIZADO.lsp
;;; Urbanismo Interno Maipore - Captura y exportacion de cantidades PPTO
;;;
;;; Mejoras V13:
;;; - Codigo consolidado: una sola definicion por funcion y comando.
;;; - Reutilizacion de definiciones para reducir el crecimiento del DWG.
;;; - Cancelacion segura, longitud geometrica protegida y CSV con conteo.
;;; - Edicion unificada con el comando EDITAR.
;;; - Migracion de atributos existentes con el comando ACTUALIZAR.
;;; - Pendiente hidrosanitaria visible y actualizada por EDITAR.
;;;
;;; Flujo: cargue el LSP, ejecute MAIPORE_BLOQUES_REDES_ELECT,
;;; inserte cantidades, edite con EDITAR y exporte con QREDES_CSV.


(vl-load-com)

;; Desactiva comandos de edicion de versiones anteriores al recargar.
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDITAR_PPTO))
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDIT_CANTIDAD))
(vl-catch-all-apply 'vl-acad-undefun (list 'c:EDITAR_CANTIDAD))
(setq c:EDITAR_PPTO nil)
(setq c:EDIT_CANTIDAD nil)
(setq c:EDITAR_CANTIDAD nil)

(setq *mp-vis-width* 2.00) ; ancho visual del tramo
(setq *mp-vis-radius* 1.50) ; radio de circulos de inicio/fin
(setq *mp-vis-text-height* 1.50) ; altura de etiqueta y pendiente

(setq *mp-blocks*
  '("TRAMO_E_MT" "TRAMO_E_BT_AP" "CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"
    "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "LUMINARIA_AP" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E"
    "TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO" "POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"
    "ACCESORIO_ACUEDUCTO"))


(setq *mp-red-list* '("Aresidual" "Alluvias" "Acueducto"))
(setq *mp-extremo-hidro-list* '("NINGUNO" "POZO" "SUMIDERO"))
(setq *mp-extremo-elec-list* '("NINGUNO" "CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
(setq *mp-diam-alc-list* '("6" "8" "10" "12" "14" "15" "16" "18" "20" "24" "27" "30" "33" "36" "48" "51" "54" "64"))
(setq *mp-diam-acu-list* '("4" "6" "8" "10" "12" "18" "24"))
(setq *mp-material-acu-list* '("PVC" "WSP" "CCP" "PE" "ACERO" "HDPE" "OTRO"))
(setq *mp-material-red-list* '("PVC" "HDPE" "GRP" "CONCRETO" "ACERO" "OTRO"))
(setq *mp-acc-acu-list*
  '("TAPON" "TEE" "VALVULA_RED_MENOR" "VALVULA_VENTOSA" "VALVULA_PURGA" "REDUCCION"
    "CODO_90" "CODO_45" "CODO_22_5" "CODO_11_5" "VALVULA_REDUCTORA_PRESION"
    "VALVULA_CIERRE_PERMANENTE" "VALVULA_PIE_HIDRANTE" "HIDRANTE_TORRE" "NIPLE_PASAMUROS" "JUNTA_CONSTRUCCION" "OTRO"))
(setq *mp-cond-mt-list*
  '("3x70mm2 Al XLPE 15kV" "3x120mm2 Al XLPE 15kV" "3x150mm2 Cu XLPE 15kV"
    "3x185mm2 Al XLPE 15kV" "2(3x185mm2) Al XLPE 15kV" "3(3x185mm2) Al XLPE 15kV"
    "5(3x185mm2) Al XLPE 15kV" "3x240mm2 Al XLPE 15kV" "3x300mm2 Al XLPE 15kV"
    "2(3x300mm2) Al XLPE 15kV" "3x500mm2 Al XLPE 35kV" "3x2/0 ACSR" "3x4/0 ACSR" "OTRO"))
(setq *mp-ductos-list* '("1" "2" "3" "4" "5" "6" "9" "12"))
(setq *mp-diam-ducto-list* '("2\"" "3\"" "4\"" "6\""))
(setq *mp-mat-ducto-list* '("PVC" "IMC" "RMC" "EMT" "OTRO"))
(setq *mp-cond-bt-list* '("3x4+4 THW" "3x6+6 THW" "3x8+8 THW" "2x4 THW" "2x6 THW" "1x4 THW" "1x6 THW" "OTRO"))
(setq *mp-elem-elec-list* '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "LUMINARIA_AP" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E"))
(setq *mp-lum-list* '("RALED II" "AREALED II" "OTRA"))
(setq *mp-led-list* '("32 LED" "48 LED" "64 LED" "160 LED" "OTRO"))

(defun mp:layer (name color / doc layers lay)
  ;; Crea la capa o reactiva una existente para evitar bloques invisibles.
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))
  (setq lay
    (if (tblsearch "LAYER" name)
      (vla-Item layers name)
      (vla-Add layers name)))
  (vla-put-LayerOn lay :vlax-true)
  (vla-put-Lock lay :vlax-false)
  (vl-catch-all-apply 'vla-put-Freeze (list lay :vlax-false))
  (vla-put-Color lay color)
  lay)

(defun mp:setatts (ename alist / obj a tag pair changed)
  ;; Guarda y actualiza cada atributo; devuelve cuantos fueron modificados.
  (setq obj (vlax-ename->vla-object ename) changed 0)
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (foreach a (vlax-invoke obj 'GetAttributes)
      (setq tag (strcase (vla-get-TagString a)))
      (if (setq pair (assoc tag alist))
        (progn
          (vla-put-TextString a (mp:safe-str (cdr pair)))
          (vla-Update a)
          (setq changed (1+ changed))))))
  (vla-Update obj)
  changed)

(defun mp:getval (tag vals def / a)
  (setq a (assoc tag vals))
  (if (and a (/= (cdr a) "")) (cdr a) def))

(defun mp:safe-str (x) (if (null x) "" (vl-princ-to-string x)))
(defun mp:reset-dialog-capture ()
  (setq *mp-dialog-values* nil)
  (setq *mp-dialog-values-active* nil))

(defun mp:capture-dialog-values (/ keys key value result)
  ;; DCL deja de exponer get_tile despues de done_dialog. Capture antes de cerrar.
  (setq keys
    '("red" "blk" "tipo" "acc" "etapa" "subetapa" "tipo_ini" "tipo_fin"
      "pini" "pfin" "diam" "diamsal" "mat" "long" "pend"
      "ctni" "ctnf" "ccini" "ccfin" "ctn" "cclave"
      "serie" "circuito" "desde" "hasta" "cond" "ductos"
      "diamducto" "matducto" "libres" "prof" "id" "lote"
      "cd" "pf" "lum" "led" "altura" "brazo" "avance"))
  (setq result nil)
  (foreach key keys
    (setq value (vl-catch-all-apply 'get_tile (list key)))
    (if (not (vl-catch-all-error-p value))
      (setq result (cons (cons key (if value value "")) result))))
  (setq *mp-dialog-values* result)
  (setq *mp-dialog-values-active* T)
  T)

(defun mp:gettile (key / pair v)
  (if (and *mp-dialog-values-active*
           (setq pair (assoc key *mp-dialog-values*)))
    (cdr pair)
    (progn
      (setq v (get_tile key))
      (if (null v) "" v))))

(defun mp:update-red-diam ()
  (if (= (mp:gettile "red") "2")
    (progn (mp:fill-popup "diam" *mp-diam-acu-list* 0) (mp:fill-popup "mat" *mp-material-acu-list* 0))
    (progn (mp:fill-popup "diam" *mp-diam-alc-list* 5) (mp:fill-popup "mat" *mp-material-red-list* 0))))

(defun mp:csv-safe (s / out i ch) (if (not s) (setq s "")) (setq out "" i 1) (while (<= i (strlen s)) (setq ch (substr s i 1)) (if (= ch "\"") (setq out (strcat out "\"\"")) (setq out (strcat out ch))) (setq i (1+ i))) (strcat "\"" out "\""))
(defun mp:att-alist (ename / obj atts res) (setq obj (vlax-ename->vla-object ename) res nil) (if (= (vla-get-HasAttributes obj) :vlax-true) (foreach a (vlax-invoke obj 'GetAttributes) (setq res (cons (cons (strcase (vla-get-TagString a)) (vla-get-TextString a)) res)))) res)

(setq *mp-cant-counter* 0)

(defun mp:starts-with (s pref / n)
  (setq s (strcase (mp:safe-str s)) pref (strcase pref) n (strlen pref))
  (and (>= (strlen s) n) (= (substr s 1 n) pref)))

(defun mp:3d (p)
  (vlax-3d-point (list (float (car p)) (float (cadr p)) (if (caddr p) (float (caddr p)) 0.0))))

(defun mp:var-dbls (lst)
  (vlax-make-variant
    (vlax-safearray-fill
      (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length lst))))
      (mapcar 'float lst))))

(defun mp:vla-add-att (blk tag prompt def pt h invisible lay col / att mode)
  ;; Modo 1 = invisible, 0 = normal. Son atributos editables con EATTEDIT.
  (setq mode (if invisible 1 0))
  (setq att (vla-AddAttribute blk (float h) mode prompt (mp:3d pt) tag (mp:safe-str def)))
  (vla-put-Layer att lay)
  (vla-put-Color att col)
  att)

(defun mp:center-visible-att (att pt height)
  ;; 10 = acAlignmentMiddleCenter.
  (vl-catch-all-apply 'vla-put-Height (list att (float height)))
  (vl-catch-all-apply 'vla-put-Alignment (list att 10))
  (vl-catch-all-apply 'vla-put-TextAlignmentPoint (list att (mp:3d pt)))
  att)

(defun mp:make-cant-tramo-block (blkname baseb dist vals / doc blks blk lay col w r th lab mid y pl ln c1 c2 cut)
  ;; V9: crea la definicin de bloque con ActiveX, no con INSERT de DWG externo.
  ;; Esto evita el error: Can't find file "CANT_TRAMO_....dwg".
  (vl-load-com)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq lay (mp:vis-layer baseb)
        col (mp:vis-color baseb)
        w   *mp-vis-width*
        r   *mp-vis-radius*
        th  *mp-vis-text-height*)
  (if (< w 0.50) (setq w 0.50))
  (if (< r 2.00) (setq r 2.00))
  (if (< th 0.50) (setq th 0.50))
  (setq lab (mp:label-tramo baseb vals))
  (setq blk (vla-Add blks (mp:3d '(0 0 0)) blkname))

  ;; La geometria conserva la longitud centro a centro, pero la franja
  ;; visible termina en el borde de los circulos de inicio y fin.
  (setq cut (min r (/ dist 4.0)))
  (setq pl
    (vla-AddLightWeightPolyline
      blk
      (mp:var-dbls (list cut 0.0 (- dist cut) 0.0))))
  (vla-put-Layer pl lay)
  (vla-put-Color pl col)
  (vla-put-ConstantWidth pl (float w))

  ;; Crculos en extremos.
  (setq c1 (vla-AddCircle blk (mp:3d '(0 0 0)) (float r)))
  (vla-put-Layer c1 lay)
  (vla-put-Color c1 col)
  (setq c2 (vla-AddCircle blk (mp:3d (list dist 0.0 0.0)) (float r)))
  (vla-put-Layer c2 lay)
  (vla-put-Color c2 col)

  ;; Etiqueta y pendiente centradas respecto al punto medio del tramo.
  (setq mid (list (/ dist 2.0) (* th 1.35) 0.0))
  (mp:center-visible-att
    (mp:vla-add-att blk "ETIQUETA" "Etiqueta visible" lab mid th nil lay col)
    mid
    th)
  (if (member baseb '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO"))
    (progn
      (setq mid (list (/ dist 2.0) (- (* th 1.35)) 0.0))
      (mp:center-visible-att
        (mp:vla-add-att
          blk
          "PENDIENTE_VIS"
          "Pendiente visible"
          (mp:pendiente-label vals)
          mid
          th
          nil
          lay
          col)
        mid
        th)))

  ;; Atributos invisibles de datos.
  (setq y (- (* th 1.25)))
  (mp:vla-add-att blk "BLOQUE_BASE" "Bloque base" baseb (list 0 y 0.0) 0.10 T lay col)
  (setq y (- y 0.20))
  (foreach a (mp:base-atts-for baseb)
    (mp:vla-add-att blk (car a) (cadr a) (if (caddr a) (caddr a) "") (list 0 y 0.0) 0.10 T lay col)
    (setq y (- y 0.20)))
  blkname)

(defun mp:ins-block-scaled (bname p1 p2 vals)
  (mp:insert-cant-tramo bname p1 p2 vals))

;; Ahora reconoce los bloques CANT_TRAMO_* como bloques de cantidad.
(defun mp:is-mp-block (en / obj b)
  (if (and en (= (cdr (assoc 0 (entget en))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq b (vla-get-EffectiveName obj))
      (mp:is-cant-blockname b))))

(defun mp:setatt-one (ename tag val / obj a)
  (setq obj (vlax-ename->vla-object ename))
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (foreach a (vlax-invoke obj 'GetAttributes)
      (if (= (strcase (vla-get-TagString a)) (strcase tag))
        (progn
          (vla-put-TextString a (mp:safe-str val))
          (vla-Update a)))))
  (vla-Update obj))


(setq *mp-etapa-list* '("1" "2" "3" "4" "5" "6" "7" "8" "9"))
(setq *mp-csv-tags*
  '("BLOQUE" "HANDLE" "LAYER" "X" "Y" "ID" "CODIGO" "ETAPA" "SUBETAPA" "RED" "TIPO_RED"
    "POZO_INI" "POZO_FIN" "COTA_TN_INI" "COTA_TN_FIN" "COTA_CLAVE_INI" "COTA_CLAVE_FIN"
    "DIAMETRO" "DIAMETRO_SALIDA" "MATERIAL" "LONGITUD" "PENDIENTE" "SERIE" "CIRCUITO" "CIRCUITO_AP"
    "DESDE" "HASTA" "CONDUCTORES" "CONDUCTOR" "CALIBRE" "MATERIAL_COND" "DUCTOS" "DIAM_DUCTO"
    "MATERIAL_DUCTO" "LIBRES" "PROFUNDIDAD" "TIPO_CAJA" "TIPO_LUMINARIA" "FUENTE_LED"
    "ALTURA_M" "BRAZO_M" "AVANCE_M" "TIPO_SE" "LOTE" "CD" "PF" "ENTRADAS" "SALIDAS" "CELDAS"
    "TIPO_ACCESORIO"))

(defun mp:subetapas-for (e)
  (cond
    ((= e "1") '("1"))
    ((= e "2") '("2"))
    ((= e "3") '("3" "3A" "3B"))
    ((= e "4") '("4" "4A" "4B" "4C" "4D" "4E"))
    ((= e "5") '("5A" "5B" "5C" "5D" "5E"))
    ((= e "6") '("6"))
    ((= e "7") '("7"))
    ((= e "8") '("8A" "8B" "8C"))
    ((= e "9") '("9A" "9B" "9C" "9D" "9E"))
    (T '("1"))))

(defun mp:update-subetapa ()
  (mp:fill-popup "subetapa" (mp:subetapas-for (mp:item *mp-etapa-list* "etapa")) 0))

(defun mp:ensure-layers ()
  ;; Capas nuevas de presupuesto: siempre con prefijo PPTO-
  (mp:layer "PPTO-ACUEDUCTO" 5)
  (mp:layer "PPTO-ALC-SANITARIO" 1)
  (mp:layer "PPTO-ALC-PLUVIAL" 3)
  (mp:layer "PPTO-ELECTRICA-MT" 6)
  (mp:layer "PPTO-ELECTRICA-BT-AP" 2)
  (mp:layer "PPTO-ACCESORIOS-ACUEDUCTO" 4)
  (mp:layer "PPTO-EQUIPOS-ELECTRICOS" 30)
  (mp:layer "PPTO-TEXTOS-CANTIDADES" 7)
  ;; Capas antiguas quedan solo por compatibilidad con bloques puntuales existentes.
  (mp:layer "RED-ELECTRICA-MT" 6)
  (mp:layer "RED-ELECTRICA-BT-AP" 2)
  (mp:layer "EQUIPOS-ELECTRICOS" 30)
  (mp:layer "REDES-ALCANTARILLADO" 1)
  (mp:layer "REDES-ACUEDUCTO" 5)
  (mp:layer "ACCESORIOS-ACUEDUCTO" 4)
  (mp:layer "TEXTOS-CANTIDADES" 7))

(defun mp:vis-layer (bname)
  (cond
    ((= bname "TRAMO_ACUEDUCTO") "PPTO-ACUEDUCTO")
    ((= bname "TRAMO_ALLUVIAS") "PPTO-ALC-PLUVIAL")
    ((= bname "TRAMO_ARESIDUAL") "PPTO-ALC-SANITARIO")
    ((= bname "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
    ((= bname "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
    (T "PPTO-TEXTOS-CANTIDADES")))

(defun mp:vis-color (bname)
  (cond
    ((= bname "TRAMO_ACUEDUCTO") 5) ; azul
    ((= bname "TRAMO_ALLUVIAS") 3) ; verde
    ((= bname "TRAMO_ARESIDUAL") 1) ; rojo
    ((= bname "TRAMO_E_MT") 6) ; magenta
    ((= bname "TRAMO_E_BT_AP") 2) ; amarillo
    (T 7)))

(defun mp:base-atts-for (bname)
  (cond
    ((= bname "TRAMO_E_MT")
      '(("SERIE" "Serie" "1") ("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("TIPO_RED" "Tipo red" "MT")
        ("CIRCUITO" "Circuito" "") ("DESDE" "Desde" "") ("HASTA" "Hasta" "")
        ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "") ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
        ("CONDUCTORES" "Conductores" "3x185mm2 Al XLPE 15kV") ("CONDUCTOR" "Conductor" "3x185mm2 Al XLPE 15kV")
        ("CALIBRE" "Calibre" "185mm2") ("MATERIAL_COND" "Material conductor" "Al XLPE")
        ("DUCTOS" "Ductos" "6") ("DIAM_DUCTO" "Diam ducto" "6\"") ("MATERIAL_DUCTO" "Material ducto" "PVC")
        ("LIBRES" "Ductos libres" "") ("LONGITUD" "Longitud m" "") ("PROFUNDIDAD" "Profundidad m" "")))
    ((= bname "TRAMO_E_BT_AP")
      '(("SERIE" "Serie" "6") ("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("TIPO_RED" "Tipo red" "BT/AP")
        ("CIRCUITO_AP" "Circuito AP" "") ("DESDE" "Desde" "") ("HASTA" "Hasta" "")
        ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "") ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
        ("CONDUCTOR" "Conductor" "3x4+4 THW") ("DUCTOS" "Ductos" "1") ("DIAM_DUCTO" "Diam ducto" "3\"")
        ("MATERIAL_DUCTO" "Material ducto" "PVC") ("LONGITUD" "Longitud m" "")))
    (T
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("RED" "Red" "")
        ("POZO_INI" "Nodo/pozo inicial" "") ("POZO_FIN" "Nodo/pozo final" "")
        ("TIPO_EXTREMO_INI" "Tipo extremo inicial" "") ("TIPO_EXTREMO_FIN" "Tipo extremo final" "")
        ("DIAMETRO" "Diametro" "") ("MATERIAL" "Material" "PVC") ("LONGITUD" "Longitud m" "")
        ("PENDIENTE" "Pendiente %" "")
        ("COTA_TN_INI" "Cota terreno ini" "") ("COTA_TN_FIN" "Cota terreno fin" "")
        ("COTA_CLAVE_INI" "Cota clave ini" "") ("COTA_CLAVE_FIN" "Cota clave fin" "")))) )

(defun mp:write-dcl (/ fn f)
  (mp:reset-dialog-capture)
  (setq fn (strcat (getvar "TEMPPREFIX") "maipore_listas_v10.dcl"))
  (setq f (open fn "w"))
  (write-line "maipore_tramo_red : dialog { label = \"Maipore - Tramo red PPTO\";" f)
  (write-line ": boxed_column { label = \"Datos de presupuesto\";" f)
  (write-line ": popup_list { label = \"Red\"; key = \"red\"; }" f)
  (write-line ": popup_list { label = \"Etapa\"; key = \"etapa\"; }" f)
  (write-line ": popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" f)
  (write-line ": edit_box { label = \"Nodo/pozo inicial\"; key = \"pini\"; edit_width = 20; }" f)
  (write-line ": edit_box { label = \"Nodo/pozo final\"; key = \"pfin\"; edit_width = 20; }" f)
  (write-line ": popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Diametro\"; key = \"diam\"; }" f)
  (write-line ": popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Pendiente %\"; key = \"pend\"; edit_width = 12; } }" f)
  (write-line ": boxed_column { label = \"Cotas\";" f)
  (write-line ": edit_box { label = \"Cota terreno inicial\"; key = \"ctni\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Cota terreno final\"; key = \"ctnf\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Cota clave inicial\"; key = \"ccini\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Cota clave final\"; key = \"ccfin\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "maipore_tramo_mt : dialog { label = \"Maipore - Tramo MT PPTO\"; : boxed_column {" f)
  (write-line ": edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" f)
  (write-line ": edit_box { label = \"Circuito\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; }" f)
  (write-line ": edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "maipore_tramo_bt : dialog { label = \"Maipore - Tramo BT/AP PPTO\"; : boxed_column {" f)
  (write-line ": edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" f)
  (write-line ": edit_box { label = \"Circuito AP/BT\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; }" f)
  (write-line ": popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } } ok_cancel; }" f)

  ;; Se mantienen los formularios de puntos/accesorios para compatibilidad con los comandos existentes.
  (write-line "maipore_elem_elec : dialog { label = \"Maipore - Elemento electrico\"; : boxed_column { : popup_list { label = \"Tipo elemento\"; key = \"blk\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 26; } : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Lote / circuito\"; key = \"lote\"; edit_width = 26; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 20; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 20; } : popup_list { label = \"Luminaria\"; key = \"lum\"; } : popup_list { label = \"Fuente LED\"; key = \"led\"; } : edit_box { label = \"Altura montaje m\"; key = \"altura\"; edit_width = 12; } : edit_box { label = \"Brazo m\"; key = \"brazo\"; edit_width = 12; } : edit_box { label = \"Avance m\"; key = \"avance\"; edit_width = 12; } } ok_cancel; }" f)
  (write-line "maipore_acc_acu : dialog { label = \"Maipore - Accesorio acueducto\"; : boxed_column { : popup_list { label = \"Tipo accesorio\"; key = \"acc\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : popup_list { label = \"Diametro principal\"; key = \"diam\"; } : popup_list { label = \"Diametro salida\"; key = \"diamsal\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Lote/Sector\"; key = \"lote\"; edit_width = 26; } } ok_cancel; }" f)
  (close f)
  fn)

(defun mp:dialog-tramo-red (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_red" dcl)) (exit))
  (mp:fill-popup "red" *mp-red-list* 0)
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:update-red-diam)
  (mp:fill-popup "tipo_ini" *mp-extremo-hidro-list* 1)
  (mp:fill-popup "tipo_fin" *mp-extremo-hidro-list* 1)
  (action_tile "red" "(mp:update-red-diam)")
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list
          (cons "REDOPT" (mp:item *mp-red-list* "red"))
          (cons "ETAPA" etapa)
          (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
          (cons "POZO_INI" (mp:gettile "pini"))
          (cons "POZO_FIN" (mp:gettile "pfin"))
          (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-hidro-list* "tipo_ini"))
          (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-hidro-list* "tipo_fin"))
          (cons "DIAMETRO" (if (= (mp:gettile "red") "2") (mp:item *mp-diam-acu-list* "diam") (mp:item *mp-diam-alc-list* "diam")))
          (cons "MATERIAL" (if (= (mp:gettile "red") "2") (mp:item *mp-material-acu-list* "mat") (mp:item *mp-material-red-list* "mat")))
          (cons "PENDIENTE" (mp:gettile "pend"))
          (cons "COTA_TN_INI" (mp:gettile "ctni"))
          (cons "COTA_TN_FIN" (mp:gettile "ctnf"))
          (cons "COTA_CLAVE_INI" (mp:gettile "ccini"))
          (cons "COTA_CLAVE_FIN" (mp:gettile "ccfin"))))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-tramo-mt (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_mt" dcl)) (exit))
  (set_tile "serie" "1")
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:fill-popup "cond" *mp-cond-mt-list* 3)
  (mp:fill-popup "ductos" *mp-ductos-list* 5)
  (mp:fill-popup "diamducto" *mp-diam-ducto-list* 3)
  (mp:fill-popup "matducto" *mp-mat-ducto-list* 0)
  (mp:fill-popup "tipo_ini" *mp-extremo-elec-list* 1)
  (mp:fill-popup "tipo_fin" *mp-extremo-elec-list* 1)
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "CIRCUITO" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
              (cons "CONDUCTORES" (mp:item *mp-cond-mt-list* "cond")) (cons "CONDUCTOR" (mp:item *mp-cond-mt-list* "cond"))
              (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos")) (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto"))
              (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto")) (cons "LIBRES" (mp:gettile "libres"))
              (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini"))
              (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-tramo-bt (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (not (new_dialog "maipore_tramo_bt" dcl)) (exit))
  (set_tile "serie" "6")
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (mp:fill-popup "cond" *mp-cond-bt-list* 0)
  (mp:fill-popup "ductos" *mp-ductos-list* 0)
  (mp:fill-popup "diamducto" *mp-diam-ducto-list* 1)
  (mp:fill-popup "matducto" *mp-mat-ducto-list* 0)
  (mp:fill-popup "tipo_ini" *mp-extremo-elec-list* 1)
  (mp:fill-popup "tipo_fin" *mp-extremo-elec-list* 1)
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "CIRCUITO_AP" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
              (cons "CONDUCTOR" (mp:item *mp-cond-bt-list* "cond")) (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos"))
              (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto")) (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini")) (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl)
  res)


(defun mp:point-layer (base)
  (cond
    ((= base "POZO_SANITARIO") "PPTO-ALC-SANITARIO")
    ((= base "POZO_PLUVIAL") "PPTO-ALC-PLUVIAL")
    ((= base "SUMIDERO") "PPTO-ALC-PLUVIAL")
    ((= base "ACCESORIO_ACUEDUCTO") "PPTO-ACCESORIOS-ACUEDUCTO")
    ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E")) "PPTO-EQUIPOS-ELECTRICOS")
    (T "PPTO-EQUIPOS-ELECTRICOS")))

(defun mp:point-color (base)
  (cond
    ((= base "POZO_SANITARIO") 1)
    ((= base "POZO_PLUVIAL") 3)
    ((= base "SUMIDERO") 3)
    ((= base "ACCESORIO_ACUEDUCTO") 5)
    ((= base "LUMINARIA_AP") 2)
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "POSTE_ELEC" "SUBESTACION_E" "CDMT_E" "TRANSFORMADOR_AP" "PUNTO_CONEXION_E")) 6)
    (T 7)))


(defun mp:base-atts-for-point (base)
  (cond
    ((member base '("POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO"))
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("RED" "Red" "")
        ("ID" "ID / Codigo" "") ("DIAMETRO" "Diametro" "")
        ("COTA_TN_INI" "Cota terreno" "") ("COTA_CLAVE_INI" "Cota clave" "")
        ("PROFUNDIDAD" "Profundidad" "")))
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_CAJA" "Tipo caja" "") ("DUCTOS" "Ductos" "") ("LIBRES" "Libres" "")
        ("PROFUNDIDAD" "Profundidad" "") ("CD" "CD" "") ("PF" "PF" "")))
    ((= base "ACCESORIO_ACUEDUCTO")
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_ACCESORIO" "Tipo accesorio" "") ("DIAMETRO" "Diametro principal" "")
        ("DIAMETRO_SALIDA" "Diametro salida" "") ("MATERIAL" "Material" "") ("LOTE" "Lote/Sector" "")))
    ((= base "LUMINARIA_AP")
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("CODIGO" "Codigo" "")
        ("TIPO_LUMINARIA" "Tipo luminaria" "") ("FUENTE_LED" "Fuente LED" "")
        ("ALTURA_M" "Altura montaje" "") ("BRAZO_M" "Brazo" "") ("AVANCE_M" "Avance" "") ("CIRCUITO_AP" "Circuito AP" "")))
    (T
      '(("ETAPA" "Etapa" "") ("SUBETAPA" "Subetapa" "") ("ID" "ID / Codigo" "")
        ("TIPO_RED" "Tipo red" "") ("LOTE" "Lote/Sector" "") ("CD" "CD" "") ("PF" "PF" "")
        ("ENTRADAS" "Entradas" "") ("SALIDAS" "Salidas" "") ("CELDAS" "Celdas" "")))) )


(defun mp:make-cant-punto-block (blkname base vals / doc blks blk lay col th r lab pl c y att pos)
  (vl-load-com)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq lay (mp:point-layer base) col (mp:point-color base) th *mp-vis-text-height* r *mp-vis-radius*)
  (if (< r 2.00) (setq r 2.00))
  (if (< th 0.50) (setq th 0.50))
  (setq lab (mp:label-point base vals))
  (setq blk (vla-Add blks (mp:3d '(0 0 0)) blkname))
  (cond
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281" "SUBESTACION_E" "CDMT_E"))
      (setq pl (vla-AddLightWeightPolyline blk (mp:var-dbls (list (- r) (- r) r (- r) r r (- r) r))))
      (vla-put-Closed pl :vlax-true) (vla-put-Layer pl lay) (vla-put-Color pl col) (vla-put-ConstantWidth pl (float (/ r 3.0))))
    ((= base "SUMIDERO")
      (setq pl (vla-AddLightWeightPolyline blk (mp:var-dbls (list (- r) 0.0 0.0 r r 0.0 0.0 (- r)))))
      (vla-put-Closed pl :vlax-true) (vla-put-Layer pl lay) (vla-put-Color pl col) (vla-put-ConstantWidth pl (float (/ r 3.0))))
    (T
      (setq c (vla-AddCircle blk (mp:3d '(0 0 0)) (float r)))
      (vla-put-Layer c lay) (vla-put-Color c col)))
  (if (member base '("POZO_SANITARIO" "POZO_PLUVIAL"))
    (progn
      (setq pos '(0.0 0.0 0.0))
      (setq att (mp:vla-add-att blk "ETIQUETA" "Numero de pozo" lab pos th nil lay col))
      (mp:center-visible-att att pos th))
    (mp:vla-add-att blk "ETIQUETA" "Etiqueta visible" lab (list (* r 1.5) (* r 1.5) 0.0) th nil lay col))
  (mp:vla-add-att blk "BLOQUE_BASE" "Bloque base" base (list 0 (- (* th 1.25)) 0.0) 0.10 T lay col)
  (setq y (- (* th 1.5)))
  (foreach a (mp:base-atts-for-point base)
    (mp:vla-add-att blk (car a) (cadr a) (if (caddr a) (caddr a) "") (list 0 y 0.0) 0.10 T lay col)
    (setq y (- y 0.20)))
  blkname)


(defun mp:write-dcl-puntos (/ fn f)
  (mp:reset-dialog-capture)
  (setq fn (strcat (getvar "TEMPPREFIX") "maipore_puntos_v11.dcl"))
  (setq f (open fn "w"))
  (write-line "maipore_punto_hidro : dialog { label = \"Maipore - Punto hidrosanitario\"; : boxed_column {" f)
  (write-line ": popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" f)
  (write-line ": edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro\"; key = \"diam\"; }" f)
  (write-line ": edit_box { label = \"Cota terreno\"; key = \"ctn\"; edit_width = 12; } : edit_box { label = \"Cota clave\"; key = \"cclave\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } } ok_cancel; }" f)
  (write-line "maipore_caja_elec : dialog { label = \"Maipore - Caja / camara electrica\"; : boxed_column {" f)
  (write-line ": popup_list { label = \"Tipo\"; key = \"tipo\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; }" f)
  (write-line ": edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : edit_box { label = \"Ductos\"; key = \"ductos\"; edit_width = 12; } : edit_box { label = \"Libres\"; key = \"libres\"; edit_width = 12; }" f)
  (write-line ": edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 14; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 14; } } ok_cancel; }" f)
  (close f)
  fn)

(defun mp:dialog-punto-hidro (red tipo / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-puntos)))
  (if (not (new_dialog "maipore_punto_hidro" dcl)) (exit))
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (if (= red "Acueducto") (mp:fill-popup "diam" *mp-diam-acu-list* 2) (mp:fill-popup "diam" *mp-diam-alc-list* 1))
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res
        (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "RED" red) (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (if (= red "Acueducto") (mp:item *mp-diam-acu-list* "diam") (mp:item *mp-diam-alc-list* "diam")))
              (cons "COTA_TN_INI" (mp:gettile "ctn")) (cons "COTA_CLAVE_INI" (mp:gettile "cclave")) (cons "PROFUNDIDAD" (mp:gettile "prof"))))))
  (unload_dialog dcl)
  res)

(defun mp:dialog-caja-electrica (/ dcl ok etapa res tipo)
  (setq dcl (load_dialog (mp:write-dcl-puntos)))
  (if (not (new_dialog "maipore_caja_elec" dcl)) (exit))
  (mp:fill-popup "tipo" '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281") 0)
  (mp:fill-popup "etapa" *mp-etapa-list* 0)
  (mp:update-subetapa)
  (action_tile "etapa" "(mp:update-subetapa)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq tipo (mp:item '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281") "tipo"))
      (setq res
        (list (cons "BLK" tipo) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "ID" (mp:gettile "id")) (cons "TIPO_CAJA" (cond ((= tipo "CAMARA_CS276") "CS276") ((= tipo "CAMARA_CS280") "CS280") (T "CS281")))
              (cons "DUCTOS" (mp:gettile "ductos")) (cons "LIBRES" (mp:gettile "libres")) (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "CD" (mp:gettile "cd")) (cons "PF" (mp:gettile "pf"))))))
  (unload_dialog dcl)
  res)

(defun mp:insert-tramo-forced (redopt / p1 p2 vals b)
  (mp:ensure-layers)
  (setq p1 (getpoint (strcat "\nPunto inicial tramo " redopt ": ")))
  (if p1 (setq p2 (getpoint p1 (strcat "\nPunto final tramo " redopt ": "))))
  (if (and p1 p2)
    (progn
      (setq vals (mp:dialog-tramo-red))
      (if vals
        (progn
          (setq vals (subst (cons "REDOPT" redopt) (assoc "REDOPT" vals) vals))
          (setq vals (append vals (list (cons "RED" redopt))))
          (setq b (cond ((= redopt "Acueducto") "TRAMO_ACUEDUCTO") ((= redopt "Alluvias") "TRAMO_ALLUVIAS") (T "TRAMO_ARESIDUAL")))
          (mp:ins-block-scaled b p1 p2 vals)
          (mp:insert-auto-endpoints b p1 p2 vals))))))


(defun mp:idx (val lst / i found)
  (setq i 0 found nil val (mp:safe-str val))
  (while (and lst (not found))
    (if (= (strcase val) (strcase (car lst)))
      (setq found i)
      (progn (setq i (1+ i)) (setq lst (cdr lst)))))
  (if found found 0))


(defun mp:attval (atts tag def / v)
  (setq v (cdr (assoc (strcase tag) atts)))
  (if (and v (/= v "")) v def))

(defun mp:subetapa-fill-current (/ etapa cur)
  (setq etapa (mp:item *mp-etapa-list* "etapa"))
  (setq cur (if (and (boundp '*mp-edit-subetapa-current*) *mp-edit-subetapa-current*) *mp-edit-subetapa-current* ""))
  (mp:fill-popup-val "subetapa" (mp:subetapas-for etapa) cur))

(defun mp:edit-layer-for-base (base)
  (cond
    ((= base "TRAMO_ACUEDUCTO") "PPTO-ACUEDUCTO")
    ((= base "TRAMO_ARESIDUAL") "PPTO-ALC-SANITARIO")
    ((= base "TRAMO_ALLUVIAS") "PPTO-ALC-PLUVIAL")
    ((= base "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
    ((= base "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
    ((= base "POZO_SANITARIO") "PPTO-ALC-SANITARIO")
    ((= base "POZO_PLUVIAL") "PPTO-ALC-PLUVIAL")
    ((= base "SUMIDERO") "PPTO-ALC-PLUVIAL")
    ((= base "ACCESORIO_ACUEDUCTO") "PPTO-ACCESORIOS-ACUEDUCTO")
    ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
    (T "PPTO-EQUIPOS-ELECTRICOS")))

(defun mp:write-dcl-editar (/ fn f)
  (mp:reset-dialog-capture)
  (setq fn (strcat (getvar "TEMPPREFIX") "maipore_editar_v12.dcl"))
  (setq f (open fn "w"))

  (write-line "edit_tramo_red : dialog { label = \"Editar PPTO - Tramo hidrosanitario\";" f)
  (write-line ": boxed_column { label = \"Clasificacion\"; : text { key = \"redtxt\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } }" f)
  (write-line ": boxed_column { label = \"Datos\"; : edit_box { label = \"Nodo/pozo inicial\"; key = \"pini\"; edit_width = 22; } : edit_box { label = \"Nodo/pozo final\"; key = \"pfin\"; edit_width = 22; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Diametro\"; key = \"diam\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } : edit_box { label = \"Pendiente %\"; key = \"pend\"; edit_width = 12; } }" f)
  (write-line ": boxed_column { label = \"Cotas\"; : edit_box { label = \"Cota terreno inicial\"; key = \"ctni\"; edit_width = 12; } : edit_box { label = \"Cota terreno final\"; key = \"ctnf\"; edit_width = 12; } : edit_box { label = \"Cota clave inicial\"; key = \"ccini\"; edit_width = 12; } : edit_box { label = \"Cota clave final\"; key = \"ccfin\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_tramo_mt : dialog { label = \"Editar PPTO - Media tension\"; : boxed_column { : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Circuito\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } : edit_box { label = \"Ductos libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_tramo_bt : dialog { label = \"Editar PPTO - Alumbrado / BT\"; : boxed_column { : edit_box { label = \"Serie\"; key = \"serie\"; edit_width = 8; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Circuito AP/BT\"; key = \"circuito\"; edit_width = 26; } : edit_box { label = \"Desde\"; key = \"desde\"; edit_width = 26; } : edit_box { label = \"Hasta\"; key = \"hasta\"; edit_width = 26; } : popup_list { label = \"Elemento inicial\"; key = \"tipo_ini\"; } : popup_list { label = \"Elemento final\"; key = \"tipo_fin\"; } : popup_list { label = \"Conductor\"; key = \"cond\"; } : popup_list { label = \"Ductos\"; key = \"ductos\"; } : popup_list { label = \"Diametro ducto\"; key = \"diamducto\"; } : popup_list { label = \"Material ducto\"; key = \"matducto\"; } : edit_box { label = \"Longitud\"; key = \"long\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_punto_hidro : dialog { label = \"Editar PPTO - Pozo / Sumidero\"; : boxed_column { : text { key = \"redtxt\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro\"; key = \"diam\"; } : edit_box { label = \"Cota terreno\"; key = \"ctn\"; edit_width = 12; } : edit_box { label = \"Cota clave\"; key = \"cclave\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } } ok_cancel; }" f)

  (write-line "edit_acc_acu : dialog { label = \"Editar PPTO - Accesorio acueducto\"; : boxed_column { : popup_list { label = \"Tipo accesorio\"; key = \"acc\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Diametro principal\"; key = \"diam\"; } : popup_list { label = \"Diametro salida\"; key = \"diamsal\"; } : popup_list { label = \"Material\"; key = \"mat\"; } : edit_box { label = \"Lote/Sector\"; key = \"lote\"; edit_width = 26; } } ok_cancel; }" f)

  (write-line "edit_caja_elec : dialog { label = \"Editar PPTO - Caja / camara electrica\"; : boxed_column { : popup_list { label = \"Tipo\"; key = \"tipo\"; } : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"ID / Codigo\"; key = \"id\"; edit_width = 24; } : edit_box { label = \"Ductos\"; key = \"ductos\"; edit_width = 12; } : edit_box { label = \"Libres\"; key = \"libres\"; edit_width = 12; } : edit_box { label = \"Profundidad\"; key = \"prof\"; edit_width = 12; } : edit_box { label = \"CD\"; key = \"cd\"; edit_width = 14; } : edit_box { label = \"PF\"; key = \"pf\"; edit_width = 14; } } ok_cancel; }" f)

  (write-line "edit_luminaria : dialog { label = \"Editar PPTO - Luminaria / equipo\"; : boxed_column { : popup_list { label = \"Etapa\"; key = \"etapa\"; } : popup_list { label = \"Subetapa\"; key = \"subetapa\"; } : edit_box { label = \"Codigo / ID\"; key = \"id\"; edit_width = 24; } : popup_list { label = \"Tipo luminaria\"; key = \"lum\"; } : popup_list { label = \"Fuente LED\"; key = \"led\"; } : edit_box { label = \"Altura montaje m\"; key = \"altura\"; edit_width = 12; } : edit_box { label = \"Brazo m\"; key = \"brazo\"; edit_width = 12; } : edit_box { label = \"Avance m\"; key = \"avance\"; edit_width = 12; } : edit_box { label = \"Circuito AP\"; key = \"circuito\"; edit_width = 24; } } ok_cancel; }" f)
  (close f)
  fn)

(defun mp:edit-dialog-tramo-red (atts base / dcl ok etapa red diamlist matlist res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_red" dcl)) (exit))
  (setq red (cond ((= base "TRAMO_ACUEDUCTO") "Acueducto") ((= base "TRAMO_ALLUVIAS") "Alluvias") (T "Aresidual")))
  (set_tile "redtxt" (strcat "Red fija del bloque: " red))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1"))
  (mp:subetapa-fill-current)
  (setq diamlist (if (= base "TRAMO_ACUEDUCTO") *mp-diam-acu-list* *mp-diam-alc-list*))
  (setq matlist (if (= base "TRAMO_ACUEDUCTO") *mp-material-acu-list* *mp-material-red-list*))
  (mp:fill-popup-val "diam" diamlist (mp:attval atts "DIAMETRO" ""))
  (mp:fill-popup-val "mat" matlist (mp:attval atts "MATERIAL" "PVC"))
  (set_tile "pini" (mp:attval atts "POZO_INI" "")) (set_tile "pfin" (mp:attval atts "POZO_FIN" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-hidro-list* (mp:attval atts "TIPO_EXTREMO_INI" "POZO"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-hidro-list* (mp:attval atts "TIPO_EXTREMO_FIN" "POZO"))
  (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1) (set_tile "pend" (mp:attval atts "PENDIENTE" ""))
  (set_tile "ctni" (mp:attval atts "COTA_TN_INI" "")) (set_tile "ctnf" (mp:attval atts "COTA_TN_FIN" ""))
  (set_tile "ccini" (mp:attval atts "COTA_CLAVE_INI" "")) (set_tile "ccfin" (mp:attval atts "COTA_CLAVE_FIN" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
  (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok
    (progn
      (setq etapa (mp:item *mp-etapa-list* "etapa"))
      (setq res (list (cons "RED" red) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                      (cons "POZO_INI" (mp:gettile "pini")) (cons "POZO_FIN" (mp:gettile "pfin"))
                      (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-hidro-list* "tipo_ini"))
                      (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-hidro-list* "tipo_fin"))
                      (cons "DIAMETRO" (mp:item diamlist "diam")) (cons "MATERIAL" (mp:item matlist "mat"))
                      (cons "PENDIENTE" (mp:gettile "pend"))
                      (cons "COTA_TN_INI" (mp:gettile "ctni"))
                      (cons "COTA_TN_FIN" (mp:gettile "ctnf")) (cons "COTA_CLAVE_INI" (mp:gettile "ccini"))
                      (cons "COTA_CLAVE_FIN" (mp:gettile "ccfin"))))))
  (unload_dialog dcl)
  res)

(defun mp:edit-dialog-tramo-mt (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_mt" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (set_tile "serie" (mp:attval atts "SERIE" "1"))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "circuito" (mp:attval atts "CIRCUITO" "")) (set_tile "desde" (mp:attval atts "DESDE" "")) (set_tile "hasta" (mp:attval atts "HASTA" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_INI" "CAMARA_CS276"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_FIN" "CAMARA_CS276"))
  (mp:fill-popup-val "cond" *mp-cond-mt-list* (mp:attval atts "CONDUCTOR" (mp:attval atts "CONDUCTORES" "")))
  (mp:fill-popup-val "ductos" *mp-ductos-list* (mp:attval atts "DUCTOS" "6"))
  (mp:fill-popup-val "diamducto" *mp-diam-ducto-list* (mp:attval atts "DIAM_DUCTO" "6\""))
  (mp:fill-popup-val "matducto" *mp-mat-ducto-list* (mp:attval atts "MATERIAL_DUCTO" "PVC"))
  (set_tile "libres" (mp:attval atts "LIBRES" "")) (set_tile "prof" (mp:attval atts "PROFUNDIDAD" "")) (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1)
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "TIPO_RED" "MT") (cons "CIRCUITO" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
                    (cons "CONDUCTORES" (mp:item *mp-cond-mt-list* "cond")) (cons "CONDUCTOR" (mp:item *mp-cond-mt-list* "cond"))
                    (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos")) (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto"))
                    (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto")) (cons "LIBRES" (mp:gettile "libres"))
                    (cons "PROFUNDIDAD" (mp:gettile "prof"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini"))
              (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-tramo-bt (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_tramo_bt" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (set_tile "serie" (mp:attval atts "SERIE" "6"))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "circuito" (mp:attval atts "CIRCUITO_AP" "")) (set_tile "desde" (mp:attval atts "DESDE" "")) (set_tile "hasta" (mp:attval atts "HASTA" ""))
  (mp:fill-popup-val "tipo_ini" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_INI" "CAMARA_CS276"))
  (mp:fill-popup-val "tipo_fin" *mp-extremo-elec-list* (mp:attval atts "TIPO_EXTREMO_FIN" "CAMARA_CS276"))
  (mp:fill-popup-val "cond" *mp-cond-bt-list* (mp:attval atts "CONDUCTOR" ""))
  (mp:fill-popup-val "ductos" *mp-ductos-list* (mp:attval atts "DUCTOS" "1"))
  (mp:fill-popup-val "diamducto" *mp-diam-ducto-list* (mp:attval atts "DIAM_DUCTO" "3\""))
  (mp:fill-popup-val "matducto" *mp-mat-ducto-list* (mp:attval atts "MATERIAL_DUCTO" "PVC"))
  (set_tile "long" (mp:attval atts "LONGITUD" "")) (mode_tile "long" 1)
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "SERIE" (mp:gettile "serie")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "TIPO_RED" "BT/AP") (cons "CIRCUITO_AP" (mp:gettile "circuito")) (cons "DESDE" (mp:gettile "desde")) (cons "HASTA" (mp:gettile "hasta"))
                    (cons "CONDUCTOR" (mp:item *mp-cond-bt-list* "cond")) (cons "DUCTOS" (mp:item *mp-ductos-list* "ductos"))
                    (cons "DIAM_DUCTO" (mp:item *mp-diam-ducto-list* "diamducto")) (cons "MATERIAL_DUCTO" (mp:item *mp-mat-ducto-list* "matducto"))
              (cons "TIPO_EXTREMO_INI" (mp:item *mp-extremo-elec-list* "tipo_ini")) (cons "TIPO_EXTREMO_FIN" (mp:item *mp-extremo-elec-list* "tipo_fin"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-punto-hidro (atts base / dcl ok etapa red diamlist res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_punto_hidro" dcl)) (exit))
  (setq red (mp:attval atts "RED" (cond ((= base "POZO_SANITARIO") "Aresidual") ((= base "POZO_PLUVIAL") "Alluvias") (T "Alluvias"))))
  (set_tile "redtxt" (strcat "Red fija del bloque: " red))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" ""))
  (setq diamlist (if (= red "Acueducto") *mp-diam-acu-list* *mp-diam-alc-list*))
  (mp:fill-popup-val "diam" diamlist (mp:attval atts "DIAMETRO" ""))
  (set_tile "ctn" (mp:attval atts "COTA_TN_INI" "")) (set_tile "cclave" (mp:attval atts "COTA_CLAVE_INI" "")) (set_tile "prof" (mp:attval atts "PROFUNDIDAD" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "RED" red) (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (mp:item diamlist "diam"))
                    (cons "COTA_TN_INI" (mp:gettile "ctn")) (cons "COTA_CLAVE_INI" (mp:gettile "cclave")) (cons "PROFUNDIDAD" (mp:gettile "prof"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-acc-acu (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_acc_acu" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "acc" *mp-acc-acu-list* (mp:attval atts "TIPO_ACCESORIO" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" ""))
  (mp:fill-popup-val "diam" *mp-diam-acu-list* (mp:attval atts "DIAMETRO" ""))
  (mp:fill-popup-val "diamsal" *mp-diam-acu-list* (mp:attval atts "DIAMETRO_SALIDA" ""))
  (mp:fill-popup-val "mat" *mp-material-acu-list* (mp:attval atts "MATERIAL" "PVC"))
  (set_tile "lote" (mp:attval atts "LOTE" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "TIPO_ACCESORIO" (mp:item *mp-acc-acu-list* "acc")) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "ID" (mp:gettile "id")) (cons "DIAMETRO" (mp:item *mp-diam-acu-list* "diam"))
                    (cons "DIAMETRO_SALIDA" (mp:item *mp-diam-acu-list* "diamsal")) (cons "MATERIAL" (mp:item *mp-material-acu-list* "mat"))
                    (cons "LOTE" (mp:gettile "lote"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-caja-elec (atts base / dcl ok etapa res typelist)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_caja_elec" dcl)) (exit))
  (setq typelist '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
  (mp:fill-popup-val "tipo" typelist base)
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "ID" "")) (set_tile "ductos" (mp:attval atts "DUCTOS" "")) (set_tile "libres" (mp:attval atts "LIBRES" ""))
  (set_tile "prof" (mp:attval atts "PROFUNDIDAD" "")) (set_tile "cd" (mp:attval atts "CD" "")) (set_tile "pf" (mp:attval atts "PF" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq base (mp:item typelist "tipo"))
    (setq res (list (cons "BLOQUE_BASE" base) (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "ID" (mp:gettile "id")) (cons "TIPO_CAJA" (cond ((= base "CAMARA_CS276") "CS276") ((= base "CAMARA_CS280") "CS280") (T "CS281")))
                    (cons "DUCTOS" (mp:gettile "ductos")) (cons "LIBRES" (mp:gettile "libres"))
                    (cons "PROFUNDIDAD" (mp:gettile "prof")) (cons "CD" (mp:gettile "cd")) (cons "PF" (mp:gettile "pf"))))))
  (unload_dialog dcl) res)

(defun mp:edit-dialog-luminaria (atts / dcl ok etapa res)
  (setq dcl (load_dialog (mp:write-dcl-editar)))
  (if (not (new_dialog "edit_luminaria" dcl)) (exit))
  (setq *mp-edit-subetapa-current* (mp:attval atts "SUBETAPA" ""))
  (mp:fill-popup-val "etapa" *mp-etapa-list* (mp:attval atts "ETAPA" "1")) (mp:subetapa-fill-current)
  (set_tile "id" (mp:attval atts "CODIGO" (mp:attval atts "ID" "")))
  (mp:fill-popup-val "lum" *mp-lum-list* (mp:attval atts "TIPO_LUMINARIA" ""))
  (mp:fill-popup-val "led" *mp-led-list* (mp:attval atts "FUENTE_LED" ""))
  (set_tile "altura" (mp:attval atts "ALTURA_M" "")) (set_tile "brazo" (mp:attval atts "BRAZO_M" "")) (set_tile "avance" (mp:attval atts "AVANCE_M" ""))
  (set_tile "circuito" (mp:attval atts "CIRCUITO_AP" ""))
  (action_tile "etapa" "(setq *mp-edit-subetapa-current* \"\")(mp:subetapa-fill-current)")
  (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)") (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
  (start_dialog)
  (if ok (progn (setq etapa (mp:item *mp-etapa-list* "etapa"))
    (setq res (list (cons "ETAPA" etapa) (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
                    (cons "CODIGO" (mp:gettile "id")) (cons "ID" (mp:gettile "id"))
                    (cons "TIPO_LUMINARIA" (mp:item *mp-lum-list* "lum")) (cons "FUENTE_LED" (mp:item *mp-led-list* "led"))
                    (cons "ALTURA_M" (mp:gettile "altura")) (cons "BRAZO_M" (mp:gettile "brazo")) (cons "AVANCE_M" (mp:gettile "avance"))
                    (cons "CIRCUITO_AP" (mp:gettile "circuito"))))))
  (unload_dialog dcl) res)


(defun c:EDITAR (/ sel en obj bname atts base vals saved)
  (setq sel (entsel "\nSeleccione bloque PPTO a editar: "))
  (if (and sel (setq en (car sel)) (= (cdr (assoc 0 (entget en))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq bname (vla-get-EffectiveName obj))
      (setq atts (mp:att-alist en))
      (setq base (mp:attval atts "BLOQUE_BASE" bname))
      (setq vals
        (cond
          ((member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO")) (mp:edit-dialog-tramo-red atts base))
          ((= base "TRAMO_E_MT") (mp:edit-dialog-tramo-mt atts))
          ((= base "TRAMO_E_BT_AP") (mp:edit-dialog-tramo-bt atts))
          ((member base '("POZO_SANITARIO" "POZO_PLUVIAL" "SUMIDERO")) (mp:edit-dialog-punto-hidro atts base))
          ((= base "ACCESORIO_ACUEDUCTO") (mp:edit-dialog-acc-acu atts))
          ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281")) (mp:edit-dialog-caja-elec atts base))
          ((= base "LUMINARIA_AP") (mp:edit-dialog-luminaria atts))
          (T nil)))
      (if vals
        (progn
          (setq saved (mp:update-block-after-edit en vals))
          (princ (strcat "\nBloque PPTO actualizado. Atributos guardados: " (itoa saved))))
        (princ "\nEste bloque no tiene formulario de edicion.")))
    (princ "\nNo selecciono un bloque valido."))
  (princ))

;;; ============================================================
;;; V13 OPTIMIZADA
;;; - Una sola implementacion activa, sin versiones concatenadas.
;;; - Reutiliza bloques de puntos por tipo.
;;; - Reutiliza bloques de tramos cuando tipo y longitud coinciden.
;;; - Cancelacion segura y formularios de elementos completos.
;;; - Conserva valores heredados que no existan en las listas.
;;; - LONGITUD se calcula desde la geometria y no se edita manualmente.
;;; ============================================================

(setq *mp-popup-lists* nil)

(defun mp:popup-list (key fallback / pair)
  (setq pair (assoc key *mp-popup-lists*))
  (if pair (cdr pair) fallback))

(defun mp:remember-popup (key lst / pair)
  (if (setq pair (assoc key *mp-popup-lists*))
    (setq *mp-popup-lists* (subst (cons key lst) pair *mp-popup-lists*))
    (setq *mp-popup-lists* (cons (cons key lst) *mp-popup-lists*))))

(defun mp:fill-popup (key lst idx)
  (mp:remember-popup key lst)
  (start_list key)
  (mapcar 'add_list lst)
  (end_list)
  (if (not idx) (setq idx 0))
  (set_tile key (itoa idx)))

(defun mp:item (lst key / raw i use)
  (setq use (mp:popup-list key lst))
  (setq raw (mp:gettile key))
  (if (= raw "") (setq raw "0"))
  (setq i (atoi raw))
  (if (and (>= i 0) (< i (length use))) (nth i use) (if use (car use) "")))

(defun mp:fill-popup-val (key lst val / use)
  (setq val (mp:safe-str val))
  (setq use
    (if (or (= val "") (member (strcase val) (mapcar 'strcase lst)))
      lst
      (cons val lst)))
  (mp:fill-popup key use (mp:idx val use)))

(defun mp:block-token (base)
  (cond
    ((= base "TRAMO_ARESIDUAL") "SAN")
    ((= base "TRAMO_ALLUVIAS") "PLU")
    ((= base "TRAMO_ACUEDUCTO") "ACU")
    ((= base "TRAMO_E_MT") "MT")
    ((= base "TRAMO_E_BT_AP") "BTAP")
    ((= base "POZO_SANITARIO") "POZO_SAN")
    ((= base "POZO_PLUVIAL") "POZO_PLU")
    ((= base "SUMIDERO") "SUMIDERO")
    ((= base "ACCESORIO_ACUEDUCTO") "ACC_ACU")
    ((= base "LUMINARIA_AP") "LUMINARIA")
    (T (vl-string-translate " -" "__" base))))

(defun mp:tramo-block-name (base dist / ds)
  (setq ds (vl-string-translate ".-" "_M" (rtos dist 2 4)))
  (strcat "MP_TRAMO_" (mp:block-token base) "_" ds))

(defun mp:point-block-name (base)
  (strcat "MP_PUNTO_" (mp:block-token base)))

(defun mp:is-cant-blockname (bname)
  (or (member (strcase bname) (mapcar 'strcase *mp-blocks*))
      (mp:starts-with bname "CANT_TRAMO_")
      (mp:starts-with bname "CANT_PUNTO_")
      (mp:starts-with bname "MP_TRAMO_")
      (mp:starts-with bname "MP_PUNTO_")))

(defun mp:is-tramo-name (bname)
  (or (mp:starts-with bname "CANT_TRAMO_")
      (mp:starts-with bname "MP_TRAMO_")))

(defun mp:is-point-name (bname)
  (or (mp:starts-with bname "CANT_PUNTO_")
      (mp:starts-with bname "MP_PUNTO_")))

(defun mp:diametro-label (vals / d)
  (setq d (vl-string-trim " " (mp:getval "DIAMETRO" vals "?")))
  (if (and (> (strlen d) 0) (= (substr d (strlen d) 1) "\""))
    d
    (strcat d "\"")))

(defun mp:label-tramo (base vals / l d mat)
  (setq l (mp:getval "LONGITUD" vals ""))
  (setq d (mp:diametro-label vals))
  (setq mat (mp:getval "MATERIAL" vals ""))
  (cond
    ((= base "TRAMO_ACUEDUCTO")
      (strcat "ACU L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_ALLUVIAS")
      (strcat "ALL L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_ARESIDUAL")
      (strcat "SAN L=" l "- %%c" d "-" mat))
    ((= base "TRAMO_E_MT")
      (strcat "MT L=" l "- " (mp:getval "DUCTOS" vals "") "x%%c" (mp:getval "DIAM_DUCTO" vals "") "-" (mp:getval "MATERIAL_DUCTO" vals "")))
    ((= base "TRAMO_E_BT_AP")
      (strcat "BT/AP L=" l "- " (mp:getval "DUCTOS" vals "") "x%%c" (mp:getval "DIAM_DUCTO" vals "") "-" (mp:getval "MATERIAL_DUCTO" vals "")))
    (T (strcat base " L=" l))))

(defun mp:pendiente-label (vals / p last)
  (setq p (vl-string-trim " " (mp:getval "PENDIENTE" vals "")))
  (if (= p "")
    ""
    (progn
      (setq last (substr p (strlen p) 1))
      (if (= last "%") p (strcat p "%")))))
(defun mp:label-point (base vals / id)
  (setq id (mp:getval "ID" vals (mp:getval "CODIGO" vals "")))
  (cond
    ((= base "POZO_SANITARIO") id)
    ((= base "POZO_PLUVIAL") id)
    ((= base "SUMIDERO") (strcat "SUM " id))
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281")) (strcat (mp:getval "TIPO_CAJA" vals base) " " id))
    ((= base "ACCESORIO_ACUEDUCTO") (strcat (mp:getval "TIPO_ACCESORIO" vals "ACC") " D" (mp:getval "DIAMETRO" vals "") " " id))
    ((= base "LUMINARIA_AP") (strcat "LUM " (mp:getval "CODIGO" vals id)))
    (T (strcat base " " id))))

(defun mp:insert-cant-tramo (baseb p1 p2 vals / doc ms dist ang blk br vals2 en lay)
  (vl-load-com)
  (setq dist (distance p1 p2) ang (angle p1 p2))
  (if (> dist 1e-9)
    (progn
      (setq vals2 (append vals (list (cons "LONGITUD" (rtos dist 2 2)))))
      (setq vals2 (append vals2 (list (cons "BLOQUE_BASE" baseb) (cons "ETIQUETA" (mp:label-tramo baseb vals2)) (cons "PENDIENTE_VIS" (mp:pendiente-label vals2)))))
      (setq blk (mp:tramo-block-name baseb dist))
      (if (not (tblsearch "BLOCK" blk))
        (mp:make-cant-tramo-block blk baseb dist vals2))
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq ms (vla-get-ModelSpace doc))
      (setq br (vla-InsertBlock ms (mp:3d p1) blk 1.0 1.0 1.0 (float ang)))
      (setq en (vlax-vla-object->ename br))
      (setq lay (mp:vis-layer baseb))
      (if (tblsearch "LAYER" lay) (vla-put-Layer br lay))
      (mp:setatts en vals2)
      (princ (strcat "\nTramo PPTO creado en " lay ": " blk))
      en)
    (progn
      (princ "\nNo se creo el tramo: los puntos coinciden.")
      nil)))

(defun mp:insert-cant-point (base p vals / doc ms blk br en vals2 lay)
  (vl-load-com)
  (setq vals2 (append vals (list (cons "BLOQUE_BASE" base))))
  (setq vals2 (append vals2 (list (cons "ETIQUETA" (mp:label-point base vals2)))))
  (setq blk (mp:point-block-name base))
  (if (not (tblsearch "BLOCK" blk))
    (mp:make-cant-punto-block blk base vals2))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq br (vla-InsertBlock ms (mp:3d p) blk 1.0 1.0 1.0 0.0))
  (setq en (vlax-vla-object->ename br))
  (setq lay (mp:point-layer base))
  (if (tblsearch "LAYER" lay) (vla-put-Layer br lay))
  (mp:setatts en vals2)
  (princ (strcat "\nPunto PPTO creado en " lay ": " blk))
  en)

(defun mp:dialog-elem-elec (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (and dcl (new_dialog "maipore_elem_elec" dcl))
    (progn
      (mp:fill-popup "blk" *mp-elem-elec-list* 0)
      (mp:fill-popup "etapa" *mp-etapa-list* 0)
      (mp:update-subetapa)
      (mp:fill-popup "lum" *mp-lum-list* 0)
      (mp:fill-popup "led" *mp-led-list* 0)
      (set_tile "serie" "1")
      (set_tile "altura" "8.4")
      (set_tile "brazo" "0.5")
      (set_tile "avance" "0.3")
      (action_tile "etapa" "(mp:update-subetapa)")
      (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
      (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
      (start_dialog)
      (if ok
        (progn
          (setq etapa (mp:item *mp-etapa-list* "etapa"))
          (setq res
            (list
              (cons "BLK" (mp:item *mp-elem-elec-list* "blk"))
              (cons "ID" (mp:gettile "id"))
              (cons "CODIGO" (mp:gettile "id"))
              (cons "SERIE" (mp:gettile "serie"))
              (cons "ETAPA" etapa)
              (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "LOTE" (mp:gettile "lote"))
              (cons "CIRCUITO_AP" (mp:gettile "lote"))
              (cons "CIRCUITO" (mp:gettile "lote"))
              (cons "CD" (mp:gettile "cd"))
              (cons "PF" (mp:gettile "pf"))
              (cons "TIPO_LUMINARIA" (mp:item *mp-lum-list* "lum"))
              (cons "FUENTE_LED" (mp:item *mp-led-list* "led"))
              (cons "ALTURA_M" (mp:gettile "altura"))
              (cons "BRAZO_M" (mp:gettile "brazo"))
              (cons "AVANCE_M" (mp:gettile "avance"))))))))
  (if dcl (unload_dialog dcl))
  res)

(defun mp:dialog-acc-acu (/ dcl ok res etapa)
  (setq dcl (load_dialog (mp:write-dcl)))
  (if (and dcl (new_dialog "maipore_acc_acu" dcl))
    (progn
      (mp:fill-popup "acc" *mp-acc-acu-list* 0)
      (mp:fill-popup "etapa" *mp-etapa-list* 0)
      (mp:update-subetapa)
      (mp:fill-popup "diam" *mp-diam-acu-list* 0)
      (mp:fill-popup "diamsal" *mp-diam-acu-list* 0)
      (mp:fill-popup "mat" *mp-material-acu-list* 0)
      (action_tile "etapa" "(mp:update-subetapa)")
      (action_tile "accept" "(mp:capture-dialog-values)(setq ok T)(done_dialog 1)")
      (action_tile "cancel" "(setq ok nil)(done_dialog 0)")
      (start_dialog)
      (if ok
        (progn
          (setq etapa (mp:item *mp-etapa-list* "etapa"))
          (setq res
            (list
              (cons "TIPO_ACCESORIO" (mp:item *mp-acc-acu-list* "acc"))
              (cons "ETAPA" etapa)
              (cons "SUBETAPA" (mp:item (mp:subetapas-for etapa) "subetapa"))
              (cons "DIAMETRO" (mp:item *mp-diam-acu-list* "diam"))
              (cons "DIAMETRO_SALIDA" (mp:item *mp-diam-acu-list* "diamsal"))
              (cons "MATERIAL" (mp:item *mp-material-acu-list* "mat"))
              (cons "LOTE" (mp:gettile "lote"))))))))
  (if dcl (unload_dialog dcl))
  res)

(defun mp:endpoint-base (tramo tipo)
  (cond
    ((or (= tipo "") (= tipo "NINGUNO")) nil)
    ((= tipo "POZO")
      (cond
        ((= tramo "TRAMO_ARESIDUAL") "POZO_SANITARIO")
        ((= tramo "TRAMO_ALLUVIAS") "POZO_PLUVIAL")
        (T nil)))
    ((and (= tipo "SUMIDERO") (= tramo "TRAMO_ALLUVIAS")) "SUMIDERO")
    ((member tipo *mp-extremo-elec-list*) tipo)
    (T nil)))

(defun mp:distance-2d (p1 p2)
  (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2))))

(defun mp:point-reference-base (en / obj bname atts base)
  (if (and en (= (cdr (assoc 0 (entget en))) "INSERT"))
    (progn
      (setq obj (vlax-ename->vla-object en))
      (setq bname (vla-get-EffectiveName obj))
      (setq atts (mp:att-alist en))
      (setq base (mp:infer-base bname atts))
      (if (and (/= base "") (not (mp:base-is-tramo base))) base ""))))

(defun mp:point-exists-p (base p / ss i en obj found ip tol found-base)
  ;; Medio metro tolera pequenos desfases de captura sin confundir pozos cercanos.
  (setq tol 0.50 found nil)
  (setq ss
    (ssget "_C"
      (list (- (car p) tol) (- (cadr p) tol) (if (caddr p) (caddr p) 0.0))
      (list (+ (car p) tol) (+ (cadr p) tol) (if (caddr p) (caddr p) 0.0))
      '((0 . "INSERT"))))
  (if ss
    (progn
      (setq i 0)
      (while (and (< i (sslength ss)) (not found))
        (setq en (ssname ss i)
              obj (vlax-ename->vla-object en)
              ip (vlax-get obj 'InsertionPoint)
              found-base (mp:point-reference-base en))
        (if (and (= found-base base)
                 (<= (mp:distance-2d p ip) tol))
          (setq found T))
        (setq i (1+ i)))))
  found)

(defun mp:endpoint-values (tramo vals is-final base / id result)
  (setq id
    (if is-final
      (mp:getval
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "HASTA" "POZO_FIN")
        vals
        "")
      (mp:getval
        (if (member tramo '("TRAMO_E_MT" "TRAMO_E_BT_AP")) "DESDE" "POZO_INI")
        vals
        "")))
  (setq result
    (list
      (cons "ETAPA" (mp:getval "ETAPA" vals ""))
      (cons "SUBETAPA" (mp:getval "SUBETAPA" vals ""))
      (cons "RED" (mp:getval "RED" vals ""))
      (cons "ID" id)
      (cons "DIAMETRO" (mp:getval "DIAMETRO" vals ""))
      (cons "DUCTOS" (mp:getval "DUCTOS" vals ""))
      (cons "LIBRES" (mp:getval "LIBRES" vals ""))
      (cons "PROFUNDIDAD" (mp:getval "PROFUNDIDAD" vals ""))))
  (if is-final
    (setq result
      (append result
        (list
          (cons "COTA_TN_INI" (mp:getval "COTA_TN_FIN" vals ""))
          (cons "COTA_CLAVE_INI" (mp:getval "COTA_CLAVE_FIN" vals "")))))
    (setq result
      (append result
        (list
          (cons "COTA_TN_INI" (mp:getval "COTA_TN_INI" vals ""))
          (cons "COTA_CLAVE_INI" (mp:getval "COTA_CLAVE_INI" vals ""))))))
  (if (member base '("CAMARA_CS276" "CAMARA_CS280" "CAJA_BARRAJE_CS281"))
    (setq result
      (append result
        (list
          (cons "TIPO_CAJA"
            (cond
              ((= base "CAMARA_CS276") "CS276")
              ((= base "CAMARA_CS280") "CS280")
              (T "CS281")))))))
  result)

(defun mp:insert-auto-endpoint (tramo p vals is-final / tipo base)
  (setq tipo
    (mp:getval
      (if is-final "TIPO_EXTREMO_FIN" "TIPO_EXTREMO_INI")
      vals
      "NINGUNO"))
  (setq base (mp:endpoint-base tramo tipo))
  (if (and base (not (mp:point-exists-p base p)))
    (mp:insert-cant-point base p (mp:endpoint-values tramo vals is-final base))))

(defun mp:insert-auto-endpoints (tramo p1 p2 vals)
  (mp:insert-auto-endpoint tramo p1 vals nil)
  (mp:insert-auto-endpoint tramo p2 vals T))

(defun mp:get-two-points (msg1 msg2 / p1 p2)
  (setq p1 (getpoint msg1))
  (if p1 (setq p2 (getpoint p1 msg2)))
  (if (and p1 p2) (list p1 p2) nil))

(defun c:INS_TRAMO_RED (/ pts data opt base vals)
  (mp:ensure-layers)
  (setq pts (mp:get-two-points "\nPunto inicial tramo red: " "\nPunto final tramo red: "))
  (if pts
    (if (setq data (mp:dialog-tramo-red))
      (progn
        (setq opt (cdr (assoc "REDOPT" data)))
        (setq base (cond ((= opt "Alluvias") "TRAMO_ALLUVIAS") ((= opt "Acueducto") "TRAMO_ACUEDUCTO") (T "TRAMO_ARESIDUAL")))
        (setq vals (vl-remove (assoc "REDOPT" data) data))
        (setq vals (append vals (list (cons "RED" opt))))
        (mp:insert-cant-tramo base (car pts) (cadr pts) vals)
        (mp:insert-auto-endpoints base (car pts) (cadr pts) vals)))
    (princ "\nComando cancelado."))
  (princ))

(defun mp:insert-electrical-tramo (base msg1 msg2 dialog-fn / pts vals)
  (mp:ensure-layers)
  (setq pts (mp:get-two-points msg1 msg2))
  (if pts
    (if (setq vals (apply dialog-fn nil))
      (progn
        (mp:insert-cant-tramo base (car pts) (cadr pts) vals)
        (mp:insert-auto-endpoints base (car pts) (cadr pts) vals)))
    (princ "\nComando cancelado."))
  (princ))

(defun c:INS_TRAMO_MT ()
  (mp:insert-electrical-tramo "TRAMO_E_MT" "\nPunto inicial tramo MT: " "\nPunto final tramo MT: " 'mp:dialog-tramo-mt))

(defun c:INS_TRAMO_BT_AP ()
  (mp:insert-electrical-tramo "TRAMO_E_BT_AP" "\nPunto inicial tramo BT/AP: " "\nPunto final tramo BT/AP: " 'mp:dialog-tramo-bt))

(defun c:SANITARIO () (mp:insert-tramo-forced "Aresidual") (princ))
(defun c:PLUVIAL () (mp:insert-tramo-forced "Alluvias") (princ))
(defun c:AGUAS_LLUVIAS () (mp:insert-tramo-forced "Alluvias") (princ))
(defun c:ACUEDUCTO () (mp:insert-tramo-forced "Acueducto") (princ))
(defun c:MT () (c:INS_TRAMO_MT))
(defun c:MEDIA_TENSION () (c:INS_TRAMO_MT))
(defun c:MEDIATENSION () (c:INS_TRAMO_MT))
(defun c:ALUMBRADO () (c:INS_TRAMO_BT_AP))
(defun c:AP () (c:INS_TRAMO_BT_AP))
(defun c:BT () (c:INS_TRAMO_BT_AP))

(defun c:POZO_SANITARIO (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Aresidual" "POZO_SANITARIO"))
    (if (setq p (getpoint "\nPunto de pozo sanitario: "))
      (mp:insert-cant-point "POZO_SANITARIO" p vals)))
  (princ))

(defun c:POZO_PLUVIAL (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Alluvias" "POZO_PLUVIAL"))
    (if (setq p (getpoint "\nPunto de pozo pluvial: "))
      (mp:insert-cant-point "POZO_PLUVIAL" p vals)))
  (princ))

(defun c:SUMIDERO (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-punto-hidro "Alluvias" "SUMIDERO"))
    (if (setq p (getpoint "\nPunto de sumidero: "))
      (mp:insert-cant-point "SUMIDERO" p vals)))
  (princ))

(defun c:CAJA_ELECTRICA (/ data vals p base)
  (mp:ensure-layers)
  (if (setq data (mp:dialog-caja-electrica))
    (if (setq p (getpoint "\nPunto de caja/camara electrica: "))
      (progn
        (setq base (cdr (assoc "BLK" data)))
        (setq vals (vl-remove (assoc "BLK" data) data))
        (mp:insert-cant-point base p vals))))
  (princ))

(defun c:CAMARA_ELECTRICA () (c:CAJA_ELECTRICA))
(defun c:CAJA_ELEC () (c:CAJA_ELECTRICA))

(defun c:ACCESORIO_ACUEDUCTO (/ vals p)
  (mp:ensure-layers)
  (if (setq vals (mp:dialog-acc-acu))
    (if (setq p (getpoint "\nPunto del accesorio de acueducto: "))
      (mp:insert-cant-point "ACCESORIO_ACUEDUCTO" p vals)))
  (princ))

(defun c:ACC_ACUEDUCTO () (c:ACCESORIO_ACUEDUCTO))
(defun c:INS_ACC_ACUEDUCTO () (c:ACCESORIO_ACUEDUCTO))

(defun c:INS_ELEM_ELEC (/ data vals p base)
  (mp:ensure-layers)
  (if (setq data (mp:dialog-elem-elec))
    (if (setq p (getpoint "\nPunto de insercion elemento electrico: "))
      (progn
        (setq base (cdr (assoc "BLK" data)))
        (setq vals (vl-remove (assoc "BLK" data) data))
        (mp:insert-cant-point base p vals))))
  (princ))

(defun c:LUMINARIA () (c:INS_ELEM_ELEC))

(defun c:ACT_ETIQUETAS_CANTIDAD (/ ss i en obj bname atts base lab)
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i) obj (vlax-ename->vla-object en) bname (vla-get-EffectiveName obj))
        (if (or (mp:is-tramo-name bname) (mp:is-point-name bname))
          (progn
            (setq atts (mp:att-alist en))
            (setq base (mp:getval "BLOQUE_BASE" atts ""))
            (if (/= base "")
              (progn
                (setq lab (if (mp:is-tramo-name bname) (mp:label-tramo base atts) (mp:label-point base atts)))
                (mp:setatt-one en "ETIQUETA" lab)
                (if (mp:is-tramo-name bname)
                  (mp:setatt-one en "PENDIENTE_VIS" (mp:pendiente-label atts)))))))
        (setq i (1+ i)))
      (princ "\nEtiquetas de cantidades actualizadas."))
    (princ "\nNo se encontraron bloques."))
  (princ))

(defun mp:merge-atts (old new / res pair)
  (setq res old)
  (foreach pair new
    (if (assoc (strcase (car pair)) res)
      (setq res (subst (cons (strcase (car pair)) (cdr pair)) (assoc (strcase (car pair)) res) res))
      (setq res (cons (cons (strcase (car pair)) (cdr pair)) res))))
  res)
(defun mp:reference-geometry-length (obj / doc blks blk bname span scale)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq bname (vla-get-EffectiveName obj))
  (setq blk (vl-catch-all-apply 'vla-Item (list blks bname)))
  (if (vl-catch-all-error-p blk)
    ""
    (progn
      (setq span (mp:block-tramo-length blk))
      (setq scale (abs (vla-get-XScaleFactor obj)))
      (if (> span 1e-9) (rtos (* span scale) 2 2) ""))))

(defun mp:ensure-reference-length (en obj atts / value)
  (setq value (mp:getval "LONGITUD" atts ""))
  (if (= value "")
    (progn
      (setq value (mp:reference-geometry-length obj))
      (if (/= value "") (mp:setatt-one en "LONGITUD" value))))
  value)
(defun mp:update-block-after-edit (en vals / obj atts merged base lab lay bname doc saved)
  (setq obj (vlax-ename->vla-object en))
  (setq atts (mp:att-alist en))
  (setq base (mp:attval atts "BLOQUE_BASE" ""))
  (setq saved (mp:setatts en vals))
  (setq merged (mp:merge-atts atts vals))
  (if (/= base "")
    (progn
      (setq lay (mp:edit-layer-for-base base))
      (if (tblsearch "LAYER" lay) (vla-put-Layer obj lay))
      (setq bname (vla-get-EffectiveName obj))
      (cond
        ((mp:is-tramo-name bname)
          (mp:ensure-reference-length en obj merged)
          (setq merged (mp:merge-atts merged (mp:att-alist en)))
          (setq lab (mp:label-tramo base merged))
          (mp:setatt-one en "ETIQUETA" lab)
          (mp:setatt-one en "PENDIENTE_VIS" (mp:pendiente-label merged)))
        ((mp:is-point-name bname)
          (setq lab (mp:label-point base merged))
          (mp:setatt-one en "ETIQUETA" lab)))
      ;; Fuerza la actualizacion visual inmediata de atributos y referencia.
      (vla-Update obj)
      (entupd en)
      (redraw en 1)
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-Regen doc 1)
      (vl-catch-all-apply 'vla-Update (list obj))
      (entupd en)))
  saved)

(defun c:QREDES_CSV (/ fn f ss i en obj bname pt row atts val count)
  (setq fn (getfiled "Guardar cantidades CSV" (strcat (getvar "DWGPREFIX") "cantidades_maipore.csv") "csv" 1))
  (if fn
    (if (setq f (open fn "w"))
      (progn
        (write-line (vl-string-right-trim "," (apply 'strcat (mapcar '(lambda (x) (strcat (mp:csv-safe x) ",")) *mp-csv-tags*))) f)
        (setq ss (ssget "X" '((0 . "INSERT"))) count 0)
        (if ss
          (progn
            (setq i 0)
            (while (< i (sslength ss))
              (setq en (ssname ss i) obj (vlax-ename->vla-object en) bname (vla-get-EffectiveName obj))
              (if (mp:is-cant-blockname bname)
                (progn
                  (setq pt (vlax-get obj 'InsertionPoint))
                  (setq atts (mp:att-alist en))
                  (setq row "")
                  (foreach h *mp-csv-tags*
                    (setq val
                      (cond
                        ((= h "BLOQUE") (mp:getval "BLOQUE_BASE" atts bname))
                        ((= h "HANDLE") (vla-get-Handle obj))
                        ((= h "LAYER") (vla-get-Layer obj))
                        ((= h "X") (rtos (car pt) 2 3))
                        ((= h "Y") (rtos (cadr pt) 2 3))
                        (T (cdr (assoc (strcase h) atts)))))
                    (setq row (strcat row (mp:csv-safe val) ",")))
                  (write-line (vl-string-right-trim "," row) f)
                  (setq count (1+ count))))
              (setq i (1+ i)))))
        (close f)
        (princ (strcat "\nCSV exportado: " fn " | Registros: " (itoa count))))
      (princ "\nNo se pudo abrir el archivo CSV para escritura.")))
  (princ))

(defun mp:block-attdef-tags (blk / tags item)
  (setq tags nil)
  (vlax-for item blk
    (if (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
      (setq tags (cons (strcase (vla-get-TagString item)) tags))))
  tags)

(defun mp:infer-base (bname atts / up red tipo)
  (setq up (strcase (mp:safe-str bname)))
  (cond
    ((/= (mp:getval "BLOQUE_BASE" atts "") "")
      (mp:getval "BLOQUE_BASE" atts ""))
    ((member up (mapcar 'strcase *mp-blocks*)) up)
    ((mp:starts-with up "MP_TRAMO_SAN_") "TRAMO_ARESIDUAL")
    ((mp:starts-with up "MP_TRAMO_PLU_") "TRAMO_ALLUVIAS")
    ((mp:starts-with up "MP_TRAMO_ACU_") "TRAMO_ACUEDUCTO")
    ((mp:starts-with up "MP_TRAMO_MT_") "TRAMO_E_MT")
    ((mp:starts-with up "MP_TRAMO_BTAP_") "TRAMO_E_BT_AP")
    ((= up "MP_PUNTO_POZO_SAN") "POZO_SANITARIO")
    ((= up "MP_PUNTO_POZO_PLU") "POZO_PLUVIAL")
    ((= up "MP_PUNTO_SUMIDERO") "SUMIDERO")
    ((= up "MP_PUNTO_ACC_ACU") "ACCESORIO_ACUEDUCTO")
    ((= up "MP_PUNTO_LUMINARIA") "LUMINARIA_AP")
    ((mp:starts-with up "MP_PUNTO_")
      (substr up 10))
    ((mp:starts-with up "CANT_TRAMO_")
      (setq red (strcase (mp:getval "RED" atts "")))
      (setq tipo (strcase (mp:getval "TIPO_RED" atts "")))
      (cond
        ((= red "ACUEDUCTO") "TRAMO_ACUEDUCTO")
        ((= red "ALLUVIAS") "TRAMO_ALLUVIAS")
        ((= red "ARESIDUAL") "TRAMO_ARESIDUAL")
        ((= tipo "MT") "TRAMO_E_MT")
        ((= tipo "BT/AP") "TRAMO_E_BT_AP")
        (T "")))
    (T "")))

(defun mp:base-is-tramo (base)
  (member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO" "TRAMO_E_MT" "TRAMO_E_BT_AP")))

(defun mp:desired-atts (base is-tramo / specs visible)
  (setq specs (if is-tramo (mp:base-atts-for base) (mp:base-atts-for-point base)))
  (setq visible
    (if (and is-tramo (member base '("TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS" "TRAMO_ACUEDUCTO")))
      (list
        (list "ETIQUETA" "Etiqueta visible" "")
        (list "PENDIENTE_VIS" "Pendiente visible" ""))
      (list (list "ETIQUETA" "Etiqueta visible" ""))))
  (append visible (list (list "BLOQUE_BASE" "Bloque base" base)) specs))

(defun mp:block-tramo-circle-span (blk / item center x minx maxx)
  ;; Los centros de los circulos definen la longitud geometrica completa.
  (setq minx nil maxx nil)
  (vlax-for item blk
    (if (= (vla-get-ObjectName item) "AcDbCircle")
      (progn
        (setq center
          (vlax-safearray->list
            (vlax-variant-value (vla-get-Center item))))
        (setq x (car center))
        (if (or (null minx) (< x minx)) (setq minx x))
        (if (or (null maxx) (> x maxx)) (setq maxx x)))))
  (if (and minx maxx (> (- maxx minx) 1e-9))
    (- maxx minx)
    0.0))

(defun mp:block-tramo-length (blk / item value best span)
  ;; Prioriza la distancia centro a centro para que el recorte visual
  ;; no reduzca LONGITUD ni las cantidades.
  (setq span (mp:block-tramo-circle-span blk))
  (if (> span 1e-9)
    span
    (progn
      (setq best 0.0)
      (vlax-for item blk
        (if (and (= (vla-get-ObjectName item) "AcDbPolyline")
                 (vlax-property-available-p item 'Length))
          (progn
            (setq value (vla-get-Length item))
            (if (> value best) (setq best value)))))
      best)))

(defun mp:normalize-tramo-graphics (blk / item span cut width)
  ;; Ajusta definiciones existentes al borde de sus circulos.
  (setq span (mp:block-tramo-length blk))
  (setq cut (min (max 2.0 *mp-vis-radius*) (/ span 4.0)))
  (setq width (max 0.50 *mp-vis-width*))
  (if (> span 1e-9)
    (vlax-for item blk
      (if (= (vla-get-ObjectName item) "AcDbPolyline")
        (progn
          (vla-put-Coordinates
            item
            (mp:var-dbls (list cut 0.0 (- span cut) 0.0)))
          (vla-put-ConstantWidth item (float width))
          (vla-Update item)))))
  span)

(defun mp:normalize-visible-attdefs (blk is-tramo base / item tag span pos)
  (if is-tramo
    (progn
      (setq span (mp:block-tramo-length blk))
      (vlax-for item blk
        (if (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
          (progn
            (setq tag (strcase (vla-get-TagString item)))
            (if (member tag '("ETIQUETA" "PENDIENTE_VIS"))
              (progn
                (setq pos
                  (list
                    (/ span 2.0)
                    (if (= tag "ETIQUETA")
                      (* *mp-vis-text-height* 1.35)
                      (- (* *mp-vis-text-height* 1.35)))
                    0.0))
                (mp:center-visible-att item pos *mp-vis-text-height*)))))))
    (if (member base '("POZO_SANITARIO" "POZO_PLUVIAL"))
      (vlax-for item blk
        (if (and
              (= (vla-get-ObjectName item) "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString item)) "ETIQUETA"))
          (mp:center-visible-att item '(0.0 0.0 0.0) *mp-vis-text-height*))))))

(defun mp:ensure-block-schema (bname base is-tramo / doc blks blk tags specs lay col y added spec tag invisible span pos height)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq blk (vl-catch-all-apply 'vla-Item (list blks bname)))
  (if (vl-catch-all-error-p blk)
    0
    (progn
      (if is-tramo (mp:normalize-tramo-graphics blk))
      (mp:normalize-visible-attdefs blk is-tramo base)
      (setq tags (mp:block-attdef-tags blk))
      (setq specs (mp:desired-atts base is-tramo))
      (setq lay (if is-tramo (mp:vis-layer base) (mp:point-layer base)))
      (setq col (if is-tramo (mp:vis-color base) (mp:point-color base)))
      (setq span (if is-tramo (mp:block-tramo-length blk) 0.0))
      (setq y -100.0 added 0)
      (foreach spec specs
        (setq tag (strcase (car spec)))
        (if (not (member tag tags))
          (progn
            (setq invisible (not (member tag '("ETIQUETA" "PENDIENTE_VIS"))))
            (setq pos
              (cond
                ((= tag "ETIQUETA") (list (/ span 2.0) (* *mp-vis-text-height* 1.35) 0.0))
                ((= tag "PENDIENTE_VIS") (list (/ span 2.0) (- (* *mp-vis-text-height* 1.35)) 0.0))
                (T (list 0.0 y 0.0))))
            (setq height (if invisible 0.10 (max 0.50 *mp-vis-text-height*)))
            (mp:vla-add-att
              blk
              tag
              (cadr spec)
              (if (caddr spec) (caddr spec) "")
              pos
              height
              invisible
              lay
              col)
            (setq tags (cons tag tags))
            (setq y (- y 0.20))
            (setq added (1+ added)))))
      added)))

(defun mp:definition-record (bname defs)
  (assoc (strcase bname) defs))

(defun mp:remove-duplicate-points (/ ss i en obj base atts id ip kept rec removed tol)
  ;; Solo elimina coincidencias inequivocas: mismo tipo, ID y coordenada.
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (setq kept nil removed 0 tol 0.50)
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq base (mp:point-reference-base en))
        (if (/= base "")
          (progn
            (setq obj (vlax-ename->vla-object en))
            (setq atts (mp:att-alist en))
            (setq id
              (strcase
                (vl-string-trim
                  " "
                  (mp:getval "ID" atts (mp:getval "CODIGO" atts "")))))
            (setq ip (vlax-get obj 'InsertionPoint))
            (setq rec nil)
            (if (/= id "")
              (foreach candidate kept
                (if (and
                      (null rec)
                      (= (car candidate) base)
                      (= (cadr candidate) id)
                      (<= (mp:distance-2d ip (caddr candidate)) tol))
                  (setq rec candidate))))
            (if rec
              (progn
                (entdel en)
                (setq removed (1+ removed)))
              (setq kept (cons (list base id ip en) kept)))))
        (setq i (1+ i)))))
  removed)

(defun c:ACTUALIZAR (/ ss i en obj bname atts base is-tramo handle refs defs rec added total-added sync-errors sync-result doc removed-dups)
  (vl-load-com)
  (mp:ensure-layers)
  (setq removed-dups (mp:remove-duplicate-points))
  (setq ss (ssget "X" '((0 . "INSERT"))))
  (setq refs nil defs nil total-added 0 sync-errors 0)
  (if ss
    (progn
      ;; Primera pasada: conserva todos los valores y agrupa definiciones.
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq obj (vlax-ename->vla-object en))
        (setq bname (vla-get-EffectiveName obj))
        (if (mp:is-cant-blockname bname)
          (progn
            (setq atts (mp:att-alist en))
            (setq base (mp:infer-base bname atts))
            (if (/= base "")
              (progn
                (setq is-tramo (mp:base-is-tramo base))
                (setq handle (vla-get-Handle obj))
                (setq refs (cons (list handle bname base is-tramo atts) refs))
                (if (not (mp:definition-record bname defs))
                  (setq defs (cons (list (strcase bname) bname base is-tramo) defs)))))))
        (setq i (1+ i)))

      ;; Segunda pasada: agrega ATTDEF faltantes y sincroniza cada definicion.
      (foreach rec defs
        (setq bname (cadr rec) base (caddr rec) is-tramo (cadddr rec))
        (setq added (mp:ensure-block-schema bname base is-tramo))
        (setq total-added (+ total-added added))
        (setq sync-result (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bname)))
        (if (vl-catch-all-error-p sync-result)
          (setq sync-errors (1+ sync-errors))))

      ;; Tercera pasada: restaura valores por handle y repara longitud/etiquetas.
      (foreach rec refs
        (setq en (handent (car rec)))
        (if en
          (progn
            (setq base (caddr rec))
            (setq atts (nth 4 rec))
            (mp:setatts en atts)
            (mp:setatt-one en "BLOQUE_BASE" base)
            (mp:update-block-after-edit en nil))))

      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-Regen doc 1)
      (princ
        (strcat
          "\nACTUALIZAR terminado. Bloques: " (itoa (length defs))
          " | Referencias: " (itoa (length refs))
          " | Atributos nuevos: " (itoa total-added)
          " | Pozos duplicados eliminados: " (itoa removed-dups)
          " | Errores de sincronizacion: " (itoa sync-errors))))
    (princ "\nNo se encontraron bloques insertados."))
  (princ))
(defun c:MP_REPARAR_VISIBILIDAD (/ doc)
  (mp:ensure-layers)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-Regen doc 1)
  (princ "\nCapas PPTO encendidas, descongeladas y desbloqueadas. Dibujo regenerado.")
  (princ))

(defun c:MAIPORE_BLOQUES_REDES_ELECT ()
  (mp:ensure-layers)
  (princ "\nMaipore V13 optimizada cargada. Use SANITARIO, PLUVIAL, ACUEDUCTO, MT, ALUMBRADO, EDITAR, ACTUALIZAR y QREDES_CSV.")
  (princ))

(princ "\nMAIPORE V13 OPTIMIZADA cargada. Comando principal: MAIPORE_BLOQUES_REDES_ELECT.")
(princ)
