open KNormal

let rec effect = function (* �����Ѥ�̵ͭ *)
  | Let(_, e1, e2) | IfEq(_, _, e1, e2) | IfLE(_, _, e1, e2) | IfLT(_, _, e1, e2) -> effect e1 || effect e2
  | LetRec(_, e) | LetTuple(_, _, e) -> effect e
  (* �����Ѥ�̵���饤�֥��ؿ� *)
  | ExtFunApp (("create_array" | "create_float_array" | "create_tuple_array" | "floor" | "ceil" | "float_of_int" | "int_of_float" | "truncate" | "not" | "xor" | "sqrt"  | "atan" | "tan" | "sin" | "cos" ), _) -> false
  | App _ | Put _  | ExtFunApp _ -> true
  | _ -> false

let rec f' = function (* �����������롼�������� *)
  | IfEq(x, y, e1, e2) -> IfEq(x, y, f' e1, f' e2)
  | IfLE(x, y, e1, e2) -> IfLE(x, y, f' e1, f' e2)
  | IfLT(x, y, e1, e2) -> IfLT(x, y, f' e1, f' e2)
  | Let((x, t), e1, e2) -> (* let�ξ�� *)
      let e1' = f' e1 in
      let e2' = f' e2 in
      if effect e1' || S.mem x (fv e2') then Let((x, t), e1', e2')
      else e2'
  | LetRec({ name = (x, t); args = yts; body = e1 }, e2) -> (* let rec�ξ�� *)
      let e2' = f' e2 in
      if S.mem x (fv e2') then
	LetRec({ name = (x, t); args = yts; body = f' e1 }, e2')
      else e2'
  | LetTuple(xts, y, e) ->
      let xs = List.map fst xts in
      let e' = f' e in
      let live = fv e' in
      if List.exists (fun x -> S.mem x live) xs then LetTuple(xts, y, e')
      else e'
  | e -> e

let f e = Format.eprintf "eliminating variables and functions...@.";
          f' e
