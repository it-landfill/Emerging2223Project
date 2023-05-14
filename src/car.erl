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
-export([main/2, memory/3, state/6, detect/8, friendship/3]).

sleep(N) ->
  receive
  after N -> ok
  end.

% Chiede agli amici la lista degli amici
findFriends(_, []) ->
  [];

findFriends(PIDS, [{PIDF, _} = El | T]) ->
  Ref = make_ref(),
  PIDF ! {getFriends, self(), PIDS, Ref},
  receive
    {myFriends, L, Ref} ->
      % io:format("~p: FRIENDS: ~p, ~p~n", [self(), El, T]),
      L ++ findFriends(PIDS, T)
  after 2000 ->
    findFriends(PIDS, T)
  end.

% Prende N amici da una lista in modo casuale
pickFriends(_, 0) ->
  [];
pickFriends([], _) ->
  [];
pickFriends(L, N) ->
  Rand = lists:nth(rand:uniform(length(L)), L),
  [Rand | pickFriends([El || El <- L, El =/= Rand], N - 1)].
% Funzione che elimina i duplicati dalla lista newlist tutti gli elementi presenti in s e che non contengono PIDS
keepNewItems(L, PIDS, NewLst) ->
  sets:to_list(
    sets:from_list([
      El || {_, PIDSoth} = El <- NewLst, PIDSoth =/= PIDS, lists:member(El, L) =:= false
    ])
  ).
% Funzione comune per la gestione delle richieste legate all'amicizia
friendshipResponse(PIDM, PIDS, L, Ref) ->
  receive
    {getFriends, PIDFReceived, _, RefReceived} ->
      PIDFReceived ! {myFriends, L, RefReceived},
      friendshipResponse(PIDM, PIDS, L, Ref);
    {insiderFriends, PIDReceived, RefReceived} ->
      % Per uso interno da parte di state
      PIDReceived ! {myFriends, L, RefReceived},
      friendshipResponse(PIDM, PIDS, L, Ref);
    {myFriends, PIDLIST, Ref} ->
      % io:format("FRIENDSHIP ~p: ricevo da WK ~p ~n", [self(), PIDLIST]),
      List2 = keepNewItems(L, PIDS, PIDLIST),
      case List2 =:= [] of
        true ->
          % io:format("FRIENDSHIP ~p: non ho ricevuto nessun amico ~n", [self()]),
          % Non ho ricevuto nessun contatto
          friendshipResponse(PIDM, PIDS, L, none);
        false ->
          % io:format("FRIENDSHIP ~p: Ha ricevuto risposta da WK ~n", [self()]),
          % Ho ricevuto un contatto, lo aggiungo alla lista
          FriendList = pickFriends(List2, 5 - length(L)),
          lists:foreach(fun({PIDF, _}) -> monitor(process, PIDF) end, FriendList),
          friendshipResponse(
            PIDM, PIDS, FriendList ++ L, none
          )
      end;
    {'DOWN', _, _, PPID, Reason} ->
      Alive = [El || {PIDF1, _} = El <- L, PPID =/= PIDF1],
      % io:format("FRIENDSHIP ~p: e' morto l'amico ~p poichè ~p~n", [self(), PPID, Reason]),
      friendshipResponse(PIDM, PIDS, Alive, Ref)
  after 2000 ->
    L
  end.

% Funzione per effettuare caching ed evitare di subissare di richieste Memory
friendship(PIDM, none, L) ->
  % io:format("FRIENDSHIP ~p: Non ha amici e non conosce PIDS~n", [self()]),
  RefM = make_ref(),
  PIDM ! {g_pids, self(), RefM},
  receive
    {get_pids, PIDS, RefM} ->
      friendship(PIDM, PIDS, L)
  end;

