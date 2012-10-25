(* translation into assembly with infinite number of virtual registers *)

open Asm

(* 変数と型の組をintとfloatに分類する関数 *)
let classify xts ini addf addi =
  List.fold_left
    (fun acc (x, t) ->
      match t with
      | Type.Unit -> acc
      | Type.Float -> addf acc x
      | _ -> addi acc x t)
    ini
    xts

(* 変数と型の組のリストをintとfloatに分ける関数 *)
let separate xts =
  classify
    xts
    ([], [])
    (fun (int, float) x -> (int, float @ [x]))
    (fun (int, float) x _ -> (int @ [x], float))

let expand xts ini addf addi =
  classify
    xts
    ini
    (fun (offset, acc) x ->
      (offset + 1, addf x offset acc))
    (fun (offset, acc) x t ->
      (offset + 1, addi x t offset acc))

(* 式の仮想マシンコード生成 *)
let rec g env = function 
  | Closure.Unit   -> Ans(Nop)
  | Closure.Int(i) -> Ans(Int(i))
  | Closure.Float(d) -> Ans(Float(d))
  | Closure.Neg(x) -> Ans(MulI(x, -1))
  | Closure.Add(x, y) -> Ans(Add(x, y))
  | Closure.Sub(x, y) -> Ans(Sub(x, y))
  | Closure.Mul(x, y) -> Ans(Mul(x, y))
  | Closure.Sll(x, y) -> Ans(SllI(x, y))
  | Closure.Sra(x, y) -> Ans(SraI(x, y))
  | Closure.FNeg(x) -> Ans(FNeg(x))
  | Closure.FAdd(x, y) -> Ans(FAdd(x, y))
  | Closure.FSub(x, y) -> Ans(FSub(x, y))
  | Closure.FMul(x, y) -> Ans(FMul(x, y))
  | Closure.FDiv(x, y) -> Ans(FDiv(x, y))
  | Closure.IfEq(x, y, e1, e2) ->
      (match M.find x env with
      | Type.Bool | Type.Int -> Ans(IfEq(x, y, g env e1, g env e2))
      | Type.Float -> Ans(IfFEq(x, y, g env e1, g env e2))
      | _ -> failwith "equality supported only for bool, int, and float")
  | Closure.IfLE(x, y, e1, e2) ->
      (match M.find x env with
      | Type.Bool | Type.Int -> Ans(IfLE(x, y, g env e1, g env e2))
      | Type.Float -> Ans(IfFLE(x, y, g env e1, g env e2))
      | _ -> failwith "inequality supported only for bool, int, and float")
 | Closure.IfLT(x, y, e1, e2) ->
      (match M.find x env with
      | Type.Bool | Type.Int -> Ans(IfLT(x, y, g env e1, g env e2))
      | Type.Float -> Ans(IfFLT(x, y, g env e1, g env e2))
      | _ -> failwith "inequality supported only for bool, int, and float")
  | Closure.Let((x, t1), e1, e2) ->
      let e1' = g env e1 in
      let e2' = g (M.add x t1 env) e2 in
      concat e1' (x, t1) e2'
  | Closure.Var(x) ->
      (match M.find x env with
      | Type.Unit -> Ans(Nop)
      | Type.Float -> Ans(FMov(x))
      | _ -> Ans(AddI(x, 0)))
  | Closure.MakeCls((x, t), { Closure.entry = l; Closure.actual_fv = ys }, e2) -> (* クロージャの生成 *)
      (* Closureのアドレスをセットしてから、自由変数の値をストア *)
      let e2' = g (M.add x t env) e2 in
      let offset, store_fv =
	expand
	  (List.map (fun y -> (y, M.find y env)) ys)
	  (1, e2')
	  (fun y offset store_fv ->  seq(FStI(y, x, offset), store_fv))
	  (fun y _ offset store_fv -> seq(StI(y, x, offset), store_fv)) in
      Let((x, t), AddI(reg_hp, 0),
	  Let((reg_hp, Type.Int), AddI(reg_hp, offset),
	      let z = Id.genid "l" in
	      Let((z, Type.Int), SetL(l),
		  seq(StI(z, x, 0),
		      store_fv))))
  | Closure.AppCls(x, ys) ->
      let (int, float) = separate (List.map (fun y -> (y, M.find y env)) ys) in
      Ans(CallCls(x, int, float))
  | Closure.AppDir(Id.L(x), ys) ->
      let (int, float) = separate (List.map (fun y -> (y, M.find y env)) ys) in
      (* xor等を変換 *)
      (match x with
      | "min_caml_xor" -> Ans(Xor(List.nth int 0, List.nth int 1))
      | "min_caml_sqrt" -> Ans(FSqrt(List.hd float))
      | "min_caml_not" -> Ans(Xor(List.hd int, reg_1))
      | _ -> Ans(CallDir(Id.L(x), int, float)))
  | Closure.Tuple(xs) -> (* 組の生成 *)
      let y = Id.genid "t" in
      let (offset, store) =
	expand
	  (List.map (fun x -> (x, M.find x env)) xs)
	  (0, Ans(AddI(y, 0)))
	  (fun x offset store ->  seq(FStI(x, y, offset), store))
	  (fun x _ offset store -> seq(StI(x, y, offset), store)) in
      Let((y, Type.Tuple(List.map (fun x -> M.find x env) xs)), AddI(reg_hp, 0),
	  Let((reg_hp, Type.Int), AddI(reg_hp, offset),
	      store))
  | Closure.LetTuple(xts, y, e2) ->
      let s = Closure.fv e2 in
      let (_, load) =
	expand
	  xts
	  (0, g (M.add_list xts env) e2)
	  (fun x offset load ->
	    if not (S.mem x s) then load else 
	    Let((x, Type.Float), FLdI(y, offset), load))
	  (fun x t offset load ->
	    if not (S.mem x s) then load else 
	    Let((x, t), LdI(y, offset), load)) in
      load
  | Closure.Get(x, y) -> (* 配列の読み出し *)
      (match M.find x env with
      | Type.Array(Type.Unit) -> Ans(Nop)
      | Type.Array(Type.Float) -> Ans(FLdR(x, y))
      | Type.Array(_) -> Ans(LdR(x, y))
      | _ -> assert false)
  | Closure.Put(x, y, z) ->
      let offset = Id.genid "o" in
      (match M.find x env with
      | Type.Array(Type.Unit) -> Ans(Nop)
      | Type.Array(Type.Float) ->
	  Let((offset, Type.Int), Add(x, y),
	      Ans(FStI(z, offset, 0)))
      | Type.Array(_) ->
	  Let((offset, Type.Int), Add(x, y),
	      Ans(StI(z, offset, 0)))
      | _ -> assert false)
  | Closure.ExtArray(Id.L(x)) -> Ans(SetL(Id.L("min_caml_" ^ x)))

(* トップレベルの関数の仮想マシンコード生成 *)
let h { Closure.name = (Id.L(x), t); Closure.args = yts; Closure.formal_fv = zts; Closure.body = e } =
  let (int, float) = separate yts in
  let (_, load) =
    expand
      zts
      (1, g (M.add x t (M.add_list yts (M.add_list zts M.empty))) e)
      (fun z offset load -> Let((z, Type.Float), FLdI(x, offset), load))
      (fun z t offset load -> Let((z, t), LdI(x, offset), load)) in
  match t with
  | Type.Fun(_, t2) ->
      { name = Id.L(x); args = int; fargs = float; body = load; ret = t2 }
  | _ -> assert false

(* プログラム全体の仮想マシンコード生成 *)
let f (Closure.Prog(fundefs, e)) =
  let fundefs = List.map h fundefs in
  let e = g M.empty e in
  Prog (fundefs, e)
