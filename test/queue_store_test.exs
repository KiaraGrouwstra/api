defmodule QueueStoreTest do
  use ExUnit.Case, async: false
  import Api.QueueStore
  use Amnesia
  use QueueDB

  @domain "example.com"
  @val "foo"

  # setup_all do
  #   Mix.Task.run "amnesia.drop", ["-db QueueDB"]
  #   Mix.Task.run "amnesia.create", ["-db QueueDB", "--disk"]
  #   {:ok, []}
  # end

  setup do
    iterate &delete/1
    on_exit fn ->
      # delete(@domain)
      iterate &delete/1
    end
    {:ok, []}
  end

  test "push, pop" do
    # failure due to existing fetcher process? could I terminate these through a central parent too?
    assert push(@domain, @val) == :created # :ok?
    assert pop(@domain) == {:value, @val}
  end

  test "pop empty" do
    assert pop(@domain) == :empty
  end

  test "init" do
    assert init(@domain) == :queue.new()
  end

  test "delete" do
    init(@domain)
    delete(@domain)
    assert (Amnesia.transaction do
      Queue.read(@domain)
    end) == :nil
  end

  import ExUnit.CaptureIO
  defp check_domains() do
    capture_io(fn ->
      iterate &IO.puts/1
    end)
  end

  test "clean slate" do
    assert check_domains() == ""
  end

  test "iterate" do
    init(@domain)
    assert check_domains() == "#{@domain}\n"
  end

  # test "consume_queue" do
  #   consume_queue(@domain, &IO.puts/1) # can't print a queue, recursive so won't terminate
  # end

end
