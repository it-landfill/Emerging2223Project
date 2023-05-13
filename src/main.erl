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
-export([launch/3, launch/0]).

rebootCar(W, H) ->
  A_PID = whereis(ambient),
  receive
    {'DOWN', _, _, A_PID, _}->
      io:format("SYS Ambient is too polluted. Killing everything..."),
      byebye;
    {'DOWN', _, _, C_PID, _} ->
      % io:format("SYS ~p: Car ~p died~n", [self(), C_PID]),
      {C_PID_REBOOT, CarRef} = spawn_monitor(car, main, [W, H]),
      rebootCar(W, H)
  end.


launch() ->
  launch(10, 10, 10).

launch(Ncars, W, H) ->
  io:format("SYS ~p: Launching main~n", [self()]),

  io:format("SYS ~p: Spawning ambient~n", [self()]),
  _ = spawn(ambient, main, [W, H, self()]),
  receive
    {ambientOK} -> monitor(process, whereis(ambient))
  end,
  io:format("SYS ~p: Ambient PID: ~p~n", [self(), ambient]),

  io:format("SYS ~p: Spawning render~n", [self()]),
  R_PID = spawn(render, main, [W, H, self()]),
  receive
    {renderOK} -> ok
  end,
  io:format("SYS ~p: Render PID: ~p~n", [self(), R_PID]),

  io:format("SYS ~p: Spawning wellknown~n", [self()]),
  W_PID = spawn(wellknown, main, [self()]),
  receive
    {wellknownOK} -> ok
  end,
  io:format("SYS ~p: Wellknown PID: ~p~n", [self(), W_PID]),

  L = lists:seq(1, Ncars),

  lists:foreach(fun(_) ->
    io:format("SYS ~p: Spawning car~n", [self()]),
    {C_PID, CarRef} = spawn_monitor(car, main, [W, H]),
    io:format("SYS ~p: Car PID: ~p~n", [self(), C_PID]) end,
    L),
  % Nel caso in cui sia necessario che sia il main stesso a uccidere le macchinine, basta tenere conto delle macchine
  % che vengono spawnate, metterle in una lista e passarla a reboot car. Questa lista andrà aggiornata per mantenere
  % l'esatta lista delle macchinine attive, in modo da poter inviare loro segnali di uccisione quando necessario.
  rebootCar(W, H),
  launch(Ncars, W, H)
.

