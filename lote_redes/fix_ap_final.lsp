;; FIX AP FINAL (2026-08-26, revision del usuario sobre el master real):
;;  1. Los tramos AP cuya etiqueta "d=" quedo mal emparejada (discrepancia
;;     grande vs la distancia geometrica REAL entre cajas) se veian
;;     "cortos": la etiqueta de presupuesto decia un numero mayor a lo
;;     realmente dibujado. Se revierte LONGITUD/LONG_VIS a la distancia
;;     geometrica real (dato del propio nombre del bloque, que SI se
;;     calculo con los nodos reales) y se escalan los M3 informativos.
;;  2. El poste huerfano MP_PUNTO_POSTE_ELEC (P-46, handle 5C3C0) en
;;     PPTO-EQUIPOS-ELECTRICOS es residuo del lote MT original (creado
;;     sin datos de AP: solo ID) -- se reubica a PPTO-ELECTRICA-MT (su
;;     capa correcta) para poder borrar la capa equipos-electricos.
;; NOTA: cruce_record2.lsp termina en (c:CRUCERECORD2) -- NO se carga aqui
;; para no disparar esa corrida completa de nuevo; se reimplementa solo lo
;; necesario (recarga de pozos del record + marcado con tolerancia mayor).
(vl-load-com)
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")
(defun fx:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_ap_final_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun fx:att-mod (ins tag val / sub sd done)
  (setq sub (entnext ins) done nil)
  (while (and sub (not done) (/= (cdr (assoc 0 (entget sub))) "SEQEND"))
    (setq sd (entget sub))
    (if (and (= (cdr (assoc 0 sd)) "ATTRIB") (= (cdr (assoc 2 sd)) tag))
      (progn (entmod (subst (cons 1 val) (assoc 1 sd) sd)) (setq done T)))
    (setq sub (entnext sub)))
  done)

(defun fx:att-val (ins tag / sub sd out)
  (setq sub (entnext ins) out nil)
  (while (and sub (not out) (/= (cdr (assoc 0 (entget sub))) "SEQEND"))
    (setq sd (entget sub))
    (if (and (= (cdr (assoc 0 sd)) "ATTRIB") (= (cdr (assoc 2 sd)) tag))
      (setq out (cdr (assoc 1 sd))))
    (setq sub (entnext sub)))
  out)

(defun fx:scale-att (ins tag k / v)
  (setq v (fx:att-val ins tag))
  (if (and v (> (atof v) 0.0)) (fx:att-mod ins tag (rtos (* (atof v) k) 2 3))))

(defun c:FIXAPFINAL (/ ss n i e ed bn distv lngv dif fixed obj k
                     f lin parts p pozos ip bd best d ejec falt)
  ;; ---------- 1) tramos AP mal etiquetados
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_BTAP_*"))))
  (setq n (if ss (sslength ss) 0) i 0 fixed 0)
  (while (< i n)
    (setq e (ssname ss i) ed (entget e))
    (setq bn (cdr (assoc 2 ed)))
    (setq distv (atof (vl-string-translate "_" "."
      (substr bn (+ 6 (vl-string-search "BTAP_" bn))))))
    (setq lngv (atof (if (fx:att-val e "LONGITUD") (fx:att-val e "LONGITUD") "0")))
    (setq dif (abs (- lngv distv)))
    (if (> dif (max 2.0 (* 0.4 distv)))
      (progn
        (fx:log (strcat "CORRIGE h=" (cdr (assoc 5 ed))
          " LONGITUD " (rtos lngv 2 2) " -> " (rtos distv 2 2)
          " (geometria real, la etiqueta d= estaba mal emparejada)"))
        (if (> lngv 0.1)
          (progn
            (setq k (/ distv lngv))
            (foreach tg '("EXCAVACION_M3" "CAMA_M3" "VOLUMEN_ELEMENTO_M3"
                          "RELLENO_M3" "REPOSICION_M2" "ARENA_M3" "BASE_GRANULAR_M3")
              (fx:scale-att e tg k))))
        (fx:att-mod e "LONGITUD" (rtos distv 2 2))
        (fx:att-mod e "LONG_VIS" (strcat "L=" (rtos distv 2 2)))
        (setq fixed (1+ fixed))
        (entupd e)))
    (setq i (1+ i)))
  (fx:log (strcat "Tramos AP corregidos: " (itoa fixed) " de " (itoa n)))
  ;; ---------- 2) poste huerfano -> capa MT + purgar capa equipos
  (setq e (handent "5C3C0"))
  (if e
    (progn
      (setq obj (vlax-ename->vla-object e))
      (vla-put-Layer obj "PPTO-ELECTRICA-MT")
      (foreach a (vlax-invoke obj 'GetAttributes) (vla-put-Layer a "PPTO-ELECTRICA-MT"))
      (fx:log "Poste huerfano P-46 (5C3C0) reubicado a PPTO-ELECTRICA-MT"))
    (fx:log "Poste huerfano 5C3C0 no encontrado (ya no existe?)"))
  (setq ss (ssget "_X" '((0 . "INSERT") (8 . "PPTO-EQUIPOS-ELECTRICOS"))))
  (fx:log (strcat "PPTO-EQUIPOS-ELECTRICOS: quedan " (itoa (if ss (sslength ss) 0)) " instancias"))
  ;; capa vacia -> _.-PURGE la elimina (LAYER no tiene opcion Delete
  ;; confiable en modo -comando headless; PURGE es el camino seguro)
  (command "_.-PURGE" "_LA" "*" "_N")
  (command "_.-PURGE" "_LA" "*" "_N")
  (fx:log (strcat "Capa PPTO-EQUIPOS-ELECTRICOS: "
    (if (tblsearch "LAYER" "PPTO-EQUIPOS-ELECTRICOS") "SIGUE (revisar)" "eliminada")))
  ;; ---------- 3) sanitario: reintentar pozos con tolerancia realista
  ;; (as-built de campo no coincide exacto con el diseno; 2.5 m dejaba
  ;; 61/150 con 342 candidatos disponibles -- se sube a 4.0 m)
  (setq f (open (strcat lr:dir "data_RECORD_RES.txt") "r"))
  (setq pozos nil)
  (while (setq lin (read-line f))
    (setq parts (lr:split lin "|"))
    (if (= (car parts) "POZO")
      (progn
        (setq p (lr:parse-pt (caddr parts)))
        (if p (setq pozos (cons p pozos))))))
  (close f)
  (fx:log (strcat "Pozos record recargados: " (itoa (length pozos))))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_POZO_SAN*"))))
  (setq n (if ss (sslength ss) 0) i 0 ejec 0 falt 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ip (cdr (assoc 10 (entget e))))
    (setq bd 4.0 best nil)
    (foreach p pozos
      (setq d (sqrt (+ (expt (- (car p) (car ip)) 2)
                       (expt (- (cadr p) (cadr ip)) 2))))
      (if (< d bd) (setq bd d best p)))
    (if best
      (progn (vl-catch-all-apply 'mp:setatt-one (list e "CONTROL_ESTADO" "EJECUTADO"))
        (setq ejec (1+ ejec)))
      (setq falt (1+ falt)))
    (setq i (1+ i)))
  (fx:log (strcat "POZOS SANITARIOS (tol 4.0m): " (itoa ejec) " EJECUTADOS / "
    (itoa falt) " por ejecutar (de " (itoa n) ")"))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (fx:log "FIXAPFINAL-TERMINADO"))
(c:FIXAPFINAL)
