-module(qerl_example_server).
-export([start/0,stop/0]).

start() -> qerl_socket_server:start(?MODULE, 7000, {qerl_fsm, start_link}).
stop() -> qerl_socket_server:stop(?MODULE).

