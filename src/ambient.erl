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
    receive
        {isFree, PID, X, Y, Ref} ->
            io:format("~p: Richiedo ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            PID ! {status, Ref, lists:member({X, Y, free}, A)},
            ambient(A);
        {park, PID, X, Y, Ref} ->
            io:format("~p: Parcheggio ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            % TODO: Implement deadlock solver
            case lists:member({X, Y, free}, A) of
                true ->
                    PID ! {parkOk, Ref},
                    ambient([{X, Y, Ref} | A -- [{X, Y, free}]]);
                false ->
                    % TODO: Gotta kill em all
                    PID ! {parkFailed, Ref},
                    ambient(A)
            end;
        {leave, PID, Ref} ->
            % Finds in the list A the touple that has as third element Ref.
            Elem = lists:keyfind(Ref, 3, A),
            case Elem of
                {X, Y, Ref} ->
                    io:format("~p: Libero ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
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
    A = [{R, C, free} || R <- lists:seq(1, W), C <- lists:seq(1, H)],
    PID = spawn(?MODULE, ambient, [A]),
    io:format("Creato ambiente con ~p ~n", [PID]),
    register(ambient, PID),
    PIDMain ! {ambientOK}.
