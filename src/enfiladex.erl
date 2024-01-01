-module(enfiladex).

-export([make_peer_name/1, initialize_node/2, anonymous_peer/3, named_peer/4,
         multi_peer/3]).

-include_lib("common_test/include/ct.hrl").

add_code_paths(Node) ->
    rpc:block_call(Node, code, add_paths, [code:get_path()]).

transfer_configuration(Node) ->
    do_transfer_configuration(Node, application:loaded_applications()).

transfer_configuration(Node, App) ->
    do_transfer_configuration(Node, [{App, nil, nil} | application:loaded_applications()]).

do_transfer_configuration(Node, Apps) ->
    [rpc:block_call(Node, application, set_env, [AppName, Key, Val])
     || {AppName, _, _} <- Apps, {Key, Val} <- application:get_all_env(AppName)].

ensure_applications_started(Node) ->
    ensure_applications_started(Node, application:loaded_applications()).

ensure_applications_started(Node, Apps) ->
    rpc:block_call(Node, application, ensure_all_started, [mix]),
    rpc:block_call(Node, 'Elixir.Mix', env, ['Elixir.Mix':env()]),

    [rpc:block_call(Node, application, ensure_all_started, [AppName])
     || {AppName, _, _} <- Apps].

maybe_transfer_config(Node, Config) ->
    case proplists:get_value(transfer_config, Config, false) of
        false ->
            ok;
        true ->
            transfer_configuration(Node);
        App ->
            transfer_configuration(Node, App)
    end.

maybe_start_applicatoins(Node, Config) ->
    case proplists:get_value(start_applications, Config, false) of
        false ->
            ok;
        true ->
            ensure_applications_started(Node);
        Apps when is_list(Apps) ->
            ensure_applications_started(Node, Apps)
    end.

apply_fun(Peer, Node, Fun)
    when is_tuple(Fun)
         orelse is_function(Fun, 0)
         orelse is_function(Fun, 1)
         orelse is_function(Fun, 2) ->
    case Fun of
        {Mod, ModFun, Args} ->
            rpc:call(Node, Mod, ModFun, Args);
        Fun0 when is_function(Fun0, 0) ->
            erpc:call(Node, Fun0);
        Fun1 when is_function(Fun1, 1) ->
            Fun1(Node);
        Fun2 when is_function(Fun2, 2) ->
            Fun2(Peer, Node)
    end.

%% specify additional arguments to the new node
%% `{ok, Peer, Node} = ?CT_PEER(["-emu_flavor", "smp"]).`
peer_with_args(Config) ->
    case proplists:get_value(peer_node_arguments, Config, nil) of
        nil ->
            ?CT_PEER();
        [] ->
            ?CT_PEER();
        Args ->
            ?CT_PEER(Args)
    end.

initialize_node(Node, Config) ->
    add_code_paths(Node),
    maybe_transfer_config(Node, Config),
    maybe_start_applicatoins(Node, Config).

get_result(Peer, Node, Fun, Callback) ->
    Result = apply_fun(Peer, Node, Fun),
    case Callback of
        Fun1 when is_function(Fun1, 1) ->
            Fun1(Result);
        Fun2 when is_function(Fun2, 2) ->
            Fun2(Node, Result);
        Fun3 when is_function(Fun3, 3) ->
            Fun3(Peer, Node, Result)
    end,
    Result.

%% Interface
anonymous_peer(Fun, Callback, Config)
    when is_function(Fun) orelse is_tuple(Fun), is_function(Callback), is_list(Config) ->
    {ok, Peer, Node} = peer_with_args(Config),
    initialize_node(Node, Config),
    Result = get_result(Peer, Node, Fun, Callback),
    peer:stop(Peer),
    Result.