% Se ho meno di 5 amici (ma non 0)
friendship(PIDM, PIDS, L) when length(L) < 5 ->
  % io:format("FRIENDSHIP ~p: Ha come amici ~p ~n", [self(), L]),
  render ! {friends, PIDM, L},
  PIDLIST = findFriends(PIDS, L),

  % List2 contiene la lista di amici NON comuni e che NON includono se stessi e NON duplicati
  List2 = keepNewItems(L, PIDS, PIDLIST),
  Needed = 5 - length(L),
  case length(List2) =:= Needed of
    true ->
      friendshipResponse(PIDM, PIDS, L ++ List2, none);
    false ->
      case length(List2) > Needed of
        true ->
          % Prendi n elementi randomici dalla list
          NewFriends_tbm = pickFriends(List2, Needed),
          lists:foreach(fun({PIDF, _}) -> monitor(process, PIDF) end, NewFriends_tbm),
          NewFriends = NewFriends_tbm ++ L,
          Ln = friendshipResponse(PIDM, PIDS, NewFriends, none),
          friendship(PIDM, PIDS, Ln);
        false ->
          % Chiama WellKnown e fatti passare i contatti se non hai ancora abbastanza amici
          lists:foreach(fun({PIDF, _}) -> monitor(process, PIDF) end, List2),
          RefWK = make_ref(),
          wellknown ! {getFriends, self(), PIDS, RefWK},
          Ln = friendshipResponse(PIDM, PIDS, L ++ List2, RefWK),
          friendship(PIDM, PIDS, Ln)
      end
  end,
  Ln1 = friendshipResponse(PIDM, PIDS, L, none),
  friendship(PIDM, PIDS, Ln1);

% Ho già 5 amici, li devo mantenere
friendship(PIDM, PIDS, L) ->
  render ! {friends, PIDM, L},
  Ln = friendshipResponse(PIDM, PIDS, L, none),
  friendship(PIDM, PIDS, Ln).

do_gossip(X, Y, IsFree, PIDF) ->
  % Esegue il gossip dopo aver ottenuto la lista amici
  Ref = make_ref(),
  PIDF ! {insiderFriends, self(), Ref},
  receive
    {myFriends, L, Ref} ->
      lists:foreach(fun({_, PIDS}) ->
        % io:format("GOSP ~p: Invio infomazioni a: ~p~n", [self(), PIDS]),
        PIDS ! {notifyStatus, X, Y, IsFree}
                    end, L)
  end.

spatial_check(L, X, Y, XG, YG, IsFree, PIDD) ->
  % Aggiorna la rappresentazione interna, e se si rende conto che il goal è occupato procede a richiedere un nuovo
  % obiettivo.
  case lists:member({X, Y, IsFree}, L) of
    true ->
      % No news, we already new that...
      L;
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
      [{X, Y, isFree} | [El || {Xi, Yi, _} = El <- L, Xi =/= X, Yi =/= Y]]
  end.

state(PIDM, none, none, L, XG, YG) ->
  % State non conosce il PIDD e PIDF, quindi li chiede per fare caching
  RefD = make_ref(),
  PIDM ! {g_pidd, self(), RefD},
  receive
    {get_pidd, PIDD1, RefD} ->
      RefF = make_ref(),
      PIDM ! {g_pidf, self(), RefF},
      receive
        {get_pidf, PIDF1, RefF} ->
          state(PIDM, PIDD1, PIDF1, L, XG, YG)
      end
  end;
state(PIDM, PIDD, PIDF, L, XG, YG) ->
  % Loop dell'agente state
  receive
    {notifyStatus, X, Y, IsFree} ->
      LNew = spatial_check(L, X, Y, XG, YG, IsFree, PIDD),
      % io:format("STATE ~p: Ricevute informazioni via gossip su: ~p,~p, ~p~n", [self(), X, Y,IsFree]),
      state(PIDM, PIDD, PIDF, LNew, XG, YG);
    {status, X, Y, IsFree} ->
      LNew = spatial_check(L, X, Y, XG, YG, IsFree, PIDD),
      % Se le due liste sono diverse (ci sono novità) allora manda la nuova informazione
      case L =:= LNew of
        false ->
          do_gossip(X, Y, IsFree, PIDF);
        true ->
          pass
      end,
      % io:format("STATE ~p: Ricevute informazioni via detect su: ~p,~p, ~p~n", [self(), X, Y,IsFree]),
      state(PIDM, PIDD, PIDF, LNew, XG, YG);
    {newGoal, X, Y} ->
      state(PIDM, PIDD, PIDF, L, X, Y)
  end.

