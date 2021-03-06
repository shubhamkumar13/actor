(*
 * Actor - Parallel & Distributed Engine of Owl System
 * Copyright (c) 2016-2018 Liang Wang <liang.wang@cl.cam.ac.uk>
 *)

(* Distributed Stochastic Gradient Decendent *)

open Owl
open Actor_types


module MX = Mat
module P2P = Actor_peer


(* variables used in distributed sgd *)
let data_x = ref (MX.empty 0 0)
let data_y = ref (MX.empty 0 0)
let _model = ref (MX.empty 0 0)
let gradfn = ref Owl_optimise.square_grad
let lossfn = ref Owl_optimise.square_loss
let step_t = ref 0.001


(* prepare data, model, gradient, loss *)
let init x y m g l =
  data_x := x;
  data_y := y;
  _model := m;
  gradfn := g;
  lossfn := l;
  MX.iteri_cols (fun i v -> P2P.set i v) !_model


let calculate_gradient b x y m g l =
  let xt, i = MX.draw_rows x b in
  let yt = MX.rows y i in
  let yt' = MX.(xt *@ m) in
  let d = g xt yt yt' in
  Owl_log.info "loss = %.10f" (l yt yt' |> MX.sum);
  d


let update_local_model = None


let schedule _context =
  let n = MX.col_num !_model in
  let k = Stats.Rnd.uniform_int ~a:0 ~b:(n - 1) () in
  [ k ]


let push _context params =
  List.map (fun (k,v) ->
    let y = MX.col !data_y k in
    let d = calculate_gradient 10 !data_x y v !gradfn !lossfn in
    let d = MX.(d *$ !step_t) in
    (k, d)
  ) params


let barrier _context = Actor_barrier.p2p_bsp _context


let pull _context updates =
  let h = Hashtbl.create 32 in
  List.iter (fun (k,v,t) ->
    if Hashtbl.mem h k = false then (
      let v', t' = P2P.get k in
      Hashtbl.add h k (v',t')
    );
    let v', t' = Hashtbl.find h k in
    let v' = MX.(v' - v) in
    let t' = max t' t in
    Hashtbl.replace h k (v',t')
  ) updates;
  Hashtbl.fold (fun k (v,t) l -> l @ [(k,v,t)]) h []


let stop _context = !_context.step > 10_000


let start jid =
  (* register schedule, push, pull functions *)
  P2P.register_barrier barrier;
  P2P.register_schedule schedule;
  P2P.register_push push;
  P2P.register_pull pull;
  P2P.register_stop stop;
  (* start running the ps *)
  Owl_log.info "P2P: sdg algorithm starts running ...";
  P2P.start jid Actor_config.manager_addr
