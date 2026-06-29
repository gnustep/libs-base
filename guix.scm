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
             (gnu packages base)
             (gnu packages xml))

(define vcs-file?
  (or (git-predicate (current-source-directory))
      (const #t)))

(define (patch-gnustep-config-shell-invocation)
  #~(lambda _
      (mkdir-p "bin")
      (copy-file (which "gnustep-config") "bin/gnustep-config")
      (chmod "bin/gnustep-config" #o755)
      (invoke "sed" "-i" "s|make |make SHELL=bash |g" "bin/gnustep-config")
      (setenv "PATH" (string-append (getcwd) "/bin:" (getenv "PATH")))
      #t))

(define (install-gnustep-rewrite-fs-layout)
  #~(lambda* (#:key outputs #:allow-other-keys)
      (let ((out (assoc-ref outputs "out")))
        (substitute* "Makefile.postamble"
          (("\\$\\(GNUSTEP_MAKEFILES\\)")
           (string-append out "/share/GNUstep/Makefiles")))
        (invoke "make" "install" "SHELL=bash"
                (string-append "GNUSTEP_HEADERS=" out "/include")
                (string-append "GNUSTEP_SYSTEM_HEADERS=" out "/include")
                (string-append "GNUSTEP_LIBRARIES=" out "/lib")
                (string-append "GNUSTEP_SYSTEM_LIBRARIES=" out "/lib")
                (string-append "GNUSTEP_LIBRARY=" out "/lib/GNUstep")
                (string-append "GNUSTEP_SYSTEM_LIBRARY=" out "/lib/GNUstep")
                (string-append "GNUSTEP_TOOLS=" out "/bin")
                (string-append "GNUSTEP_SYSTEM_TOOLS=" out "/bin")
                (string-append "GNUSTEP_BINS=" out "/bin")
                (string-append "GNUSTEP_SYSTEM_BINS=" out "/bin")
                (string-append "GNUSTEP_APPS=" out "/lib/GNUstep/Applications")
                (string-append "GNUSTEP_SYSTEM_APPS=" out "/lib/GNUstep/Applications")
                (string-append "GNUSTEP_SERVICES=" out "/libexec/GNUstep/Services")
                (string-append "GNUSTEP_SYSTEM_SERVICES=" out "/libexec/GNUstep/Services")
                (string-append "GNUSTEP_DOC=" out "/share/GNUstep/Documentation")
                (string-append "GNUSTEP_SYSTEM_DOC=" out "/share/GNUstep/Documentation")
                (string-append "GNUSTEP_DOC_MAN=" out "/share/man")
                (string-append "GNUSTEP_SYSTEM_DOC_MAN=" out "/share/man")
                (string-append "GNUSTEP_MAN=" out "/share/man")
                (string-append "GNUSTEP_SYSTEM_MAN=" out "/share/man")
                (string-append "GNUSTEP_DOC_INFO=" out "/share/info")
                (string-append "GNUSTEP_SYSTEM_DOC_INFO=" out "/share/info")
                (string-append "GNUSTEP_WEB_APPS=" out "/lib/GNUstep/WebApplications")
                (string-append "GNUSTEP_SYSTEM_WEB_APPS=" out "/lib/GNUstep/WebApplications"))
        #t)))

(package
  (name "gnustep-base")
  (version "1.31.1-git")
  (source (local-file "." "gnustep-base-checkout"
            #:recursive? #t
            #:select? vcs-file?))
  (build-system gnu-build-system)
  (arguments
    (list #:tests? #f
          #:configure-flags #~'("--with-installation-domain=SYSTEM")
          #:make-flags #~(list "SHELL=bash"
                               (string-append "ADDITIONAL_LDFLAGS=-Wl,-rpath=" #$output "/lib"))
          #:phases
          #~(modify-phases %standard-phases
              (replace 'install #$(install-gnustep-rewrite-fs-layout))
              (add-before 'configure 'patch-gnustep-config #$(patch-gnustep-config-shell-invocation)))))
  (native-inputs
    (append (list autoconf
                  automake
                  pkg-config
                  which)))
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