xmove(X, Y, W, XG) ->
  % Movimento sull'asse X
  case {(X - XG) > (W div 2), X - XG > 0} of
    {true, true} -> {(X + 1) rem W, Y};
    {true, false} -> {(X - 1) rem W, Y};
    {false, true} -> {(X - 1) rem W, Y};
    {false, false} -> {(X + 1) rem W, Y}
  end.

ymove(X, Y, H, YG) ->
  % Movimento sull'asse Y
  case {(Y - YG) > (H div 2), Y - YG > 0} of
    {true, true} -> {X, (Y + 1) rem H};
    {true, false} -> {X, (Y - 1) rem H};
    {false, true} -> {X, (Y - 1) rem H};
    {false, false} -> {X, (Y + 1) rem H}
  end.

move(X, Y, W, H, XG, YG) ->
  % ---- Move ----
  case {X =:= XG, Y =:= YG} of
    {true, true} ->
      % io:format("DETECT ~p: Arrivato al goal~n", [self()]),
      {X, Y};
    {false, false} ->
      case rand:uniform(2) of
        1 ->
          ymove(X, Y, H, YG);
        2 ->
          xmove(X, Y, W, XG)
      end;
    {true, false} ->
      ymove(X, Y, H, YG);
    {false, true} ->
      xmove(X, Y, W, XG)
  end.

detect(PIDM, none, X, Y, W, H, XG, YG) ->
  % Detect non conosce PIDS
  RefS = make_ref(),
  PIDM ! {g_pids, self(), RefS},
  receive
    {get_pids, PIDS1, RefS} ->
      detect(PIDM, PIDS1, X, Y, W, H, XG, YG);
    _ = Msg ->
      %% io:format("~p: Ricevuto messaggio non previsto in risoluzione di PIDS: ~p~n", [self(), Msg]),
      self() ! Msg,
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

  %% io:format("~p: Detect~n", [self()]),

  % ---- Communicate ----
  Ref = make_ref(),
  ambient ! {isFree, self(), X, Y, Ref},
  receive
    {status, Ref, IsFree} ->
      PIDS ! {status, X, Y, IsFree},
      % io:format("DETECT ~p: Status, ~p~n", [self(), {X =:= XG, Y =:= YG, IsFree}]),
      case {X =:= XG, Y =:= YG, IsFree} of
        % Sono al goal ed è libero
        {true, true, true} ->
          RefP = make_ref(),
          ambient ! {park, self(), X, Y, RefP},
          receive
          % Parcheggio riuscito
            {parkOk, RefP} ->
              % io:format("DETECT ~p: Parcheggio riuscito~n", [self()]),
              render ! {parked, PIDM, X, Y, 1},
              sleep((rand:uniform(4) + 1) * 1000);
          % Parcheggio fallito
            {parkFailed, RefP} ->
              % io:format("DETECT ~p: Parcheggio fallito~n", [self()]),
              exit(park_busy)
          end,
          ambient ! {leave, self(), RefP},
          receive
          % Ripartenza riuscita
            {leaveOk, RefP} ->
              %% io:format("~p: Parcheggio liberato con successo~n", [self()]),
              render ! {parked, PIDM, X, Y, 0};
          % Ripartenza fallita (questa situazione non dovrebbe mai verificarsi)
            {leaveFailed, RefP} ->
              io:format("DETECT ~p: Errore in liberamento del parcheggio~n", [self()]),
              exit(leave_failed)
          end,
          self() ! {newGoal},
          detect(PIDM, PIDS, X, Y, W, H, XG, YG);
        _ ->
          sleep(2000),
          {NX, NY} = move(X, Y, W, H, XG, YG),
          %% io:format("~p: Spostamento in: (~p,~p)~n", [self(), NX, NY]),
          render ! {position, PIDM, NX, NY},
          detect(PIDM, PIDS, NX, NY, W, H, XG, YG)
      end;
    {newGoal} ->
      {NXG, NYG} = newCoordinates(W, H),
      %% io:format("~p: Nuovo obiettivo: (~p,~p)~n", [self(), NXG, NYG]),
      PIDS ! {newGoal, NXG, NYG},
      render ! {target, PIDM, NXG, NYG},
      % Flush inbox
      receive
        {status, _, _} = MsgFlush ->
          pass
      % io:format("DETECT ~p: Flush msg ~p~n", [self(), MsgFlush])
      end,
      detect(PIDM, PIDS, X, Y, W, H, NXG, NYG)
  end.

