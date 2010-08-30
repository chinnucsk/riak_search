%% -------------------------------------------------------------------
%%
%% mi: Merge-Index Data Store
%%
%% Copyright (c) 2007-2010 Basho Technologies, Inc. All Rights Reserved.
%%
%% -------------------------------------------------------------------
-module(mi_utils).
-author("Rusty Klophaus <rusty@basho.com>").
-include("merge_index.hrl").
-export([
    fold/3,
    file_exists/1,
    create_empty_file/1,
    now_to_timestamp/1,
    ets_next/2,
    ets_info/0
]).


fold(F, Acc, Resource) ->
    case F(Resource, Acc) of
        {ok, NewResource, NewAcc} -> fold(F, NewAcc, NewResource);
        {eof, NewAcc} -> {ok, NewAcc}
    end.

file_exists(Filename) ->
    filelib:is_file(Filename).

create_empty_file(Filename) ->
    file:write_file(Filename, <<"">>).

now_to_timestamp({Mega, Sec, Micro}) ->
    <<TS:64/integer>> = <<Mega:16/integer, Sec:24/integer, Micro:24/integer>>,
    TS.

%% Return the next key greater than or equal to the supplied key.
ets_next(Table, Key) ->
    case Key == undefined of 
        true ->
             ets:first(Table);
        false ->
            case ets:lookup(Table, Key) of
                [{Key, _Values}] -> 
                    Key;
                [] ->
                    ets:next(Table, Key)
            end
    end.

ets_info() ->
    L = [{ets:info(T, name), ets:info(T, memory) * erlang:system_info(wordsize)} || T <- ets:all()],
    Grouped = lists:foldl(fun({Name, Size}, Acc) -> orddict:update_counter(Name, Size, Acc) end,
                          [], L),
    lists:reverse(lists:keysort(2, Grouped)).