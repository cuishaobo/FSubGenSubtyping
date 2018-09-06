Set Implicit Arguments.
Require Import LibLN.
Implicit Types x : var.
Implicit Types X : var.

(* ********************************************************************** *)
(** * Description of the Language *)

(** Representation of types *)

Inductive Mode := Sub | Sup.

Definition flip (m : Mode) : Mode :=
  match m with
  | Sub => Sup
  | Sup => Sub
  end.

Inductive typ : Set :=
  | typ_btm   : typ
  | typ_top   : typ
  | typ_int   : typ
  | typ_arrow : typ -> typ -> typ
  | typ_bvar  : nat -> typ
  | typ_fvar  : var -> typ
  | typ_all   : Mode -> typ -> typ -> typ.

(** Representation of pre-terms *)

Inductive trm : Set :=
  | trm_unit : trm
  | trm_bvar : nat -> trm
  | trm_fvar : var -> trm
  | trm_nval : nat -> trm
  | trm_nsucc: trm -> trm
  | trm_nind : trm -> trm -> trm -> trm
  | trm_abs  : typ -> trm -> trm
  | trm_app  : trm -> trm -> trm
  | trm_tabs : Mode -> typ -> trm -> trm
  | trm_tapp : trm -> typ -> trm.

(** Opening up a type binder occuring in a type *)

Fixpoint open_tt_rec (K : nat) (U : typ) (T : typ) {struct T} : typ :=
  match T with
  | typ_btm         => typ_btm
  | typ_top         => typ_top
  | typ_int         => typ_int
  | typ_bvar J      => If K = J then U else (typ_bvar J)
  | typ_fvar X      => typ_fvar X
  | typ_arrow T1 T2 => typ_arrow (open_tt_rec K U T1) (open_tt_rec K U T2)
  | typ_all m T1 T2 => typ_all m (open_tt_rec K U T1)(open_tt_rec (S K) U T2)
  end.

Definition open_tt T U := open_tt_rec 0 U T.

(** Opening up a type binder occuring in a term *)

Fixpoint open_te_rec (K : nat) (U : typ) (e : trm) {struct e} : trm :=
  match e with
  | trm_unit      => trm_unit
  | trm_bvar i    => trm_bvar i
  | trm_fvar x    => trm_fvar x
  | trm_nval v    => trm_nval v
  | trm_nsucc t   => trm_nsucc (open_te_rec K U t)
  | trm_nind t1 t2 t3 => trm_nind (open_te_rec K U t1) (open_te_rec K U t2) (open_te_rec K U t3)
  | trm_abs V e1  => trm_abs  (open_tt_rec K U V)  (open_te_rec K U e1)
  | trm_app e1 e2 => trm_app  (open_te_rec K U e1) (open_te_rec K U e2)
  | trm_tabs m T e => trm_tabs m (open_tt_rec K U T) (open_te_rec (S K) U e)
  | trm_tapp e1 V => trm_tapp (open_te_rec K U e1) (open_tt_rec K U V)
  end.

Definition open_te t U := open_te_rec 0 U t.

(** Opening up a term binder occuring in a term *)

Fixpoint open_ee_rec (k : nat) (f : trm) (e : trm) {struct e} : trm :=
  match e with
  | trm_unit      => trm_unit
  | trm_bvar i    => If k = i then f else (trm_bvar i)
  | trm_fvar x    => trm_fvar x
  | trm_nval v    => trm_nval v
  | trm_nsucc s   => trm_nsucc (open_ee_rec k f s)
  | trm_nind i z s => trm_nind (open_ee_rec k f i) (open_ee_rec k f z) (open_ee_rec k f s)
  | trm_abs V e1  => trm_abs V (open_ee_rec (S k) f e1)
  | trm_app e1 e2 => trm_app (open_ee_rec k f e1) (open_ee_rec k f e2)
  | trm_tabs m T t => trm_tabs m T (open_ee_rec k f t)
  | trm_tapp t  T => trm_tapp (open_ee_rec k f t) T
  end.

Definition open_ee t u := open_ee_rec 0 u t.

(** Notation for opening up binders with type or term variables *)

Notation "T 'open_tt_var' X" := (open_tt T (typ_fvar X)) (at level 67).
Notation "t 'open_te_var' X" := (open_te t (typ_fvar X)) (at level 67).
Notation "t 'open_ee_var' x" := (open_ee t (trm_fvar x)) (at level 67).

Inductive bind : Set :=
  | bind_tRel : Mode -> typ -> bind
  | bind_typ : typ -> bind.

Notation "X !: m <>: T" := (X ~ bind_tRel m T)
  (at level 23, left associativity) : env_scope.

Notation "x ~: T" := (x ~ bind_typ T)
  (at level 23, left associativity) : env_scope.

Definition env := LibEnv.env bind.

Definition mode_to_sub m := match m with
  | Sub => typ_top
  | Sup => typ_btm end.

(** Types as locally closed pre-types *)

Inductive type : typ -> Prop :=
  | type_top :
      type typ_top
  | type_int :
      type typ_int
  | type_btm :
      type typ_btm
  | type_var : forall X,
      type (typ_fvar X)
  | type_arrow : forall T1 T2,
      type T1 -> 
      type T2 -> 
      type (typ_arrow T1 T2)
  | type_all : forall m L T1 T2,
      type T1 ->
      (forall X, X \notin L -> type (T2 open_tt_var X)) ->
      type (typ_all m T1 T2).

(** Terms as locally closed pre-terms *)

Inductive term : trm -> Prop :=
  | term_unit : term trm_unit
  | term_var : forall x,
      term (trm_fvar x)
  | term_nval : forall v,
      term (trm_nval v)
  | term_nsucc : forall t,
    term t -> term (trm_nsucc t)
  | term_nind : forall t1 t2 t3,
    term t1 ->
    term t2 ->
    term t3 ->
    term (trm_nind t1 t2 t3)
  | term_abs : forall L V e1,
      type V ->
      (forall x, x \notin L -> term (e1 open_ee_var x)) ->
      term (trm_abs V e1)
  | term_app : forall e1 e2,
      term e1 ->
      term e2 ->
      term (trm_app e1 e2)
  | term_tabs : forall m T L e1, type T ->
      (forall X, X \notin L -> term (e1 open_te_var X)) ->
      term (trm_tabs m T e1)
  | term_tapp : forall e1 V,
      term e1 ->
      type V ->
      term (trm_tapp e1 V).

(** Binding map term variables to types, and keeps type variables in the environment.
 [x ~: T] is a typing assumption *)


(** Well-formedness of a pre-type T in an environment E:
  all the type variables of T must be bound via a
  subtyping relation in E. This predicates implies
  that T is a type *)

Inductive wft : env -> typ -> Prop :=
  | wft_top : forall E, 
      wft E typ_top
  | wft_var : forall m T1 E X,
      binds X (bind_tRel m T1) E ->
      wft E (typ_fvar X) 
  | wft_int : forall E,
      wft E typ_int
  | wft_btm :forall E,
      wft E typ_btm
  | wft_arrow : forall E T1 T2,
      wft E T1 -> 
      wft E T2 -> 
      wft E (typ_arrow T1 T2)
  | wft_all : forall L E T m Tn,
      wft E Tn ->
      (forall X, X \notin L -> 
        wft (E & X !: m <>: Tn) (T open_tt_var X)) ->
      wft E (typ_all m Tn T).

Inductive okt : env -> Prop :=
  | okt_empty :
      okt empty
  | okt_tvr : forall E X m T,
      okt E -> wft E T -> X # E -> okt (E & X !: m <>: T)
  | okt_typ : forall E x T,
      okt E -> wft E T -> x # E -> okt (E & x ~: T).

Definition BindPosVariance m1 m2 :=
  match m1 with
    | Sup => m2
    | Sub => flip m2 end.

Definition SelectBound m1:= 
  match m1 with
    | Sup => typ_btm
    | Sub => typ_top end.

Inductive R : env -> Mode -> typ -> typ -> Prop :=
| SInt : forall E m, okt E -> R E m typ_int typ_int
| STB1 : forall E A m, okt E ->wft E A ->R E m A (mode_to_sub m)
| STB2 : forall E A m, okt E -> wft E A ->
R E m (mode_to_sub (flip m)) A
| SFun : forall E A B C D m, R E (flip m) A C -> R E m B D -> R E m (typ_arrow A B) (typ_arrow C D)
| SVarRefl : forall E X m, okt E -> wft E (typ_fvar X) -> R E m (typ_fvar X) (typ_fvar X)
| SVarBnd : forall E X m T F, binds X (bind_tRel m T) E -> wft E T ->
 R E m T F -> R E m (typ_fvar X) F
| SVarBndFl :  forall E X m T F, binds X (bind_tRel m T) E -> wft E T -> 
R E m T F -> R E (flip m) F (typ_fvar X)
(* | SVarTrns : forall E X m T1 T2 , R E m T1 (typ_fvar X) -> R E m (typ_fvar X) T2 -> R E m T1 T2 *)
| SAll : forall E L m1 m2 T1 T2 T3 T4, (*wft E T1 -> wft E T2 ->*)
  R E (BindPosVariance m1 m2) T1 T2 ->
(forall X, X \notin L ->
  R (E&(X !: m1 <>: (SelectBound m1))) m2 (T3 open_tt_var X) (T4 open_tt_var X))-> 
  R E m2 (typ_all m1 T1 T3) (typ_all m1 T2 T4).
(** Generalized Subtyping Judgements *)

(* Inductive R : Mode -> typ -> typ -> Prop :=
| SInt : forall m, R m typ_int typ_int
| STop1 : forall A, R Sub A typ_top
| STop2 : forall A, R Sup typ_top A
| SBot1 : forall A, R Sup A typ_btm
| SBot2 : forall A, R Sub typ_btm A
| SFun : forall A B C D m, R (flip m) A C -> R m B D -> R m (typ_arrow A B) (typ_arrow C D). *)

Inductive typing : env -> trm -> typ -> Prop :=
  | typing_unit : forall E, okt E ->typing E trm_unit typ_top
  | typing_var : forall E x T,
      okt E ->
      binds x (bind_typ T) E ->
      typing E (trm_fvar x) T
  | typing_nval : forall E v,
      okt E ->
   typing E (trm_nval v) typ_int
  | typing_nsucc : forall E t,
    okt E ->
    typing E t typ_int ->
    typing E (trm_nsucc t) typ_int
  | typing_nind : forall E V t1 t2 t3,
    okt E ->
    typing E t1 typ_int ->
    typing E t2 V ->
    typing E t3 (typ_arrow V V) ->
    typing E (trm_nind t1 t2 t3) V
  | typing_abs : forall L E V e1 T1,
      (forall x, x \notin L ->
        typing (E & x ~: V) (e1 open_ee_var x) T1) ->
      typing E (trm_abs V e1) (typ_arrow V T1)
  | typing_app : forall T1 E e1 e2 T2,
      typing E e1 (typ_arrow T1 T2) ->
      typing E e2 T1 ->
      typing E (trm_app e1 e2) T2
  | typing_tabs : forall L m Tk E e T,
      (forall X, X \notin L ->
        typing (E & X!: m <>: Tk) (e open_te_var X) (T open_tt_var X)) ->
      typing E (trm_tabs m Tk e) (typ_all m Tk T)
  | typing_tapp : forall m E Tb T1 T2 e,
    typing E e (typ_all m Tb T1) ->
    R E m T2 Tb ->
    typing E (trm_tapp e T2) (open_tt T1 T2)
  | typing_sub : forall S E e T,
      typing E e S ->
      R E Sub S T ->
      wft E T ->
      typing E e T.

