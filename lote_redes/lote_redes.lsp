;;; ============================================================
;;; LOTE REDES (2026-08-24) - pluvial, acueducto, MT y alumbrado
;;; Port de la logica del lote RESIDUAL (handoff urbanismo-externo):
;;; los datos ya vienen EXTRAIDOS de los planos fuente (data_*.txt,
;;; extract.scr via accoreconsole) y los xrefs del master se insertan
;;; en 0,0 rot 0 escala 1 (verificado por sonda) => coordenadas
;;; identidad, sin matriz. Crea los elementos con las funciones NO
;;; interactivas del plugin (mp:insert-cant-point / mp:insert-cant-
;;; tramo). Sin etapa/subetapa (mismo criterio del lote RESIDUAL).
;;; Idempotente: salta elementos ya existentes por base+posicion.
;;; ============================================================

(setq lr:dir "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/")
(setq lr:logf nil)

(defun lr:log (msg)
  ;; log forense: abrir/cerrar por linea (leccion del 2026-08-17)
  (setq lr:logf (open (strcat lr:dir "lote_result.txt") "a"))
  (if lr:logf (progn (write-line msg lr:logf) (close lr:logf)))
  (princ (strcat "\n" msg))
  (princ))

(defun lr:num (s / v) (if (and s (setq v (distof s 2))) v nil))

(defun lr:num-coma (s / i c out v)
  ;; "38,2m ..." -> 38.2 (decimales con coma en SERIE 1/6). OJO: atof,
  ;; no distof -- distof devuelve nil si hay texto despues del numero
  ;; (bug del piloto 1 que tumbo TODAS las etiquetas)
  (setq out "" i 1)
  (repeat (strlen s)
    (setq c (substr s i 1))
    (setq out (strcat out (if (= c ",") "." c)))
    (setq i (1+ i)))
  (setq v (atof out))
  (if (> v 0.0) v nil))

(defun lr:split (s sep / out pos)
  (setq out nil)
  (while (setq pos (vl-string-search sep s))
    (setq out (cons (substr s 1 pos) out))
    (setq s (substr s (+ pos 1 (strlen sep)))))
  (reverse (cons s out)))

(defun lr:parse-pt (s / parts x y)
  ;; SOLO para campos "x,y" simples; con cadenas multipunto "x,y;x,y"
  ;; el distof estricto da nil en la Y (bug cazado en la fase AP) --
  ;; ahora devuelve nil completo si alguna coordenada no parsea
  (setq parts (lr:split s ","))
  (if (>= (length parts) 2)
    (progn
      (setq x (distof (car parts) 2))
      (setq y (distof (cadr parts) 2))
      (if (and x y) (list x y) nil))
    nil))

(defun lr:parse-pts (s / out p)
  (setq out nil)
  (foreach tok (lr:split s ";")
    (if (and (> (strlen tok) 0) (setq p (lr:parse-pt tok))
             (car p) (cadr p) (> (car p) 1000.0))
      (setq out (cons p out))))
  (reverse out))

(defun lr:d2 (a b)
  (sqrt (+ (expt (- (car a) (car b)) 2) (expt (- (cadr a) (cadr b)) 2))))

;; carga un data_*.txt como lista de registros (tipo capa resto...)
(defun lr:read-data (fname / f ln out parts)
  (setq f (open (strcat lr:dir fname) "r") out nil)
  (if f
    (progn
      (while (setq ln (read-line f))
        (setq parts (lr:split ln "|"))
        (if (>= (length parts) 3) (setq out (cons parts out))))
      (close f)))
  (reverse out))

;; longitud REAL de la cadena (suma de segmentos) -- las etiquetas de
;; los planos traen esta longitud, no la cuerda recta
(defun lr:chain-len (pts / l i)
  (setq l 0.0 i 0)
  (while (< i (1- (length pts)))
    (setq l (+ l (lr:d2 (nth i pts) (nth (1+ i) pts))) i (1+ i)))
  l)

;; extremos REALES de una cadena de vertices: el par mas alejado
;; (protege contra flechas/vertices decorativos al final)
(defun lr:chain-extremos (pts / best bi bj i j d)
  (setq best -1.0 bi nil bj nil i 0)
  (foreach a pts
    (setq j 0)
    (foreach b pts
      (if (> j i)
        (progn
          (setq d (lr:d2 a b))
          (if (> d best) (setq best d bi a bj b))))
      (setq j (1+ j)))
    (setq i (1+ i)))
  (if bi (list bi bj) nil))

;; ---------- registro de nodos por disciplina ----------
;; nodo = (pt id ename base)
(setq lr:nodos nil)

(defun lr:nodo-mas-cercano (p tol / best bd d)
  (setq best nil bd tol)
  (foreach nd lr:nodos
    (setq d (lr:d2 p (car nd)))
    (if (< d bd) (setq bd d best nd)))
  best)

;; elementos existentes del programa (idempotencia): posiciones por base
(setq lr:existentes nil)

(defun lr:cargar-existentes (/ ss i en ed bn ip)
  (setq lr:existentes nil)
  (if (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_*,MP_TRAMO_*"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq en (ssname ss i) ed (entget en))
        (setq bn (cdr (assoc 2 ed)) ip (cdr (assoc 10 ed)))
        (setq lr:existentes
          (cons (list (list (car ip) (cadr ip)) bn en) lr:existentes))
        (setq i (1+ i)))))
  (lr:log (strcat "Existentes en el master: "
    (itoa (length lr:existentes)) " bloques MP_*")))

(defun lr:ya-existe-punto (p patron / found)
  (setq found nil)
  (foreach ex lr:existentes
    (if (and (not found)
             (wcmatch (cadr ex) patron)
             (< (lr:d2 p (car ex)) 0.35))
      (setq found ex)))
  found)

;; crear punto con dedupe + registro de nodo
(defun lr:punto (base p id vals patron / ex en h res)
  (setq ex (lr:ya-existe-punto p patron))
  (if ex
    (progn
      (setq en (caddr ex))
      (setq lr:nodos (cons (list p id en base) lr:nodos))
      (lr:log (strcat "  reutilizado " base " " id))
      en)
    (progn
      (setq res
        (vl-catch-all-apply 'mp:insert-cant-point
          (list base (list (car p) (cadr p) 0.0) vals)))
      (if (vl-catch-all-error-p res)
        (progn
          (lr:log (strcat "  ERROR punto " base " " id ": "
            (vl-catch-all-error-message res)))
          nil)
        (progn
          (setq en (entlast))
          (setq lr:nodos (cons (list p id en base) lr:nodos))
          en)))))

(defun lr:handle-de (en)
  (if (and en (entget en)) (cdr (assoc 5 (entget en))) ""))

