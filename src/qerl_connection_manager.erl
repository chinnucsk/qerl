-module(qerl_connection_manager).
-behaviour(gen_server).

-compile(export_all).

-define(TCP_OPTIONS, [binary, {packet, 0}, {active, false}, {reuseaddr, true}]).
-record(server_state,{module,socket,listeners_size}).

%% Simple start of connection manager by providing:
%% - Listening Module (LModule)
%% - port used for establishing the connection (Port)
%% - the default number of preinitialized listeners (LSize)
start(LModule,Port,LSize) ->
    gen_server:start({local,?MODULE},?MODULE,[LModule,Port,LSize],[]).

%% Start and linking of connection manager by providing:
%% - Listening Module (LModule)
%% - port used for establishing the connection (Port)
%% - the default number of preinitialized listeners (LSize)
start_link(LModule,Port,LSize) -> gen_server:start_link({local,?MODULE},?MODULE,[LModule,Port,LSize],[]).

detach() -> gen_server:call(?MODULE,detach).

init([LModule,Port,LSize]) ->
    process_flag(trap_exit,true),
    case gen_tcp:listen(Port,?TCP_OPTIONS) of
        {ok,LSocket} ->
            ok = spawn_listeners(LModule,LSocket,LSize),
            {ok,#server_state{module=LModule,socket=LSocket,listeners_size=LSize}};
        {error,Reason} ->
            {stop,Reason}
    end.

handle_call(detach,{From,_Ref}, State = #server_state{module=LModule,socket=LSocket}) ->
    io:format(" -> ~p:handle_call >> detach, From - ~p~n",[?MODULE,From]),
    ok = spawn_listeners(LModule,LSocket,1),
    io:format("    -> spawned new listener~n"),
    unlink(From),
    io:format("    -> unlinked From ~p~n",[From]),
    {reply,ok,State};
handle_call(_Request,_From,State) ->
    Reply = ok,
    {reply,Reply,State}.

handle_cast(_Msg,State) -> {noreply,State}.

handle_info(Info,State) ->
    {noreply,State}.

terminate(_Reason,_State) ->
    io:format(" -> closing connection manager~n"),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok,State}.

spawn_listeners(_,_,0) -> ok;
spawn_listeners(LModule,LSocket,LSize) ->
    LModule:start_link(LSocket),
    spawn_listeners(LModule,LSocket,LSize-1).

