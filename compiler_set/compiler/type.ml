type t = (* MinCaml�η���ɽ������ǡ����� *)
  | Unit
  | Bool
  | Int
  | Float
  | Fun of t list * t (* arguments are uncurried *)
  | Tuple of t list
  | Array of t
  | Var of t option ref

let rec show x =
  match x with
  | Unit -> "Unit"
  | Bool -> "Bool"
  | Int -> "Int"
  | Float -> "Float"
  | Fun (l,t) -> "Fun((" ^ String.concat "," (List.map show l) ^ ")->" ^ show t ^ ")"
  | Tuple l -> "(" ^ String.concat " * " (List.map show l) ^")"
  | Array t -> "(Array " ^ show t ^ ")"
  | Var a ->
      (match !a with
       | Some t -> "Var " ^ show t
       | None -> "Var")

let gentyp () = Var(ref None) (* ���������ѿ����� *)

