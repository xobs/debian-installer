<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
<!ENTITY dbstyle SYSTEM "/usr/share/sgml/docbook/stylesheet/dsssl/modular/print/docbook.dsl" CDATA DSSSL>
]>
<style-sheet>
<style-specification use="docbook">
<style-specification-body>

(define %section-autolabel% 
  ;; Are sections enumerated?
   #t )

(define %paper-type%
  ;; Name of paper type
    "A4"
    ;;  "USletter"
    )
(define %hyphenation%
  ;; Allow automatic hyphenation?
    #t)

(define %default-quadding%
    'justify)

(define %language%
    'NL)

</style-specification-body>
</style-specification>
<external-specification id="docbook" document="dbstyle">
</style-sheet>