memory(PIDS, PIDD, PIDF) ->
  % Memorizza e mantiene nel suo stato i PID di State, Detect e Friendship, rendendoli
  % disponibili a tutti i componenti del veicolo.
  receive
    {s_pids, Value} ->
      % io:format("MEM ~p: Ricevuto messaggio s_pids ~p~n", [self(), Value]),
      link(Value),
      memory(Value, PIDD, PIDF);
    {s_pidd, Value} ->
      % io:format("MEM ~p: Ricevuto messaggio s_pidd ~p~n", [self(), Value]),
      link(Value),
      memory(PIDS, Value, PIDF);
    {s_pidf, Value} ->
      % io:format("MEM ~p: Ricevuto messaggio s_pidf ~p~n", [self(), Value]),
      link(Value),
      memory(PIDS, PIDD, Value);
    {g_pids, Pid, Ref} ->
      % io:format("MEM ~p: Ricevuto messaggio g_pids ~p~n", [self(), PIDS]),
      Pid ! {get_pids, PIDS, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidd, Pid, Ref} ->
      % io:format("MEM ~p: Ricevuto messaggio g_pidd ~p~n", [self(), PIDD]),
      Pid ! {get_pidd, PIDD, Ref},
      memory(PIDS, PIDD, PIDF);
    {g_pidf, Pid, Ref} ->
      % io:format("MEM ~p: Ricevuto messaggio g_pidf ~p~n", [self(), PIDF]),
      Pid ! {get_pidf, PIDF, Ref},
      memory(PIDS, PIDD, PIDF);
    {die} ->
      % io:format("MEM ~p: Ricevuto messaggio die~n", [self()]),
      exit(random_heart_attack)
  end.

newCoordinates(W, H) ->
  {rand:uniform(W) - 1, rand:uniform(H) - 1}.

main(W, H) ->
  {X, Y} = newCoordinates(W, H),
  {XG, YG} = newCoordinates(W, H),
  % io:format("CAR ~p: Coordinate di partenza: ~p,~p~n", [self(), X, Y]),
  % io:format("CAR ~p: Target: ~p,~p~n", [self(), XG, YG]),

  % Spawn "DNS" actor
  {PIDM, MemRef} = spawn_monitor(?MODULE, memory, [none, none, none]),

  % Spawn actors
  PIDS = spawn(?MODULE, state, [PIDM, none, none, [], XG, YG]),
  PIDM ! {s_pids, PIDS},
  PIDD = spawn(?MODULE, detect, [PIDM, none, X, Y, W, H, XG, YG]),
  PIDM ! {s_pidd, PIDD},
  PIDF = spawn(?MODULE, friendship, [PIDM, none, []]),
  PIDM ! {s_pidf, PIDF},
  render ! {position, PIDM, X, Y},
  render ! {target, PIDM, XG, YG},
  % io:format("CAR ~p: Generato detect(~p), state(~p), friendship(~p), memory(~p) ~n", [self(), PIDD, PIDS, PIDF, PIDM]),
  ARef = monitor(process, ambient),
  receive
    {'DOWN', ARef, _, ambient, Reason} ->
      io:format("CAR ~p: We polluted too much and the ambient is now really sad... ~p~n", [self(), Reason]),
      exit(normal);
    {'DOWN', MemRef, _, PIDM, Reason} ->
      io:format("CAR ~p: Something went wrong, restarting everything... ~p~n", [self(), Reason]),
      main(W, H)
  after rand:uniform(15000) + 15000 ->
    % io:format("CAR ~p: Time to die... ~n", [self()]),
    % KIll memory actor and exit
    PIDM ! {die},
    exit(random_heart_attack)
  end.

