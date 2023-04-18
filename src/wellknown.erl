%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:08
%%%-------------------------------------------------------------------
-module(wellknown).
-author("Balugani, Benetton, Crespan").

%% API
-export([main/1, wellknown/1]).

wellknown(L) ->
  receive
    {get, Ref, Pid} when length(L) > 1 ->
      Pid ! {ok, Ref, lists:nth(rand:uniform(length(L)), L)},
      wellknown(L);
    {get, Ref, Pid} when length(L) =:= 1 ->
      case lists:nth(L, 1) =:= Pid of
        true -> Pid ! {ko, Ref};
        false -> Pid ! {ok, Ref, lists:nth(1, L)}
      end,
      wellknown(L);
    {get, Ref, Pid} -> Pid ! {ko, Ref};
    {set, Ref, Pid} ->
      Pid ! {ok, Ref},
      wellknown([Pid | L])
  end
.

main(PIDMain) ->
  Pid = spawn(?MODULE, wellknown, [[]]),
  register(wellknown, Pid),
  PIDMain ! {wellknownOK}.
