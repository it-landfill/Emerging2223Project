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
    receive
        {getFriends, PID1, PID2, Ref} ->
            PID1 ! {myFriends, L, Ref},
            case lists:member(PID2, L) of
                true -> wellknown(L);
                false -> wellknown([PID2 | L])
            end
        %TODO: What if friends die?
    end.

main(PIDMain) ->
    Pid = spawn(?MODULE, wellknown, [[]]),
    register(wellknown, Pid),
    PIDMain ! {wellknownOK}.
