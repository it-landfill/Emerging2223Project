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
-export([main/2, memory/3, state/5, detect/8, friendship/2]).

sleep(N) ->
  receive
  after N -> ok
  end.

% Ask my friends for their friend list and use it to find new friends
findFriends(_, []) ->
  [];
findFriends(PIDS, [H | T]) ->
  Ref = make_ref(),
  % FIXME: H is a state PID!!!
  H ! {getFriends, self(), PIDS, Ref},
  receive
    {myFriends, L, Ref} ->
      [L | findFriends(PIDS, T)]
  after 2000 ->
    io:format("~p: Friend ~p might be dead...~n", [self(), H]),
    findFriends(PIDS, T)
  end.

% Pick N random friends from a list
pickFriends(_, 0) ->
  [];
pickFriends([], _) ->
  [];
pickFriends(L, N) ->
  Rand = lists:nth(rand:uniform(length(L)), L),
  [Rand | pickFriends([El || El <- L, El =/= Rand], N - 1)].

% Ping my friends and check if they are alive
pingFriends([]) ->
  [];
pingFriends([H | T]) ->
  Ref = make_ref(),
  H ! {ping, self(), Ref},
  receive
    {pong, Ref} ->
      [H | pingFriends(T)]
  after 2000 ->
    io:format("~p: Friend ~p might be dead...~n", [self(), H]),
    pingFriends(T)
  end.

% Case I have no friends
friendship(PIDM, L) when length(L) =:= 0 ->
  % Chiama WellKnown e fatti passare un contatto
  RefD = make_ref(),
  PIDM ! {g_pids, self(), RefD},
  receive
    {get_pids, PIDS, RefD} ->
      Ref2 = make_ref(),
      wellknown ! {getFriends, self(), PIDS, Ref2},
      receive
        {myFriends, PIDLIST, Ref2} ->
          List2 = [El || El <- PIDLIST, El =/= PIDS],
          case List2 =:= [] of
            true ->
              % Non ho ricevuto nessun contatto, riprovo tra 2 secondi

              % TODO: Random delay?
              sleep(2000),
              friendship(PIDM, L);
            false ->
              % Ho ricevuto un contatto, lo aggiungo alla lista
              friendship(PIDM, [lists:nth(rand:uniform(length(List2)), List2)])
          end
      end
  end;
% Case I have less than 5 friends
friendship(PIDM, L) when length(L) < 5, length(L) > 0 ->
  RefD = make_ref(),
  PIDM ! {g_pids, self(), RefD},
  receive
    {get_pids, PIDS, RefD} ->
      PIDLIST = lists:flatten(findFriends(PIDS, L)),
      List2 = [El || El <- PIDLIST, El =/= PIDS],
      Needed = 5 - length(L),
      case length(List2) =:= Needed of
        true ->
          friendship(PIDM, [L, List2]);
        false ->
          case length(List2) =:= 0 of
            true ->
              % Non ho ricevuto nessun contatto, riprovo tra 2 secondi
              sleep(2000),
              friendship(PIDM, L);
            false ->
              % Prendi n elementi randomici dalla list
              NewFriends = lists:flatten([L, pickFriends(List2, Needed)]),
              %TODO: Check if I already have them
              %TODO: If they are less than Needed, resort to WellKnown
              friendship(PIDM, NewFriends)
          end
      end
  end;
% Case I already have 5 friends
friendship(PIDM, L) ->
  sleep(2000),
  friendship(PIDM, lists:flatten(pingFriends(L))).

state(PIDM, PIDD, L, XG, YG) when PIDD =:= none ->
  RefD = make_ref(),
  PIDM ! {g_pidd, self(), RefD},
  receive
    {get_pidd, PIDD1, RefD} ->
      state(PIDM, PIDD1, L, XG, YG);
    _ = Msg ->
      io:format("~p: Ricevuto messaggio non previsto: ~p~n", [self(), Msg]),
      self() ! Msg,
      % TODO: Is this tail recursion?
      state(PIDM, PIDD, L, XG, YG)
  end;


state(PIDM, PIDD, L, XG, YG) ->
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

  % ---- Resolve PIDD ----


  receive
    {status, X, Y, IsFree} ->
      case lists:member({X, Y, IsFree}, L) of
        true ->
          % No news, we already new that...
          state(PIDM, PIDD, L, XG, YG);
        false ->
          % New news, we need to gossip
          % ---- Check if message concerns goal ----
          case {X =:= XG, Y =:= YG, IsFree} of
            {true, true, false} ->
              % ---- Goal is now occupied ----
              PIDD ! {newGoal};
            _ ->
              pass
          end,

          % TODO: gossip
          state(
            PIDM,
            PIDD,
            [
              {X, Y, isFree} | [El || {Xi, Yi, _} = El <- L, Xi =/= X, Yi =/= Y]
            ],
            XG,
            YG
          )
      end;
    {newGoal, X, Y} ->
      state(PIDM, PIDD, L, X, Y);
    _ ->
      io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
      state(PIDM, PIDD, L, XG, YG)
  end.

move(X, Y, W, H, XG, YG) ->
  % ---- Move ----
  % TODO: Pacman effect
  case {X =:= XG, Y =:= YG} of
    {true, true} ->
      io:format("~p: Arrivato al goal~n", [self()]),
      {X, Y};
    {false, false} ->
      case rand:uniform(2) of
        1 ->
          case Y > YG of
            true ->
              {X, (Y - 1) rem H};
            false ->
              {X, (Y + 1) rem H}
          end;
        2 ->
          case X > XG of
            true ->
              {(X - 1) rem W, Y};
            false ->
              {(X + 1) rem W, Y}
          end
      end;
    {true, false} ->
      case Y > YG of
        true ->
          {X, (Y - 1) rem H};
        false ->
          {X, (Y + 1) rem H}
      end;
    {false, true} ->
      case X > XG of
        true ->
          {(X - 1) rem W, Y};
        false ->
          {(X + 1) rem W, Y}
      end
  end.

