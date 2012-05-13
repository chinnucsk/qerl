-module(qerl_stomp_protocol).

-export([is_eof/1, parse/1]).

-define(LF, 10).

-define(NULL, 0).

is_eof(BinData) ->
    LfBin =
	drop_invalid_beginning_frame(qerl_stomp_utils:drop(cr,
							   BinData)),
    case binary:match(LfBin, <<(?NULL)>>) of
      nomatch -> false;
      _ -> binary:match(LfBin, <<(?LF), (?LF)>>) =/= nomatch
    end.

parse(Frame) ->
    LfBin =
	drop_invalid_beginning_frame(qerl_stomp_utils:drop(cr,
							   data_without_null_and_lf(Frame))),
    ToParse = binary:split(LfBin, <<(?LF)>>, []),
    case ToParse of
      [_] -> [H] = ToParse, parse_msg([H, <<>>]);
      _ -> parse_msg(ToParse)
    end.

parse_msg([<<"CONNECT">>, Frame]) ->
    {connect, {headers, get_headers(Frame)}};
parse_msg([<<"SEND">>, Frame]) ->
    {send, {headers, get_headers(Frame)},
     {body, get_body(Frame)}};
parse_msg([<<"SUBSCRIBE">>, Frame]) ->
    {subscribe, {headers, get_headers(Frame)}};
parse_msg([<<"UNSUBSCRIBE">>, Frame]) ->
    {unsubscribe, {headers, get_headers(Frame)}};
parse_msg([<<"BEGIN">>, Frame]) ->
    {begin_tx, {headers, get_headers(Frame)}};
parse_msg([<<"COMMIT">>, Frame]) ->
    {commit, {headers, get_headers(Frame)}};
parse_msg([<<"ABORT">>, Frame]) ->
    {abort, {headers, get_headers(Frame)}};
parse_msg([<<"ACK">>, Frame]) ->
    {ack, {headers, get_headers(Frame)}};
parse_msg([<<"DISCONNECT">>, Frame]) ->
    {disconnect, {headers, get_headers(Frame)}};
%% Debug/helper commands, that are not part of STOMP specs.
parse_msg([<<"QINFO">>, _]) -> {queue_info};
parse_msg([UnknownBinCommand, _]) ->
    UnknownCommand =
	erlang:binary_to_list(UnknownBinCommand),
    {unknown_command, UnknownCommand}.

get_body(Frame) ->
    case has_headers(Frame) of
      true -> parse_body_with_headers(Frame);
      false -> parse_body_without_headers(Frame)
    end.

get_headers(Frame) ->
    case has_headers(Frame) of
      true -> parse_headers(Frame);
      false -> []
    end.

parse_headers(Frame) ->
    parse_headers(binary:split(Frame, <<(?LF)>>, []), []).

parse_headers([], Headers) -> to_headers(Headers);
parse_headers([Head], Headers) ->
    to_headers([Head | Headers]);
parse_headers([<<>>, _Rest], Headers) ->
    to_headers(Headers);
parse_headers([H, Rest], Headers) ->
    parse_headers(binary:split(Rest, <<(?LF)>>, []),
		  [H | Headers]).

has_headers(<<>>) -> false;
has_headers(Frame) ->
    case binary:first(Frame) of
      ?LF -> false;
      _Else -> true
    end.

parse_body_with_headers([_Headers, Rest]) ->
    to_list_body(Rest);
parse_body_with_headers([_H | _T]) -> [];
parse_body_with_headers([]) -> [];
parse_body_with_headers(BinData) ->
    parse_body_with_headers(binary:split(BinData,
					 <<(?LF), (?LF)>>, [])).

parse_body_without_headers(<<(?LF), Rest/binary>>) ->
    to_list_body(Rest);
parse_body_without_headers(BinData) ->
    to_list_body(BinData).

to_list_body(BinBody) ->
    ListBody = binary:bin_to_list(BinBody),
    lists:takewhile(fun (X) -> X =/= 0 end, ListBody).

data_without_null_and_lf(BinData) ->
    [H | _] = binary:split(BinData, <<(?NULL), (?LF)>>, []),
    H.

to_headers(BinHeaders) -> to_headers(BinHeaders, []).

to_headers([], Headers) -> Headers;
to_headers([H | T], Headers) ->
    {BinK, BinV} =
	list_to_tuple(create_header(binary:split(H, <<":">>))),
    to_headers(T,
	       [{binary:bin_to_list(BinK),
		 trim_left(binary:bin_to_list(BinV))}
		| Headers]).

create_header(L) ->
    case length(L) of
      0 -> [<<>>, <<>>];
      1 -> [H | _] = L, [H, <<>>];
      _ -> lists:sublist(L, 2)
    end.

trim_left([32 | T]) -> trim_left(T);
trim_left(L) -> L.

drop_invalid_beginning_frame(<<>>) -> <<>>;
drop_invalid_beginning_frame(<<(?LF), Rest/binary>>) ->
    drop_invalid_beginning_frame(Rest);
drop_invalid_beginning_frame(Frame) -> Frame.

