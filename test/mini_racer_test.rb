require 'test_helper'

class MiniRacerTest < Minitest::Test

  def test_it_can_use_snapshots
    snapshot = MiniRacer::Snapshot.new('function hello() { return "world"; }; var foo = "bar";')

    context = MiniRacer::Context.new(snapshot: snapshot)

    assert_equal "world", context.eval("hello()")
    assert_equal "bar", context.eval("foo")
  end

  # TODO wkpo
  def test_buggy_snapshots_throw_an_exception
    
  end
end
