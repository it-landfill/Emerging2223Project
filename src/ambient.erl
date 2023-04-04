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
    {isFree, PID, X, Y, Ref} ->
      io:format("~p: Richiedo ~p ~p~n", [PID,X,Y]),
      PID ! {status, Ref, lists:member({X,Y,free},A)},
      ambient(A);
    {park, PID, X, Y, Ref} ->
      io:format("~p: Parcheggio ~p ~p~n", [PID,X,Y]),
      % TODO: Implement deadlock solver
      case lists:member({X,Y,free},A) of
        true ->
          PID ! {parkok, Ref},
          ambient([{X,Y,Ref} | A -- [{X, Y, free}]]);
        false ->
          % TODO: Gotta kill em all
          PID ! {parkfailed, Ref},
          ambient(A)
      end;
    {leave, PID, X, Y, Ref} ->
      io:format("~p: Libero ~p ~p~n", [PID,X,Y]),
      case lists:member({X,Y,Ref},A) of
        true ->
          PID ! {leaveok, Ref},
          ambient([{X,Y,free} | A -- [{X, Y, Ref}]]);
        false ->
          % How did you get here?
          % TODO: Gotta kill em all
          PID ! {leavefailed, Ref}
      end,
      ambient(A)
  end.

main(W, H) ->
  A = [ {R,C,free} || R<-lists:seq(1,W), C<-lists:seq(1, H) ],
  PID = spawn(?MODULE, ambient, [A]),
  io:format("Creato ambiente con ~p ~n", [PID]),
  register(ambient, PID)
.