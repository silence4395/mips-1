open ANormal

let before = ref (Ans(Unit))

let rec effect env = function (* �����Ѥ�̵ͭ *)
  | Let(_, exp, e) -> effect' env exp || effect env e
  | LetRec(_, e) | LetTuple(_, _, e) -> effect env e
  | Ans(exp) -> effect' env exp
and effect' env = function
  | IfEq(_, _, e1, e2) | IfLE(_, _, e1, e2) | IfLT(_, _, e1, e2) -> effect env e1 || effect env e2
  (* �����Ѥ�̵���饤�֥��ؿ� *)
  | ExtFunApp (("create_array" | "create_float_array" | "create_tuple_array" | "floor" | "ceil" | "float_of_int" | "int_of_float" | "truncate" | "not" | "xor" | "sqrt"  | "atan" | "tan" | "sin" | "cos" ), _) -> false
  | App (x, _) when S.mem x env -> false
  | App _ | Put _  | ExtFunApp _ -> true
  | _ -> false

let rec g env = function (* �����������롼�������� *)
  | Let((x, t), exp, e) -> (* let�ξ�� *)
      let (exp', fvs') = g' env exp in
      let (e', fvs) = g env e in
      if effect' env exp' || S.mem x (fv e') then
	if e' = Ans(Unit) then (Ans(exp'), fvs') else
	(Let((x, t), exp', e'), S.union fvs' (S.remove x fvs))
      else (e', fvs)
  | LetRec({ name = (x, t); args = yts; body = e1 }, e2) -> (* let rec�ξ�� *)
      let env' =
	let env' = S.add x env in
        if effect env' e1 then env else env' in
      let (e2', fvs2) = g env' e2 in
      if S.mem x fvs2 then
	let (e1', fvs1) = g env' e1 in
	(LetRec({ name = (x, t); args = yts; body = e1' }, e2'), S.remove x (S.union (S.diff fvs1 (S.of_list (List.map fst yts))) fvs2))
      else (e2', fvs2)
  | LetTuple(xts, y, e) ->
      let xs = List.map fst xts in
      let (e', fvs) = g env e in
      if List.exists (fun x -> S.mem x fvs) xs then
	(LetTuple(xts, y, e'), S.add y (S.diff fvs (S.of_list (List.map fst xts))))
      else (e', fvs)
  | Ans(exp) ->
      let (exp', fvs) = g' env exp in
      (Ans(exp'), fvs)
and g' env = function
  | IfEq(x, y, e1, e2) ->
      let (e1', fvs1) = g env e1 in
      let (e2', fvs2) = g env e2 in
      if e1' = Ans(Unit) && e2' = Ans(Unit) then (Unit, S.empty) else
      (IfEq(x, y, e1', e2'), S.add x (S.add y (S.union fvs1 fvs2)))
  | IfLE(x, y, e1, e2) -> 
      let (e1', fvs1) = g env e1 in
      let (e2', fvs2) = g env e2 in
      if e1' = Ans(Unit) && e2' = Ans(Unit) then (Unit, S.empty) else
      (IfLE(x, y, e1', e2'), S.add x (S.add y (S.union fvs1 fvs2)))
  | IfLT(x, y, e1, e2) -> 
      let (e1', fvs1) = g env e1 in
      let (e2', fvs2) = g env e2 in
      if e1' = Ans(Unit) && e2' = Ans(Unit) then (Unit, S.empty) else
      (IfLT(x, y, e1', e2'), S.add x (S.add y (S.union fvs1 fvs2)))
  | exp -> (exp, fv' exp)

let f e = Format.eprintf "eliminating variables and functions...@.";
          let e' = fst (g S.empty e) in
	  (*before := e';*)
	  e'
