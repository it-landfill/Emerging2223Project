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
-export([launch/0]).

launch() ->
    io:format("~p: Launching main~n", [self()]),
    W = 10,
    H = 10,

    io:format("~p: Spawning render~n", [self()]),
    R_PID = spawn(render, main, [W, H, self()]),
    receive
        {renderOK} -> ok
    end,
    io:format("~p: Render PID: ~p~n", [self(), R_PID]),

    io:format("~p: Spawning ambient~n", [self()]),
    A_PID = spawn(ambient, main, [W, H, self()]),
    receive
        {ambientOK} -> ok
    end,
    io:format("~p: Ambient PID: ~p~n", [self(), A_PID]),

    io:format("~p: Spawning wellknown~n", [self()]),
    W_PID = spawn(wellknown, main, [self()]),
    receive
        {wellknownOK} -> ok
    end,
    io:format("~p: Wellknown PID: ~p~n", [self(), W_PID]),

    io:format("~p: Spawning car~n", [self()]),
    C_PID = spawn(car, main, [W, H]),
    io:format("~p: Car PID: ~p~n", [self(), C_PID]),

    io:format("~p: Spawning car~n", [self()]),
    C2_PID = spawn(car, main, [W, H]),
    io:format("~p: Car PID: ~p~n", [self(), C2_PID]).