;; crear tramo entre dos nodos con dedupe por extremos
(setq lr:tramos-creados nil)
(defun lr:nodo-clave (n / h)
  ;; clave estable del nodo: handle si existe; si es virtual (sin
  ;; bloque), sus coordenadas -- ANTES la clave vacia hacia que todos
  ;; los tramos virtuales chocaran entre si como "duplicados"
  (setq h (lr:handle-de (caddr n)))
  (if (= h "")
    (strcat (rtos (car (car n)) 2 2) "_" (rtos (cadr (car n)) 2 2))
    h))
(defun lr:tramo (baseb n1 n2 vals / k res)
  (setq k (strcat (lr:nodo-clave n1) ">" (lr:nodo-clave n2)))
  (if (or (member k lr:tramos-creados)
          (member (strcat (lr:nodo-clave n2) ">" (lr:nodo-clave n1))
            lr:tramos-creados))
    (progn (lr:log "  tramo duplicado saltado") nil)
    (progn
      (setq vals
        (append vals
          (list (cons "POZO_INI" (cadr n1))
                (cons "POZO_FIN" (cadr n2))
                (cons "HANDLE_EXTREMO_INI" (lr:handle-de (caddr n1)))
                (cons "HANDLE_EXTREMO_FIN" (lr:handle-de (caddr n2))))))
      (setq res
        (vl-catch-all-apply 'mp:insert-cant-tramo
          (list baseb
            (list (car (car n1)) (cadr (car n1)) 0.0)
            (list (car (car n2)) (cadr (car n2)) 0.0)
            vals)))
      (if (vl-catch-all-error-p res)
        (progn
          (lr:log (strcat "  ERROR tramo " (cadr n1) "-" (cadr n2) ": "
            (vl-catch-all-error-message res)))
          nil)
        (progn
          (setq lr:tramos-creados (cons k lr:tramos-creados))
          T)))))

;; ---------- parseo de textos ----------
;; ultimo numero de un texto (cotas apiladas tapa\Pclave -> clave)
(defun lr:ultimo-numero (s / i c num nums)
  (setq i 1 num "" nums nil)
  (repeat (strlen s)
    (setq c (substr s i 1))
    (if (or (wcmatch c "#") (= c "."))
      (setq num (strcat num c))
      (progn
        (if (> (strlen num) 3) (setq nums (cons num nums)))
        (setq num "")))
    (setq i (1+ i)))
  (if (> (strlen num) 3) (setq nums (cons num nums)))
  (if nums (distof (car nums) 2) nil))

