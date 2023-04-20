%%%-------------------------------------------------------------------
%%% @author Balugani, Benetton, Crespan
%%% @copyright (C) 2023, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. apr 2023 15:08
%%%-------------------------------------------------------------------
-module(wellknown).
-author("Balugani, Benetton, Crespan").

%% API
-export([main/1, wellknown/1]).

wellknown(L) ->
    io:format("~p: WK conosce ~p~n", [self(),L]),
    receive
        {getFriends, PID1, PID2, Ref} ->
            io:format("~p: WK riceve messaggio da ~p~n", [self(),PID1]),
            PID1 ! {myFriends, L, Ref},
            case lists:member({PID1, PID2}, L) of
                true -> wellknown(L);
                false -> wellknown([{PID1,PID2} | L])
            end
        %TODO: What if friends die?
    end.

main(PIDMain) ->
    Pid = spawn(?MODULE, wellknown, [[]]),
    register(wellknown, Pid),
    PIDMain ! {wellknownOK}.
