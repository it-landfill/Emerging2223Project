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
-export([main/2, memory/3, state/5, detect/8, friendship/3]).

sleep(N) ->
  receive
  after N -> ok
  end.

% Ask my friends for their friend list and use it to find new friends
findFriends(_, []) ->
  [];
findFriends(PIDS, [{PIDF, _}=El | T]) ->
  Ref = make_ref(),
  % FIXME: H is a state PID!!!!!!!!!!!
  PIDF ! {getFriends, self(), PIDS, Ref},
  receive
    {myFriends, L, Ref} ->
      [L | findFriends(PIDS, T)]
  after 2000 ->
    io:format("~p: Friend ~p might be dead...~n", [self(), PIDF]),
    %findFriends(PIDS, T)
    [El | findFriends(PIDS, T)]
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
pingFriends([{PIDF, _} | T]) ->
  Ref = make_ref(),
  PIDF ! {ping, self(), Ref},
  receive
    {pong, Ref} ->
      [PIDF | pingFriends(T)]
  after 2000 ->
    io:format("~p: Friend ~p might be dead...~n", [self(), PIDF]),
    pingFriends(T)
  end.

% Case I have no friends
friendship(PIDM, none, L) ->
  io:format("~p: Non ha amici e non conosce PIDS~n", [self()]),
  RefM = make_ref(),
  PIDM ! {g_pids, self(), RefM},
  receive
    {get_pids, PIDS, RefM} ->
    friendship(PIDM, PIDS, L)
  end;

friendship(PIDM, PIDS, L) when length(L) =:= 0 ->
  % Chiama WellKnown e fatti passare un contatto
  io:format("~p: Ha come amici ~p ~n", [self(), L]),
  Ref = make_ref(),
  wellknown ! {getFriends, self(), PIDS, Ref},
  receive
    {myFriends, PIDLIST, Ref} ->
      io:format("~p: ricevo da WK ~p ~n", [self(), PIDLIST]),
      List2 = [El || {PIDF, PIDSoth}=El <- PIDLIST, PIDSoth =/= PIDS],
      case List2 =:= [] of
        true ->
          io:format("~p: non ho ricevuto nessuna risposta ~n", [self()]),
          % Non ho ricevuto nessun contatto, riprovo tra 2 secondi
          sleep(2000),
          friendship(PIDM, PIDS, L);
        false ->
          io:format("~p: Ha ricevuto risposta da WK~n", [self()]),
          % Ho ricevuto un contatto, lo aggiungo alla lista
          friendship(PIDM, PIDS, [lists:nth(rand:uniform(length(List2)), List2)])
      end
  end;
% Case I have less than 5 friends
friendship(PIDM, PIDS, L) when length(L) < 5, length(L) > 0 ->
  io:format("~p: Ha come amici ~p ~n", [self(), L]),
  render ! {friends, PIDM, L},
  PIDLIST = lists:flatten(findFriends(PIDS, L)),
  % List2 contiene la lista di amici NON comuni e che NON includono se stessi e NON duplicati
  List2 = sets:to_list(sets:from_list([El || {PIDF, PIDSoth}=El <- PIDLIST, PIDSoth =/= PIDS , lists:member(El, L)=:=false])),
  Needed = 5 - length(L),
  case length(List2) =:= Needed of
    true ->
      friendship(PIDM, PIDS, [L, List2]);
    false ->
      case length(List2) =:= 0 of
        true ->
          % Non ho ricevuto nessun contatto, riprovo tra 2 secondi
          sleep(2000),
          friendship(PIDM,PIDS, L);
        false ->
          % Prendi n elementi randomici dalla list
          NewFriends = lists:flatten([L|pickFriends(List2, Needed)]),
          case length(NewFriends) =:= 5 of
            true -> pass;
            false ->
              % TODO: Nel caso in cui gli amici non siano ancora abbastanza per colmare il vuoto, contattiamo wk oppure
              % gli diamo una possibilità in più (sistema a counter, se dopo 3 tentativi la lista amici non si è
              % ripopolata chiedi a wk)
              not_implemented
          end,
          friendship(PIDM, PIDS,NewFriends)
      end
  end;
