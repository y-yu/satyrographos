open Satyrographos
open Core

let scheme_version = 1

let prefix = match SatysfiDirs.home_dir () with
  | Some(d) -> d
  | None -> failwith "Cannot find home directory"

let target_dist_dir = Filename.concat prefix ".satysfi"
let root_dir = Filename.concat prefix ".satyrographos"
let repository_dir = SatyrographosDirs.repository_dir root_dir
let library_dir = SatyrographosDirs.library_dir root_dir
let metadata_file = SatyrographosDirs.metadata_file root_dir

let current_scheme_version = SatyrographosDirs.get_scheme_version root_dir

(* TODO Move this to a new module *)
let initialize () =
  match current_scheme_version with
  | None ->
    Repository.initialize repository_dir metadata_file;
    Registry.initialize library_dir metadata_file;
    SatyrographosDirs.mark_scheme_version root_dir scheme_version
  | Some 0 -> Printf.sprintf "Semantics of `pin add` has been changed.\nPlease remove %s to continue." root_dir |> failwith
  | Some 1 -> ()
  | Some v -> Printf.sprintf "Unknown scheme version %d" v |> failwith

let () =
  initialize ()

(* Source repository *)
let repo = Repository.read repository_dir metadata_file
(* Binary registry *)
let reg = Registry.read library_dir repo metadata_file
let reg_opam =
  SatysfiDirs.opam_share_dir ()
  |> Option.map ~f:(fun opam_share_dir ->
      OpamSatysfiRegistry.read (Filename.concat opam_share_dir "satysfi"))

let default_target_dir =
  Sys.getenv "SATYSFI_RUNTIME"
  |> Option.value ~default:target_dist_dir
  |> (fun dir -> Filename.concat dir "dist")