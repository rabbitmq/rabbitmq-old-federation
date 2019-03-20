%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ Federation.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2013 VMware, Inc.  All rights reserved.
%%

-module(rabbit_federation_old_util).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_federation_old.hrl").

-export([local_params/1, pget_bin/2, pget_bin/3, should_forward/2]).
-export([validate_arg/3, fail/2]).

-import(rabbit_misc, [pget_or_die/2, pget/3]).

%%----------------------------------------------------------------------------

local_params(VHost) ->
    {ok, U} = application:get_env(rabbitmq_old_federation, local_username),
    #amqp_params_direct{username     = list_to_binary(U),
                        virtual_host = VHost}.

pget_bin(K, T) -> list_to_binary(pget_or_die(K, T)).

pget_bin(K, T, D) when is_binary(D) -> pget_bin(K, T, binary_to_list(D));
pget_bin(K, T, D) when is_list(D)   -> list_to_binary(pget(K, T, D)).

should_forward(undefined, _MaxHops) ->
    true;
should_forward(Headers, MaxHops) ->
    case rabbit_misc:table_lookup(Headers, ?ROUTING_HEADER) of
        undefined  -> true;
        {array, A} -> length(A) < MaxHops
    end.

validate_arg(Name, Type, Args) ->
    case rabbit_misc:table_lookup(Args, Name) of
        {Type, _} -> ok;
        undefined -> fail("Argument ~s missing", [Name]);
        _         -> fail("Argument ~s must be of type ~s", [Name, Type])
    end.

fail(Fmt, Args) -> rabbit_misc:protocol_error(precondition_failed, Fmt, Args).
