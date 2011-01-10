#lang racket/base
(require racket/class
         racket/file
         racket/path
         racket/math
         "syntax.rkt"
         ffi/unsafe
         "../unsafe/cairo.ss"
	 "dc.ss"
         "font.ss"
         "local.ss"
         "ps-setup.ss"
         "write-bytes.rkt")

(provide svg-dc%)

(define dc-backend%
  (class default-dc-backend%
    (init [(init-w width)]
          [(init-h height)]
          [(init-output output)]
          [exists 'error])

    (unless (and (real? init-w) (not (negative? init-w)))
      (raise-type-error (init-name 'svg-dc%) "nonnegative real or #f" init-w))
    (unless (and (real? init-h) (not (negative? init-h)))
      (raise-type-error (init-name 'svg-dc%) "nonnegative real or #f" init-h))
    (unless (or (output-port? init-output)
                (path-string? init-output))
      (raise-type-error (init-name 'svg-dc%) "path string or output port" init-output))
    (unless (memq exists '(error append update can-update
                                 replace truncate
                                 must-truncate truncate/replace))
      (raise-type-error (init-name 'svg-dc%) 
                        "'error, 'append, 'update, 'can-update, 'replace, 'truncate, 'must-truncate, or 'truncate/replace"
                        exists))

    (define width init-w)
    (define height init-h)
    (define close-port? (path-string? init-output))

    (define port-box ; needs to be accessible as long as `s' or `c'
      (let ([output (if (output-port? init-output)
                        init-output
                        (open-output-file init-output #:exists exists))])
        (make-immobile output)))
    (define s (cairo_svg_surface_create_for_stream 
               write_port_bytes
               port-box
               width
               height))

    (define c (and s (cairo_create s)))    
    (when s (cairo_surface_destroy s))

    (define/override (ok?) (and c #t))

    (define/override (get-cr) c)

    (def/override (get-size)
      (values width height))

    (define/override (end-cr)
      (cairo_surface_finish s)
      (cairo_destroy c)
      (set! c #f)
      (set! s #f)
      (when close-port?
        (close-output-port (ptr-ref port-box _racket)))
      (set! port-box #f))

    (define/override (get-pango font)
      (send font get-pango))

    (define/override (get-font-metrics-key sx sy)
      (if (and (= sx 1.0) (= sy 1.0))
          3
          0))

    (define/override (can-combine-text? sz)
      #t)

    (super-new)))

(define svg-dc% (class (dc-mixin dc-backend%)
                  (super-new)))