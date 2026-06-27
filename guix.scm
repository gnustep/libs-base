(use-modules (guix)
             (guix build-system gnu)
             (guix git-download)
             ((guix licenses) #:prefix license:)
             (gnu packages autotools)
             (gnu packages curl)
             (gnu packages gnustep)
             (gnu packages icu4c)
             (gnu packages pkg-config)
             (gnu packages libffi)
             (gnu packages tls)
             (gnu packages xml))

(define vcs-file?
  (or (git-predicate (current-source-directory))
      (const #t)))

(package
  (name "gnustep-base")
  (version "1.31.1")
  (source (local-file "." "gnustep-base-checkout"
            #:recursive? #t
            #:select? vcs-file?))
  (build-system gnu-build-system)
  (arguments
    (list #:configure-flags #~'("--with-installation-domain=SYSTEM")))
  (native-inputs
    (append (list autoconf
                  automake
                  pkg-config)))
  (inputs
    (list curl
          gnustep-make
          gnutls
          icu4c
          libffi
          libxml2
          libxslt))
  (synopsis "GNUstep base library.")
  (description "Base library for GNUstep software, compatible with OpenStep Foundation.")
  (home-page "https://www.gnustep.org")
  (license license:gpl2))

