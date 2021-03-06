require 'floss/rpc'
require 'floss/rpc/zmq'
require 'floss/rpc/in_memory'

class TestActor
  include Celluloid

  execute_block_on_receiver :exec

  def exec
    yield
  end
end

shared_examples 'an RPC implementation' do
  def actor_run(&block)
    actor = TestActor.new
    result = actor.exec(&block)
    actor.terminate
    result
  end

  let(:server_class) { described_class::Server }
  let(:client_class) { described_class::Client }

  let(:command) { :command }
  let(:payload) { Hash[key: 'value'] }

  it 'executes calls' do
    server = server_class.new(address) { |command, payload| [command, payload] }
    client = client_class.new(address)
    actor_run { client.call(command, payload) }.should eq([command, payload])
  end

  it 'executes multiple calls sequentially' do
    calls = 3.times.map { |i| [:command, i] }
    server = server_class.new(address) { |command, payload| [command, payload] }
    client = client_class.new(address)
    actor_run { calls.map { |args| client.call(*args) } }.should eq(calls)
  end

  it 'raises an error if server is not available' do
     client = client_class.new(address)
     expect { actor_run { client.call(:command, :payload) } }.to raise_error(Floss::TimeoutError)
  end

  it 'raises an error if server does not respond in time' do
    server = server_class.new(address) { |command, payload| sleep 1.5; [command, payload] }
    client = client_class.new(address)
    expect { actor_run { client.call(:command, :payload) } }.to raise_error(Floss::TimeoutError)
  end
end

describe Floss::RPC::InMemory do
  let(:address) { :node1 }

  before(:each) do
    Celluloid.shutdown
    Celluloid.boot
  end

  it_should_behave_like 'an RPC implementation'
end

describe Floss::RPC::ZMQ do
  let(:address) { 'tcp://127.0.0.1:12345' }

  before(:each) do
    Celluloid.shutdown
    Celluloid.boot
  end

  it_should_behave_like 'an RPC implementation'
end
