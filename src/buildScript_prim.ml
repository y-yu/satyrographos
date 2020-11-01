open Core

type position = int * int
[@@deriving sexp]

let position_of_range (r : Sexp.Annotated.range) = 
  let pos = r.start_pos in
  (pos.line, pos.col + 1)

type link = {
  dst: string;
  src: string;
}
[@@deriving sexp]

type source = [
  | `Doc of link
  | `File of link
  | `Font of link
  | `Hash of link
  | `Package of link
]
[@@deriving sexp]

type sources = source list
[@@deriving sexp]

let pacages_of_sources =
  let f = function
    | `Package l -> [l]
    | _ -> []
  in
  List.concat_map ~f

let empty_sources = []

module CompatibilityIdents = Set.Make(String)
module Compatibility = struct
  type t =
    | Satyrographos of string
    | RenamePackage of string * string
    | RenameFont of string * string
    [@@deriving sexp, compare]
end
module CompatibilitySet = Set.Make(Compatibility)

type library = {
  name: string;
  version: string;
  opam: string;
  sources: sources [@sexp.omit_nil];
  dependencies: Library.Dependency.t [@sexp.omit_nil];
  compatibility: CompatibilitySet.t [@sexp.omit_nil];
  position: position option;
} [@@deriving sexp]

type documentSource = [
  | `Doc of link
]
[@@deriving sexp]

type libraryDoc = {
  name: string;
  version: string;
  opam: string;
  workingDirectory: string;
  build: string list list [@sexp.omit_nil];
  sources: documentSource list [@sexp.omit_nil];
  dependencies: Library.Dependency.t [@sexp.omit_nil];
  position: position option;
} [@@deriving sexp]

type doc = {
  name: string;
  workingDirectory: string;
  build: string list list [@sexp.omit_nil];
  dependencies: Library.Dependency.t [@sexp.omit_nil];
  position: position option;
} [@@deriving sexp]

type m =
  | Library of library
  | LibraryDoc of libraryDoc
  | Doc of doc
  [@@deriving sexp]

module StringMap = Map.Make(String)
module StringSet = Set.Make(String)

type t =
  | Lang_0_0_2 of m StringMap.t
  | Lang_0_0_3 of m StringMap.t
[@@deriving sexp]

let get_module_map = function
  | Lang_0_0_2 module_map
  | Lang_0_0_3 module_map ->
    module_map

let library_to_opam_file name =
  let name = OpamPackage.Name.of_string ("satysfi-" ^ name) in
  OpamFile.OPAM.empty
  |> OpamFile.OPAM.with_name name

let library_doc_to_opam_file name =
  let name = OpamPackage.Name.of_string ("satysfi-" ^ name ^ "-doc") in
  OpamFile.OPAM.empty
  |> OpamFile.OPAM.with_name name

let export_opam_package = function
  | Library p ->
    let file = OpamFilename.raw p.opam in
    library_to_opam_file p.name
    |> OpamFile.OPAM.write (OpamFile.make file)
  | LibraryDoc p ->
    let file = OpamFilename.raw p.opam in
    library_doc_to_opam_file p.name
    |> OpamFile.OPAM.write (OpamFile.make file)
  | Doc _ ->
    failwithf "export_opam_package does not support doc modules" ()

let export_opam bs =
  StringMap.iter bs ~f:export_opam_package

let get_compatibility_opt = function
  | Library l -> Some l.compatibility
  | LibraryDoc _ -> None
  | Doc _ -> None

let get_dependencies_opt = function
  | Library l -> Some l.dependencies
  | LibraryDoc l -> Some l.dependencies
  | Doc l -> Some l.dependencies

let get_name = function
  | Library l -> l.name
  | LibraryDoc l -> l.name
  | Doc l -> l.name (* TODO Return None *)

let get_opam_opt = function
  | Library l -> Some l.opam
  | LibraryDoc l -> Some l.opam
  | Doc _ -> None

let get_position_opt = function
  | Library l -> l.position
  | LibraryDoc l -> l.position
  | Doc l -> l.position

let get_sources_opt : m -> source list option = function
  | Library l -> Some l.sources
  | LibraryDoc l -> Some (l.sources :> source list)
  | Doc _ -> None

let get_version_opt = function
  | Library l -> Some l.version
  | LibraryDoc l -> Some l.version
  | Doc _ -> None

(* Compatibility treatment *)
let compatibility_treatment (m: m) (l: Library.t) =
  let f = function
    | Compatibility.RenamePackage (n, o) ->
      Library.Compatibility.{ empty with
        rename_packages = Library.RenameSet.singleton Library.Rename.{
          new_name = n;
          old_name = o;
        }
      }
    | Compatibility.RenameFont (n, o) ->
      Library.Compatibility.{ empty with
        rename_fonts = Library.RenameSet.singleton Library.Rename.{
          new_name = n;
          old_name = o;
        }
      }
    | Satyrographos "0.0.1" ->
      Library.Compatibility.empty
    | unknown_symbol -> begin
      let unknown_symbol =
      unknown_symbol
      |> [%sexp_of: Compatibility.t]
      |> Sexp.to_string_hum
      in
      failwithf "Unknown compatibility symbols: %s\n" unknown_symbol ()
  end
  in
  let compatibility =
    get_compatibility_opt m
    |> Option.value_map ~default:[] ~f:CompatibilitySet.to_list
    |> List.map ~f
    |> Library.Compatibility.union_list
  in
  Library.(union l { empty with compatibility})

(* Read *)
let rebase_file ~src_dir ~library_name =
  let append_prefix dst_dir {dst; src} =
    let dst_prefix =
      if String.is_empty dst_dir
      then ident
      else Filename.concat dst_dir in
    {dst=dst_prefix dst; src=Filename.concat src_dir src}
  in
  function
  | `File l ->
    `Filename (append_prefix "" l)
  | `Hash l ->
    `Hash (append_prefix "hash" l)
  | `Font l ->
    `Filename (append_prefix (Filename.concat "fonts" library_name) l)
  | `Package l ->
    `Filename (append_prefix (Filename.concat "packages" library_name) l)
  | `Doc l ->
    `Filename (append_prefix (Filename.concat "docs" library_name) l)

let read_module (m: m) ~src_dir =
  let name = get_name m in
  let version = get_version_opt m in
  let dependencies =
    get_dependencies_opt m
    |> Option.value ~default:(Library.Dependency.empty)
  in
  let sources =
    get_sources_opt m
    |> Option.value ~default:[]
  in
  let to_update_library_function = function
    | `Hash {dst; src} ->
      Library.add_hash dst src
    | `Filename {dst; src} ->
      Library.add_file dst src
  in
  let initial_library =
    Library.{ empty with
              name = Some name;
              version;
              dependencies;
            }
  in
  let libraries =
    List.fold sources ~init:initial_library ~f:(fun l s ->
        (rebase_file ~src_dir ~library_name:name s |> to_update_library_function) l
      )
  in
  Library.union initial_library libraries
  |> compatibility_treatment m
