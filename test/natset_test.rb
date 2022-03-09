require 'natset'

class NatSetTest < Test::Unit::TestCase
  def test_empty
    assert NatSet.empty.empty?
  end

  def test_universal
    assert NatSet.universal.universal?
  end

  def test_open
    assert !NatSet.empty.open?
    assert NatSet.universal.open?
  end

  def test_singleton
    assert_equal 1, NatSet[1].singleton?
    assert_equal nil, NatSet[1..2].singleton?
  end

  def test_complement
    assert_equal NatSet.empty,     ~NatSet.universal
    assert_equal NatSet.universal, ~NatSet.empty
    assert_equal NatSet[1],        ~NatSet[0, 2..]
    assert_equal NatSet[0, 2..],   ~NatSet[1]
  end

  def test_union
    assert_equal NatSet.empty,     NatSet.empty + NatSet.empty
    assert_equal NatSet.universal, NatSet.empty + NatSet.universal
    assert_equal NatSet.universal, NatSet.universal + NatSet.empty
    assert_equal NatSet.universal, NatSet.universal + NatSet.universal
    assert_equal NatSet[0..2], NatSet[0, 2] + NatSet[0, 1]
  end

  def test_intersect
    assert_equal NatSet.empty,     NatSet.empty & NatSet.empty
    assert_equal NatSet.empty,     NatSet.empty & NatSet.universal
    assert_equal NatSet.empty,     NatSet.universal & NatSet.empty
    assert_equal NatSet.universal, NatSet.universal & NatSet.universal
    assert_equal NatSet[0],        NatSet[0, 2] & NatSet[0, 1]
  end

  def test_subtract
    assert_equal NatSet.empty,     NatSet.empty - NatSet.empty
    assert_equal NatSet.empty,     NatSet.empty - NatSet.universal
    assert_equal NatSet.universal, NatSet.universal - NatSet.empty
    assert_equal NatSet.empty,     NatSet.universal - NatSet.universal
    assert_equal NatSet[2],        NatSet[0, 2] - NatSet[0, 1]
  end

  def test_new
    assert_equal [1..1], NatSet.new(1).ranges
    assert_equal [1..2], NatSet.new(1, 2).ranges
    assert_equal [1..3], NatSet.new(1, 2, 3).ranges
    assert_equal [1..3], NatSet.new(1, 3, 2).ranges
    assert_equal [10..20], NatSet.new(10..20).ranges
    assert_equal [10..19], NatSet.new(10...20).ranges
    assert_equal [1..1, 3..3, 5..5], NatSet.new(1, 3, 5).ranges
    assert_equal [1..15], NatSet.new(5..15, 1..10).ranges
    assert_equal [1..15], NatSet.new(11..15, 1..10).ranges

    assert_raises(ArgumentError) { NatSet.new("a") }
    assert_raises(ArgumentError) { NatSet.new("a".."b") }
    assert_raises(ArgumentError) { NatSet.new(-1) }
    assert_raises(ArgumentError) { NatSet.new(-1..3) }
  end

  def test_cast
    assert_equal [1..], NatSet[1..Float::INFINITY].ranges
    assert_equal [0..10], NatSet[..10].ranges
    assert_equal [0..], NatSet[..nil].ranges
    assert_equal [97..122], NatSet['a'..'z'].ranges
    assert_equal [0..0, 2..2], NatSet[0, 2].ranges
  end

  def test_min
    assert_equal nil, NatSet[].min
    assert_equal 1, NatSet[1..10].min
  end

  def test_max
    assert_equal nil, NatSet[].max
    assert_equal 10, NatSet[1..10].max
    assert_equal Float::INFINITY, NatSet[1..].max
  end

  def test_include
    assert NatSet[1..20].include?(10)
    assert NatSet[1..].include?(10)
    assert NatSet.universal.include?(10)

    refute NatSet.empty.include?(10)
    refute NatSet[1..].include?(0)
    refute NatSet[2..4, 6..10].include?(5)
  end
end
