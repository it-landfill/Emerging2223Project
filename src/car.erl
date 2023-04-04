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
-export([main/2]).

sleep(N) -> receive after N -> ok end.

friendship() ->
	pass
	%TODO: implement friendship
	% mantenere 5 attori nella lista di attori, integrandone di nuovi nel caso in cui il numero scenda.
.

state(PIDD, L) ->
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
	
	receive
		{status, X, Y, IsFree} ->
			case lists:member({X, Y, IsFree}) of 
				true ->
					% No news, we already new that...
					state(PIDD, L);
				false ->
					% New news, we need to gossip
					% TODO: gossip
					state(PIDD, [{X, Y, isFree} | [El || {Xi, Yi, _} = El <- L, Xi =/= X, Yi =/= Y]])
				end;
		_ ->
			io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
			state(PIDD, L)
	end.

detect(PIDS, X, Y, W, H, XG, YG) ->
	% TODO: implement detect
	% muovere l'automobile sulla scacchiera
	% interagendo con l'attore "ambient" per fare sensing dello stato di occupazione dei posteggi.

	% Si muove di una cella verso l'obiettivo
	%% Si muove al fine di ridurre la coordinata con distanza maggiore. se pari random
	% Chiede ad ambient lo stato della cella attuale
	%% ambient ! {isFree, self(), X, Y, Ref}
	% Inoltra la risposta a state
	% Dorme 2 secondi
	
	Ref = make_ref(),
	ambient ! {isFree, self(), X, Y, Ref},

	case {X, Y} of
		{XG, YG} ->
			io:format("~p: Arrivato al goal~n", [self()]), %%TODO: Park
			NX = X,
			NY = Y;
		{XG, _} ->
			NX = X,
			NY = (Y + 1) rem H;
		{_, YG} ->
			NX = (X + 1) rem W,
			NY = Y
	end,

	io:format("~p: Spostamento in ~p, ~p~n", [self(), NX, NY]),

	receive
		{status, Ref, IsFree} ->
			PIDS ! {status, X, Y, IsFree},
		
			sleep(2000),
			detect(PIDS, NX, NY, W, H, XG, YG);
		_ ->
			io:format("~p: Ricevuto messaggio non previsto~n", [self()]),
			detect(PIDS, X, Y, W, H, XG, YG)
	end.


main(W, H) ->
	X = rand:uniform(W),
	Y = rand:uniform(H),
	% TODO: Define goal parking
	XG = 1,
	YG = 1,
	% TODO: Check if park is free


	PIDS = spawn(?MODULE, state, [none, []]),
	PIDD = spawn(?MODULE, detect, [PIDS, X, Y, W, H, XG, YG]),
	link(PIDS),
	link(PIDD)
	% PIDF = spawn(?MODULE, friendship, []),
.
