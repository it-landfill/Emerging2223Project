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
-export([main/3, ambient/1]).

ambient(A) ->
    io:format("AMBIENT ~p: Status ~p ~n", [self(), A]),
    receive
        {isFree, PID, X, Y, Ref} ->
            io:format("AMBIENT ~p: Richiedo ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            PID ! {status, Ref, lists:member({X, Y, free}, A)},
            ambient(A);
        {park, PID, X, Y, Ref} ->
            io:format("AMBIENT ~p: Parcheggio ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            case lists:member({X, Y, free}, A) of
                true ->
                    PID ! {parkOk, Ref},
                    ambient([{X, Y, Ref} | A -- [{X, Y, free}]]);
                false ->
                    io:format("AMBIENT ~p: Parcheggio ~p (~p,~p) | ~p FALLITO ~n", [self(), PID, X, Y, Ref]),
                    PID ! {parkFailed, Ref},
                    ambient(A)
            end;
        {leave, PID, Ref} ->
            % Finds in the list A the touple that has as third element Ref.
            Elem = lists:keyfind(Ref, 3, A),
            case Elem of
                {X, Y, Ref} ->
                    io:format("AMBIENT ~p: Libero ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
                    PID ! {leaveOk, Ref},
                    ambient([{X, Y, free} | A -- [Elem]]);
                false ->
                    % How did you get here?
                    % TODO: Gotta kill em all
                    PID ! {leaveFailed, Ref}
            end,
            ambient(A)
    end.

main(W, H, PIDMain) ->
    A = [{R, C, free} || R <- lists:seq(0, W-1), C <- lists:seq(0, H-1)],
    PID = spawn(?MODULE, ambient, [A]),
    io:format("SYS Creato ambiente con ~p ~n", [PID]),
    register(ambient, PID),
    PIDMain ! {ambientOK}.
