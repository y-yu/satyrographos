open Core

let satysfi_package_opam =
  "satysfi-package.opam", TestLib.opam_file_for_test
    ~name:"satysfi-package"
    ~version:"0.1"
    ()

let satysfi_package_doc_opam =
  "satysfi-package-doc.opam", TestLib.opam_file_for_test
    ~name:"satysfi-package-doc"
    ~version:"0.1"
    ()

let satyristes =
  "Satyristes", sprintf
    {|(version "0.0.2")

(library
  (name "package")
  (version "0.1")
  (sources ())
  (opam "satysfi-package.opam")
  (dependencies ((unspecified-package ()))))

(libraryDoc
  (name "package-doc")
  (version "0.1")
  (build ())
  (sources ())
  (opam "satysfi-package-doc.opam")
  (dependencies ((package ()))))
|}

let files =
  [ satysfi_package_opam;
    satysfi_package_doc_opam;
    satyristes;
  ]

let () =
  TestCommand.test_lint_command files
