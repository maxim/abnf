require 'natset'

class NatsetTest < Test::Unit::TestCase
  def test_empty
    assert Natset.empty.empty?
  end

  def test_universal
    assert Natset.universal.universal?
  end

  def test_open
    assert !Natset.empty.open?
    assert Natset.universal.open?
  end

  def test_singleton
    assert_equal 1, Natset[1].singleton?
    assert_equal nil, Natset[1..2].singleton?
  end

  def test_complement
    assert_equal Natset.empty,     ~Natset.universal
    assert_equal Natset.universal, ~Natset.empty
    assert_equal Natset[1],        ~Natset[0, 2..]
    assert_equal Natset[0, 2..],   ~Natset[1]
  end

  def test_union
    assert_equal Natset.empty,     Natset.empty + Natset.empty
    assert_equal Natset.universal, Natset.empty + Natset.universal
    assert_equal Natset.universal, Natset.universal + Natset.empty
    assert_equal Natset.universal, Natset.universal + Natset.universal
    assert_equal Natset[0..2], Natset[0, 2] + Natset[0, 1]
  end

  def test_intersect
    assert_equal Natset.empty,     Natset.empty & Natset.empty
    assert_equal Natset.empty,     Natset.empty & Natset.universal
    assert_equal Natset.empty,     Natset.universal & Natset.empty
    assert_equal Natset.universal, Natset.universal & Natset.universal
    assert_equal Natset[0],        Natset[0, 2] & Natset[0, 1]
  end

  def test_subtract
    assert_equal Natset.empty,     Natset.empty - Natset.empty
    assert_equal Natset.empty,     Natset.empty - Natset.universal
    assert_equal Natset.universal, Natset.universal - Natset.empty
    assert_equal Natset.empty,     Natset.universal - Natset.universal
    assert_equal Natset[2],        Natset[0, 2] - Natset[0, 1]
  end

  def test_new
    assert_equal [1..1], Natset.new(1).ranges
    assert_equal [1..2], Natset.new(1, 2).ranges
    assert_equal [1..3], Natset.new(1, 2, 3).ranges
    assert_equal [1..3], Natset.new(1, 3, 2).ranges
    assert_equal [10..20], Natset.new(10..20).ranges
    assert_equal [10..19], Natset.new(10...20).ranges
    assert_equal [1..1, 3..3, 5..5], Natset.new(1, 3, 5).ranges
    assert_equal [1..15], Natset.new(5..15, 1..10).ranges
    assert_equal [1..15], Natset.new(11..15, 1..10).ranges

    assert_raises(ArgumentError) { Natset.new("a") }
    assert_raises(ArgumentError) { Natset.new("a".."b") }
    assert_raises(ArgumentError) { Natset.new(-1) }
    assert_raises(ArgumentError) { Natset.new(-1..3) }
  end

  def test_cast
    assert_equal [1..], Natset[1..Float::INFINITY].ranges
    assert_equal [0..10], Natset[..10].ranges
    assert_equal [0..], Natset[..nil].ranges
    assert_equal [97..122], Natset['a'..'z'].ranges
    assert_equal [0..0, 2..2], Natset[0, 2].ranges
  end

  def test_min
    assert_equal nil, Natset[].min
    assert_equal 1, Natset[1..10].min
  end

  def test_max
    assert_equal nil, Natset[].max
    assert_equal 10, Natset[1..10].max
    assert_equal Float::INFINITY, Natset[1..].max
  end

  def test_include
    assert Natset[1..20].include?(10)
    assert Natset[1..].include?(10)
    assert Natset.universal.include?(10)

    refute Natset.empty.include?(10)
    refute Natset[1..].include?(0)
    refute Natset[2..4, 6..10].include?(5)
  end
end
