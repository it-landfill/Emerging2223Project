%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:10
%%%-------------------------------------------------------------------
-module(gui).
-author("Balugani, Benetton, Crespan").

%% API
-export([start/2, window/5]).
-include_lib("wx/include/wx.hrl").

sleep(N) -> receive after N -> ok end.


window(H, W, Elem, Friends, PrevData)->
  % Funzione per la creazione e aggiornamento delle finestre.
  link(whereis(render)),
  case Elem of
    null ->   wx:new(),
      Frame = wxFrame:new(wx:null(), ?wxID_ANY, "Mappa"),
      Grid = wxGrid:new(Frame, 2, []),
      wxGrid:createGrid(Grid, H, W),
      wxFrame:show(Frame),
      Frame2 = wxFrame:new(wx:null(), ?wxID_ANY, "Amicizie"),
      FriendsNew = wxTextCtrl:new(Frame2, 1, [{value, ""},
        {style, ?wxDEFAULT bor ?wxTE_MULTILINE}]),
      wxFrame:show(Frame2);
    _ -> Grid = Elem, FriendsNew = Friends
  end,
  wxTextCtrl:clear(FriendsNew),
  wxGrid:clearGrid(Grid),
  % Reset dei colori della griglia
  maps:foreach(fun(_, V) -> wxGrid:setCellBackgroundColour(Grid, lists:nth(1, V), lists:nth(2,V), ?wxWHITE),
                            wxGrid:setCellBackgroundColour(Grid, lists:nth(3, V), lists:nth(4,V), ?wxWHITE) end, PrevData),
  render ! {data, self()},
  receive
    {ok, Data} ->
      maps:foreach(fun(K,V) ->
        wxGrid:setCellValue(Grid, lists:nth(1, V), lists:nth(2, V), io_lib:format("Auto ~p", [K])),
        case lists:nth(5, V) of
          1 ->  wxGrid:setCellBackgroundColour(Grid, lists:nth(1, V), lists:nth(2, V), ?wxGREEN);
          0 ->  wxGrid:setCellBackgroundColour(Grid, lists:nth(1, V), lists:nth(2, V), ?wxRED),
                wxGrid:setCellBackgroundColour(Grid, lists:nth(3, V), lists:nth(4, V), ?wxCYAN),
                wxGrid:setCellValue(Grid, lists:nth(3, V), lists:nth(4, V), io_lib:format("Target ~p", [K]))
        end,
        case length(lists:nth(6,V)) of
          0 -> wxTextCtrl:appendText(FriendsNew, io_lib:format("Amici di ~p: nessuno~n", [K]));
          _ -> wxTextCtrl:appendText(FriendsNew, io_lib:format("Amici di ~p: ~p~n", [K, lists:nth(6,V)]))
        end
                   end,
        Data),
      sleep(500),
      window(H, W, Grid, FriendsNew, Data);
    _ -> window(H, W, Grid, FriendsNew, PrevData)
  end.



start(H,W) ->
  % Avvia la gui, fornendo le dimensioni della griglia da visualizzare.
  spawn(?MODULE, window, [H, W, null, null, #{}]).