(*
 * Actor - Parallel & Distributed Engine of Owl System
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 *)

module Make
  (Net : Actor_net.Sig)
  (Sys : Actor_sys.Sig)
  = struct

  module Server = Actor_mapreserver.Make (Net) (Sys)

  module Client = Actor_mapreclient.Make (Net) (Sys)

  open Actor_types


  let init config =
    let uuid = config.myself in
    let addr = Hashtbl.find config.book uuid in

    if config.myself = config.server then (
      Owl_log.debug "mapre server %s @ %s" uuid addr;
      Server.init config
    )
    else (
      Owl_log.debug "mapre client %s @ %s" uuid addr;
      Client.init config
    )



  (* interface to mapreserver functions *)

end