detect(PIDM, PIDS, X, Y, W, H, XG, YG) when PIDS =:= none ->
  RefS = make_ref(),
  PIDM ! {g_pids, self(), RefS},
  receive
    {get_pids, PIDS1, RefS} ->
      detect(PIDM, PIDS1, X, Y, W, H, XG, YG);
    _ = Msg ->
      io:format("~p: Ricevuto messaggio non previsto in risoluzione di PIDS: ~p~n", [self(), Msg]),
      self() ! Msg,
      % TODO: Is this tail recursion?
      detect(PIDM, PIDS, X, Y, W, H, XG, YG)
  end;

detect(PIDM, PIDS, X, Y, W, H, XG, YG) ->
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

  % ---- Communicate ----
  Ref = make_ref(),
  ambient ! {isFree, self(), X, Y, Ref},
  receive
    {status, Ref, IsFree} = Ajeje ->
      io:format("~p: Resp ~p~n", [self(), Ajeje]),
      PIDS ! {status, X, Y, IsFree},

      case {X =:= XG, Y =:= YG, IsFree} of
        % Sono al goal ed è libero
        {true, true, true} ->
          RefP = make_ref(),
          ambient ! {park, self(), X, Y, RefP},
          receive
          % Parcheggio riuscito
            {parkOk, RefP} ->
              io:format("~p: Parcheggio riuscito~n", [self()]),
              render ! {parked, self(), X, Y, 1}, % FIXME: CRASH HERE
              sleep((rand:uniform(4) + 1) * 1000);
          % Parcheggio fallito
            {parkFailed, RefP} ->
              io:format("~p: Parcheggio fallito~n", [self()])
          % TODO: Time to die
          end,
          ambient ! {leave, self(), RefP},
          receive
          % Parcheggio riuscito
            {leaveOk, RefP} ->
              io:format("~p: Parcheggio liberato con successo~n", [self()]),
              render ! {parked, self(), X, Y, 0};
          % Parcheggio fallito
            {leaveFailed, RefP} ->
              io:format("~p: Errore in liberamento del parcheggio~n", [self()])
          % TODO: Time to die
          end,
          self() ! {newGoal},
          detect(PIDM, PIDS, X, Y, W, H, XG, YG);
        _ ->
          sleep(2000),
          {NX, NY} = move(X, Y, W, H, XG, YG),
          io:format("~p: Spostamento in: (~p,~p)~n", [self(), NX, NY]),
          render ! {position, self(), NX, NY},
          detect(PIDM, PIDS, NX, NY, W, H, XG, YG)
      end;
    {newGoal} ->
      {NXG, NYG} = newCoordinates(W, H),
      io:format("~p: Nuovo obiettivo: (~p,~p)~n", [self(), NXG, NYG]),
      % TODO: Should I check if newGoal is free?
      PIDS ! {newGoal, NXG, NYG},
      render ! {target, self(), NXG, NYG},
      % Flush inbox
      receive
        {status, _, _} = MsgFlush ->
          io:format("~p: Flush msg ~p~n", [self(), MsgFlush])
      end,
      detect(PIDM, PIDS, X, Y, W, H, NXG, NYG);
    _ = Msg1 ->
      io:format("~p: Ricevuto messaggio non previsto: ~p~n", [self(), Msg1]),
      detect(PIDM, PIDS, X, Y, W, H, XG, YG)
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
      Pid ! {get_pids, PIDS, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidd, Pid, Ref} ->
      io:format("~p: Ricevuto messaggio g_pidd ~p~n", [self(), PIDD]),
      Pid ! {get_pidd, PIDD, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidf, Pid, Ref} ->
      io:format("~p: Ricevuto messaggio g_pidf ~p~n", [self(), PIDF]),
      Pid ! {get_pidf, PIDF, Ref},
      memory(PIDS, PIDD, PIDF)
  end.

newCoordinates(W, H) ->
  {rand:uniform(W) - 1, rand:uniform(H) - 1}.

main(W, H) ->
  {X, Y} = newCoordinates(W, H),
  {XG, YG} = newCoordinates(W, H),
  io:format("~p: Coordinate di partenza: ~p,~p~n", [self(), X, Y]),
  io:format("~p: Target: ~p,~p~n", [self(), XG, YG]),

  % Spawn "DNS" actor
  PIDM = spawn(?MODULE, memory, [none, none, none]),

  % Spawn actors
  PIDS = spawn(?MODULE, state, [PIDM, none, [], XG, YG]),
  PIDM ! {s_pids, PIDS},
  PIDD = spawn(?MODULE, detect, [PIDM, none, X, Y, W, H, XG, YG]),
  PIDM ! {s_pidd, PIDD},
  %spawn(?MODULE, friendship, []),
  PIDF = none,
  %PIDM ! {s_pidf, PIDF},
  render ! {position, PIDD, X, Y},
  render ! {target, PIDD, XG, YG},
  io:format("~p: Generato detect(~p), state(~p), friendship(~p), memory(~p) ~n", [
    self(), PIDD, PIDS, PIDF, PIDM
  ]).
