require Logger

defmodule PlayerSync do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, client_pid } = Philae.DDP.connect("ws://localhost:3000/websocket", __MODULE__, self)
    {collection, id} = Philae.DDP.subscribe(client_pid, "players")
    {:ok, %{client_pid: client_pid, subscription_id: id, collection: collection}}
  end

  #Client API

  def add_player(pid, player_name) do
    GenServer.call(pid, {:add, player_name})
  end

  def vote_for_player(pid, player_name) do
    GenServer.call(pid, {:vote, player_name})
  end

  def added(pid, message) do
    GenServer.call(pid, {:added, message})
  end

  def changed(pid, message) do
    GenServer.call(pid, {:changed, message})
  end

  def result(pid, message) do
    Logger.info "Got a result message of" <> inspect message
  end

  def connected(_pid, _message) do
    Logger.info("Connected to the player collection")
  end

  def ready(_pid, _message) do
    Logger.info("Collection is ready")
  end

  def updated(_pid, message) do
    Logger.info "Receved an Updated method call" <> inspect message
  end

  # Server API
  def handle_call({:vote, player_name}, _from, %{client_pid: client_pid} = state) do
    Philae.DDP.method(client_pid, :vote, [player_name])
    {:reply, :ok, state}
  end

  def handle_call({:add, player_name}, _from, %{client_pid: client_pid} = state) do
    Philae.DDP.method(client_pid, :add, [player_name])
    {:reply, :ok, state}
  end

  def handle_call({:added, %{"fields" => fields, "id" => mongo_id} = message}, _from, state) do
    Logger.info "PlayerVoter recieved added msg:" <> inspect message
    Player.create_or_update_by_mongo_id(mongo_id, fields)
    {:reply, :ok, state}
  end

  def handle_call({:changed, %{"fields" => fields, "id" => mongo_id} = message}, _from, state) do
    Logger.info "PlayerVoter recieved changed msg:" <> inspect message
    Player.create_or_update_by_mongo_id(mongo_id, fields)
    {:reply, :ok, state}
  end

  def handle_call(message, _from, state) do
    Logger.info "PlayerVoter recieved msg:" <> inspect message
    {:reply, :ok, state}
  end
end

