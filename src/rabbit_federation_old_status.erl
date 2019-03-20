%%  The contents of this file are subject to the Mozilla Public License
%%  Version 1.1 (the "License"); you may not use this file except in
%%  compliance with the License. You may obtain a copy of the License
%%  at https://www.mozilla.org/MPL/
%%
%%  Software distributed under the License is distributed on an "AS IS"
%%  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%  the License for the specific language governing rights and
%%  limitations under the License.
%%
%%  The Original Code is RabbitMQ Federation.
%%
%%  The Initial Developer of the Original Code is VMware, Inc.
%%  Copyright (c) 2007-2013 VMware, Inc.  All rights reserved.
%%

-module(rabbit_federation_old_status).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_federation_old.hrl").

-export([start_link/0]).

-export([report/3, remove/1, status/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(ETS_NAME, ?MODULE).

-record(state, {}).
-record(entry, {key, status, timestamp}).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

report(Upstream, XName, Status) ->
    gen_server:cast(?SERVER, {report, Upstream, XName, Status,
                              calendar:local_time()}).

remove(XName) ->
    gen_server:call(?SERVER, {remove, XName}, infinity).

status() ->
    gen_server:call(?SERVER, status, infinity).

init([]) ->
    ?ETS_NAME = ets:new(?ETS_NAME,
                        [named_table, {keypos, #entry.key}, private]),
    {ok, #state{}}.

handle_call({remove, XName}, _From, State) ->
    true = ets:match_delete(?ETS_NAME, #entry{key       = {XName, '_'},
                                              status    = '_',
                                              timestamp = '_'}),
    {reply, ok, State};

handle_call(status, _From, State) ->
    Entries = ets:tab2list(?ETS_NAME),
    {reply, [format(Entry) || Entry <- Entries], State}.

handle_cast({report, Upstream, XName, Status, Timestamp}, State) ->
    true = ets:insert(?ETS_NAME, #entry{key        = {XName, Upstream},
                                        status     = Status,
                                        timestamp  = Timestamp}),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

format(#entry{key       = {#resource{virtual_host = VHost,
                                     kind         = exchange,
                                     name         = XNameBin},
                           #upstream{connection_name = Connection,
                                     exchange        = UXNameBin}},
              status    = Status,
              timestamp = Timestamp}) ->
        [{exchange,          XNameBin},
         {vhost,             VHost},
         {connection,        list_to_binary(Connection)},
         {upstream_exchange, UXNameBin},
         {status,            Status},
         {timestamp,         Timestamp}].