% Case I already have 5 friends
friendship(PIDM, PIDS, L) ->
  sleep(2000),
  render ! {friends, PIDM, L},
  friendship(PIDM, PIDS,lists:flatten(pingFriends(L))).

state(PIDM, none, L, XG, YG) ->
  RefD = make_ref(),
  PIDM ! {g_pidd, self(), RefD},
  receive
    {get_pidd, PIDD1, RefD} ->
      state(PIDM, PIDD1, L, XG, YG);
    _ = Msg ->
      %io:format("~p: Ricevuto messaggio non previsto: ~p~n", [self(), Msg]),
      self() ! Msg,
      state(PIDM, none, L, XG, YG)
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
      %io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
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

detect(PIDM, none, X, Y, W, H, XG, YG) ->
  RefS = make_ref(),
  PIDM ! {g_pids, self(), RefS},
  receive
    {get_pids, PIDS1, RefS} ->
      detect(PIDM, PIDS1, X, Y, W, H, XG, YG);
    _ = Msg ->
      %io:format("~p: Ricevuto messaggio non previsto in risoluzione di PIDS: ~p~n", [self(), Msg]),
      self() ! Msg,
      % TODO: Is this tail recursion?
      detect(PIDM, none, X, Y, W, H, XG, YG)
  end;

detect(PIDM, PIDS, X, Y, W, H, XG, YG) ->
  % muovere l'automobile sulla scacchiera
  % interagendo con l'attore "ambient" per fare sensing dello stato di occupazione dei posteggi.

  % Si muove di una cella verso l'obiettivo
  %% Si muove al fine di ridurre la coordinata con distanza maggiore. se pari random
  % Chiede ad ambient lo stato della cella attuale
  %% ambient ! {isFree, self(), X, Y, Ref}
  % Inoltra la risposta a state
  % Dorme 2 secondi

  %io:format("~p: Detect~n", [self()]),

  % ---- Communicate ----
  Ref = make_ref(),
  ambient ! {isFree, self(), X, Y, Ref},
  receive
    {status, Ref, IsFree} = Ajeje ->
      %io:format("~p: Resp ~p~n", [self(), Ajeje]),
      PIDS ! {status, X, Y, IsFree},

      case {X =:= XG, Y =:= YG, IsFree} of
        % Sono al goal ed è libero
        {true, true, true} ->
          RefP = make_ref(),
          ambient ! {park, self(), X, Y, RefP},
          receive
          % Parcheggio riuscito
            {parkOk, RefP} ->
              %io:format("~p: Parcheggio riuscito~n", [self()]),
              render ! {parked, PIDM, X, Y, 1},
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
              %io:format("~p: Parcheggio liberato con successo~n", [self()]),
              render ! {parked, PIDM, X, Y, 0};
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
          %io:format("~p: Spostamento in: (~p,~p)~n", [self(), NX, NY]),
          render ! {position, PIDM, NX, NY},
          detect(PIDM, PIDS, NX, NY, W, H, XG, YG)
      end;
    {newGoal} ->
      {NXG, NYG} = newCoordinates(W, H),
      %io:format("~p: Nuovo obiettivo: (~p,~p)~n", [self(), NXG, NYG]),
      % TODO: Should I check if newGoal is free?
      PIDS ! {newGoal, NXG, NYG},
      render ! {target, PIDM, NXG, NYG},
      % Flush inbox
      receive
        {status, _, _} = MsgFlush ->
          io:format("~p: Flush msg ~p~n", [self(), MsgFlush])
      end,
      detect(PIDM, PIDS, X, Y, W, H, NXG, NYG);
    _ = Msg1 ->
      %io:format("~p: Ricevuto messaggio non previsto: ~p~n", [self(), Msg1]),
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
  PIDF = spawn(?MODULE, friendship, [PIDM, none, []]),
  PIDM ! {s_pidf, PIDF},
  render ! {position, PIDM, X, Y},
  render ! {target, PIDM, XG, YG},
  io:format("~p: Generato detect(~p), state(~p), friendship(~p), memory(~p) ~n", [
    self(), PIDD, PIDS, PIDF, PIDM
  ]).
