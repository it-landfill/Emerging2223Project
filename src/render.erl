%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:09
%%%-------------------------------------------------------------------
-module(render).
-author("Balugani, Benetton, Crespan").

%% API
-export([main/0, main/3, render/1, logger/0]).

sleep(N) -> receive after N -> ok end.

render(Data) ->
  % Server render, raccoglie i dati provenienti da automobili e li mantiene in memoria, per poi restituirli
  % agli attori di visualizzazione (logger oppure gui). E' linkato a ambient in quanto elemento vitale del sistema.
  link(whereis(ambient)),
  receive
    {position, PID, X, Y} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [X, Y, 0, 0, 0, []], Data),
          monitor(process, PID);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [X, Y, lists:nth(3, Tmp),
            lists:nth(4, Tmp), lists:nth(5, Tmp), lists:nth(6, Tmp)], Data)
      end,
      render(NData);
    {target, PID, X, Y} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, X, Y, 0, []], Data),
          monitor(process, PID);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            X, Y, lists:nth(5, Tmp), lists:nth(6, Tmp)], Data)
      end,
      render(NData);
    {parked, PID, X, Y, IsParked} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, X, Y, IsParked, []], Data),
          monitor(process, PID);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            lists:nth(3, Tmp), lists:nth(4, Tmp), IsParked, lists:nth(6, Tmp)], Data)
      end,
      render(NData);
    {friends, PID, PIDLIST} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, 0, 0, 0, PIDLIST], Data),
          monitor(process, PID);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            lists:nth(3, Tmp), lists:nth(4, Tmp), lists:nth(5, Tmp), PIDLIST], Data)
      end,
      render(NData);
    {data, PID} ->
      % Chiamata per la lettura da parte degli attori di visualizzazione dei dati di render
      PID ! {ok, Data},
      render(Data);
    {'DOWN', _, _, PPID, _} ->
      % Nel caso in cui un attore muoia, i suoi dati vengono rimossi.
      render(maps:remove(PPID, Data))
  end.

logger() ->
  % Logger base che restituisce i dati di render.
  sleep(10000),
  io:format("Updating...~n"),
  render ! {data, self()},
  receive
    {ok, Data} ->
      io:format("~p~n", [Data]),
      logger()
  end.

main() ->
  % Main per lo spawn del logger
  PID = spawn(?MODULE, render, [#{}]),
  io:format("Creato render con ~p ~n", [PID]),
  register(render, PID),
  spawn(?MODULE, logger, []).

main(W, H, PIDMain) ->
  % Main per lo spawn della gui
  PID = spawn(?MODULE, render, [#{}]),
  io:format("SYS Creato render con ~p~n", [PID]),
  register(render, PID),
  GPID = spawn(gui, start, [W, H]),
  io:format("SYS Creato widget con ~p~n", [GPID]),
  PIDMain ! {renderOK}
.