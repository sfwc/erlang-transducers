-module(transducers_tests).

-import(transducers, [compose/2, drop_while/1, filter/1, list/2, map/1]).

-include_lib("eunit/include/eunit.hrl").


transducer_test_() -> [
  [?_assertEqual([1, 2, 3], list(fun (X) -> X end, [1, 2, 3]))],
  [?_assertEqual([4, 5],
                 list(filter(fun (X) -> X > 3 end), [1, 2, 3, 4, 5]))],
  [?_assertEqual([true, true, false],
                 list(map(fun (N) -> N < 3 end), [1, 2, 3]))],
  [?_assertEqual(["4", "5"],
                 list(compose(filter(fun (N) -> N > 3 end),
                              map(fun (N) -> integer_to_list(N) end)),
                      [1, 2, 3, 4, 5]))],
  [?_assertEqual([3, 4, 1],
                 list(drop_while(fun (X) -> X < 3 end), [1, 2, 3, 4, 1]))]
].