named_peer(Name, Fun, Callback, Config)
    when is_function(Fun) orelse is_tuple(Fun), is_function(Callback), is_list(Config) ->
    Config2 = [{peer_node_arguments, #{name => ?CT_PEER_NAME(Name)}} | Config],
    anonymous_peer(Fun, Callback, Config2).

multi_peer(Fun, Callback, Config)
    when is_function(Fun) orelse is_tuple(Fun), is_function(Callback), is_list(Config) ->
    Count = proplists:get_value(nodes_count, Config, 3),
    Peers = [?CT_PEER(#{wait_boot => {self(), enfiladex}}) || _ <- lists:seq(1, Count)],
    %% wait for all nodes to complete boot process, get their names:
    Nodes =
        [receive
             {enfiladex, {started, Node, Peer}} ->
                 {Peer, Node}
         end
         || {ok, Peer, _Node} <- Peers],
    [initialize_node(Node, Config) || {_Peer, Node} <- Nodes],
    Result = [{Peer, Node, get_result(Peer, Node, Fun, Callback)} || {Peer, Node} <- Nodes],
    [peer:stop(Peer) || {ok, Peer, _Node} <- Peers],
    Result.

make_peer_name(ConfigOrName) ->
    case ConfigOrName of
        nil ->
            ?CT_PEER_NAME();
        Config when is_list(Config) ->
            make_peer_name(proplists:get_value(peer_name, Config, nil));
        Name ->
            ?CT_PEER_NAME(Name)
    end.

% restart_node(Config) when is_list(Config) ->
%     Name = ?CT_PEER_NAME(),
%     {ok, Peer, Node} = ?CT_PEER(#{name => Name}),
%     peer:stop(Peer),
%     %% restart the node with the same name as before
%     {ok, Peer2, Node} = ?CT_PEER(#{name => Name, args => ["+fnl"]}),
%     peer:stop(Peer2).

% remote_node(Host) ->
%     Ssh = os:find_executable("ssh"),
%     peer:start_link(#{exec => {Ssh, [Host, "erl"]}, connection => standard_io}).

% docker(Config) when is_list(Config) ->
%     Docker = os:find_executable("docker"),
%     PrivDir = proplists:get_value(priv_dir, Config),
%     build_release(PrivDir),
%     build_image(PrivDir),

%     %% start two Docker containers
%     {ok, Peer, Node} = peer:start_link(#{name => lambda,
%         connection => standard_io,
%         exec => {Docker, ["run", "-h", "one", "-i", "lambda"]}}),
%     {ok, Peer2, Node2} = peer:start_link(#{name => lambda,
%         connection => standard_io,
%         exec => {Docker, ["run", "-h", "two", "-i", "lambda"]}}),

%     %% find IP address of the second node using alternative connection RPC
%     {ok, Ips} = peer:call(Peer2, inet, getifaddrs, []),
%     {"eth0", Eth0} = lists:keyfind("eth0", 1, Ips),
%     {addr, Ip} = lists:keyfind(addr, 1, Eth0),

%     %% make first node to discover second one
%     ok = peer:call(Peer, inet_db, set_lookup, [[file]]),
%     ok = peer:call(Peer, inet_db, add_host, [Ip, ["two"]]),

%     %% join a cluster
%     true = peer:call(Peer, net_kernel, connect_node, [Node2]),
%     %% verify that second peer node has only the first node visible
%     [Node] = peer:call(Peer2, erlang, nodes, []),

%     %% stop peers, causing containers to also stop
%     peer:stop(Peer2),
%     peer:stop(Peer).

% build_release(Dir) ->
%     %% load sasl.app file, otherwise application:get_key will fail
%     application:load(sasl),
%     %% create *.rel - release file
%     RelFile = filename:join(Dir, "lambda.rel"),
%     Release = {release, {"lambda", "1.0.0"},
%         {erts, erlang:system_info(version)},
%         [{App, begin {ok, Vsn} = application:get_key(App, vsn), Vsn end}
%             || App <- [kernel, stdlib, sasl]]},
%     ok = file:write_file(RelFile, list_to_binary(lists:flatten(
%         io_lib:format("~tp.", [Release])))),
%     RelFileNoExt = filename:join(Dir, "lambda"),

%     %% create boot script
%     {ok, systools_make, []} = systools:make_script(RelFileNoExt,
%         [silent, {outdir, Dir}]),
%     %% package release into *.tar.gz
%     ok = systools:make_tar(RelFileNoExt, [{erts, code:root_dir()}]).

% build_image(Dir) ->
%     %% Create Dockerfile example, working only for Ubuntu 20.04
%     %% Expose port 4445, and make Erlang distribution to listen
%     %%  on this port, and connect to it without EPMD
%     %% Set cookie on both nodes to be the same.
%     BuildScript = filename:join(Dir, "Dockerfile"),
%     Dockerfile =
%       "FROM ubuntu:23.10 as runner\n"
%       "EXPOSE 4445\n"
%       "WORKDIR /opt/lambda\n"
%       "COPY lambda.tar.gz /tmp\n"
%       "RUN tar -zxvf /tmp/lambda.tar.gz -C /opt/lambda\n"
%       "ENTRYPOINT [\"/opt/lambda/erts-" ++ erlang:system_info(version) ++
%       "/bin/dyn_erl\", \"-boot\", \"/opt/lambda/releases/1.0.0/start\","
%       " \"-kernel\", \"inet_dist_listen_min\", \"4445\","
%       " \"-erl_epmd_port\", \"4445\","
%       " \"-setcookie\", \"secret\"]\n",
%     ok = file:write_file(BuildScript, Dockerfile),
%     os:cmd("docker build -t lambda " ++ Dir).
