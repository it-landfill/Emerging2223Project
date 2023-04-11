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
-export([main/0, main/2, render/1, logger/0]).

sleep(N) -> receive after N -> ok end.

render(Data) ->
  receive
    {position, PID, X, Y} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [X, Y, 0, 0, 0, []], Data);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [X, Y, lists:nth(3, Tmp),
            lists:nth(4, Tmp), lists:nth(5, Tmp), lists:nth(6, Tmp)], Data)
      end,
      PID ! ok,
      render(NData);
    {target, PID, X, Y} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, X, Y, 0, []], Data);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            X, Y, lists:nth(5, Tmp), lists:nth(6, Tmp)], Data)
      end,
      PID ! ok,
      render(NData);
    {parked, PID, X, Y, IsParked} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, X, Y, IsParked, []], Data);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            lists:nth(3, Tmp), lists:nth(4, Tmp), IsParked, lists:nth(6, Tmp)], Data)
      end,
      PID ! ok,
      render(NData);
    {friends, PID, PIDLIST} ->
      case maps:find(PID, Data) of
        error ->
          NData = maps:put(PID, [0, 0, 0, 0, 0, PIDLIST], Data);
        _ ->
          Tmp = maps:get(PID, Data),
          NData = maps:update(PID, [lists:nth(1, Tmp), lists:nth(2, Tmp),
            lists:nth(3, Tmp), lists:nth(4, Tmp), lists:nth(5, Tmp), PIDLIST], Data)
      end,
      PID ! ok,
      render(NData);
    {data, PID} ->
      % This call will be made by the window agent periodically
      PID ! {ok, Data},
      render(Data)
  end.

logger() ->
  sleep(10000),
  io:format("Updating...~n"),
  render ! {data, self()},
  receive
    {ok, Data} ->
      io:format("~p~n", [Data]),
      logger()
  end.

main() ->
  PID = spawn(?MODULE, render, [#{}]),
  io:format("Creato render con ~p ~n", [PID]),
  register(render, PID).
  %spawn(?MODULE, logger, []).

main(W, H) ->
  PID = spawn(?MODULE, render, [#{}]),
  io:format("Creato render con ~p ~n", [PID]),
  register(render, PID),
  spawn(gui, start, [W, H]),
  io:format("Creato widget con ~n").