-module(transducers).

-export([compose/2, drop_while/1, filter/1, list/2, map/1, stateful/3]).

-type reduction(A) :: {ok, A} | {halt, A}.
-type reduction() :: reduction(any()).
-type step(A) :: fun ((reduction(), A) -> reduction()).
-type stateful_step(A) :: fun ((A, reduction(), any()) -> {A, reduction()}).
-type finalizer() :: fun ((reduction()) -> reduction()).
-type stateful_finalizer(A) :: fun ((A, reduction()) -> reduction()).
-type reducer(A) :: {step(A), finalizer()}.
-type reducer() :: reducer(any()).
-type transducer() :: fun ((reducer()) -> reducer()).

-type predicate() :: fun ((any()) -> boolean()).

-spec list(transducer(), list()) -> list().
list(Transduce, List) ->
  {Step, Finalize} = Transduce({
    fun ({Type, Acc}, Input) -> {Type, [Input | Acc]} end,
    fun ({Type, Acc}) -> {Type, lists:reverse(Acc)} end
  }),
  {_, Result} = fun
    Feed(Acc={halt, _}, _) -> Finalize(Acc);
    Feed(Acc, []) -> Finalize(Acc);
    Feed(Acc, [Input | Rest]) -> Feed(Step(Acc, Input), Rest)
  end({ok, []}, List),
  Result.

-spec compose(transducer(), transducer()) -> transducer().
compose(T1, T2) -> fun (R) -> T1(T2(R)) end.

-spec filter(predicate()) -> transducer().
filter(Pred) ->
  fun ({Step, Finalize}) ->
    {fun (Acc, Input) ->
       case Pred(Input) of
         true -> Step(Acc, Input);
         false -> Acc
       end
     end,
     Finalize}
  end.

-spec map(fun ((any()) -> any())) -> transducer().
map(F) ->
  fun ({Step, Finalize}) ->
    {fun (Acc, Input) ->
       Step(Acc, F(Input))
     end, Finalize}
  end.

-spec stateful(A, stateful_step(A), stateful_finalizer(A)) -> reducer().
stateful(InitialState, Step, Finalize) ->
  Self = self(),
  P = spawn_link(fun () ->
    fun Remember(State) ->
      receive
        {finalize, Reduction} -> Self ! {self(), Finalize(State, Reduction)};
        {step, Reduction, Input} ->
          {NewState, NewReduction} = Step(State, Reduction, Input),
          Self ! {self(), NewReduction},
          Remember(NewState)
      end
    end(InitialState)
  end),
  {fun (Reduction, Input) ->
     P ! {step, Reduction, Input},
     receive {P, NewReduction} -> NewReduction end
   end,
   fun (Reduction) ->
     P ! {finalize, Reduction},
     receive {P, NewReduction} -> NewReduction end
   end}.

-spec drop_while(predicate()) -> transducer().
drop_while(Pred) ->
  fun ({Step, Finalize}) ->
    stateful(Pred, fun (CurrentPred, Acc, Input) ->
      case CurrentPred(Input) of
        true -> {Pred, Acc};
        false -> {fun (_) -> false end, Step(Acc, Input)}
      end
    end, fun (_CurrentPred, Acc) -> Finalize(Acc) end)
  end.
