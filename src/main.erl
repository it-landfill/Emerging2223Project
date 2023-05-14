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
-export([launch/3, main/0]).

rebootCar(W, H) ->
  % Rimane in ascolto per crash dell'ambient e delle macchine.
  A_PID = whereis(ambient),
  receive
    {'DOWN', _, _, A_PID, _} ->
      io:format("SYS Ambient is too polluted. Killing everything..."),
      byebye;
    {'DOWN', _, _, C_PID, _} ->
      % io:format("SYS ~p: Car ~p died~n", [self(), C_PID]),
      spawn_monitor(car, main, [W, H]),
      rebootCar(W, H)
  end.


main() ->
  % Main dell'applicazione, crea una griglia 10*10 con 10 macchine.
  launch(10, 10, 10).

launch(Ncars, W, H) ->
  % Launcher del progetto. Avvia l'ambient, wellknown e state, per poi creare le macchine.
  io:format("SYS ~p: Launching main~n", [self()]),

  io:format("SYS ~p: Spawning ambient~n", [self()]),
  spawn(ambient, main, [W, H, self()]),
  receive
    {ambientOK} -> monitor(process, whereis(ambient))
  end,
  io:format("SYS ~p: Ambient PID: ~p~n", [self(), whereis(ambient)]),

  io:format("SYS ~p: Spawning render~n", [self()]),
  spawn(render, main, [W, H, self()]),
  receive
    {renderOK} -> ok
  end,
  io:format("SYS ~p: Render PID: ~p~n", [self(), whereis(render)]),

  io:format("SYS ~p: Spawning wellknown~n", [self()]),
  spawn(wellknown, main, [self()]),
  receive
    {wellknownOK} -> ok
  end,
  io:format("SYS ~p: Wellknown PID: ~p~n", [self(), whereis(wellknown)]),

  L = lists:seq(1, Ncars),

  % Nella nostra implementazione, sono le macchine a autodistruggersi dopo un dato lasso di tempo. Di conseguenza
  % non è necessario memorizzare alcuna lista di pid.
  lists:foreach(fun(_) ->
    io:format("SYS ~p: Spawning car~n", [self()]),
    {C_PID, _} = spawn_monitor(car, main, [W, H]),
    io:format("SYS ~p: Car PID: ~p~n", [self(), C_PID]) end,
    L),
  rebootCar(W, H),
  launch(Ncars, W, H)
.

