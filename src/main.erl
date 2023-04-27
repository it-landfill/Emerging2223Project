%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:10
%%%-------------------------------------------------------------------
-module(main).
-author("Balugani, Benetton, Crespan").

%% API
-export([launch/3]).

launch(Ncars, W, H) ->
    io:format("SYS ~p: Launching main~n", [self()]),

    io:format("SYS ~p: Spawning render~n", [self()]),
    R_PID = spawn(render, main, [W, H, self()]),
    receive
        {renderOK} -> ok
    end,
    io:format("SYS ~p: Render PID: ~p~n", [self(), R_PID]),

    io:format("SYS ~p: Spawning ambient~n", [self()]),
    A_PID = spawn(ambient, main, [W, H, self()]),
    receive
        {ambientOK} -> ok
    end,
    io:format("SYS ~p: Ambient PID: ~p~n", [self(), A_PID]),

    io:format("SYS ~p: Spawning wellknown~n", [self()]),
    W_PID = spawn(wellknown, main, [self()]),
    receive
        {wellknownOK} -> ok
    end,
    io:format("SYS ~p: Wellknown PID: ~p~n", [self(), W_PID]),

    L = lists:seq(1, Ncars),

    lists:foreach(fun(_) ->
        io:format("SYS ~p: Spawning car~n", [self()]),
        C_PID = spawn(car, main, [W, H]),
        io:format("SYS ~p: Car PID: ~p~n", [self(), C_PID]) end,
        L).
