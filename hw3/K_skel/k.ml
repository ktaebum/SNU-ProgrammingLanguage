(*
 * SNU 4190.310 Programming Languages 2018 Fall
 *  K- Interpreter Skeleton Code
 *)

(* Location Signature *)
module type LOC =
sig
  type t
  val base : t
  val equal : t -> t -> bool
  val diff : t -> t -> int
  val increase : t -> int -> t
end

module Loc : LOC =
struct
  type t = Location of int
  let base = Location(0)
  let equal (Location(a)) (Location(b)) = (a = b)
  let diff (Location(a)) (Location(b)) = a - b
  let increase (Location(base)) n = Location(base+n)
end

(* Memory Signature *)
module type MEM = 
sig
  type 'a t
  exception Not_allocated
  exception Not_initialized
  val empty : 'a t (* get empty memory *)
  val load : 'a t -> Loc.t  -> 'a (* load value : Mem.load mem loc => value *)
  val store : 'a t -> Loc.t -> 'a -> 'a t (* save value : Mem.store mem loc value => mem' *)
  val alloc : 'a t -> Loc.t * 'a t (* get fresh memory cell : Mem.alloc mem => (loc, mem') *)
end

(* Environment Signature *)
module type ENV =
sig
  type ('a, 'b) t
  exception Not_bound
  val empty : ('a, 'b) t (* get empty environment *)
  val lookup : ('a, 'b) t -> 'a -> 'b (* lookup environment : Env.lookup env key => content *)
  val bind : ('a, 'b) t -> 'a -> 'b -> ('a, 'b) t  (* id binding : Env.bind env key content => env'*)
end

(* Memory Implementation *)
module Mem : MEM =
struct
  exception Not_allocated
  exception Not_initialized
  type 'a content = V of 'a | U
  type 'a t = M of Loc.t * 'a content list
  let empty = M (Loc.base,[])

  let rec replace_nth = fun l n c -> 
    match l with
    | h::t -> if n = 1 then c :: t else h :: (replace_nth t (n - 1) c)
    | [] -> raise Not_allocated

  let load (M (boundary,storage)) loc =
    match (List.nth storage ((Loc.diff boundary loc) - 1)) with
    | V v -> v 
    | U -> raise Not_initialized

  let store (M (boundary,storage)) loc content =
    M (boundary, replace_nth storage (Loc.diff boundary loc) (V content))

  let alloc (M (boundary,storage)) = 
    (boundary, M (Loc.increase boundary 1, U :: storage))
end

(* Environment Implementation *)
module Env : ENV=
struct
  exception Not_bound
  type ('a, 'b) t = E of ('a -> 'b)
  let empty = E (fun x -> raise Not_bound)
  let lookup (E (env)) id = env id
  let bind (E (env)) id loc = E (fun x -> if x = id then loc else env x)
end

(*
 * K- Interpreter
 *)
module type KMINUS =
sig
  exception Error of string
  type id = string
  type exp =
    | NUM of int | TRUE | FALSE | UNIT
    | VAR of id
    | ADD of exp * exp
    | SUB of exp * exp
    | MUL of exp * exp
    | DIV of exp * exp
    | EQUAL of exp * exp
    | LESS of exp * exp
    | NOT of exp
    | SEQ of exp * exp            (* sequence *)
    | IF of exp * exp * exp       (* if-then-else *)
    | WHILE of exp * exp          (* while loop *)
    | LETV of id * exp * exp      (* variable binding *)
    | LETF of id * id list * exp * exp (* procedure binding *)
    | CALLV of id * exp list      (* call by value *)
    | CALLR of id * id list       (* call by referenece *)
    | RECORD of (id * exp) list   (* record construction *)
    | FIELD of exp * id           (* access record field *)
    | ASSIGN of id * exp          (* assgin to variable *)
    | ASSIGNF of exp * id * exp   (* assign to record field *)
    | READ of id
    | WRITE of exp
  type program = exp
  type memory
  type env
  type value =
    | Num of int
    | Bool of bool
    | Unit
    | Record of (id -> Loc.t)
  val emptyMemory : memory
  val emptyEnv : env
  val run : memory * env * program -> value
end

module K : KMINUS =
struct
  exception Error of string

  type id = string
  type exp =
    | NUM of int | TRUE | FALSE | UNIT
    | VAR of id
    | ADD of exp * exp
    | SUB of exp * exp
    | MUL of exp * exp
    | DIV of exp * exp
    | EQUAL of exp * exp
    | LESS of exp * exp
    | NOT of exp
    | SEQ of exp * exp            (* sequence *)
    | IF of exp * exp * exp       (* if-then-else *)
    | WHILE of exp * exp          (* while loop *)
    | LETV of id * exp * exp      (* variable binding *)
    | LETF of id * id list * exp * exp (* procedure binding *)
    | CALLV of id * exp list      (* call by value *)
    | CALLR of id * id list       (* call by referenece *)
    | RECORD of (id * exp) list   (* record construction *)
    | FIELD of exp * id           (* access record field *)
    | ASSIGN of id * exp          (* assgin to variable *)
    | ASSIGNF of exp * id * exp   (* assign to record field *)
    | READ of id
    | WRITE of exp

  type program = exp

  type value =
    | Num of int
    | Bool of bool
    | Unit
    | Record of (id -> Loc.t)
    
  type memory = value Mem.t
  type env = (id, env_entry) Env.t
  and  env_entry = Addr of Loc.t | Proc of id list * exp * env

  let emptyMemory = Mem.empty
  let emptyEnv = Env.empty

  let value_int v =
    match v with
    | Num n -> n
    | _ -> raise (Error "TypeError : not int")

  let value_bool v =
    match v with
    | Bool b -> b
    | _ -> raise (Error "TypeError : not bool")

  let value_unit v =
    match v with
    | Unit -> ()
    | _ -> raise (Error "TypeError : not unit")

  let value_record v =
    match v with
    | Record r -> r
    | _ -> raise (Error "TypeError : not record")

  let lookup_env_loc e x =
    try
      (match Env.lookup e x with
      | Addr l -> l
      | Proc _ -> raise (Error "TypeError : not addr")) 
    with Env.Not_bound -> raise (Error "Unbound")

  let lookup_env_proc e f =
    try
      (match Env.lookup e f with
      | Addr _ -> raise (Error "TypeError : not proc") 
      | Proc (id_list, exp, env) -> (id_list, exp, env))
    with Env.Not_bound -> raise (Error "Unbound")

  let rec eval mem env e =
    match e with
    | READ x -> 
      let v = Num (read_int()) in
      let l = lookup_env_loc env x in
      (v, Mem.store mem l v)
    | WRITE e ->
      let (v, mem') = eval mem env e in
      let n = value_int v in
      let _ = print_endline (string_of_int n) in
      (v, mem')
    | LETV (x, e1, e2) ->
      let (v, mem') = eval mem env e1 in
      let (l, mem'') = Mem.alloc mem' in
      eval (Mem.store mem'' l v) (Env.bind env x (Addr l)) e2
    | LETF (f, args, e1, e2) -> 
      (* Idea
       * Put all ids in args into current environment, and make new environment.
       *)
      let f_env = Env.bind env f (Proc (args, e1, env)) in
      eval mem f_env e2
    | ASSIGN (x, e) ->
      let (v, mem') = eval mem env e in
      let l = lookup_env_loc env x in
      (v, Mem.store mem' l v)
    | NUM v ->
      (Num v, mem)
    | TRUE ->
      (Bool true, mem)
    | FALSE -> 
      (Bool false, mem)
    | UNIT ->
      (Unit, mem)
    | VAR id ->
      (* get id, load addr location
       * read addr and return value *)
      let l = lookup_env_loc env id in
      (Mem.load mem l, mem)
    | ADD (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      let i1 = value_int v1 in
      let i2 = value_int v2 in 
      (Num (i1 + i2), mem'')
    | SUB (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      let i1 = value_int v1 in
      let i2 = value_int v2 in
      (Num (i1 - i2), mem'')
    | MUL (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      let i1 = value_int v1 in
      let i2 = value_int v2 in
      (Num (i1 * i2), mem'')
    | DIV (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      let i1 = value_int v1 in
      let i2 = value_int v2 in
      (Num (i1 / i2), mem'')
    | SEQ (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      (v2, mem'')
    | EQUAL (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      (
        match (v1, v2) with
        | (Num i1, Num i2) ->
          if (i1 = i2) then (Bool true, mem'') else (Bool false, mem'')
        | (Unit, Unit) -> (Bool true, mem'')
        | (Bool b1, Bool b2) ->
          if (b1 = b2) then (Bool true, mem'') else (Bool false, mem'')
        | (_, _) -> 
          (Bool false, mem'')
      )
    | NOT e ->
      let (v, mem') = eval mem env e in
      let v2bool = value_bool v in
      (Bool (not v2bool), mem')
    | IF (condition, e1, e2) ->
      let (v, mem') = eval mem env condition in
      let v2bool = value_bool v in
      (match v2bool with 
       | true -> 
         (* truc case, eval e1 *)
         eval mem' env e1
       | false ->
         eval mem' env e2)
    | LESS (e1, e2) ->
      let (v1, mem') = eval mem env e1 in
      let (v2, mem'') = eval mem' env e2 in
      let i1 = value_int v1 in
      let i2 = value_int v2 in
      (Bool (i1 < i2), mem'')
    | WHILE (e1, e2) ->
      (* while e1 is true, do e2 *)
      let (v, mem') = eval mem env e1 in
      (
        match v with
       | Bool false ->
         (* do nothing *)
         (Unit, mem')
       | Bool true ->
         let (v1, mem1) = eval mem' env e2 in
         eval mem1 env (WHILE (e1, e2))
       | _ -> raise (Error "Type Error: Boolean Required")
      )
    | CALLV (f, exps) ->
      (* unpacked_exp has (v_1, v_2, ... v_n) and M_n *)
      let rec calculate_values exps =
        (* Unpack exp list and calculate its corresponding values 
         * @param exps: expression list
         *
         * Returns: tuple of (values list, latest Memory
         *)
        match exps with
        | [] -> 
          (* empty list, return ([], current memory *)
          ([], mem)
        | hd :: tl ->
          (* first call recursively to get cumulated memory *)
          let (values, mem') = calculate_values tl in

          (* eval head *)
          let (v, mem') = eval mem' env hd in
          (v :: values, mem')
      in
      let (values, mem') = calculate_values exps in

      (* get proc of (id list, e, env) *)
      let (args, e', env') = lookup_env_proc env f in

      (* Support recursive call *)
      let env' = Env.bind env' f (Proc (args, e', env')) in

      (* allocate new locations for each id *)
      let rec allocate_locations args = 
        match args with 
        | [] -> 
          (* empty args *)
          ([], mem')
        | hd :: tl ->
          let (locations, mem'') = allocate_locations tl in
          let (l, mem'') = Mem.alloc mem'' in
          (l :: locations, mem'') 
      in
      let (locations, mem') = allocate_locations args in

      (* store values to location *)
      let rec store_value2location values locations = 
        match (values, locations) with 
        | ([], []) -> mem'
        | (_ :: _, []) -> raise (Error "InvalidArg")
        | ([], _ :: _) -> raise (Error "InvalidArg")
        | (hd_val :: tl_val, hd_loc :: tl_loc) -> 
          let mem'' = store_value2location tl_val tl_loc in
          Mem.store mem'' hd_loc hd_val
      in
      let mem' = store_value2location values locations in

      (* bind new environment from locations and each argument's id *)
      let rec bind_locations2args locations args= 
        match (locations, args) with
        | ([], []) -> env'
        | (_ :: _, []) -> raise (Error "InvalidArg")
        | ([], _ :: _) -> raise (Error "InvalidArg")
        | (hd_loc :: tl_loc, hd_arg :: tl_arg) ->
          let env' = bind_locations2args tl_loc tl_arg in
          Env.bind env' hd_arg (Addr hd_loc)
      in

      let env' = bind_locations2args locations args in
      eval mem' env' e'
    | CALLR (f, args_id) ->
      (* get procedure *)
      let (args, e', env') = lookup_env_proc env f in

      (* support recursive call *)
      let env' = Env.bind env' f (Proc (args, e', env')) in

      (* get locations from args_id *)
      let rec get_locations args_id = 
        match args_id with 
        | [] -> []
        | hd :: tl ->
          (lookup_env_loc env hd) :: get_locations tl
      in

      let locations = get_locations args_id in

      let rec bind_locations2args locations args =
        match (locations, args) with
        | ([], []) -> env'
        | (_ :: _, []) -> raise (Error "InvalidArg")
        | ([], _ :: _) -> raise (Error "InvalidArg")
        | (hd_loc :: tl_loc, hd_arg :: tl_arg) ->
          let env' = bind_locations2args tl_loc tl_arg in
          Env.bind env' hd_arg (Addr hd_loc)
      in

      let env' = bind_locations2args locations args in
      eval mem env' e'
    | RECORD records ->
      (* records is type of (id * exp) list *)

      (* parse args and exps *)
      let args = List.map fst records in 
      let exps = List.map snd records in

      (* unpacked_exp has (v_1, v_2, ... v_n) and M_n *)
      let rec calculate_values exps =
        (* Unpack exp list and calculate its corresponding values 
         * @param exps: expression list
         *
         * Returns: tuple of (values list, latest Memory
         * Same function of CALLV
         *)
        match exps with
        | [] -> 
          (* empty list, return ([], current memory *)
          ([], mem)
        | hd :: tl ->
          (* first call recursively to get cumulated memory *)
          let (values, mem') = calculate_values tl in

          (* eval head *)
          let (v, mem') = eval mem' env hd in
          (v :: values, mem')
      in

      let (values, mem') = calculate_values exps in

      (* allocate new locations for each id *)
      let rec allocate_locations args = 
        match args with 
        | [] -> 
          (* empty args *)
          ([], mem')
        | hd :: tl ->
          let (locations, mem'') = allocate_locations tl in
          let (l, mem'') = Mem.alloc mem'' in
          (l :: locations, mem'') 
      in
      let (locations, mem') = allocate_locations args in

      (* store values to location *)
      let rec store_value2location values locations = 
        match (values, locations) with 
        | ([], []) -> mem'
        | (_ :: _, []) -> raise (Error "InvalidArg")
        | ([], _ :: _) -> raise (Error "InvalidArg")
        | (hd_val :: tl_val, hd_loc :: tl_loc) -> 
          let mem'' = store_value2location tl_val tl_loc in
          Mem.store mem'' hd_loc hd_val
      in
      let mem' = store_value2location values locations in

      let rec bind_locations2args locations args =
        match (locations, args) with
        | ([], []) -> env
        | (_ :: _, []) -> raise (Error "InvalidArg")
        | ([], _ :: _) -> raise (Error "InvalidArg")
        | (hd_loc :: tl_loc, hd_arg :: tl_arg) ->
          let env' = bind_locations2args tl_loc tl_arg in
          Env.bind env' hd_arg (Addr hd_loc)
      in

      let env' = bind_locations2args locations args in
      
      let find_location id =
        lookup_env_loc env' id
      in

      ((Record find_location), mem')
    | FIELD (e, id) ->
      let (v, mem') = eval mem env e in
      (
        match v with 
        | Record map -> 
          (Mem.load mem' (map id), mem')
        | _ -> raise (Error "Type Error: Not Record")
      )
    | ASSIGNF (record, field, value) ->
      (* assign new value to record's field *)
      let (map, mem') = eval mem env record in
      let (v, mem'') = eval mem' env value in
        (match map with
        | Record map -> 
          let get_location table id =
            try table id
            with Env.Not_bound -> raise (Error "Type Error")
          in
            let loc = get_location map field in
            let mem'' = Mem.store mem'' loc v in
            (Unit, mem'')
        | _ -> raise (Error "Type Error: Not Record")
         )
  let run (mem, env, pgm) = 
    let (v, _ ) = eval mem env pgm in
    v
end
