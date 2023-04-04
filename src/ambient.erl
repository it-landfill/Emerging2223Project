%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:08
%%%-------------------------------------------------------------------
-module(ambient).
-author("Balugani, Benetton, Crespan").

%% API
-export([main/2, ambient/1]).

ambient(A) ->
  receive

    _ ->
      io:format("Ambient not implemented~n"),
      ambient(A)
  end.
.

main(W, H) ->
  A = [ {R,C,free} || R<-lists:seq(1,W), C<-lists:seq(1, H) ],
  PID = spawn(?MODULE, ambient, [A]),
  register(ambient, PID)
.