;; quita los codigos de formato MTEXT (\A1; \W0.8; \Fsimplex c0; \P {})
;; para que sus numeros no contaminen el parseo
(defun lr:sin-formato (s / i c n out)
  (setq i 1 n (strlen s) out "")
  (while (<= i n)
    (setq c (substr s i 1))
    (cond
      ((= c "\\")
        (setq c (strcase (substr s (1+ i) 1)))
        (if (member c '("P" "L" "O" "K" "X" "~" "{" "}" "\\"))
          (setq i (+ i 2) out (strcat out " "))
          (progn
            ;; codigo con parametro: saltar hasta ";"
            (while (and (<= i n) (/= (substr s i 1) ";")) (setq i (1+ i)))
            (setq i (1+ i) out (strcat out " ")))))
      ((or (= c "{") (= c "}")) (setq i (1+ i)))
      (T (setq out (strcat out c)) (setq i (1+ i)))))
  out)

;; todos los numeros de un texto (ya limpio), en orden
(defun lr:numeros (s / i c num out)
  (setq i 1 num "" out nil)
  (repeat (strlen s)
    (setq c (substr s i 1))
    (if (or (wcmatch c "#") (= c "."))
      (setq num (strcat num c))
      (progn
        (if (and (> (strlen num) 0) (/= num ".")) (setq out (cons num out)))
        (setq num "")))
    (setq i (1+ i)))
  (if (and (> (strlen num) 0) (/= num ".")) (setq out (cons num out)))
  (mapcar 'atof (reverse out)))

;; "25.31 %%C12''" / "\\A1;{\\W0.8;102.81-Ø8\"-PVC}" -> (long diam mat)
;; primer numero = longitud, segundo = diametro (acueducto usa Ø literal
;; y pluvial %%C -- por eso NO se busca el simbolo, se toman los numeros
;; en orden tras limpiar el formato)
(defun lr:parse-etq-hidro (s / nums lng diam mat)
  (setq nums (lr:numeros (lr:sin-formato s)))
  (setq lng (if (and nums (> (car nums) 0.3)) (car nums) nil))
  (setq diam
    (if (and (cadr nums) (>= (cadr nums) 1.0) (<= (cadr nums) 60.0))
      (fix (+ 0.5 (cadr nums)))
      nil))
  (setq mat nil)
  (cond
    ((vl-string-search "PVC" (strcase s)) (setq mat "PVC"))
    ((vl-string-search "-HD" (strcase s)) (setq mat "HD"))
    ((vl-string-search "NOVAFORT" (strcase s)) (setq mat "NOVAFORT"))
    ((vl-string-search "CSR" (strcase s)) (setq mat "CSR")))
  (list lng diam mat))

;; ============================================================
;; PLUVIAL
;; ============================================================
(defun lr:pluvial (/ data pozos sums cabs caps rebs ejes etiquetas cotas
                   rec lay pts id ras p n nd creados tr-creados sin-diam
                   sin-clave ext e1 e2 n1 n2 etq best bd mid lng lng2 diam
                   mat d cl tip val claves-ini claves-fin ref atts vals dom
                   tt ot)
  (setq lr:plu-tramos nil)
  (lr:log "==== PLUVIAL ====")
  (setq data (lr:read-data "data_SRC_PLUVIAL.txt"))
  (setq pozos nil sums nil cabs nil caps nil rebs nil ejes nil
        etiquetas nil cotas nil creados 0 tr-creados 0
        sin-diam 0 sin-clave 0 dom 0)
  (foreach rec data
    (setq lay (cadr rec))
    (cond
      ((and (= (car rec) "BLK") (= lay "LLUVIAS-POZO PROYECTO"))
        (setq pozos (cons rec pozos)))
      ((and (= (car rec) "BLK") (= lay "SUMIDEROS-PROY"))
        (setq sums (cons rec sums)))
      ((and (= (car rec) "BLK") (= lay "CABEZAL")
            (= (caddr rec) "CABEZAL"))
        (setq cabs (cons rec cabs)))
      ((and (= (car rec) "BLK") (= lay "CAPTACION-PROY"))
        (setq caps (cons rec caps)))
      ((and (= (car rec) "BLK") (= lay "LLUVIAS-POZO PROYECTO CAPTACION"))
        (setq rebs (cons rec rebs)))
      ((and (= (car rec) "PLW")
            (or (= lay "EJES-LLUVIAS") (= lay "LLUVIAS-DOMICILIARIAS")))
        (setq ejes (cons rec ejes)))
      ((and (= (car rec) "BLK") (wcmatch lay "LLUVIAS-DATOS*")
            (= (caddr rec) "TEXTO"))
        (setq etiquetas (cons rec etiquetas)))
      ((and (= (car rec) "MLD") (wcmatch lay "LLUVIAS COTAS*"))
        (setq cotas (cons rec cotas)))))
  (lr:log (strcat "Leidos: " (itoa (length pozos)) " pozos, "
    (itoa (length sums)) " sumideros, " (itoa (length cabs)) " cabezales, "
    (itoa (length caps)) " captaciones, " (itoa (length rebs)) " rebose/rural, "
    (itoa (length ejes)) " ejes, " (itoa (length etiquetas)) " etiquetas, "
    (itoa (length cotas)) " cotas"))
  ;; --- pozos: atributos cruzados (RASANTE=id, POZO=cota rasante) como
  ;; en el RESIDUAL
  (setq lr:nodos nil)
  (foreach rec pozos
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq id "" ras "")
    (foreach tok rec
      (if (wcmatch tok "RASANTE=*") (setq id (substr tok 9)))
      (if (wcmatch tok "POZO=*") (setq ras (substr tok 6))))
    (if (= id "") (setq id "PLU-SIN-ID"))
    (if (lr:punto "POZO_PLUVIAL" p (strcat "PLL-" id)
          (list (cons "ID" (strcat "PLL-" id))
                (cons "COTA_CLAVE_INI" "")
                (cons "RED" "ALC-PLUVIAL"))
          "MP_PUNTO_POZO_PLU*")
      (setq creados (1+ creados))))
  ;; --- sumideros (dedupe posicional: vienen duplicados en 2 capas)
  (foreach rec sums
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq id "")
    (foreach tok rec
      (if (wcmatch tok "SUMIDERO=*") (setq id (substr tok 10))))
    (if (= id "") (setq id "S-?"))
    (if (not (lr:nodo-mas-cercano p 0.2))
      (if (lr:punto "SUMIDERO" p id
            (list (cons "ID" id) (cons "RED" "ALC-PLUVIAL"))
            "MP_PUNTO_SUMIDERO*")
        (setq creados (1+ creados)))))
  ;; --- cabezales, captaciones y rebose/alcantarilla rural: el ppto los
  ;; tiene como items UN PROPIOS (Cabezal de entrega fila 1004,
  ;; Captacion de aguas lluvias 1010, Alcantarilla rural con cabezales
  ;; 1011) y el plugin NO tiene esos tipos de punto -- modelarlos como
  ;; pozo/sumidero CONTAMINARIA los conteos de pozos del presupuesto.
  ;; Quedan como NODOS VIRTUALES (los tramos conectan igual) y sus
  ;; conteos se reportan para vinculacion manual o para crear los tipos
  ;; nuevos si el usuario lo pide.
  (foreach rec (append cabs caps rebs)
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq id "")
    (foreach tok rec
      (if (and (= id "") (wcmatch tok "CABEZAL=*")) (setq id (substr tok 9)))
      (if (and (= id "") (wcmatch tok "*=REB*"))
        (setq id (substr tok (+ 2 (vl-string-search "=" tok))))))
    (if (= id "") (setq id "CAP/CP"))
    (if (not (lr:nodo-mas-cercano p 0.2))
      (setq lr:nodos (cons (list p id nil nil) lr:nodos))))
  (lr:log (strcat "AFECTACION PLUVIAL: " (itoa (length cabs))
    " cabezales de entrega, " (itoa (length caps))
    " captaciones y " (itoa (length rebs))
    " alcantarillas rurales/rebose NO se modelaron como bloques (el"
    " plugin no tiene esos tipos y el ppto los cobra como UN propios:"
    " filas 1004/1010/1011). Quedaron como nodos de conexion; conteos"
    " listos para vinculo manual."))
  (lr:log (strcat "Puntos pluviales creados/reutilizados: " (itoa creados)))
  ;; --- tramos: extremos del eje -> nodo mas cercano (tol 3.0)
  (foreach rec ejes
    (setq pts (lr:parse-pts (caddr rec)))
    (if (>= (length pts) 2)
      (progn
        (setq ext (lr:chain-extremos pts))
        (setq e1 (car ext) e2 (cadr ext))
        (setq n1 (lr:nodo-mas-cercano e1 3.0))
        (setq n2 (lr:nodo-mas-cercano e2 3.0))
        (if (and n1 n2 (not (equal n1 n2)))
          (progn
            ;; etiqueta de datos: la mas cercana al punto medio validada
            ;; por longitud +-4.5 m contra la CUERDA o la longitud real
            ;; de la cadena (la que calce -- los ejes traen decoraciones)
            (setq mid (list (/ (+ (car e1) (car e2)) 2.0)
                            (/ (+ (cadr e1) (cadr e2)) 2.0)))
            (setq lng (lr:d2 e1 e2))
            (setq lng2 (lr:chain-len pts))
            (setq best nil bd 40.0)
            (foreach etq etiquetas
              (setq p (lr:parse-pt (nth 3 etq)))
              (setq d (lr:d2 p mid))
              (if (< d bd)
                (progn
                  (setq val nil)
                  (foreach tok etq
                    (if (wcmatch tok "TEXTO=*") (setq val (substr tok 7))))
                  (if val
                    (progn
                      (setq tip (lr:parse-etq-hidro val))
                      (if (and (car tip)
                               (or (< (abs (- (car tip) lng)) 4.5)
                                   (< (abs (- (car tip) lng2)) 4.5)))
                        (setq bd d best tip)))))))
            (setq diam (if best (cadr best) nil))
            ;; material por defecto NOVAFORT: el ppto pluvial NO tiene
            ;; PVC (solo NOVAFORT/CCR/CER/CSR) y las etiquetas del plano
            ;; casi nunca declaran material
            (setq mat (if (and best (caddr best)) (caddr best) "NOVAFORT"))
            (if (null diam)
              (progn (setq sin-diam (1+ sin-diam))
                (setq diam (if (= (cadr rec) "LLUVIAS-DOMICILIARIAS") 12 nil))))
            (if (= (cadr rec) "LLUVIAS-DOMICILIARIAS") (setq dom (1+ dom)))
            ;; claves: MLD apilada cuya punta cae a <6 m del nodo; texto
            ;; mas cercano a 2 m adentro del tramo (criterio RESIDUAL)
            (setq cl (lr:clave-para e1 e2 cotas))
            (setq claves-ini cl)
            (setq cl (lr:clave-para e2 e1 cotas))
            (setq claves-fin cl)
            (if (and (null claves-ini) (null claves-fin))
              (setq sin-clave (1+ sin-clave)))
            ;; RED = "Alluvias": es el token que urb:ppto-tramo-red
            ;; espera para clasificar ALC-PLUVIAL (con "ALC-PLUVIAL"
            ;; el tramo quedaba SIN filas de presupuesto -- piloto 4)
            (setq vals
              (list (cons "RED" "Alluvias")
                    (cons "MATERIAL" mat)))
            (if diam (setq vals (cons (cons "DIAMETRO" (itoa diam)) vals)))
            (if claves-ini
              (setq vals (cons (cons "COTA_CLAVE_INI" (rtos claves-ini 2 2)) vals)))
            (if claves-fin
              (setq vals (cons (cons "COTA_CLAVE_FIN" (rtos claves-fin 2 2)) vals)))
            (if (lr:tramo "TRAMO_ALLUVIAS" n1 n2 vals)
              (progn
                (setq tr-creados (1+ tr-creados))
                (setq lr:plu-tramos
                  (cons (list (lr:nodo-clave n1) (lr:nodo-clave n2)
                          (entlast) diam)
                    lr:plu-tramos)))))
          (lr:log (strcat "  eje sin nodos en extremos ("
            (rtos (car e1) 2 1) "," (rtos (cadr e1) 2 1) ") - saltado"))))))
  (lr:log (strcat "Tramos pluviales creados: " (itoa tr-creados)
    " (domiciliarios: " (itoa dom) ") | sin diametro de etiqueta al crear: "
    (itoa sin-diam) " | sin ninguna clave: " (itoa sin-clave)))
  ;; --- propagacion de diametro por CONTINUIDAD de red: un tramo sin
  ;; etiqueta hereda el diametro del vecino conectado (el mayor si hay
  ;; varios), iterando hasta estabilizar -- asi lo leeria un ingeniero;
  ;; el plano solo etiqueta tramos representativos
  (setq n 1)
  (setq creados 0)
  (while (> n 0)
    (setq n 0)
    (foreach tt lr:plu-tramos
      (if (null (nth 3 tt))
        (progn
          (setq best nil)
          (foreach ot lr:plu-tramos
            (if (and (nth 3 ot)
                     (or (= (car ot) (car tt)) (= (car ot) (cadr tt))
                         (= (cadr ot) (car tt)) (= (cadr ot) (cadr tt))))
              (if (or (null best) (> (nth 3 ot) best))
                (setq best (nth 3 ot)))))
          (if best
            (progn
              (vl-catch-all-apply 'mp:setatt-one
                (list (caddr tt) "DIAMETRO" (itoa best)))
              (setq lr:plu-tramos
                (subst (list (car tt) (cadr tt) (caddr tt) best) tt
                  lr:plu-tramos))
              (setq n (1+ n) creados (1+ creados))))))))
  (setq n 0)
  (foreach tt lr:plu-tramos (if (null (nth 3 tt)) (setq n (1+ n))))
  (lr:log (strcat "  Propagacion por continuidad: " (itoa creados)
    " tramos heredaron diametro del vecino; quedan SIN diametro: "
    (itoa n)))
  ;; --- guardia de cordura de claves (piloto 4: en la zona del dique
  ;; las etiquetas de cota pertenecen a otra estructura y daban
  ;; profundidades de 10-17 m): si terreno - clave > 6.5 m o la clave
  ;; queda POR ENCIMA del terreno +0.5, se descartan las claves del
  ;; tramo y se re-sincroniza (excavacion vuelve a 0 y queda logueado
  ;; para completar a mano)
  (setq creados 0)
  (foreach tt lr:plu-tramos
    (setq atts (vl-catch-all-apply 'mp:att-alist (list (caddr tt))))
    (if (not (vl-catch-all-error-p atts))
      (progn
        (setq cl (atof (urb:safe-string
          (cdr (assoc "COTA_CLAVE_INI" atts)) "0")))
        (setq ras (atof (urb:safe-string
          (cdr (assoc "COTA_TN_INI" atts)) "0")))
        (if (and (> cl 100.0) (> ras 100.0)
                 (or (> (- ras cl) 6.5) (> cl (+ ras 0.5))))
          (progn
            (vl-catch-all-apply 'mp:setatt-one
              (list (caddr tt) "COTA_CLAVE_INI" ""))
            (vl-catch-all-apply 'mp:setatt-one
              (list (caddr tt) "COTA_CLAVE_FIN" ""))
            (vl-catch-all-apply 'mp:update-block-after-edit
              (list (caddr tt) nil))
            (setq creados (1+ creados)))))))
  (lr:log (strcat "  Claves DESCARTADAS por inconsistentes con el terreno: "
    (itoa creados) " tramos (quedan sin excavacion -- completar a mano)")))

;; clave para el extremo e1 del tramo e1->e2: MLD con punta a <6 m de e1,
;; desambiguada por cercania del TEXTO al punto 2 m adentro del tramo
(defun lr:clave-para (e1 e2 cotas / ref dx dy dd best bd rec pts tp txt v d)
  (setq dx (- (car e2) (car e1)) dy (- (cadr e2) (cadr e1)))
  (setq dd (sqrt (+ (* dx dx) (* dy dy))))
  (if (< dd 0.01) (setq dd 1.0))
  (setq ref (list (+ (car e1) (* 2.0 (/ dx dd)))
                  (+ (cadr e1) (* 2.0 (/ dy dd)))))
  ;; bd arranca SIN tope: el texto de la etiqueta esta a 10-20 m del
  ;; tramo; el tope de 6 m solo aplica a la PUNTA del leader (arriba).
  ;; Con bd=6.0 inicial casi ninguna clave se asignaba (bug del piloto 1)
  (setq best nil bd 1e9)
  (foreach rec cotas
    (setq pts (lr:parse-pts (caddr rec)))
    (setq tp nil)
    (foreach p pts
      (if (< (lr:d2 p e1) 6.0) (setq tp p)))
    (if tp
      (progn
        (setq txt (nth 3 rec))
        (setq v (lr:ultimo-numero txt))
        (if (and v (> v 2000.0) (< v 3000.0) pts)
          (progn
            (setq d (lr:d2 (car pts) ref))
            (if (< d bd) (setq bd d best v)))))))
  best)

;; ============================================================
;; ACUEDUCTO
;; ============================================================
(defun lr:acueducto (/ data tuberias etiquetas accs rec lay pts ext e1 e2
                     lng best bd etq p d tip diam mat creados tr sin-etq
                     id n1 n2 nd vals nombre tipo cnt-acc surf mid i tn1
                     tn2 en cnt ac seg tt ot)
  (setq lr:acu-accs nil lr:acu-tramos nil)
  (lr:log "==== ACUEDUCTO (fuente TOTALES -- la que referencia el master) ====")
  (setq data (lr:read-data "data_TOT_ACUEDUCTO.txt"))
  (setq tuberias nil etiquetas nil accs nil creados 0 tr 0 sin-etq 0
        cnt-acc 0)
  (foreach rec data
    (setq lay (cadr rec))
    (cond
      ((and (member (car rec) '("PLW" "LIN" "PL2"))
            (= lay "REDMENOR_ACUEDPROY"))
        (setq tuberias (cons rec tuberias)))
      ((and (= (car rec) "TXT") (wcmatch (strcase lay) "ACUEDUCTO-DATOS*,Acueducto-datos*"))
        (setq etiquetas (cons rec etiquetas)))
      ((and (= (car rec) "TXT") (wcmatch lay "Acueducto-datos*"))
        (setq etiquetas (cons rec etiquetas)))
      ((and (= (car rec) "BLK")
            (wcmatch (caddr rec)
              "A Tee,A Codo*,codo 45,CODO90,A Tapon,A Buje,Union,A Hidrante,Valvula HIDRANTE,VALVULA PROY,VENTOSA,VCP"))
        (setq accs (cons rec accs)))))
  (lr:log (strcat "Leidos: " (itoa (length tuberias)) " tuberias, "
    (itoa (length etiquetas)) " etiquetas, " (itoa (length accs))
    " accesorios"))
  ;; --- accesorios como nodos (mapa de tipo del plano -> catalogo)
  (setq lr:nodos nil)
  (foreach rec accs
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq nombre (caddr rec))
    (setq tipo
      (cond
        ((= nombre "A Tee") "TEE")
        ((= nombre "A Codo22.5") "CODO_22_5")
        ((= nombre "A Codo11.25") "CODO_11_5")
        ((= nombre "codo 45") "CODO_45")
        ((= nombre "CODO90") "CODO_90")
        ((= nombre "A Tapon") "TAPON")
        ((= nombre "A Buje") "REDUCCION")
        ((= nombre "Union") "OTRO")
        ((= nombre "A Hidrante") "HIDRANTE_TORRE")
        ((= nombre "Valvula HIDRANTE") "VALVULA_PIE_HIDRANTE")
        ((= nombre "VALVULA PROY") "VALVULA_RED_MENOR")
        ((= nombre "VENTOSA") "VALVULA_VENTOSA")
        ((= nombre "VCP") "VALVULA_CIERRE_PERMANENTE")
        (T "OTRO")))
    (if (not (lr:nodo-mas-cercano p 0.15))
      (progn
        (setq cnt-acc (1+ cnt-acc))
        (setq id (strcat "AC-" (itoa cnt-acc)))
        (setq en
          (lr:punto "ACCESORIO_ACUEDUCTO" p id
            (list (cons "ID" id) (cons "TIPO_ACCESORIO" tipo)
                  (cons "MATERIAL" "PVC"))
            "MP_PUNTO_ACC_ACU*"))
        (if en
          (progn
            (setq creados (1+ creados))
            (setq lr:acu-accs (cons (cons en p) lr:acu-accs)))))))
  (lr:log (strcat "Accesorios creados: " (itoa creados)))
  ;; --- tramos POR SEGMENTO (las polilineas de acueducto curvan: un
  ;; tramo recto por cada par de vertices conserva la longitud real).
  ;; La etiqueta se valida contra la longitud REAL de la polilinea
  ;; completa y aplica a todos sus segmentos. Claves: cota terreno de la
  ;; superficie - 1.00 m de recubrimiento (SUPUESTO a confirmar; sin
  ;; esto la excavacion del acueducto saldria 0 porque el plano no trae
  ;; cotas de la red presurizada).
  (setq cnt-acc 0)
  (setq surf (vl-catch-all-apply 'mp:current-terrain-surface nil))
  (if (vl-catch-all-error-p surf) (setq surf nil))
  (if (null surf)
    (lr:log "  AVISO: sin superficie de terreno -- claves de acueducto no asignadas (excavacion quedara 0)"))
  (foreach rec tuberias
    (setq pts (lr:parse-pts (caddr rec)))
    (if (>= (length pts) 2)
      (progn
        (setq lng (lr:chain-len pts))
        (setq mid (nth (/ (length pts) 2) pts))
        (setq best nil bd 25.0)
        (foreach etq etiquetas
          (setq p (lr:parse-pt (caddr etq)))
          (setq d (lr:d2 p mid))
          (if (< d bd)
            (progn
              (setq tip (lr:parse-etq-hidro (nth 3 etq)))
              (if (and (car tip) (< (abs (- (car tip) lng)) 3.5))
                (setq bd d best tip)))))
        (setq diam (if best (cadr best) nil))
        (setq mat (if (and best (caddr best)) (caddr best) "PVC"))
        (if (null best) (setq sin-etq (1+ sin-etq)))
        (setq i 0)
        (while (< i (1- (length pts)))
          (setq e1 (nth i pts) e2 (nth (1+ i) pts))
          ;; tope 130 m: en TOTALES hay polilineas en la capa de red que
          ;; NO son tuberia (p.ej. el perimetro del loteo) -- ninguna
          ;; tuberia real corre >130 m entre accesorios (etiqueta maxima
          ;; del plano: 103 m); sin este filtro 59 "tramos" sumaban
          ;; 11.5 km fantasma
          (if (and (> (lr:d2 e1 e2) 0.8) (< (lr:d2 e1 e2) 130.0))
            (progn
              (setq n1 (lr:nodo-mas-cercano e1 1.5))
              (setq n2 (lr:nodo-mas-cercano e2 1.5))
              (setq cnt-acc (1+ cnt-acc))
              (if (null n1)
                (setq n1 (list e1 (strcat "N" (itoa cnt-acc) "A") nil nil)))
              (if (null n2)
                (setq n2 (list e2 (strcat "N" (itoa cnt-acc) "B") nil nil)))
              (setq vals
                (list (cons "RED" "ACUEDUCTO")
                      (cons "TIPO_RED" "ACUEDUCTO")
                      (cons "MATERIAL" mat)))
              (if diam (setq vals (cons (cons "DIAMETRO" (itoa diam)) vals)))
              (if surf
                (progn
                  (setq tn1 (vl-catch-all-apply 'urb:surface-elevation
                    (list surf (car e1) (cadr e1))))
                  (setq tn2 (vl-catch-all-apply 'urb:surface-elevation
                    (list surf (car e2) (cadr e2))))
                  (if (and (not (vl-catch-all-error-p tn1)) tn1)
                    (setq vals (cons (cons "COTA_CLAVE_INI"
                      (rtos (- tn1 1.0) 2 2)) vals)))
                  (if (and (not (vl-catch-all-error-p tn2)) tn2)
                    (setq vals (cons (cons "COTA_CLAVE_FIN"
                      (rtos (- tn2 1.0) 2 2)) vals)))))
              (if (lr:tramo "TRAMO_ACUEDUCTO" n1 n2 vals)
                (progn
                  (setq tr (1+ tr))
                  (setq lr:acu-tramos
                    (cons (list (lr:nodo-clave n1) (lr:nodo-clave n2)
                            (entlast) diam
                            (list (/ (+ (car e1) (car e2)) 2.0)
                                  (/ (+ (cadr e1) (cadr e2)) 2.0)))
                      lr:acu-tramos))))))
          (setq i (1+ i))))))
  (lr:log (strcat "Tramos acueducto creados (por segmento): " (itoa tr)
    " | polilineas sin etiqueta validada: " (itoa sin-etq)))
  (lr:log "  SUPUESTO acueducto: recubrimiento 1.00 m sobre clave (clave = terreno - 1.00) -- confirmar")
  ;; --- propagacion de diametro por continuidad (segmentos de la misma
  ;; polilinea comparten vertice; polilineas se tocan en accesorios)
  (setq cnt 0 i 1)
  (while (> i 0)
    (setq i 0)
    (foreach tt lr:acu-tramos
      (if (null (nth 3 tt))
        (progn
          (setq best nil)
          (foreach ot lr:acu-tramos
            (if (and (nth 3 ot)
                     (or (= (car ot) (car tt)) (= (car ot) (cadr tt))
                         (= (cadr ot) (car tt)) (= (cadr ot) (cadr tt))))
              (if (or (null best) (> (nth 3 ot) best))
                (setq best (nth 3 ot)))))
          (if best
            (progn
              (vl-catch-all-apply 'mp:setatt-one
                (list (caddr tt) "DIAMETRO" (itoa best)))
              (vl-catch-all-apply 'mp:update-block-after-edit
                (list (caddr tt) nil))
              (setq lr:acu-tramos
                (subst (list (car tt) (cadr tt) (caddr tt) best
                        (nth 4 tt)) tt lr:acu-tramos))
              (setq i (1+ i) cnt (1+ cnt))))))))
  (setq i 0)
  (foreach tt lr:acu-tramos (if (null (nth 3 tt)) (setq i (1+ i))))
  (lr:log (strcat "  Propagacion acueducto: " (itoa cnt)
    " segmentos heredaron diametro; quedan SIN diametro: " (itoa i)))
  ;; --- diametro de accesorios desde el tramo vecino (el ppto cobra los
  ;; accesorios POR DIAMETRO -- Codo 45 Ø8, Tee Ø8x8...; los bloques del
  ;; plano no lo traen). Corre DESPUES de propagar para heredar mas.
  (setq cnt 0)
  (foreach ac lr:acu-accs
    (setq best nil bd 12.0)
    (foreach tt lr:acu-tramos
      (if (nth 3 tt)
        (progn
          (setq d (lr:d2 (cdr ac) (nth 4 tt)))
          (if (< d bd) (setq bd d best (nth 3 tt))))))
    (if best
      (progn
        (vl-catch-all-apply 'mp:setatt-one
          (list (car ac) "DIAMETRO" (itoa best)))
        (setq cnt (1+ cnt)))))
  (lr:log (strcat "  Diametro asignado desde el tramo vecino a " (itoa cnt)
    " de " (itoa (length lr:acu-accs)) " accesorios"))
  ;; --- acometidas: solo etiquetas en el plano (sin geometria propia);
  ;; el ppto las cobra como UN por diametro (filas 804-808)
  (setq cnt 0)
  (foreach etq etiquetas
    (if (vl-string-search "ACOMETIDA" (strcase (nth 3 etq)))
      (setq cnt (1+ cnt))))
  (lr:log (strcat "AFECTACION ACUEDUCTO: " (itoa cnt)
    " etiquetas de ACOMETIDA en el plano -- el ppto las cobra como UN"
    " por diametro (filas 804-808); NO se modelaron (sin tipo en el"
    " plugin). Conteo listo para vinculo manual.")))

;; ============================================================
;; MEDIA TENSION (SERIE 1)
;; ============================================================
(defun lr:mt (/ data canaliz etiquetas cajas equipos postes rec lay pts
              ext e1 e2 lng best bd etq p d creados tr sin-etq id n1 n2
              vals txt ductos diamd libres pos cnt info dbg cerca cd)
  (lr:log "==== MEDIA TENSION (SERIE 1) ====")
  (setq data (lr:read-data "data_SRC_SERIE1.txt"))
  (setq canaliz nil etiquetas nil cajas nil equipos nil postes nil
        creados 0 tr 0 sin-etq 0 cnt 0)
  (foreach rec data
    (setq lay (cadr rec))
    (cond
      ((and (member (car rec) '("PLW" "LIN"))
            (= lay "0_0 TUBERIA PROY"))
        (setq canaliz (cons rec canaliz)))
      ((and (= (car rec) "TXT") (= lay "0_0 TEXTO"))
        (setq etiquetas (cons rec etiquetas)))
      ((and (= (car rec) "BLK") (= lay "0_0 CAJAS"))
        (setq cajas (cons rec cajas)))
      ((and (= (car rec) "BLK")
            (wcmatch (caddr rec) "SIMBOLOTRAFO,SIMBOLO TRAFO*,SUBESTACION"))
        (setq equipos (cons rec equipos)))
      ((and (= (car rec) "BLK") (wcmatch (caddr rec) "Poste R*"))
        (setq postes (cons rec postes)))))
  (lr:log (strcat "Leidos: " (itoa (length canaliz)) " segmentos de canalizacion, "
    (itoa (length etiquetas)) " textos, " (itoa (length cajas)) " cajas, "
    (itoa (length equipos)) " trafos/subestaciones, "
    (itoa (length postes)) " postes"))
  ;; --- cajas CS276/CS280 como nodos
  (setq lr:nodos nil)
  (foreach rec cajas
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq cnt (1+ cnt))
    (setq id (strcat "C276-" (itoa cnt)))
    (if (wcmatch (caddr rec) "*280*") (setq id (strcat "C280-" (itoa cnt))))
    (if (not (lr:nodo-mas-cercano p 0.15))
      (if (lr:punto
            (if (wcmatch (caddr rec) "*280*") "CAMARA_CS280" "CAMARA_CS276")
            p id
            (list (cons "ID" id)
                  (cons "TIPO_CAJA"
                    (if (wcmatch (caddr rec) "*280*") "CS-280" "CS-276")))
            "MP_PUNTO_CAMARA*")
        (setq creados (1+ creados)))))
  (lr:log (strcat "Cajas creadas: " (itoa creados)))
  ;; --- trafos/subestaciones (SIMBOLOTRAFO = S/E T-Lxx del plano) y
  ;; postes R-12m; ambos como puntos-nodo tambien
  (setq creados 0 cnt 0)
  (foreach rec equipos
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq cnt (1+ cnt))
    (if (not (lr:nodo-mas-cercano p 0.3))
      (if (lr:punto "SUBESTACION_E" p (strcat "SE-" (itoa cnt))
            (list (cons "ID" (strcat "SE-" (itoa cnt))))
            "MP_PUNTO_SUBESTACION*")
        (setq creados (1+ creados)))))
  (foreach rec postes
    (setq p (lr:parse-pt (nth 3 rec)))
    (setq cnt (1+ cnt))
    (if (not (lr:nodo-mas-cercano p 0.3))
      (if (lr:punto "POSTE_ELEC" p (strcat "P-" (itoa cnt))
            (list (cons "ID" (strcat "P-" (itoa cnt))))
            "MP_PUNTO_POSTE*")
        (setq creados (1+ creados)))))
  (lr:log (strcat "Trafos/subestaciones/postes creados: " (itoa creados)))
  ;; --- canalizacion: cada segmento un TRAMO_E_MT; datos de la
  ;; etiqueta "d= 38,2m 6%%C6\" PVC 3 Libres" validada por longitud
  (setq dbg 0)
  (foreach rec canaliz
    (setq pts (lr:parse-pts (caddr rec)))
    (if (>= (length pts) 2)
      (progn
        (setq ext (lr:chain-extremos pts))
        (setq e1 (car ext) e2 (cadr ext))
        (setq lng (lr:chain-len pts))
        (if (> lng 0.8)
          (progn
            (setq best nil bd 35.0 cerca nil cd 1e9)
            (foreach etq etiquetas
              (setq txt (nth 3 etq))
              (setq pos (vl-string-search "d=" txt))
              (if pos
                (progn
                  (setq p (lr:parse-pt (caddr etq)))
                  (setq d (lr:d2 p (list (/ (+ (car e1) (car e2)) 2.0)
                                         (/ (+ (cadr e1) (cadr e2)) 2.0))))
                  (if (< d cd)
                    (progn (setq cd d)
                      (setq cerca (lr:parse-etq-mt txt))))
                  (if (< d bd)
                    (progn
                      (setq info (lr:parse-etq-mt txt))
                      (if (and (car info)
                               (< (abs (- (car info) lng)) 6.0))
                        (setq bd d best info)))))))
            (if (null best)
              (progn
                (setq sin-etq (1+ sin-etq))
                (if (< dbg 6)
                  (progn
                    (setq dbg (1+ dbg))
                    (lr:log (strcat "  DBG sin-etq: seg-lng="
                      (rtos lng 2 1) " etiqueta-mas-cercana d="
                      (rtos cd 2 1) " m, lng-etq="
                      (if (and cerca (car cerca))
                        (rtos (car cerca) 2 1) "nil")))))))
            (setq ductos (if best (cadr best) 6))
            (setq diamd (if best (caddr best) 6))
            (setq libres (if (and best (nth 3 best)) (nth 3 best) 0))
            (setq n1 (lr:nodo-mas-cercano e1 2.0))
            (setq n2 (lr:nodo-mas-cercano e2 2.0))
            (setq cnt (1+ cnt))
            (if (null n1) (setq n1 (list e1 (strcat "MT" (itoa cnt) "A") nil nil)))
            (if (null n2) (setq n2 (list e2 (strcat "MT" (itoa cnt) "B") nil nil)))
            (setq vals
              (list (cons "RED" "ELECTRICA-MT")
                    (cons "TIPO_RED" "MT")
                    (cons "UBICACION" "ANDEN O ZONA VERDE")
                    (cons "DUCTOS" (itoa ductos))
                    (cons "DIAM_DUCTO" (itoa diamd))
                    (cons "MATERIAL_DUCTO" "PVC")
                    (cons "LIBRES" (itoa libres))
                    (cons "CONDUCTOR" (if (and best (nth 4 best)) (nth 4 best) ""))))
            (if (lr:tramo "TRAMO_E_MT" n1 n2 vals)
              (setq tr (1+ tr))))))))
  (lr:log (strcat "Tramos MT creados: " (itoa tr)
    " | sin etiqueta validada (banco 6d6\" por defecto): " (itoa sin-etq))))

;; "...3x185mm2...\Pd= 38,2m 6%%C6\" PVC   3 Libres" ->
;; (long ductos diam-ducto libres conductor)
(defun lr:parse-etq-mt (s / pos lng resto ductos diamd libres cond-s p2)
  (setq lng nil ductos nil diamd nil libres 0 cond-s "")
  (setq pos (vl-string-search "d=" s))
  (if pos
    (progn
      (setq resto (substr s (+ pos 3)))
      (setq lng (lr:num-coma resto))
      (setq p2 (vl-string-search "%%C" resto))
      (if p2
        (progn
          ;; el numero pegado ANTES de %%C = ductos; despues = diametro
          (setq ductos (lr:digito-antes resto p2))
          (setq diamd (atoi (substr resto (+ p2 4))))
          (if (<= diamd 0) (setq diamd 6))))
      (setq p2 (vl-string-search "Libres" resto))
      (if p2 (setq libres (lr:digito-antes resto p2)))))
  (if (vl-string-search "3x185" s) (setq cond-s "3x185mm2 Al XLPE 15kV"))
  (if (and (= cond-s "") (vl-string-search "3x70" s))
    (setq cond-s "3x70mm2 Al XLPE 15kV"))
  (list lng (if ductos ductos 6) (if diamd diamd 6) libres cond-s))

;; digito(s) inmediatamente antes de la posicion pos (saltando espacios)
(defun lr:digito-antes (s pos / i c num)
  (setq i pos num "")
  (while (and (> i 0) (= (substr s i 1) " ")) (setq i (1- i)))
  (while (and (> i 0) (wcmatch (substr s i 1) "#"))
    (setq num (strcat (substr s i 1) num))
    (setq i (1- i)))
  (if (> (strlen num) 0) (atoi num) nil))

;; ============================================================
;; ALUMBRADO (SERIE 6): luminarias + TRAMOS AP RECONSTRUIDOS.
;; La red NO esta dibujada en el plano: los circuitos se reconstruyen
;; encadenando luminarias del MISMO circuito (prefijo D..J) con numero
;; consecutivo n -> n+1, tomando la instancia MAS CERCANA (los IDs se
;; repiten hasta 5 veces porque cada S/E reutiliza las letras; tope 80
;; m). Validado offline: 553 enlaces, distancia media 29 m, total 16.0
;; km ~ 15.58 km sumados de las etiquetas "d=" (dos totales
;; independientes que coinciden). Cada tramo toma ductos/conductor de
;; la etiqueta mas cercana que calce en longitud (default 1 ducto de
;; 3" PVC + 3x4+4 THW).
(defun lr:ap (/ data lums etiquetas rec lay p id creados etq total-m
              cnt-etq txt lng pos pfx num dash lm lm2 best bd d n1 n2
              info vals tr en)
  (lr:log "==== ALUMBRADO (SERIE 6) ====")
  (setq data (lr:read-data "data_SRC_SERIE6.txt"))
  (setq lums nil etiquetas nil creados 0 total-m 0.0 cnt-etq 0 tr 0)
  (setq lr:nodos nil)
  (foreach rec data
    (setq lay (cadr rec))
    (cond
      ((and (= (car rec) "TXT") (= lay "0_0 TEXTO NODOS"))
        (setq p (lr:parse-pt (caddr rec)))
        (setq id (vl-string-trim " " (nth 3 rec)))
        (if (and p (wcmatch id "@-##,@-#,@@-##,@@-#"))
          (if (not (lr:nodo-mas-cercano p 0.5))
            (progn
              (setq en
                (lr:punto "LUMINARIA_AP" p id
                  (list (cons "CODIGO" id)
                        (cons "TIPO_LUMINARIA" "LED"))
                  "MP_PUNTO_LUMINARIA*"))
              (if en
                (progn
                  (setq creados (1+ creados))
                  (setq dash (vl-string-search "-" id))
                  (setq pfx (substr id 1 dash))
                  (setq num (atoi (substr id (+ dash 2))))
                  (setq lums
                    (cons (list pfx num p en id) lums))))))))
      ((and (member (car rec) '("TXT" "MLD")) (= lay "0_0 TEXTO"))
        (setq txt (nth 3 rec))
        (if (null txt) (setq txt ""))
        (setq pos (vl-string-search "d=" txt))
        (if pos
          (progn
            (setq lng (lr:num-coma (substr txt (+ pos 3))))
            (if (and lng (> lng 0.0) (< lng 500.0))
              (progn
                (setq total-m (+ total-m lng) cnt-etq (1+ cnt-etq))
                ;; MLD trae cadena multipunto -- tomar el PRIMER punto
                ;; valido via parse-pts (parse-pt directo daba y=nil)
                (setq p (car (lr:parse-pts (caddr rec))))
                (if p
                  (setq etiquetas
                    (cons (list p lng txt) etiquetas))))))))))
  (lr:log (strcat "Luminarias creadas: " (itoa creados)))
  ;; --- tramos: encadenamiento n -> n+1 del mismo circuito
  (foreach lm lums
    (setq best nil bd 80.0)
    (foreach lm2 lums
      (if (and (= (car lm2) (car lm))
               (= (cadr lm2) (1+ (cadr lm))))
        (progn
          (setq d (lr:d2 (caddr lm) (caddr lm2)))
          (if (< d bd) (setq bd d best lm2)))))
    (if best
      (progn
        (setq lng (lr:d2 (caddr lm) (caddr best)))
        ;; etiqueta mas cercana al punto medio que calce en longitud
        (setq info nil d 1e9)
        (setq p (list (/ (+ (car (caddr lm)) (car (caddr best))) 2.0)
                      (/ (+ (cadr (caddr lm)) (cadr (caddr best))) 2.0)))
        (foreach etq etiquetas
          (if (and (< (lr:d2 (car etq) p) d)
                   (< (abs (- (cadr etq) lng)) 8.0))
            (progn (setq d (lr:d2 (car etq) p))
              (setq info (lr:parse-etq-mt (caddr etq))))))
        (setq n1 (list (caddr lm) (nth 4 lm) (cadddr lm) "LUMINARIA_AP"))
        (setq n2 (list (caddr best) (nth 4 best) (cadddr best) "LUMINARIA_AP"))
        (setq vals
          (list (cons "RED" "ELECTRICA-BT-AP")
                (cons "TIPO_RED" "AP")
                (cons "UBICACION" "ANDEN O ZONA VERDE")
                (cons "DUCTOS" (itoa (if info (cadr info) 1)))
                (cons "DIAM_DUCTO" (itoa (if info (caddr info) 3)))
                (cons "MATERIAL_DUCTO" "PVC")
                (cons "CONDUCTOR" "3x4+4 THW")))
        (if (lr:tramo "TRAMO_E_BT_AP" n1 n2 vals)
          (setq tr (1+ tr))))))
  (lr:log (strcat "Tramos de alumbrado reconstruidos: " (itoa tr)
    " (encadenando luminarias consecutivas del mismo circuito;"
    " validado contra " (itoa cnt-etq) " etiquetas 'd=' que suman "
    (rtos total-m 2 1) " m)")))

;; ============================================================
;; MAIN
;; ============================================================
;; agrega las filas de presupuesto que generarian los elementos del
;; dibujo (mismos colectores del export, sin abrir Excel) y las agrupa
;; por red|concepto|um para el cruce de inconsistencias
(defun lr:dump-rows (/ rows f agreg r key itm)
  (setq rows
    (append
      (vl-catch-all-apply 'urb:ppto-rows-tramos nil)
      (vl-catch-all-apply 'urb:ppto-rows-puntos nil)))
  (if (vl-catch-all-error-p rows) (setq rows nil))
  (setq agreg nil)
  (foreach r rows
    (if (and r (listp r) (>= (length r) 9))
      (progn
        (setq key (strcat (nth 0 r) "|" (nth 1 r) "|" (nth 7 r)))
        (setq itm (assoc key agreg))
        (if itm
          (setq agreg (subst (cons key (+ (cdr itm) (nth 8 r))) itm agreg))
          (setq agreg (cons (cons key (nth 8 r)) agreg))))))
  (setq f (open (strcat lr:dir "cantidades_modelo.txt") "w"))
  (if f
    (progn
      (write-line "red|concepto|um = cantidad total (todo el dibujo)" f)
      (foreach itm agreg
        (write-line (strcat (car itm) " = " (rtos (cdr itm) 2 2)) f))
      (close f)
      (lr:log (strcat "Cantidades del modelo volcadas: "
        (itoa (length agreg)) " conceptos en cantidades_modelo.txt")))
    (lr:log "ERROR: no se pudo escribir cantidades_modelo.txt")))

(defun lr:fase (nombre fn / r)
  ;; los errores de una fase NO se tragan callados (leccion v2: lr:ap
  ;; murio sin rastro tras crear las luminarias)
  (setq r (vl-catch-all-apply fn nil))
  (if (vl-catch-all-error-p r)
    (lr:log (strcat "ERROR EN FASE " nombre ": "
      (vl-catch-all-error-message r))))
  r)

(defun c:LOTEREDES (/ t0)
  (setq lr:logf (open (strcat lr:dir "lote_result.txt") "w"))
  (if lr:logf (progn (write-line "LOTE REDES - inicio" lr:logf) (close lr:logf)))
  (lr:log (strcat "Dibujo: " (getvar "DWGNAME")))
  (vl-catch-all-apply 'mp:ensure-layers nil)
  (lr:cargar-existentes)
  (lr:fase "pluvial" 'lr:pluvial)
  (lr:cargar-existentes)
  (lr:fase "acueducto" 'lr:acueducto)
  (lr:cargar-existentes)
  (lr:fase "mt" 'lr:mt)
  (lr:cargar-existentes)
  (lr:fase "ap" 'lr:ap)
  (lr:fase "dump" 'lr:dump-rows)
  (lr:log "LOTE-REDES-TERMINADO")
  (princ))
(princ "\nlote_redes.lsp cargado. Comando: LOTEREDES")
(princ)
