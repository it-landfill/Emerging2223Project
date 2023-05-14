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
    % Server ambient.
    receive
        {isFree, PID, X, Y, Ref} ->
            % io:format("AMBIENT ~p: Richiedo ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            PID ! {status, Ref, lists:member({X, Y, free, none, none}, A)},
            ambient(A);
        {park, PID, X, Y, Ref} ->
            % io:format("AMBIENT ~p: Parcheggio ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
            case lists:member({X, Y, free, none, none}, A) of
                true ->
                    PID ! {parkOk, Ref},
                    MRef = monitor(process, PID),
                    ambient([{X, Y, Ref, MRef, PID} | A -- [{X, Y, free, none, none}]]);
                false ->
                    io:format("AMBIENT ~p: Parcheggio ~p (~p,~p) | ~p FALLITO ~n", [self(), PID, X, Y, Ref]),
                    PID ! {parkFailed, Ref},
                    ambient(A)
            end;
        {leave, PID, Ref} ->
            % Trova nella lista A l'elemento che ha la Ref desiderata.
            Elem = lists:keyfind(Ref, 3, A),
            case Elem of
                {X, Y, Ref, MRef, _} ->
                    % io:format("AMBIENT ~p: Libero ~p (~p,~p) | ~p~n", [self(), PID, X, Y, Ref]),
                    PID ! {leaveOk, Ref},
                    demonitor(MRef),
                    ambient([{X, Y, free, none, none} | A -- [Elem]]);
                false ->
                    % Questo codice non dovrebbe essere raggiungibile.
                    PID ! {leaveFailed, Ref}
            end,
            ambient(A);
        {'DOWN', MRef, _, PID, _} ->
            Elem = lists:keyfind(PID, 5, A),
            io:format("AMBIENT ~p: Auto ~p e' morta, libero il posteggio... ~n",[self(), PID]),
            % Is this proper?
            case Elem of
                {X, Y, _, MRef, _} ->
                    ambient([{X, Y, free, none, none} | A -- [Elem]]);
                false ->
                    % Questo codice non dovrebbe essere raggiungibile.
                    % io:format("AMBIENT ~p: Auto ~p è morta, ma il posteggio era gia' stato liberato...? ~p ~p~n",[self(), PID, Elem, A]),
                    ambient(A)
            end
    end.

main(W, H, PIDMain) ->
    A = [{R, C, free, none, none} || R <- lists:seq(0, W-1), C <- lists:seq(0, H-1)],
    PID = spawn(?MODULE, ambient, [A]),
    io:format("SYS Creato ambiente con ~p ~n", [PID]),
    register(ambient, PID),
    PIDMain ! {ambientOK}.
