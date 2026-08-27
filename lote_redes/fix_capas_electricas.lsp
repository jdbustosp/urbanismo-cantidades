;; FIX CAPAS ELECTRICAS (2026-08-26): las definiciones de bloque MP_TRAMO_*/
;; MP_PUNTO_* electricas NO se regeneran si el nombre ya existe -- varias
;; quedaron con sus ATTDEF (atributos invisibles: DUCTOS, MATERIAL, etapa,
;; etc.) horneados en la capa vieja "PPTO-EQUIPOS-ELECTRICOS" de cuando se
;; crearon por primera vez, aunque el INSERT visible ya este en la capa
;; correcta. Se normaliza CADA definicion electrica (geometria + attdefs)
;; a su capa real y se hace ATTSYNC para propagar a las instancias.
(vl-load-com)
(defun fc:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_capas_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun fc:base-de-nombre (nb / u)
  (setq u (strcase nb))
  (cond
    ((wcmatch u "MP_TRAMO_MT_*") "TRAMO_E_MT")
    ((wcmatch u "MP_TRAMO_BTAP_*") "TRAMO_E_BT_AP")
    ((wcmatch u "MP_PUNTO_CAMARA_CS276*") "CAMARA_CS276")
    ((wcmatch u "MP_PUNTO_CAMARA_CS280*") "CAMARA_CS280")
    ((wcmatch u "MP_PUNTO_CAMARA_CS274*") "CAMARA_CS274")
    ((wcmatch u "MP_PUNTO_CAMARA_CS275*") "CAMARA_CS275")
    ((wcmatch u "MP_PUNTO_SUBESTACION*") "SUBESTACION_E")
    ((wcmatch u "MP_PUNTO_POSTE*") "POSTE_ELEC")
    ((wcmatch u "MP_PUNTO_TRANSFORMADOR*") "TRANSFORMADOR_AP")
    ((wcmatch u "MP_PUNTO_LUMINARIA*") "LUMINARIA_AP")
    (T nil)))

(defun fc:capa-de-base (base)
  (cond
    ((= base "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
    ((= base "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
    ((member base '("CAMARA_CS276" "CAMARA_CS280" "SUBESTACION_E")) "PPTO-ELECTRICA-MT")
    ((member base '("CAMARA_CS274" "CAMARA_CS275" "POSTE_ELEC" "TRANSFORMADOR_AP")) "PPTO-ELECTRICA-BT-AP")
    ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
    (T nil)))

(defun c:FIXCAPASELEC (/ blks blk nb base lay n tocadas totalatt e on
                       ss i obj att ninst nattinst nombres par)
  (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
  (setq tocadas 0 totalatt 0)
  ;; PASO 1: RECOLECTAR nombres de definiciones a tocar (sin mutar nada
  ;; mientras se itera la coleccion Blocks -- ATTSYNC/mutaciones dentro
  ;; de un vlax-for sobre blks corrompe el iterador COM y crashea acad
  ;; sin rastro, mismo patron que el bug de los circulos con vlax-for)
  (setq nombres nil)
  (vlax-for blk blks
    (setq nb (vla-get-Name blk))
    (if (wcmatch (strcase nb) "MP_TRAMO_*,MP_PUNTO_*")
      (setq base (fc:base-de-nombre nb))
      (setq base nil))
    (if (and base (fc:capa-de-base base))
      (setq nombres (cons (list nb base) nombres))))
  (fc:log (strcat "Definiciones electricas candidatas: " (itoa (length nombres))))
  ;; PASO 2: MUTAR -- ya fuera del vlax-for sobre blks, uno a la vez
  (foreach par nombres
    (setq nb (car par) base (cadr par) lay (fc:capa-de-base base))
    (setq blk (vla-Item blks nb))
    (setq n 0)
    (vlax-for e blk
      (setq on (vla-get-ObjectName e))
      (if (/= (vla-get-Layer e) lay)
        (progn (vla-put-Layer e lay) (setq n (1+ n)))))
    (if (> n 0)
      (progn
        (vl-cmdf "_.ATTSYNC" "_N" nb)
        (setq tocadas (1+ tocadas) totalatt (+ totalatt n))
        (fc:log (strcat "  " nb " (" base "): " (itoa n)
          " entidades movidas a " lay)))))
  (fc:log (strcat "RESUMEN definiciones: " (itoa tocadas) " normalizadas, "
    (itoa totalatt) " entidades internas corregidas"))
  ;; refuerzo directo sobre INSTANCIAS (ATTSYNC no garantiza mover la capa
  ;; de atributos YA insertados, solo la estructura) -- recorre cada
  ;; instancia electrica y fuerza capa correcta en INSERT + TODOS sus attrs
  (setq ninst 0 nattinst 0)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_*,MP_PUNTO_*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (setq base (fc:base-de-nombre (vla-get-EffectiveName obj)))
    (if base
      (progn
        (setq lay
          (cond
            ((= base "TRAMO_E_MT") "PPTO-ELECTRICA-MT")
            ((= base "TRAMO_E_BT_AP") "PPTO-ELECTRICA-BT-AP")
            ((member base '("CAMARA_CS276" "CAMARA_CS280" "SUBESTACION_E")) "PPTO-ELECTRICA-MT")
            ((member base '("CAMARA_CS274" "CAMARA_CS275" "POSTE_ELEC" "TRANSFORMADOR_AP")) "PPTO-ELECTRICA-BT-AP")
            ((= base "LUMINARIA_AP") "PPTO-ELECTRICA-BT-AP")
            (T nil)))
        (if lay
          (progn
            (if (/= (vla-get-Layer obj) lay)
              (progn (vla-put-Layer obj lay) (setq ninst (1+ ninst))))
            (foreach att (vlax-invoke obj 'GetAttributes)
              (if (/= (vla-get-Layer att) lay)
                (progn (vla-put-Layer att lay) (setq nattinst (1+ nattinst)))))))))
    (setq i (1+ i)))
  (fc:log (strcat "RESUMEN instancias: " (itoa ninst) " INSERT + "
    (itoa nattinst) " atributos movidos directamente (de " (itoa n) " instancias)"))
  ;; verificar que la capa vieja quede vacia
  (setq ss (ssget "_X" '((8 . "PPTO-EQUIPOS-ELECTRICOS"))))
  (fc:log (strcat "PPTO-EQUIPOS-ELECTRICOS tras el fix: "
    (itoa (if ss (sslength ss) 0)) " entidades (sueltas, en model space)"))
  (command "_.-PURGE" "_LA" "*" "_N")
  (command "_.-PURGE" "_LA" "*" "_N")
  (fc:log (strcat "Capa PPTO-EQUIPOS-ELECTRICOS: "
    (if (tblsearch "LAYER" "PPTO-EQUIPOS-ELECTRICOS") "SIGUE (revisar)" "eliminada")))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (fc:log "FIXCAPASELEC-TERMINADO"))
(c:FIXCAPASELEC)
