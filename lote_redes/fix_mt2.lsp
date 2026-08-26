;; FIX MT v2 (2026-08-26, revision del usuario sobre el master aplicado):
;;  1. LONGITUD de cada tramo MT = d= del plano (el plano acota entre
;;     BORDES de caja; confirmado: 125/154 tramos con dif +1.0..+2.0 m).
;;     Los M3 derivados se escalan proporcionalmente (d/L).
;;  2. Bancos SIN "d=" (acometidas a subestacion, "4{\U+2205}6\" PVC"):
;;     DUCTOS del plano + etiqueta visible corregida + volumen de ductos
;;     recalculado.
;;  3. REPORTE de tramos con doble/triple circuito ("2(3x185...)(C1)...")
;;     -- el cable de esos tramos debe multiplicarse (afectacion).
;; Corre en accoreconsole (solo entmod de atributos, sin mp:*).
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")
(setq pf (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_mt2_log.txt" "w"))
(defun fg (m) (write-line m pf))

;; --- parseo de etiquetas (ambas codificaciones de la O barrada)
(defun fx:ductos-u2205 (txt / p1 sub p2 c n)
  ;; "...\P4{\fISOCPEUR...;\U+2205}6\" PVC" -> 4
  (setq p1 (vl-string-search "\\U+2205}" txt))
  (if p1
    (progn
      (setq sub (substr txt 1 p1))
      (setq p2 (vl-string-position (ascii "{") sub 0 T))
      (if p2
        (progn
          (setq n "")
          (setq c (1- p2))
          (while (and (>= c 0) (wcmatch (substr sub (1+ c) 1) "#"))
            (setq n (strcat (substr sub (1+ c) 1) n))
            (setq c (1- c)))
          (if (> (strlen n) 0) (atoi n) nil))
        nil))
    nil))

(defun fx:circuitos (txt / n s p)
  ;; nro de circuitos de cable: "2(3x185" cuenta 2; cada "3x185" extra +1
  (setq n 0 s txt)
  (while (setq p (vl-string-search "3x185" s))
    (setq n (1+ n))
    (setq s (substr s (+ p 6))))
  (if (vl-string-search "2(3x185" txt) (setq n (1+ n)))
  (max 1 n))

;; --- cargar etiquetas del plano
(setq etqs nil bancos nil)
(setq f (open (strcat lr:dir "data_SRC_SERIE1.txt") "r"))
(while (setq lin (read-line f))
  (if (wcmatch lin "TXT|*")
    (progn
      (setq parts (lr:split lin "|"))
      (setq txt (nth 3 parts))
      (setq p (lr:parse-pt (nth 2 parts)))
      (if (and txt p)
        (if (vl-string-search "d=" txt)
          (progn
            (setq info (lr:parse-etq-mt txt))
            (if (and info (car info))
              (setq etqs (cons (list (car p) (cadr p) (car info)
                (fx:circuitos txt)) etqs))))
          (progn
            (setq nd (fx:ductos-u2205 txt))
            (if (and nd (vl-string-search "PVC" (strcase txt)))
              (setq bancos (cons (list (car p) (cadr p) nd
                (fx:circuitos txt)) bancos)))))))))
(close f)
(fg (strcat "Etiquetas d=: " (itoa (length etqs))
  " | bancos sin d=: " (itoa (length bancos))))

(defun dist-nom (nb / pos)
  (setq pos (vl-string-search "MT_" nb))
  (atof (vl-string-translate "_" "." (substr nb (+ pos 4)))))

(defun fx:att-mod (ins tag val / sub sd done)
  (setq sub (entnext ins) done nil)
  (while (and sub (not done) (/= (cdr (assoc 0 (entget sub))) "SEQEND"))
    (setq sd (entget sub))
    (if (and (= (cdr (assoc 0 sd)) "ATTRIB")
             (= (cdr (assoc 2 sd)) tag))
      (progn
        (entmod (subst (cons 1 val) (assoc 1 sd) sd))
        (setq done T)))
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
  (if (and v (> (atof v) 0.0))
    (fx:att-mod ins tag (rtos (* (atof v) k) 2 3))))

;; --- recorrido de tramos
(setq e (entnext) tot 0 fixl 0 fixd 0 dobles nil sinref 0)
(while e
  (setq ed (entget e))
  (if (and (= (cdr (assoc 0 ed)) "INSERT")
           (wcmatch (cdr (assoc 2 ed)) "MP_TRAMO_MT_*"))
    (progn
      (setq tot (1+ tot))
      (setq ip (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
      (setq distv (dist-nom (cdr (assoc 2 ed))))
      (setq mx (+ (car ip) (* (/ distv 2.0) (cos rot)))
            my (+ (cadr ip) (* (/ distv 2.0) (sin rot))))
      (setq a-lng (atof (if (fx:att-val e "LONGITUD") (fx:att-val e "LONGITUD") "0")))
      ;; 1) etiqueta d= validada -> LONGITUD del plano + escalar M3
      (setq best nil bd 35.0)
      (foreach q etqs
        (setq d (sqrt (+ (expt (- (car q) mx) 2) (expt (- (cadr q) my) 2))))
        (if (and (< d bd) (< (abs (- (caddr q) a-lng)) 6.0))
          (setq bd d best q)))
      (if (and best (> a-lng 0.1))
        (progn
          (setq k (/ (caddr best) a-lng))
          (fx:att-mod e "LONGITUD" (rtos (caddr best) 2 2))
          (fx:att-mod e "LONG_VIS" (strcat "L=" (rtos (caddr best) 2 2)))
          (foreach tg '("EXCAVACION_M3" "CAMA_M3" "VOLUMEN_ELEMENTO_M3"
                        "RELLENO_M3" "SOBRANTE_M3" "REPOSICION_M2"
                        "ARENA_M3" "BASE_GRANULAR_M3")
            (fx:scale-att e tg k))
          (setq fixl (1+ fixl))
          (if (> (nth 3 best) 1)
            (setq dobles (cons (list (cdr (assoc 5 ed)) (caddr best) (nth 3 best)) dobles))))
        ;; 2) sin d= validada: banco sin d= cercano (acometidas)
        (progn
          (setq bb nil bbd 25.0)
          (foreach b bancos
            (setq d (sqrt (+ (expt (- (car b) mx) 2) (expt (- (cadr b) my) 2))))
            (if (< d bbd) (setq bbd d bb b)))
          (if bb
            (progn
              (setq nd (caddr bb))
              (setq od (atoi (if (fx:att-val e "DUCTOS") (fx:att-val e "DUCTOS") "6")))
              (if (/= nd od)
                (progn
                  (fx:att-mod e "DUCTOS" (itoa nd))
                  (fx:att-mod e "ETIQUETA"
                    (strcat (itoa nd) "%%c6\" PVC"))
                  ;; volumen de ductos y relleno/sobrante proporcionales
                  (setq v (fx:att-val e "VOLUMEN_ELEMENTO_M3"))
                  (if (and v (> (atof v) 0.0) (> od 0))
                    (progn
                      (setq vn (* (atof v) (/ (float nd) od)))
                      (setq exc (atof (if (fx:att-val e "EXCAVACION_M3") (fx:att-val e "EXCAVACION_M3") "0")))
                      (setq cam (atof (if (fx:att-val e "CAMA_M3") (fx:att-val e "CAMA_M3") "0")))
                      (fx:att-mod e "VOLUMEN_ELEMENTO_M3" (rtos vn 2 3))
                      (fx:att-mod e "RELLENO_M3" (rtos (max 0.0 (- exc cam vn)) 2 3))
                      (fx:att-mod e "SOBRANTE_M3" (rtos (+ cam vn) 2 3))))
                  (setq fixd (1+ fixd))))
              (if (> (nth 3 bb) 1)
                (setq dobles (cons (list (cdr (assoc 5 ed)) a-lng (nth 3 bb)) dobles))))
            (setq sinref (1+ sinref)))))
      (entupd e)))
  (setq e (entnext e)))
(fg (strcat "RESUMEN: " (itoa tot) " tramos | LONGITUD ajustada al d= del plano: "
  (itoa fixl) " | bancos corregidos (sin d=, acometidas): " (itoa fixd)
  " | sin ninguna referencia: " (itoa sinref)))
(fg "TRAMOS CON CIRCUITO MULTIPLE (el cable debe multiplicarse -- afectacion):")
(foreach d dobles
  (fg (strcat "  h=" (car d) " L=" (rtos (cadr d) 2 1)
    " circuitos=" (itoa (caddr d)))))
(fg (strcat "Total tramos multi-circuito: " (itoa (length dobles))))
(fg "FIXMT2-OK")
(close pf)
(princ)