(** Values *)

Inductive value : trm -> Prop :=
  | value_unit : value trm_unit
  | value_abs  : forall V e1, term (trm_abs V e1) ->
                 value (trm_abs V e1)
  | value_ival : forall v, value (trm_nval v)
  | value_tabs : forall m T e, term (trm_tabs m T e) ->
                 value (trm_tabs m T e).

(** One-step reduction *)

Inductive red : trm -> trm -> Prop :=
  | red_app_1 : forall e1 e1' e2,
      term e2 ->
      red e1 e1' ->
      red (trm_app e1 e2) (trm_app e1' e2)
  | red_app_2 : forall e1 e2 e2',
      value e1 ->
      red e2 e2' ->
      red (trm_app e1 e2) (trm_app e1 e2')
  | red_abs : forall V e1 v2,
      term (trm_abs V e1) ->
      value v2 ->
      red (trm_app (trm_abs V e1) v2) (open_ee e1 v2)
  | red_succ_can : forall v,
      red (trm_nsucc (trm_nval v)) (trm_nval (S v))
  | red_succ_red : forall t t',
      red t t'->
      red (trm_nsucc t) (trm_nsucc t')
  | red_ind_nred : forall t1 t1' t2 t3,
      red t1 t1' ->
      term t2 ->
      term t3 ->
      red (trm_nind t1 t2 t3) (trm_nind t1' t2 t3)
  | red_ind_icase : forall t1 t2 t3 t3',
      value t1 ->
      term t2 ->
      red t3 t3' ->
      red (trm_nind t1 t2 t3) (trm_nind t1 t2 t3')
  | red_ind_izero : forall t2 t3,
      term t2 ->
      value t3 ->
      red (trm_nind (trm_nval 0) t2 t3) t2
  | red_ind_isucc : forall k t2 t3,
      term t2 ->
      value t3 ->
      red (trm_nind (trm_nval (S k)) t2 t3) (trm_app t3 (trm_nind (trm_nval k) t2 t3))
  | red_tabs : forall m T e V,
      term (trm_tabs m T e) ->
      type V ->
      red (trm_tapp (trm_tabs m T e) V) (open_te e V)
  | red_tapp : forall e1 e1' V,
      type V ->
      red e1 e1' ->
      red (trm_tapp e1 V) (trm_tapp e1' V).

(** Our goal is to prove preservation and progress *)

Definition preservation := forall E e e' T,
  typing E e T -> 
  red e e' -> 
  typing E e' T.

Definition progress := forall e T,
  typing empty e T -> 
     value e 
  \/ exists e', red e e'.

(** * Additional Definitions Used in the Proofs *)

(** Computing free term variables in a type *)

Fixpoint fv_tt (T : typ) {struct T} : vars :=
  match T with
  | typ_fvar X      => \{X}
  | typ_arrow T1 T2 => (fv_tt T1) \u (fv_tt T2)
  | typ_all _ T1 T2   => (fv_tt T1) \u (fv_tt T2)
  | _           => \{}
  end.

(** Computing free type variables in a term *)

Fixpoint fv_te (e : trm) {struct e} : vars :=
  match e with
  | trm_nsucc t   => fv_te t
  | trm_nind t1 t2 t3 => (fv_te t1) \u (fv_te t2) \u (fv_te t3)
  | trm_abs V e1  => (fv_tt V) \u (fv_te e1)
  | trm_app e1 e2 => (fv_te e1) \u (fv_te e2)
  | trm_tabs m T e1   =>  (fv_tt T) \u (fv_te e1)
  | trm_tapp e1 V => (fv_tt V) \u (fv_te e1)
  | _ => \{}
  end.

(** Computing free term variables in a type *)

Fixpoint fv_ee (e : trm) {struct e} : vars :=
  match e with
  | trm_unit      => \{}
  | trm_bvar i    => \{}
  | trm_fvar x    => \{x}
  | trm_nval _    => \{}
  | trm_nsucc t   => fv_ee t
  | trm_nind t1 t2 t3 => (fv_ee t1) \u (fv_ee t2) \u (fv_ee t3)
  | trm_abs V e1  => (fv_ee e1)
  | trm_app e1 e2 => (fv_ee e1) \u (fv_ee e2)
  | trm_tabs m T t    => fv_ee t
  | trm_tapp t1 _ => (fv_ee t1)
  end.

(** Substitution for free type variables in types. *)

Fixpoint subst_tt (Z : var) (U : typ) (T : typ) {struct T} : typ :=
  match T with
  | typ_top         => typ_top
  | typ_int         => typ_int
  | typ_btm         => typ_btm
  | typ_bvar J      => typ_bvar J
  | typ_fvar X      => If X = Z then U else (typ_fvar X)
  | typ_arrow T1 T2 => typ_arrow (subst_tt Z U T1) (subst_tt Z U T2)
  | typ_all m T1 T2  => typ_all m (subst_tt Z U T1) (subst_tt Z U T2)
  end.

(** Substitution for free type variables in terms. *)

Fixpoint subst_te (Z : var) (U : typ) (e : trm) {struct e} : trm :=
  match e with
  | trm_unit      => trm_unit
  | trm_bvar i    => trm_bvar i
  | trm_fvar x    => trm_fvar x
  | trm_nval v    => trm_nval v
  | trm_nsucc t   => trm_nsucc (subst_te Z U t)
  | trm_nind t1 t2 t3 => trm_nind (subst_te Z U t1) (subst_te Z U t2) (subst_te Z U t3)
  | trm_abs V e1  => trm_abs  (subst_tt Z U V)  (subst_te Z U e1)
  | trm_app e1 e2 => trm_app  (subst_te Z U e1) (subst_te Z U e2)
  | trm_tabs m T e => trm_tabs m (subst_tt Z U T) (subst_te Z U e)
  | trm_tapp e1 V => trm_tapp (subst_te Z U e1) (subst_tt Z U V)
  end.

(** Substitution for free term variables in terms. *)

Fixpoint subst_ee (z : var) (u : trm) (e : trm) {struct e} : trm :=
  match e with
  | trm_unit      => trm_unit
  | trm_bvar i    => trm_bvar i
  | trm_fvar x    => If x = z then u else (trm_fvar x)
  | trm_nval i    => trm_nval i
  | trm_nsucc t   => trm_nsucc (subst_ee z u t)
  | trm_nind t1 t2 t3 => trm_nind (subst_ee z u t1) (subst_ee z u t2) (subst_ee z u t3)
  | trm_abs V e1  => trm_abs V (subst_ee z u e1)
  | trm_app e1 e2 => trm_app (subst_ee z u e1) (subst_ee z u e2)
  | trm_tabs m T t=> trm_tabs m T (subst_ee z u t)
  | trm_tapp t1 T => trm_tapp (subst_ee z u t1) T
  end.

Definition subst_tb (Z : var) (P : typ) (b : bind) : bind :=
  match b with
  | bind_tRel m T => bind_tRel m (subst_tt Z P T)
  | bind_typ T => bind_typ (subst_tt Z P T)
  end.


(* ********************************************************************** *)
(** * Tactics *)

(** Constructors as hints. *)

Hint Constructors type term wft ok okt value red.

Hint Resolve 
  STB1 STB2 SInt SFun SVarRefl 
  typing_var typing_app typing_sub typing_tapp typing_nval typing_nsucc typing_nind.

(** Gathering free names already used in the proofs *)


Ltac gather_vars :=
  let A := gather_vars_with (fun x : vars => x) in
  let B := gather_vars_with (fun x : var => \{x}) in
  let C := gather_vars_with (fun x : trm => fv_te x) in
  let D := gather_vars_with (fun x : trm => fv_ee x) in
  let E := gather_vars_with (fun x : typ => fv_tt x) in
  let F := gather_vars_with (fun x : env => dom x) in
  constr:(A \u B \u C \u D \u E \u F).

(** "pick_fresh x" tactic create a fresh variable with name x *)

Ltac pick_fresh x :=
  let L := gather_vars in (pick_fresh_gen L x).

(** "apply_fresh T as x" is used to apply inductive rule which
   use an universal quantification over a cofinite set *)    

Tactic Notation "apply_fresh" constr(T) "as" ident(x) :=
  apply_fresh_base T gather_vars x.

Tactic Notation "apply_fresh" "*" constr(T) "as" ident(x) :=
  apply_fresh T as x; autos*.

(** These tactics help applying a lemma which conclusion mentions
  an environment (E & F) in the particular case when F is empty *)

Ltac get_env :=
  match goal with
  | |- wft ?E _ => E
  | |- R ?E _ _ _  => E
  | |- typing ?E _ _ => E
  end.

Tactic Notation "apply_empty_bis" tactic(get_env) constr(lemma) :=
  let E := get_env in rewrite <- (concat_empty_r E);
  eapply lemma; try rewrite concat_empty_r.

Tactic Notation "apply_empty" constr(F) :=
  apply_empty_bis (get_env) F.

Tactic Notation "apply_empty" "*" constr(F) :=
  apply_empty F; autos*.

(** Tactic to undo when Coq does too much simplification *)   

Ltac unsimpl_map_bind :=
  match goal with |- context [ ?B (subst_tt ?Z ?P ?U) ] =>
    unsimpl ((subst_tb Z P) (B U)) end.

Tactic Notation "unsimpl_map_bind" "*" :=
  unsimpl_map_bind; autos*.

(** Tactic to undo when Coq does too much simplification *)   

(* ********************************************************************** *)
(** * Properties of Substitutions *)

(** Substitution on indices is identity on well-formed terms. *)

Lemma open_tt_rec_type_core : forall T j V U i, i <> j ->
  (open_tt_rec j V T) = open_tt_rec i U (open_tt_rec j V T) ->
  T = open_tt_rec i U T.
Proof.
  induction T; introv Neq H; simpl in *; inversion H; f_equal*.
  case_nat*. case_nat*.
Qed.

Lemma open_tt_rec_type : forall T U,
  type T -> forall k, T = open_tt_rec k U T.
Proof.
 induction 1; intros; simpl; f_equal*. unfolds open_tt.
  pick_fresh X. apply* (@open_tt_rec_type_core T2 0 (typ_fvar X)).
Qed.

(** Substitution for a fresh name is identity. *)

Lemma subst_tt_fresh : forall Z U T,
  Z \notin fv_tt T -> subst_tt Z U T = T.
Proof.
  induction T; simpl; intros; f_equal*.
  case_var*. 
Qed.

(** Substitution distributes on the open operation. *)

Lemma subst_tt_open_tt_rec : forall T1 T2 X P n, type P ->
  subst_tt X P (open_tt_rec n T2 T1) =
  open_tt_rec n (subst_tt X P T2) (subst_tt X P T1).
Proof.
  introv WP. generalize n.
  induction T1; intros k; simpls; f_equal*.
  case_nat*.
  case_var*. rewrite* <- open_tt_rec_type.
Qed.

Lemma subst_tt_open_tt : forall T1 T2 X P, type P ->
  subst_tt X P (open_tt T1 T2) =
  open_tt (subst_tt X P T1) (subst_tt X P T2).
Proof.
  unfold open_tt. autos* subst_tt_open_tt_rec.
Qed.

(** Substitution and open_var for distinct names commute. *)

Lemma subst_tt_open_tt_var : forall X Y U T, Y <> X -> type U ->
  (subst_tt X U T) open_tt_var Y = subst_tt X U (T open_tt_var Y).
Proof.
  introv Neq Wu. rewrite* subst_tt_open_tt.
  simpl. case_var*.
Qed.

(** Opening up a body t with a type u is the same as opening
  up the abstraction with a fresh name x and then substituting u for x. *)

Lemma subst_tt_intro : forall X T2 U, 
  X \notin fv_tt T2 -> type U ->
  open_tt T2 U = subst_tt X U (T2 open_tt_var X).
Proof.
  introv Fr Wu. rewrite* subst_tt_open_tt.
  rewrite* subst_tt_fresh. simpl. case_var*.
Qed.

(* ********************************************************************** *)
(** ** Properties of type substitution in terms *)

Lemma open_te_rec_term_core : forall e j u i P ,
  open_ee_rec j u e = open_te_rec i P (open_ee_rec j u e) ->
  e = open_te_rec i P e.
Proof.
  induction e; intros; simpl in *; inversion H; f_equal*; f_equal*.
Qed.

Lemma open_te_rec_type_core : forall e j Q i P, i <> j ->
  open_te_rec j Q e = open_te_rec i P (open_te_rec j Q e) ->
   e = open_te_rec i P e.
Proof.
  induction e; intros; simpl in *; inversion H0; f_equal*;
  match goal with H: ?i <> ?j |- ?t = open_tt_rec ?i _ ?t =>
   apply* (@open_tt_rec_type_core t j) end.
Qed.

Lemma open_te_rec_term : forall e U,
  term e -> forall k, e = open_te_rec k U e.
Proof.  
  intros e U WF. induction WF; intros; simpl;
    f_equal*; try solve [ apply* open_tt_rec_type ].
  unfolds open_ee. pick_fresh x. 
   apply* (@open_te_rec_term_core e1 0 (trm_fvar x)).
  unfolds open_te. pick_fresh X. 
   apply* (@open_te_rec_type_core e1 0 (typ_fvar X)).
Qed.

(** Substitution for a fresh name is identity. *)

Lemma subst_te_fresh : forall X U e,
  X \notin fv_te e -> subst_te X U e = e.
Proof.
  induction e; simpl; intros; f_equal*; autos* subst_tt_fresh.
Qed.

(** Substitution distributes on the open operation. *)

Lemma subst_te_open_te : forall e T X U, type U ->
  subst_te X U (open_te e T) =
  open_te (subst_te X U e) (subst_tt X U T).
Proof.
  intros. unfold open_te. generalize 0.
  induction e; intros; simpls; f_equal*;
  autos* subst_tt_open_tt_rec.
Qed.

(** Substitution and open_var for distinct names commute. *)

Lemma subst_te_open_te_var : forall X Y U e, Y <> X -> type U ->
  (subst_te X U e) open_te_var Y = subst_te X U (e open_te_var Y).
Proof.
  introv Neq Wu. rewrite* subst_te_open_te.
  simpl. case_var*.
Qed.

(** Opening up a body t with a type u is the same as opening
  up the abstraction with a fresh name x and then substituting u for x. *)

Lemma subst_te_intro : forall X U e, 
  X \notin fv_te e -> type U ->
  open_te e U = subst_te X U (e open_te_var X).
Proof.
  introv Fr Wu. rewrite* subst_te_open_te.
  rewrite* subst_te_fresh. simpl. case_var*.
Qed.


(* ********************************************************************** *)
(** ** Properties of term substitution in terms *)

Lemma open_ee_rec_term_core : forall e j v u i, i <> j ->
  open_ee_rec j v e = open_ee_rec i u (open_ee_rec j v e) ->
  e = open_ee_rec i u e.
Proof.
  induction e; introv Neq H; simpl in *; inversion H; f_equal*.
  case_nat*. case_nat*.
Qed.

Lemma open_ee_rec_type_core : forall e j V u i,
  open_te_rec j V e = open_ee_rec i u (open_te_rec j V e) ->
  e = open_ee_rec i u e.
Proof.
  induction e; introv H; simpls; inversion H; f_equal*.
Qed.


Lemma open_ee_rec_term : forall u e,
  term e -> forall k, e = open_ee_rec k u e.
Proof.
  induction 1; intros; simpl; f_equal*.
  unfolds open_ee. pick_fresh x. 
   apply* (@open_ee_rec_term_core e1 0 (trm_fvar x)).
   unfolds open_te. pick_fresh X. 
   apply* (@open_ee_rec_type_core e1 0 (typ_fvar X)).
Qed.

(** Substitution for a fresh name is identity. *)

Lemma subst_ee_fresh : forall x u e,
  x \notin fv_ee e -> subst_ee x u e = e.
Proof.
  induction e; simpl; intros; f_equal*.
  case_var*. 
Qed.

(** Substitution distributes on the open operation. *)

Lemma subst_ee_open_ee : forall t1 t2 u x, term u ->
  subst_ee x u (open_ee t1 t2) =
  open_ee (subst_ee x u t1) (subst_ee x u t2).
Proof.
  intros. unfold open_ee. generalize 0.
  induction t1; intros; simpls; f_equal*.
  case_nat*.
  case_var*. rewrite* <- open_ee_rec_term.
Qed.

(** Substitution and open_var for distinct names commute. *)

Lemma subst_ee_open_ee_var : forall x y u e, y <> x -> term u ->
  (subst_ee x u e) open_ee_var y = subst_ee x u (e open_ee_var y).
Proof.
  introv Neq Wu. rewrite* subst_ee_open_ee.
  simpl. case_var*.
Qed.

(** Opening up a body t with a type u is the same as opening
  up the abstraction with a fresh name x and then substituting u for x. *)

Lemma subst_ee_intro : forall x u e, 
  x \notin fv_ee e -> term u ->
  open_ee e u = subst_ee x u (e open_ee_var x).
Proof.
  introv Fr Wu. rewrite* subst_ee_open_ee.
  rewrite* subst_ee_fresh. simpl. case_var*.
Qed.

(** Interactions between type substitutions in terms and opening
  with term variables in terms. *)

Lemma subst_te_open_ee_var : forall Z P x e,
  (subst_te Z P e) open_ee_var x = subst_te Z P (e open_ee_var x).
Proof.
  introv. unfold open_ee. generalize 0.
  induction e; intros; simpl; f_equal*. case_nat*.
Qed.

(** Interactions between term substitutions in terms and opening
  with type variables in terms. *)

Lemma subst_ee_open_te_var : forall z u e X, term u ->
  (subst_ee z u e) open_te_var X = subst_ee z u (e open_te_var X).
Proof.
  introv. unfold open_te. generalize 0.
  induction e; intros; simpl; f_equal*.
  case_var*. symmetry. autos* open_te_rec_term.
Qed.

(** Substitutions preserve local closure. *)

Lemma subst_tt_type : forall T Z P,
  type T -> type P -> type (subst_tt Z P T).
Proof.
  induction 1; intros; simpl; auto.
  case_var*.
  apply type_all with (L:=L \u \{Z}). apply* IHtype.
  intros. rewrite* subst_tt_open_tt_var. 
Qed.

Lemma subst_te_term : forall e Z P,
  term e -> type P -> term (subst_te Z P e).
Proof.
  lets: subst_tt_type. induction 1; intros; simpl; auto.
  apply_fresh* term_abs as x. rewrite* subst_te_open_ee_var.
  apply term_tabs with (L:=L \u \{Z}). auto. 
  intros. rewrite* subst_te_open_te_var.
Qed.

Lemma subst_ee_term : forall e1 Z e2,
  term e1 -> term e2 -> term (subst_ee Z e2 e1).
Proof.
  induction 1; intros; simpl; auto.
  case_var*.
  apply_fresh* term_abs as y. rewrite* subst_ee_open_ee_var.
  apply term_tabs with (L:=L \u \{Z}). auto. intros. rewrite* subst_ee_open_te_var.
Qed.

Hint Resolve subst_tt_type subst_te_term subst_ee_term.

(* ********************************************************************** *)
(** * Properties of well-formedness of a type in an environment *)

(** If a type is well-formed in an environment then it is locally closed. *)

Lemma wft_type : forall E T,
  wft E T -> type T.
Proof.
  induction 1; eauto. 
Qed.

(** Through weakening *)

Lemma wft_weaken : forall G T E F,
  wft (E & G) T ->
  ok (E & F & G) ->
  wft (E & F & G) T.
Proof.
  intros. gen_eq K: (E & G). gen E F G.
  induction H; intros; subst; eauto.
  (* case: var *)
  apply (@wft_var m T1 (E0&F&G)). apply* binds_weaken. autos*.
  (* case: all *)
  apply_fresh* wft_all as Y. apply_ih_bind* H1.
Qed.

(** Through strengthening *)

Lemma wft_strengthen : forall E F x U T,
 wft (E & x ~: U & F) T -> wft (E & F) T.
Proof.
  intros. gen_eq G: (E & x ~: U & F). gen F. assert (wft G T). { auto. }
  induction H; intros F EQ; subst; auto.
  apply (@wft_var m T1). destruct (binds_concat_inv H) as [?|[? ?]].
    apply* binds_concat_right. 
    destruct (binds_push_inv H2) as [[? ?]|[? ?]].
      subst. false.
      apply~ binds_concat_left.
  autos*.
  (* todo: binds_cases tactic *)
  apply_fresh* wft_all as Y. apply_ih_bind* H2.
Qed.

(** Through type substitution *)

Lemma wft_subst_tb : forall m T1 F E Z P T,
  wft (E & Z !:m  <>: T1 & F) T ->
  wft E P ->
  ok (E & map (subst_tb Z P) F) ->
  wft (E & map (subst_tb Z P) F) (subst_tt Z P T).
Proof.
  introv WT WP. gen_eq G: (E & Z !:m <>: T1 & F). gen F.
  induction WT; intros F EQ Ok; subst; simpl subst_tt; auto.
  case_var*.
    apply_empty* wft_weaken. 
     destruct (binds_concat_inv H) as [?|[? ?]]. 
      apply wft_var with (m:=m0) (T1:=(subst_tt Z P T0)). 
       apply~ binds_concat_right. 
      unsimpl_map_bind. apply~ binds_map.  
      destruct (binds_push_inv H1) as [[? ?]|[? ?]].
        subst. false~.
        applys wft_var. apply* binds_concat_left. 
  apply_fresh* wft_all as Y. 
   unsimpl ((subst_tb Z P) (bind_tRel m0 Tn)).
   lets: wft_type.
   rewrite* subst_tt_open_tt_var.
   apply_ih_map_bind* H0.
Qed.

(** Through type reduction *)

Lemma wft_open : forall E U m T1 T2,
  ok E ->
  wft E (typ_all m T1 T2) -> 
  wft E U ->
  wft E (open_tt T2 U).
Proof.
  introv Ok WA WU. inversions WA. pick_fresh X. 
  autos* wft_type. rewrite* (@subst_tt_intro X).
  lets K: (@wft_subst_tb m T1 empty).
  specializes_vars K. clean_empty K. apply* K.
  (* todo: apply empty ? *)
Qed.

(** Through narrowing *)

Lemma wft_narrow : forall m V F U T E X,
  wft (E & X !: m <>: V & F) T ->
  ok (E & X !: m <>: U & F) -> 
  wft (E & X !: m <>: U & F) T.
Proof.
  intros. gen_eq K: (E & X !: m <>: V & F). gen E F.
  induction H; intros; subst; eauto.
  destruct (binds_middle_inv H) as [K|[K|K]]; try destructs K.
    applys wft_var. apply* binds_concat_right.
    subst. applys wft_var. apply~ binds_middle_eq.
    applys wft_var. apply~ binds_concat_left.
     apply* binds_concat_left.
  apply_fresh* wft_all as Y. apply_ih_bind* H1.
Qed.

(* ********************************************************************** *)
(** * Relations between well-formed environment and types well-formed
  in environments *)

(** If an environment is well-formed, then it does not contain duplicated keys. *)

Lemma ok_from_okt : forall E,
  okt E -> ok E.
Proof.
  induction 1; auto. 
Qed.

Hint Extern 1 (ok _) => apply ok_from_okt.

(** Extraction from a typing assumption in a well-formed environments *)

Lemma wft_from_env_has_typ : forall x U E, 
  okt E -> binds x (bind_typ U) E -> wft E U.
Proof.
  induction E using env_ind; intros Ok B.
  false* binds_empty_inv.
  inversions Ok.
    false (empty_push_inv H0).
    destruct (eq_push_inv H) as [? [? ?]]. subst. clear H.
     destruct (binds_push_inv B) as [[? ?]|[? ?]]. inversion H3. 
       apply_empty* wft_weaken.
    destruct (eq_push_inv H) as [? [? ?]]. subst. clear H.
     destruct (binds_push_inv B) as [[? ?]|[? ?]]. subst.
       inversions H3. apply_empty* wft_weaken.
       apply_empty* wft_weaken.
Qed. 

Lemma wft_from_env_has_sub : forall x m U E,
  okt E -> binds x (bind_tRel m U) E -> wft E U.
Proof.
  induction E using env_ind; intros Ok B.
  false* binds_empty_inv.
  inversions Ok.
    false (empty_push_inv H0).
    destruct (eq_push_inv H) as [? [? ?]]. subst. clear H.
     destruct (binds_push_inv B) as [[? ?]|[? ?]]. subst.
       inversions H3. apply_empty* wft_weaken.
       apply_empty* wft_weaken.
    destruct (eq_push_inv H) as [? [? ?]]. subst. clear H.
     destruct (binds_push_inv B) as [[? ?]|[? ?]]. subst.
       inversions H3.
       apply_empty* wft_weaken.
Qed.

(** Extraction from a well-formed environment *)

Lemma wft_from_okt_typ : forall x T E,
  okt (E & x ~: T) -> wft E T.
Proof.
  intros. inversions* H.
  false (empty_push_inv H1).
  destruct (eq_push_inv H0) as [? [? ?]]. false.
  destruct (eq_push_inv H0) as [? [? ?]]. inversions~ H4.
Qed.

Lemma wft_from_okt_sub : forall m x T E,
  okt (E & x !: m <>: T) -> wft E T.
Proof.
  intros. inversions* H.
  false (empty_push_inv H1).
  destruct (eq_push_inv H0) as [? [? ?]]. inversions~ H4.
  destruct (eq_push_inv H0) as [? [? ?]]. false.
Qed.

Lemma wft_weaken_right : forall T E F,
  wft E T ->
  ok (E & F) ->
  wft (E & F) T.
Proof.
  intros. apply_empty* wft_weaken.
Qed.

Hint Resolve wft_weaken_right.
Hint Resolve wft_from_okt_typ wft_from_okt_sub.
Hint Immediate wft_from_env_has_typ wft_from_env_has_sub.
Hint Resolve wft_subst_tb.

(** Extraction from a subtyping assumption in a well-formed environments *)

(* ********************************************************************** *)
(** ** Properties of well-formedness of an environment *)

(** Inversion lemma *)

Lemma okt_push_inv : forall E X B,
  okt (E & X ~ B) -> (exists m T, B = bind_tRel m T) \/ exists T, B = bind_typ T.
Proof.
  introv O. inverts O.
    false* empty_push_inv.
    lets (?&?&?): (eq_push_inv H). subst*.
    lets (?&?&?): (eq_push_inv H). subst*.
Qed.

Lemma okt_push_tvr_inv : forall E X m T,
  okt (E & X !:m <>: T) -> okt E /\ wft E T /\ X # E.
Proof.
  introv O. inverts O.
    false* empty_push_inv.
    lets (?&M&?): (eq_push_inv H). subst. inverts~ M.
    lets (?&?&?): (eq_push_inv H). false.
Qed.


Lemma okt_push_sub_type : forall m E X T,
  okt (E & X !: m <>: T) -> type T.
Proof. intros. applys wft_type. forwards*: okt_push_tvr_inv. Qed.

Lemma okt_push_typ_inv : forall E x T,
  okt (E & x ~: T) -> okt E /\ wft E T /\ x # E.
Proof.
  introv O. inverts O.
    false* empty_push_inv.
    lets (?&?&?): (eq_push_inv H). false.
    lets (?&M&?): (eq_push_inv H). subst. inverts~ M.
Qed.

Lemma okt_push_typ_type : forall E X T,
  okt (E & X ~: T) -> type T.
Proof. intros. applys wft_type. forwards*: okt_push_typ_inv. Qed.

Hint Immediate okt_push_typ_type okt_push_sub_type.
(** Through strengthening *)

Lemma okt_strengthen : forall x T (E F:env),
  okt (E & x ~: T & F) ->
  okt (E & F).
Proof.
 introv O. induction F using env_ind.
  rewrite concat_empty_r in *. lets*: (okt_push_typ_inv O).
  rewrite concat_assoc in *. 
   lets: okt_push_inv O. destruct H; subst.
     destruct H. destruct H. subst.
     lets (?&?): (okt_push_tvr_inv O).
      applys~ okt_tvr. applys* wft_strengthen. destruct* H0. 
    destruct H. subst. lets (?&?): (okt_push_typ_inv O).
    applys~ okt_typ. applys* wft_strengthen. destruct* H0.
Qed.

Lemma okt_strengthen_l : forall E F,
  okt (E&F) ->
  okt E.
Proof. introv OKC. induction F using env_ind.
  rewrite concat_empty_r in *. auto.
  rewrite concat_assoc in *. 
   lets: okt_push_inv OKC. destruct H; try destruct H; subst.
    destruct H. subst. 
     lets (?&?): (okt_push_tvr_inv OKC). apply IHF. apply H.
      lets (?&?): (okt_push_typ_inv OKC). apply* IHF.
Qed.

Lemma okt_subst_tb : forall Q m Z P (E F:env),
  okt (E & Z!: m <>: Q & F) ->
  wft E P ->
  okt (E & map (subst_tb Z P) F).
Proof.
 introv O W. induction F using env_ind.
  rewrite map_empty. rewrite concat_empty_r in *.
   lets*: (okt_push_tvr_inv O).
  rewrite map_push. rewrite concat_assoc in *.
   lets : okt_push_inv O. destruct H; try destruct H; subst.
   destruct H. subst. lets (?&?): (okt_push_tvr_inv O).
      applys~ okt_tvr. destruct* H0. autos*.
      lets (?&?&?): (okt_push_typ_inv O).
      applys~ okt_typ. apply* wft_subst_tb.  
Qed.

Lemma okt_narrow : forall m V (E F:env) U X,
  okt (E & X !: m <>: V & F) ->
  wft E U ->
  okt (E & X !: m <>: U & F).
Proof.
  introv O W. induction F using env_ind.
  rewrite concat_empty_r in *. lets*: (okt_push_tvr_inv O).
  rewrite concat_assoc in *.
   lets [(?&?&?)|(?&?)]: okt_push_inv O; subst.
     lets (?&?&?): (okt_push_tvr_inv O).
      applys~ okt_tvr. applys* wft_narrow. 
     lets (?&?&?): (okt_push_typ_inv O).
      applys~ okt_typ. applys* wft_narrow. 
Qed.

(** Automation *)

Hint Resolve okt_narrow okt_subst_tb wft_weaken.
Hint Immediate okt_strengthen.

(* ********************************************************************** *)
(** ** Environment is unchanged by substitution from a fresh name *)

Lemma notin_fv_tt_open : forall Y X T,
  X \notin fv_tt (T open_tt_var Y) ->
  X \notin fv_tt T.
Proof.
 introv. unfold open_tt. generalize 0.
 induction T; simpl; intros k Fr; auto.
 specializes IHT1 k. specializes IHT2 k. auto.
 specializes IHT1 k. specializes IHT2 (S k). auto.
Qed.

Lemma notin_fv_wf : forall E X T,
  wft E T -> X # E -> X \notin fv_tt T.
Proof.
  induction 1; intros Fr; simpl.
  eauto.
  rewrite notin_singleton. intro. subst. applys binds_fresh_inv H Fr.
  auto. auto. auto.
  notin_simpl; auto. 
 notin_simpl; auto. pick_fresh Y. apply* (@notin_fv_tt_open Y).
Qed.

Lemma map_subst_tb_id : forall G Z P,
  okt G -> Z # G -> G = map (subst_tb Z P) G.
Proof.
  induction 1; intros Fr; autorewrite with rew_env_map; simpl.
  auto.
  rewrite* <- IHokt. rewrite* subst_tt_fresh. apply* notin_fv_wf.
    rewrite* <- IHokt. rewrite* subst_tt_fresh. apply* notin_fv_wf.
Qed.
(* ********************************************************************** *)
(** ** Regularity of relations *)

(** The subtyping relation is restricted to well-formed objects. *)
Lemma sub_regular : forall E m T1 T2,
  R E m T1 T2 -> okt E /\ wft E T1 /\ wft E T2.
Proof. introv Rel.
induction Rel; autos*. 
  - destruct m; autos*.
  - destruct m; autos*.
  - split. destruct IHRel; auto. split; apply_fresh* wft_all as Y.
    destruct (H0 Y); auto. destruct H2. destruct m1; simpl in H2.
     apply_empty* (@wft_narrow Sub typ_top); autos.
     apply_empty* (@wft_narrow Sup typ_btm); autos.
    destruct (H0 Y); auto. destruct H2. destruct m1; simpl in H3.
    apply_empty* (@wft_narrow Sub typ_top); autos.
     apply_empty* (@wft_narrow Sup typ_btm); autos.
   Qed.

Lemma sub_wft : forall E m T1 T2,
  R E m T1 T2 -> wft E T1 /\ wft E T2.
Proof. intros. apply sub_regular in H. destruct H; auto. Qed.

(** The typing relation is restricted to well-formed objects. *)

Lemma typing_regular : forall E e T,
  typing E e T -> okt E /\ term e /\ wft E T.
Proof. 
  induction 1; splits*.
   pick_fresh y. specializes H0 y. destructs~ H0. 
    forwards*: okt_push_typ_inv.
   apply_fresh* term_abs as y. 
     pick_fresh y. specializes H0 y. destructs~ H0.
      forwards*: okt_push_typ_inv.
     specializes H0 y. destructs~ H0.
   pick_fresh y. specializes H0 y. destructs~ H0. 
    apply* wft_arrow.
      forwards*: okt_push_typ_inv.
      apply_empty* wft_strengthen.
  destructs IHtyping1. inversion* H3.
   pick_fresh y. specializes H0 y. destructs~ H0. 
    forwards*: okt_push_tvr_inv.
  apply term_tabs with (L:=L).
   pick_fresh X. destruct H0 with (X:=X).
  autos. apply okt_push_tvr_inv in H1. destruct H1. destruct H3. 
  apply wft_type in H3. auto.
   intros.
      forwards~ K: (H0 X). destructs K. 
       forwards*: okt_push_tvr_inv. 
   apply_fresh* wft_all as Y.  
     pick_fresh y. forwards~ K: (H0 y). destructs K. 
      forwards*: okt_push_tvr_inv.
     forwards~ K: (H0 Y). destructs K.
      forwards*: okt_push_tvr_inv. 
  apply term_tapp; autos*. eapply wft_type. apply sub_wft in H0. 
  destruct H0. apply H0.
  destruct IHtyping. destruct H2. inversion H3.  subst.
   applys* wft_open T2. apply sub_wft in H0. destruct* H0.  
Qed. 

(** The value relation is restricted to well-formed objects. *)

Lemma value_regular : forall t,
  value t -> term t.
Proof.
  induction 1; autos*.
Qed.

(** The reduction relation is restricted to well-formed objects. *)

Lemma red_regular : forall t t',
  red t t' -> term t /\ term t'.
Proof.
  induction 1; split; autos* value_regular.
  inversions H. pick_fresh y. rewrite* (@subst_ee_intro y). 
  inversions H. pick_fresh Y. rewrite* (@subst_te_intro Y).  
Qed.

(** Automation *)

Hint Extern 1 (okt ?E) =>
  match goal with
  | H: R _ _ _ _ |- _ => apply (proj31 (sub_regular H))
  | H: typing _ _ _ |- _ => apply (proj31 (typing_regular H))
  end.

Hint Extern 1 (wft ?E ?T) =>
  match goal with
  | H: typing E _ T |- _ => apply (proj33 (typing_regular H))
  | H: R E _ T _ |- _ => apply (proj32 (sub_regular H))
  | H: R E _ _ T |- _ => apply (proj33 (sub_regular H))
  end.

Hint Extern 1 (type ?T) =>
  let go E := apply (@wft_type E); auto in
  match goal with
  | H: typing ?E _ T |- _ => go E
  | H: R ?E _ T _ |- _ => go E
  | H: R ?E _ _ T |- _ => go E
  end.

Hint Extern 1 (term ?e) =>
  match goal with
  | H: typing _ ?e _ |- _ => apply (proj32 (typing_regular H))
  | H: red ?e _ |- _ => apply (proj1 (red_regular H))
  | H: red _ ?e |- _ => apply (proj2 (red_regular H))
  end.

(* ********************************************************************** *)
(** * Properties of Subtyping *)

(* ********************************************************************** *)
(** Reflexivity (1) *)
Lemma refl : forall E m A,
  okt E ->
  wft E A -> 
  R E m A A.
  introv OK WFT. lets W:(wft_type WFT). gen E. gen m.
  induction W; intros; inversion WFT; eauto.
  - destruct m. apply* STB1. apply* STB2.
  - destruct m. apply* STB2. apply* STB1.
  - subst. pick_fresh X. apply SAll with (L:=L\u L0 \u dom E). 
    auto. intros v Hv. apply notin_union_r in Hv. destruct Hv. 
    apply notin_union_r in H2. destruct H2.
    apply H0 with (E:=E & v!:m<>:(SelectBound m)); auto.
    destruct m; auto.
    apply_empty* (@wft_narrow m T1).
Defined.

(* ********************************************************************** *)
(** Weakening (2) *)

Lemma sub_weakening : forall m E F G S T,
   R (E & G) m S T -> 
   okt (E & F & G) ->
   R (E & F & G) m S T.
Proof.
  introv Typ. gen F. inductions Typ; introv Ok; auto.
  (* case: fvar trans *)
  apply SVarBnd with (T:=T). apply* binds_weaken.
  autos. autos.
  apply SVarBndFl with (T:=T). apply* binds_weaken.
  autos. autos.
(*   apply SVarTrns with (X:=X); auto.  *)
  (* case: all *)
  apply SAll with (L:=L \u (dom E) \u (dom F) \u (dom G)). auto. intros. 
  assert (E & F & G & X !: m1 <>: (SelectBound m1) = E&F&(G & X !: m1<>:(SelectBound m1))).
  rewrite concat_assoc. reflexivity. rewrite H2. apply H0; auto.
  rewrite concat_assoc. auto. rewrite concat_assoc. apply* okt_tvr.
  destruct m1; simpl. auto. auto. 
Qed.

(* ********************************************************************** *)
(** Symmetry*)

Lemma m_flip_inv : forall m, m = flip (flip m).
Proof. intros. destruct* m. Qed.

Lemma sym1 : forall E A B m, R E m A B -> R E (flip m) B A.
  intros. induction H.
  - autos.
  - destruct m; apply* STB2.
  - destruct m; apply* STB1.
  - apply* SFun.
  - apply* SVarRefl.
  - apply* SVarBndFl.
  - apply SVarBnd with (T:=T); try rewrite <- m_flip_inv; auto. 
(*   - apply SVarTrns with (X:=X); auto. *)
  - apply* SAll. destruct m1; simpl. simpl in IHR. auto.
    simpl in IHR. auto.
Defined.

Corollary sym2 : forall E A B m, R E m A B <-> R E (flip m) B A.
destruct m; split; apply sym1.
Defined. 

Corollary sym : forall E A B, R E Sub A B <-> R E Sup B A.
  intros. split; apply sym1.
Defined.

(** In parentheses are given the label of the corresponding
  lemma in the description of the POPLMark Challenge. *)
Lemma TopBtmMustEq1 : forall m T1 T2 E,
okt E -> wft E T2 -> R E m T1 (mode_to_sub (flip m)) -> R E m T1 T2.
Proof. introv OK WF H. remember (mode_to_sub (flip m)) as T'. 
  induction H; try destruct m; inversion* HeqT'.
  - subst. eapply SVarBnd. apply H. auto. auto.
  - subst. eapply SVarBnd. apply H. auto. auto.
(*   - subst. eapply SVarTrns. apply H. apply* IHR2.
  - subst. eapply SVarTrns. apply H. apply* IHR2.  *)- destruct m2; inversion H3.  
Qed.

Lemma TopBtmMustEq2 : forall m T1 T2 E,
okt E -> wft E T2 -> R E m (mode_to_sub m) T1  -> R E m T2 T1.
Proof. introv OK WF H. remember (mode_to_sub m) as T'. 
  induction H; try destruct m; inversion* HeqT'.
  - subst. eapply SVarBndFl. apply H. auto. apply TopBtmMustEq1 with (T2:=T2) in H1; auto.
  - subst. eapply SVarBndFl. apply H. auto. apply TopBtmMustEq1 with (T2:=T2) in H1; auto.
(*   - subst. eapply SVarTrns. apply* IHR1. apply H0.
  - subst. eapply SVarTrns. apply* IHR1. apply H0. *)
  - destruct m2; inversion H3.  Qed.

Hint Resolve TopBtmMustEq1 TopBtmMustEq2.

Lemma top_btm_var : forall m E T,
R E m T (mode_to_sub (flip m)) -> T = mode_to_sub (flip m) \/( exists X Tn, T = typ_fvar X /\ binds X (bind_tRel m Tn) E
  /\ R E m Tn (mode_to_sub (flip m))).
Proof. introv rels. inductions rels; try solve [ destruct m; inversion x].
- left. reflexivity.
- destruct IHrels; auto. right. exists X. exists T. 
  split; autos. right. exists X. exists T. split; auto.
- destruct m2; inversion x.
Qed.

Lemma TopBtmMustEq3 : forall m T1 T2 E,
R E m T2 T1 -> R E m T1 (mode_to_sub (flip m)) -> R E m T2 (mode_to_sub (flip m)).
Proof. introv R1 R2.
apply top_btm_var in R2. destruct R2; subst.
- auto.
- destruct H. destruct H. destruct H. destruct H0. subst.
  inductions R1.
  + destruct m; inversion x.
  + apply* refl.
  + eapply SVarBnd. apply H1. auto. auto.
  + eapply SVarBnd. apply H. auto. eapply IHR1. auto.
    apply H1. auto.
  + apply binds_get in H. apply binds_get in H1. rewrite H1 in H.
    inversion H. destruct m; inversion H4. Qed.

Lemma form_vtrans : forall m E X A B,
R E m (typ_fvar X) A -> R E m B (typ_fvar X) ->
  A = mode_to_sub m \/
  (exists X', A = typ_fvar X' /\ ((X' = X) \/ (exists T0, binds X' (bind_tRel (flip m) T0) E /\ R E m (typ_fvar X) T0 ))) \/ 
  B = mode_to_sub (flip m) \/ 
  (exists X', B = typ_fvar X' /\ ((X' = X) \/ (exists T0, binds X' (bind_tRel m T0) E /\ R E (flip m) (typ_fvar X) T0 ))).
Proof. introv R1 R2. gen B. inductions R1; introv R2.
- left*.
- destruct m; inversion x.
- right. left. exists X. split; auto.
- right. right. inductions R2; autos*.
  + destruct m; inversion x.
  + right. exists X0. split; auto. right. exists T0. 
    split; auto. apply sym1; auto.
  + apply binds_get in H1. apply binds_get in H. rewrite H1 in H.
    inversion H. destruct m; inversion H4.
- right. left. exists X0. split; auto.
  inductions R2. 
  + destruct m; inversion x. 
  + right. exists T. rewrite <- m_flip_inv. split; auto.
    apply sym1. auto.
  + right. exists T. rewrite <- m_flip_inv. split; auto.
    apply sym1. auto.
  + right. exists T. rewrite <- m_flip_inv. split; auto.
    apply sym1. auto.
  + right. exists T. rewrite <- m_flip_inv. split; auto.
    apply sym1. auto.  Qed.

Lemma subvar_inv : forall m E X A,
R E m (typ_fvar X) A ->
  A = mode_to_sub m \/
  (exists T, binds X (bind_tRel m T) E /\ R E m T A) \/
  (exists X', A = typ_fvar X' /\ ((X' = X) \/ (exists T0, binds X' (bind_tRel (flip m) T0) E /\ R E m (typ_fvar X) T0 ))).
Proof. introv Rel. inductions Rel; autos.
- destruct m; inversion x.
- right. right. exists X. split; auto.
- right. left. exists* T.
- right. right. exists X0. split; auto. right. exists T.
  rewrite <- m_flip_inv. split; auto. apply* sym1. Qed.

Lemma inv_rinv :  forall m E X A, (okt E /\ wft E (typ_fvar X) /\ A = mode_to_sub m) \/
  (exists T, binds X (bind_tRel m T) E /\ R E m T A) \/
  (exists X', A = typ_fvar X' /\ ((okt E /\ wft E (typ_fvar X) /\ X' = X) \/ (exists T0, binds X' (bind_tRel (flip m) T0) E /\ R E m (typ_fvar X) T0 ))) ->
    R E m (typ_fvar X) A.
Proof. introv H. destruct H. destruct H. destruct H0. subst*. 
  destruct H.
- destruct H. destruct H. eapply SVarBnd. apply H. auto. auto.
- destruct H. destruct H. destruct H0.
  + destruct H0. destruct H1. subst. apply* refl.
  + destruct H0. destruct H0.  subst. apply sym2. 
    eapply SVarBnd. apply H0. auto. apply sym1. auto. Qed. 
  
Lemma subvar_inv_binds : forall m E X A B,
R E m (typ_fvar X) A -> binds X (bind_tRel m B) E ->
  R E m B A \/ (exists X', A = typ_fvar X' /\ ((X' = X) \/ (exists T0, binds X' (bind_tRel (flip m) T0) E /\ R E m (typ_fvar X) T0 ))).
Proof. introv Re bnd. lets K:Re. apply subvar_inv in Re.
  destruct Re. 
- left. subst. apply STB1; autos. eapply wft_from_env_has_sub. autos. apply bnd.
- destruct H. 
  + destruct H. destruct H. assert (bind_tRel m x = bind_tRel m B). { eapply binds_functional. apply H.
     apply bnd. } inversion H1. subst. left. auto.
  + right*. Qed. 

Lemma subvar_inv_binds_fl : forall m E X A B,
R E m (typ_fvar X) A -> binds X (bind_tRel (flip m) B) E ->
  A = mode_to_sub m \/
  (exists X', A = typ_fvar X' /\ ((X' = X) \/ (exists T0, binds X' (bind_tRel (flip m) T0) E /\ R E m (typ_fvar X) T0 ))).
Proof. introv R Bnd. apply subvar_inv in R. destruct R.
- left*.
- destruct H. destruct H. destruct H. apply binds_get in H. apply binds_get in Bnd. 
  rewrite Bnd in H. inversion H. destruct m; inversion H2.
  right. auto. Qed.

(* ********************************************************************** *)
(** Narrowing and Transitivity (3) *)

Definition transitivity_on Q := forall E m S T,
  R E m S Q -> R E m Q T -> R E m S T.

Hint Unfold transitivity_on.

Hint Resolve wft_narrow.
(* 
Lemma sub_narrowing_aux : forall m1 m2 Q F E Z P S T,
  transitivity_on Q ->
  R (E & Z !:m1 <>: Q & F) m2 S T ->
  R E m1 P Q ->
  R (E & Z !:m1 <>: P & F) m2 S T.
Proof.
  introv TransQ SsubT PsubQ. 
  inductions SsubT; introv.
  apply* SInt.
  apply* STB1.
  apply* STB2.
  apply* SFun.
  apply* SVarRefl.
  tests EQ: (X = Z).
    lets M: (@okt_narrow m1 Q).
    apply SVarBnd with (T:=P).
      asserts~ N: (ok (E & Z !:m1 <>: P & F)).
       lets: ok_middle_inv_r N.
        assert (m = m1). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
       subst;  apply* binds_middle_eq.
       replace E with (E&empty) in PsubQ; try apply concat_empty_r.
        apply sub_weakening with (F:=Z!:m1<>:P&F) in PsubQ.
        rewrite concat_empty_r in PsubQ. rewrite concat_assoc in PsubQ.
         apply sub_wft in PsubQ. destruct* PsubQ. rewrite concat_empty_r.
         rewrite concat_assoc. apply* M. rewrite concat_empty_r in PsubQ. 
        apply sub_wft in PsubQ. destruct* PsubQ.     
      apply TransQ.
      assert (m = m1). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
        subst.
        do_rew* concat_assoc (apply_empty* sub_weakening).
        binds_get H. inversion H1. subst. autos*.
    apply SVarBnd with (T:=T); auto. binds_cases H; auto.
  apply* wft_narrow. autos*. 
    tests EQ: (X = Z).
    lets M: (@okt_narrow m1 Q).
    apply SVarBndFl with (T:=P).
      asserts~ N: (ok (E & Z !:m1 <>: P & F)).
       lets: ok_middle_inv_r N.
        assert (m = m1). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
       subst;  apply* binds_middle_eq.
       replace E with (E&empty) in PsubQ; try apply concat_empty_r.
        apply sub_weakening with (F:=Z!:m1<>:P&F) in PsubQ.
        rewrite concat_empty_r in PsubQ. rewrite concat_assoc in PsubQ.
         apply sub_wft in PsubQ. destruct* PsubQ. rewrite concat_empty_r.
         rewrite concat_assoc. apply* M. rewrite concat_empty_r in PsubQ. 
        apply sub_wft in PsubQ. destruct* PsubQ.     
      apply TransQ.
      assert (m = m1). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
        subst.
        do_rew* concat_assoc (apply_empty* sub_weakening).
        binds_get H. inversion H1. subst. autos*.
    apply SVarBndFl with (T:=T); auto. binds_cases H; auto.
  apply* wft_narrow. autos*. 
(*   apply SVarTrns with (X:=X); autos*. *)
  apply SAll with (L:=L). apply IHSsubT with (Q0:=Q); autos*.
  (*apply* wft_narrow. apply ok_from_okt. 
  apply* okt_narrow.*) (*pick_fresh X. assert (X \notin L). auto.*)
  intros. 
  apply H0 with (E0:=E) (Z0:=Z) (m3:=m1) (Q0:=Q) (F0:= (F & X !: m0 <>: SelectBound m0)) in H1; auto.
  rewrite concat_assoc in H1. auto. rewrite concat_assoc. auto.
Qed. *)

Lemma Var_Trans : forall E m T1 T2 X,
R E m T1 (typ_fvar X) -> R E m (typ_fvar X) T2 -> 
  R E m T1 T2.
Proof. introv H1 H2. gen T2. inductions H1.
- destruct m; inversion x.
- introv Hy. apply* STB2.
- autos.
- introv Hy. eapply SVarBnd. apply H.
  autos. apply IHR with (X0:=X). autos. auto.
- introv Hy. apply sym2 in Hy. inductions Hy.
  + destruct m; inversion x.
  + apply* STB1.
  + eapply SVarBndFl. apply H. auto. auto.
  + eapply SVarBndFl. apply H3. auto. apply sym2.
    apply IHHy with (X0:=X); autos.
  + apply binds_get in H3. apply binds_get in H.
    rewrite H3 in H. inversion H. destruct m; inversion H5.
Qed.

Lemma sub_transitivity : forall Q E S m T,
  R E m S Q -> R E m Q T -> R E m S T.
Proof. introv R1. gen T. induction R1; introv R2; autos.
- inductions R2; autos.
  + destruct m; inversion x.
  + assert (forall T0, R E m T T0 -> R E m (typ_fvar X) T0).
     { intros. eapply SVarBnd. apply H. auto. auto.  }
    clear H. clear IHR2. inductions R2; autos.
    * destruct m; inversion x.
    * apply sym1. apply H2. autos.
    * apply sym1. apply H1. apply sym2. apply SFun.
      apply IHR1_1. apply sym1. auto.
      apply IHR1_2. apply sym1. auto.
    * apply IHR2 with (C0:=C) (D0:=D); autos.
      introv Hy. apply H2. eapply SVarBnd. apply H.
      auto. apply Hy.
- eapply SVarBnd. apply H. auto. apply IHR1. auto.
- apply Var_Trans with (X:=X). eapply SVarBndFl. 
  apply H. auto. auto. auto.
- inductions R2; autos.
  + apply STB1. auto. apply wft_all with (L:=L \u dom E). autos.
    intros. assert (X \notin L). { autos. } apply H in H4. 
    destruct m; simpl in H4.
    auto. apply_empty (@wft_narrow m1 (SelectBound m1)). auto. apply ok_from_okt.
    apply okt_tvr. auto. auto. auto. apply_empty (@wft_narrow m1 (SelectBound m1)).
    auto. apply ok_from_okt.
    apply okt_tvr. auto. auto. auto.
  + destruct m; inversion x.
  + assert (forall T0, R E m T T0 -> R E m (typ_fvar X) T0).
     { intros. eapply SVarBnd. apply H1. auto. auto.  }
    (*clear H3.*) clear H1. clear IHR2. inductions R2; autos.
    * destruct m; inversion x.
    * apply sym1. apply H4. apply STB2. auto. apply wft_all with (L:=L \u dom E).
      auto. intros. assert (X0 \notin L). { autos. } apply H1 in H6. 
      destruct m; simpl in H6.
      apply_empty (@wft_narrow m1 (SelectBound m1)). auto. auto.  
      apply_empty (@wft_narrow m1 (SelectBound m1)). auto. auto.  
    * apply IHR2 with (m2:=m1) (T5:=T2) (T6:=T4); autos.
      introv Hy. apply H4. eapply SVarBnd. apply H. auto.
      auto.
    * apply sym1. apply H4. apply SAll with (L:=L \u L0 \u dom E); autos.
      { destruct m1; simpl; simpl in IHR1; simpl in R2.
        apply sym2. apply IHR1. apply sym1. auto.
        apply sym2. apply IHR1. apply sym1. auto. } clear IHR2. clear H0.
      introv NI. apply sym2. apply H3. auto.
      apply sym1. auto. 
  + apply SAll with (L:= L \u L0); autos. 
Qed. 

Lemma sub_narrowing : forall Q E m m' F Z P S T,
  R E m' P Q ->
  R (E & Z !: m' <>: Q & F) m S T ->
  R (E & Z !: m' <>: P & F) m S T.
Proof. introv R1 R2. inductions R2; autos; intros.
- apply* SInt.
- apply* STB1.
- apply* STB2.
- apply SFun. eapply IHR2_1. apply R1.
  auto. eapply IHR2_2. apply R1. auto.
- apply* SVarRefl.
- tests EQ:(X=Z).
  + lets M: (@okt_narrow m' Q).
    apply SVarBnd with (T:=P).
      asserts~ N: (ok (E & Z !:m' <>: P & F)); auto.
       lets: ok_middle_inv_r N.
        assert (m = m'). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
       subst;  apply* binds_middle_eq. auto. 
        replace E with (E&empty) in R1; try apply concat_empty_r.
        apply sub_weakening with (F:=Z!:m'<>:P&F) in R1.
        rewrite concat_empty_r in R1. rewrite concat_assoc in R1.
         apply sub_wft in R1. destruct* R1. rewrite concat_empty_r.
         rewrite concat_assoc. apply* M. rewrite concat_empty_r in R1. 
        apply sub_wft in R1. destruct* R1.     
        assert (T = Q). {
         apply binds_middle_eq_inv in H. inversion* H. auto. }
         assert (m = m'). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }
        subst. eapply sub_transitivity. apply_empty sub_weakening.
        apply_empty sub_weakening. apply R1. apply okt_strengthen_l with (F:=F).
        auto. auto. apply IHR2 with (Q0:=Q); auto.
    +  apply SVarBnd with (T:=T); auto. binds_cases H; auto.
      apply wft_narrow with (V:=Q); auto. apply ok_from_okt.
      apply okt_narrow with (V:=Q); auto. eapply IHR2.
      apply R1. auto.
-  tests EQ:(X=Z).
  + lets M: (@okt_narrow m' Q).
    apply SVarBndFl with (T:=P).
      asserts~ N: (ok (E & Z !:m' <>: P & F)); auto.
       lets: ok_middle_inv_r N.
        assert (m = m'). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }  
       subst;  apply* binds_middle_eq. auto. 
        replace E with (E&empty) in R1; try apply concat_empty_r.
        apply sub_weakening with (F:=Z!:m'<>:P&F) in R1.
        rewrite concat_empty_r in R1. rewrite concat_assoc in R1.
         apply sub_wft in R1. destruct* R1. rewrite concat_empty_r.
         rewrite concat_assoc. apply* M. rewrite concat_empty_r in R1. 
        apply sub_wft in R1. destruct* R1.     
        assert (T = Q). {
         apply binds_middle_eq_inv in H. inversion* H. auto. }
         assert (m = m'). {
        apply binds_middle_eq_inv in H. inversion* H. auto. }
        subst. eapply sub_transitivity. apply_empty sub_weakening.
        apply_empty sub_weakening. apply R1. apply okt_strengthen_l with (F:=F).
        auto. auto. apply IHR2 with (Q0:=Q); auto.
    +  apply SVarBndFl with (T:=T); auto. binds_cases H; auto.
      apply wft_narrow with (V:=Q); auto. apply ok_from_okt.
      apply okt_narrow with (V:=Q); auto. eapply IHR2.
      apply R1. auto.
-  apply SAll with (L:=L). apply IHR2 with (Q0:=Q); autos*.
  intros. auto. 
apply H0 with (Q0:=Q) (Z0:=Z) (E0:=E) (m'0:=m') (F0:=F & X !: m1 <>: SelectBound m1) in H1.
rewrite concat_assoc in H1. auto. auto. rewrite concat_assoc. auto.
Qed.
         

(* ********************************************************************** *)
(** Type substitution preserves subtyping (10) *)

Lemma okt_notin : forall E F X v,
okt(E&X~v&F) -> X # E.
Proof. induction F using env_ind; introv OK.
- rewrite concat_empty_r in OK. destruct v. apply okt_push_tvr_inv in OK.
destruct* OK.  apply okt_push_typ_inv in OK. destruct* OK.
- rewrite concat_assoc in OK. destruct v. apply okt_push_tvr_inv in OK.
destruct* OK.  apply okt_push_typ_inv in OK. destruct* OK. Qed.

Lemma sub_through_subst_tt : forall m1 m2 Q E F Z S T P,
  R (E & Z !: m1 <>: Q & F) m2 S T ->
  R E m1 P Q ->
  R (E & map (subst_tb Z P) F) m2 (subst_tt Z P S) (subst_tt Z P T).
Proof.
  introv SsubT PsubQ.
  inductions SsubT; introv; simpl subst_tt.
  apply* SInt. 
  destruct m; apply* STB1. 
  destruct m; apply* STB2. 
  autos*. 
  case_var.
    apply* refl.
    apply* SVarRefl.
    inversions H0. binds_cases H3.
      apply* wft_var.
      apply wft_var with (m:=m0) (T1:=subst_tt Z P T1). unsimpl_map_bind*.
      case_var. 
      apply binds_middle_eq_inv in H. inversion H. subst. 
     apply sub_transitivity with (Q:=Q). apply_empty* sub_weakening.
    rewrite* <- (@subst_tt_fresh Z P Q).
    apply (@notin_fv_wf E).
    apply sub_wft in PsubQ. destruct* PsubQ.
    apply sub_regular in SsubT. destruct SsubT. eapply okt_notin. apply H1. 
    apply ok_from_okt. apply sub_regular in SsubT. destruct* SsubT.
    apply SVarBnd with (T:=(subst_tt Z P T)). rewrite* (@map_subst_tb_id E Z P).
    binds_cases H; unsimpl_map_bind*. 
     apply sub_regular in PsubQ. destruct* PsubQ.
    apply* IHSsubT.
    case_var.
    apply binds_middle_eq_inv in H; auto. inversion H. subst.
    assert ( R (E & map (subst_tb Z P) F) m1 (subst_tt Z P Q) (subst_tt Z P F0)).
    {  autos*. } apply sym1. apply sub_transitivity with (Q:=(subst_tt Z P Q)); auto.  
    rewrite*  (@subst_tt_fresh Z P Q). apply_empty sub_weakening; auto. 
    apply (@notin_fv_wf E); auto. apply sub_regular in SsubT. destruct SsubT. 
    apply okt_notin with (E:=E) (v:=(bind_tRel m1 Q)) (F:=F); auto.
    apply SVarBndFl with (T:=(subst_tt Z P T)). rewrite* (@map_subst_tb_id E Z P).
    binds_cases H; unsimpl_map_bind*.  apply* wft_subst_tb.
    apply* IHSsubT. 
    (*assert (R (E & map (subst_tb Z P) F) m (subst_tt Z P T1) (subst_tt Z P (typ_fvar X))).
    { autos*. }
    assert (R (E & map (subst_tb Z P) F) m (subst_tt Z P (typ_fvar X)) (subst_tt Z P T2)).
    { autos*. } eapply sub_transitivity. apply H. auto.*)
  apply SAll with (L:=L \u \{Z}).
   apply* IHSsubT.
  intros. assert (X \notin L). auto. 
  apply H0 with (m3:=m1) (Q0:=Q) (E0:=E) (F0:=(F & X !: m0 <>: SelectBound m0)) (Z0:=Z) in H2.
  assert ((bind_tRel m0 (SelectBound m0)) = (subst_tb Z P (bind_tRel m0 (SelectBound m0)))).
  { destruct m0; autos. } rewrite H3.  
  rewrite* subst_tt_open_tt_var. rewrite* subst_tt_open_tt_var. 
  rewrite <- concat_assoc. rewrite <- map_push. auto.
   rewrite concat_assoc. auto. auto. 
Qed.

(* ********************************************************************** *)
(** * Properties of Typing *)

(* ********************************************************************** *)
(** Weakening (5) *)

Lemma typing_weakening : forall E F G e T,
   typing (E & G) e T -> 
   okt (E & F & G) ->
   typing (E & F & G) e T.
Proof. 
  introv Typ. gen F. inductions Typ; introv Ok.
  apply* typing_unit.
  apply* typing_var. apply* binds_weaken.
  apply* typing_nval.
  apply* typing_nsucc.
  apply* typing_nind. 
  apply_fresh* typing_abs as x. forwards~ K: (H x).
   apply_ih_bind (H0 x); eauto.
  apply* typing_app.
  apply_fresh* typing_tabs as X. forwards~ K : (H X).
   apply_ih_bind (H0 X); eauto.
  apply* typing_tapp. apply* sub_weakening.
  apply* typing_sub. apply* sub_weakening. 
Qed.
(* ********************************************************************** *)
(** Strengthening (6) *)

Lemma sub_strengthening : forall m x U E F S T,
  R (E & x ~: U & F) m S T ->
  R (E & F) m S T.
Proof.
  intros m x U E F S T SsubT. 
  inductions SsubT; introv; autos* wft_strengthen.
  (* case: fvar trans *)
  apply SVarBnd with (T:=T); autos*. binds_cases H; autos*. 
  apply SVarBndFl with (T:=T); autos*. binds_cases H; autos*.
  (*apply SVarTrns with (X:=X); autos*. *)
  (* case: all *)
  apply SAll with (L:= L); autos*. intros. apply_ih_bind* H0.
Qed.

(************************************************************************ *)
(** Preservation by Term Substitution (8) *)

Lemma typing_through_subst_ee : forall U E F x T e u,
  typing (E & x ~: U & F) e T ->
  typing E u U ->
  typing (E & F) (subst_ee x u e) T.
Proof.
  introv TypT TypU. inductions TypT; introv; simpl.
  apply* typing_unit.
  case_var.
    binds_get H0. apply_empty* typing_weakening.
    binds_cases H0; apply* typing_var.
  apply* typing_nval.
  apply* typing_nsucc.
  apply* typing_nind. 
  apply_fresh* typing_abs as y.
    rewrite* subst_ee_open_ee_var.
    apply_ih_bind* H0.
  lets M:TypU. apply typing_regular in M. destruct M. auto.
  apply* typing_app. 
  apply_fresh* typing_tabs as Y.
    rewrite* subst_ee_open_te_var.
    apply_ih_bind* H0.
  apply* typing_tapp. apply* sub_strengthening.
  apply* typing_sub. apply* sub_strengthening. apply* wft_strengthen.
Qed.

(************************************************************************ *)
(** Preservation by Type Substitution (11) *)

Lemma typing_through_subst_te : forall E F Z m Ty e T P,
  typing (E & Z!: m <>: Ty & F) e T ->
  R E m P Ty ->
  typing (E & map (subst_tb Z P) F) (subst_te Z P e) (subst_tt Z P T).
Proof.
  introv Typ WFT. 
  inductions Typ; simpls subst_tt; simpls subst_te; autos*.
  subst. apply* typing_unit. 
  subst. apply* typing_var. rewrite* (@map_subst_tb_id E Z P).
  binds_cases H0; unsimpl_map_bind*. 
  subst. apply* typing_nind. 
  (* case abs *)
  apply_fresh* typing_abs as y.
    unsimpl (subst_tb Z P (bind_typ V)). 
   rewrite* subst_te_open_ee_var.
   apply_ih_map_bind* H0.
  (* case tabs *)
  apply_fresh* typing_tabs as Y. 
   unsimpl (subst_tb Z P (bind_tRel m0 Tk)).
    rewrite* subst_te_open_te_var.
    rewrite* subst_tt_open_tt_var.
    apply_ih_map_bind* H0.
    rewrite* subst_tt_open_tt. apply* typing_tapp.
    apply* sub_through_subst_tt. 
  apply* typing_sub. apply* sub_through_subst_tt.
Qed.

(* ********************************************************************** *)
(** * Preservation *)

(* ********************************************************************** *)
(** Inversions for Typing (13) *)

Lemma typing_inv_abs : forall E S1 e1 T,
  typing E (trm_abs S1 e1) T -> 
  (forall U1 U2, R E Sub T (typ_arrow U1 U2) ->
     R E Sub U1 S1
  /\ exists S2, exists L, forall x, x \notin L ->
     typing (E & x ~: S1) (e1 open_ee_var x) S2 /\ R E Sup U2 S2).
Proof.
  introv Typ. gen_eq e: (trm_abs S1 e1). gen S1 e1.
  induction Typ; intros S1 b1 EQ U1 U2 R; inversions EQ.
  inversions* R. split.
  rewrite <- sym2 in H6. auto.
  exists T1. exists L. split; autos.
  rewrite sym2. apply H8.
  apply IHTyp. autos. eapply sub_transitivity.
  apply H. apply R.
  (*pick_fresh Y. assert (Y \notin L). { autos. }
  eapply H0 in H3. 
  apply IHTyp. auto. 
  eapply trans. apply H. apply R. *)
Qed.

Fact typing_inv_abs_not_sup : ~(forall E S1 e1 T,
  typing E (trm_abs S1 e1) T -> 
  (forall U1 U2, R E Sup T (typ_arrow U1 U2) ->
     R E Sup U1 S1
  /\ exists S2, exists L, forall x, x \notin L ->
     typing (E & x ~: S1) (e1 open_ee_var x) S2 /\ R E Sub U2 S2)).
Proof. 
  intros contra. 
  assert (R empty Sup typ_int typ_top).
  { specialize (@contra empty typ_top (trm_nval 0) typ_top).
    assert (typing empty (trm_abs typ_top (trm_nval 0)) typ_top).
    { eapply typing_sub. apply typing_abs with (L:=\{}). introv X.
      assert (trm_nval 0 open_ee_var x = trm_nval 0).
      { unfold open_ee. simpl. reflexivity. }
      rewrite H. apply typing_nval.
      autos. apply STB1. auto. auto. auto.   }
    apply contra with (U1 := typ_int) (U2 := typ_top) in H.
    destruct H. apply H. apply STB2. auto. auto. 
  } 
  inversion H. Qed.

Lemma typing_inv_tabs : forall E e T m0 T0,
  typing E (trm_tabs m0 T0 e) T -> 
  forall U m T', R E Sub T (typ_all m T' U) ->
  exists S, exists L, forall X, X \notin L ->
     typing (E & X!:m <>: T0) (e open_te_var X) (S open_tt_var X)
     /\ R (E & X!:m <>: T') Sub (S open_tt_var X) (U open_tt_var X)
     /\ m = m0
     /\ R E (BindPosVariance Sub m) T0 T'.
Proof.
  introv Ty Sub. remember (trm_tabs m0 T0 e) as trm. 
  remember (typ_all m T' U) as ty.
  induction Ty; inversion Heqtrm; subst; clear H0.
  - exists T. inversion Sub. subst. exists (L \u L0).
    introv NI. apply notin_union_r in NI. destruct NI. split.
    apply* H. split; auto. apply_empty sub_narrowing. 
    apply STB1; auto. destruct m; simpl in H9; simpl; auto. 
  - apply* IHTy. eapply sub_transitivity. apply H. auto.  
Qed. 

(* ********************************************************************** *)
(** Preservation Result (20) *)

Lemma preservation_result : preservation.
Proof.
  introv Typ. gen e'. induction Typ; introv Red; 
   try solve [ inversion Red ].
  - inversion Red. apply* typing_nval.
    apply* typing_nsucc.
  - inversion Red; try solve [apply* typing_nind].
    subst. auto.
    subst. apply* typing_app.
  (* case: app *) 
  - inversions Red; try solve [ apply* typing_app ].
  destruct~ (typing_inv_abs Typ1 (U1:=T1) (U2:=T2)) as [P1 [S2 [L P2]]].
    apply refl with (E:=E). apply typing_regular in Typ1. destruct Typ1. 
    destruct H0. auto. auto.
    pick_fresh X. forwards~ K: (P2 X). destruct K.
     rewrite* (@subst_ee_intro X).
     apply_empty (@typing_through_subst_ee V).  
       apply* (@typing_sub S2). apply* sym2.
      apply_empty sub_weakening. auto. auto.
       inversion Typ1. subst. apply Typ2. subst. eapply typing_sub. apply Typ2. auto.
       auto.
  (* case: tapp *)
  -inversions Red; try solve [ apply* typing_tapp ].
   destruct (typing_inv_tabs Typ (U:=T1) (m:=m) (T':=Tb)). 
    apply* refl. (* apply typing_regular in Typ. 
 apply refl with (E:=E). destruct Typ. destruct H1. auto. *)
   apply typing_regular in Typ. destruct Typ.
    destruct H3.  inversion H5; subst. destruct H0. 
    pick_fresh X. forwards~ K : ( H0 X). destruct K.
   rewrite* (@subst_te_intro X). rewrite* (@subst_tt_intro X).
   replace E with (E & map (subst_tb X T2) empty).
   replace (E & X!: m <>: T) with (E & X!: m <>: T & empty) in H6.
    eapply typing_sub.
   apply (typing_through_subst_te H6) .
    destruct H7. destruct H8. eapply sub_transitivity.
    apply H. apply sym2. apply H10. 
   apply* (@sub_through_subst_tt m Sub Tb E empty X).
    destruct H7. rewrite concat_empty_r. auto.
   apply* wft_subst_tb.
   apply* concat_empty_r.
   rewrite map_empty. apply* concat_empty_r.
  (* case sub *)
  - apply* typing_sub.
Qed.

(* ********************************************************************** *)
(** * Progress *)

(* ********************************************************************** *)
(** Canonical Forms (14) *)


Lemma canonical_form_abs : forall t U1 U2,
  value t -> typing empty t (typ_arrow U1 U2) -> 
  exists V, exists e1, t = trm_abs V e1.
Proof.
  introv Val Typ. 
  gen_eq T: (typ_arrow U1 U2). intro st.
   assert (R empty Sub T (typ_arrow U1 U2)). 
{ rewrite st. 
    apply refl with (E:=empty); auto. subst. apply typing_regular in Typ. 
    destruct Typ. destruct H0. auto. }
  clear st. gen_eq E: (@empty typ).  gen U1 U2.
  induction Typ; introv EQT EQE; 
   try solve [ inversion Val | inversion EQT | eauto ].
    subst. assert (R E0 Sub S (typ_arrow U1 U2)). { 
    eapply sub_transitivity. apply H. apply EQT. }
   eapply IHTyp. apply Val. apply H1. reflexivity. Qed. 

Lemma canonical_form_nat : forall t,
  value t -> typing empty t typ_int -> 
  exists v, t = trm_nval v.
Proof.
  introv Val Typ. 
  gen_eq T: typ_int. intro st. assert (R empty Sub T typ_int). { rewrite* st.  }
  clear st. gen_eq E: (@empty typ).
  induction Typ; introv EQE; 
   try solve [ inversion Val | inversion EQE | eauto | inversion H ].
  eapply IHTyp. apply Val. eapply sub_transitivity. apply H0. apply H. apply EQE. Qed. 

Lemma tall_inv : forall E m m1 m2 T1 T2 M N,
R E m (typ_all m1 T1 M) (typ_all m2 T2 N) -> m1=m2 /\   
R E (BindPosVariance m2 m) T1 T2. 
Proof. introv TA. inductions TA. 
- destruct m; inversion x.
- destruct m; inversion x.
- split; auto. Qed. 

Lemma canonical_form_tabs : forall t T m U,
  value t -> typing empty t (typ_all m T U) -> 
  exists T' e1, t = trm_tabs m T' e1 /\ R empty (BindPosVariance m Sub) T' T.
Proof. 
  introv Val Typ. 
  gen_eq Ty: (typ_all m T U). intro st. 
  assert (R empty Sub Ty (typ_all m T U)). { rewrite* st.
  apply refl with (E:=empty); auto. subst. apply typing_regular in Typ. destruct Typ. 
   destruct H0. auto. }
  clear st. gen_eq E: (@empty typ).
  induction Typ; introv EQE; 
   try solve [ inversion Val | inversion EQE | eauto | inversion H ].
  apply tall_inv in H.
  exists Tk. exists e. split. destruct H. subst. auto.
  destruct H. auto. 
  apply* IHTyp. eapply sub_transitivity.
  apply H0. auto. Qed.
(* ********************************************************************** *)
(** Progress Result (16) *)

Lemma progress_result : progress.
Proof.
  introv Typ. gen_eq E: (@empty typ). lets Typ': Typ. remember empty as Env.
  induction Typ; intros EQ; subst.
  left*. 
  (* case: var *)
  false* binds_empty_inv.
  (* case: nval *)
  left*.
  (* case: succ *)
  right*. 
  destruct* IHTyp as [Val1 | R1].
    destruct (canonical_form_nat Val1 Typ) as [ v ].
    subst. exists (trm_nval (S v)). auto.
    destruct R1. exists (trm_nsucc x). auto.
  (* case : ind *)
  right*.
  {
    assert (value t1 \/ (exists e', red t1 e')). { auto. }
    assert (value t2 \/ (exists e', red t2 e')). { auto. }
    assert (value t3 \/ (exists e', red t3 e')). { auto. }
    clear IHTyp1 IHTyp2 IHTyp3. destruct H0; subst.
    - destruct (canonical_form_nat H0 Typ1) as [ v ].
     destruct H2. 
      + subst. destruct v. 
        * exists t2. apply red_ind_izero; auto.
        * exists (trm_app t3 (trm_nind (trm_nval v) t2 t3)). 
        apply red_ind_isucc. apply* typing_regular. auto.
      + destruct* H2.
    - destruct* H0.  }
  (* case: abs *) 
  left*. 
  (* case: app *)
  right. destruct* IHTyp1 as [Val1 | [e1' Rede1']].
    destruct* IHTyp2 as [Val2 | [e2' Rede2']].
      destruct (canonical_form_abs Val1 Typ1) as [S [e3 EQ]].
        subst. exists* (open_ee e3 e2).  
  left*.
  right. destruct* IHTyp as [Val | [e1 Red]].
      destruct (canonical_form_tabs Val Typ).
        destruct H0. destruct H0.
        subst. exists* (open_te x0 T2). 
  autos*.
Qed.

