%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:09
%%%-------------------------------------------------------------------
-module(car).
-author("Balugani, Benetton, Crespan").

%% API
-export([main/2, memory/3, state/2, detect/7]).

sleep(N) -> receive after N -> ok end.

friendship() ->
  pass
%TODO: implement friendship
% mantenere 5 attori nella lista di attori, integrandone di nuovi nel caso in cui il numero scenda.
.

state(PIDM, L) ->
  % TODO: implement state
  % mantenere il modello interno dell'ambiente e le coordinate del posteggio obiettivo.
  % registra per ogni cella l'ultima informazione giunta in suo possesso (posteggio libero/occupato/nessuna informazione)
  % propaga le nuove informazione ottenute agli amici (protocollo di gossiping).
  % cambia il posteggio obiettivo quando necessario (es. quando scopre che il posteggio è ora occupato).

  % Riceve dal detect lo stato della cella attuale
  % Inoltra lo stato a friendship
  % Riceve dal friendship gli stati delle altre celle
  % Aggiorna lo stato interno
  %% Aggiorna il goal (eventualmente)
  %% Comunica il nuovo goal a detect (eventualmente)

  io:format("~p: State~n", [self()]),
  RefD = make_ref(),
  PIDM ! {g_pidd, self(), RefD},
  receive {ok, PIDD, RefD} ->
    receive
      {status, X, Y, IsFree} ->
        case lists:member({X, Y, IsFree}, L) of
          true ->
            % No news, we already new that...
            state(PIDM, L);
          false ->
            % New news, we need to gossip
            % TODO: gossip
            state(PIDM, [{X, Y, isFree} | [El || {Xi, Yi, _} = El <- L, Xi =/= X, Yi =/= Y]])
        end;
      _ ->
        io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
        state(PIDM, L)
    end
  end.




detect(PIDM, X, Y, W, H, XG, YG) ->
  % TODO: implement detect
  % muovere l'automobile sulla scacchiera
  % interagendo con l'attore "ambient" per fare sensing dello stato di occupazione dei posteggi.

  % Si muove di una cella verso l'obiettivo
  %% Si muove al fine di ridurre la coordinata con distanza maggiore. se pari random
  % Chiede ad ambient lo stato della cella attuale
  %% ambient ! {isFree, self(), X, Y, Ref}
  % Inoltra la risposta a state
  % Dorme 2 secondi

  io:format("~p: Detect~n", [self()]),

  case X =:= XG of % TODO: Correct logic should decrease the longest coordinate and should decide if increase or decrease to minimize
    true ->
      case Y =:= YG of
        true ->
          io:format("~p: Arrivato al goal~n", [self()]), %%TODO: Park
          NX = X,
          NY = Y;
        false ->
          NY = (Y + 1) rem H,
          NX = X
      end;
    false ->
      NY = Y,
      NX = (X + 1) rem W
  end,

  io:format("~p: Spostamento in ~p, ~p~n", [self(), NX, NY]),

  RefS = make_ref(),
  PIDM ! {g_pids, self(), RefS},
  receive
    {ok, PIDS, RefS} ->
      Ref = make_ref(),
      ambient ! {isFree, self(), X, Y, Ref},
      receive
        {status, Ref, IsFree} ->
          PIDS ! {status, X, Y, IsFree},
          sleep(2000),
          detect(PIDM, NX, NY, W, H, XG, YG);
        _ ->
          io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
          detect(PIDM, X, Y, W, H, XG, YG)
      end;
    _ = Msg ->
      io:format("~p: Ricevuto messaggio non previsto: ~p~n", [self(), Msg]),
      detect(PIDM, X, Y, W, H, XG, YG)
  end.

memory(PIDS, PIDD, PIDF) ->
  % Memorizza e mantiene nel suo stato i PID di State, Detect e Friendship, rendendoli
  % disponibili a tutti i componenti del veicolo.
  receive
    {s_pids, Value} ->
      io:format("~p: Ricevuto messaggio s_pids ~p~n", [self(), Value]),
      memory(Value, PIDD, PIDF);
    {s_pidd, Value} ->
      io:format("~p: Ricevuto messaggio s_pidd ~p~n", [self(), Value]),
      memory(PIDS, Value, PIDF);
    {s_pidf, Value} ->
      io:format("~p: Ricevuto messaggio s_pidf ~p~n", [self(), Value]),
      memory(PIDS, PIDD, Value);
    {g_pids, Pid, Ref} ->
      io:format("~p: Ricevuto messaggio g_pids ~p~n", [self(), PIDS]),
      Pid ! {ok, PIDS, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidd, Pid, Ref} ->
      io:format("~p: Ricevuto messaggio g_pidd ~p~n", [self(), PIDD]),
      Pid ! {ok, PIDD, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidf, Pid, Ref} ->
      io:format("~p: Ricevuto messaggio g_pidf ~p~n", [self(), PIDF]),
      Pid ! {ok, PIDF, Ref},
      memory(PIDS, PIDD, PIDF)
  end.


main(W, H) ->
  X = rand:uniform(W),
  Y = rand:uniform(H),
  % TODO: Define goal parking
  XG = 1,
  YG = 1,
  % TODO: Check if park is free
  io:format("~p: Coordinate di partenza: ~p,~p~n", [self(), X, Y]),
  io:format("~p: Target: ~p,~p~n", [self(), XG, YG]),

  % Spawn "DNS" actor
  PIDM = spawn(?MODULE, memory, [none, none, none]),

  % Spawn actors
  PIDS = spawn(?MODULE, state, [PIDM, []]),
  PIDM ! {s_pids, PIDS},
  PIDD = spawn(?MODULE, detect, [PIDM, X, Y, W, H, XG, YG]),
  PIDM ! {s_pidd, PIDD},
  io:format("~p: Generato detect(~p) e state(~p) ~n", [self(), PIDD, PIDS])
% PIDF = spawn(?MODULE, friendship, []),
% PIDM ! {s_pidf, PIDF},
.
