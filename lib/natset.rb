require 'pp'

# Natset represents a set of naturals - non-negative integers.
class Natset
  attr_reader :ranges

  class << self
    alias empty new
    def universal; new(0..) end

    # Casts different types of objects into ranges of natural numbers before
    # adding them into the set.
    #
    # * Casts strings and string ranges into their character code equivalents.
    # * Replaces Float::INFINITY at the end of a range with nil (endless).
    # * Casts individual strings into character codes.
    # * Relies on initialize to normalize casted values.
    def cast(*items); new(*items.flat_map { |item| cast_item(item) }) end
    alias [] cast

    private

    def cast_item(item)
      return item.ranges          if self === item
      return (item.ord..item.ord) if String === item
      return (item..item)         if Integer === item

      bad_value!(item) unless Range === item
      bad_value!(item) unless castable_range_type?(item.begin)
      bad_value!(item) unless castable_range_type?(item.end)

      new_begin =
        case item.begin
        when String;  item.begin.ord
        else;         item.begin
        end

      new_end =
        case item.end
        when String;          item.max.ord
        when Integer;         item.max
        when Float::INFINITY; nil
        else;                 item.end
        end

      (new_begin..new_end)
    end

    def castable_range_type?(value)
      [nil, String, Integer, Float::INFINITY].any? { |type| type === value }
    end

    def bad_value!(value)
      raise ArgumentError, "bad value for #{self}.from_misc: #{value}"
    end
  end

  # Accepts natural numbers and ranges of natural numbers. Performs
  # sorting and concatenation of ranges where needed.
  def initialize(*values)
    @ranges = validate_sort_and_concat(*values)
  end

  def universal?; self == self.class.universal end
  def empty?;     @ranges.empty? end
  def open?;      @ranges.last&.size&.infinite? end
  def singleton?; @ranges.one? && @ranges[0].one? && @ranges[0].begin || nil end
  def min;        @ranges.first&.begin end
  def max;        @ranges.last && (@ranges.last.end || Float::INFINITY) end
  def hash;       @ranges.hash end
  def size;       @ranges.sum(&:size) end

  def ==(other); @ranges == other.ranges end
  alias === ==
  alias eql? ==

  # Returns a new set with elements of both set.
  def merge(other); self.class.new(*ranges, *other.ranges) end
  alias union merge
  alias + merge
  alias | merge

  # Returns a new set with elements not in this set.
  def complement
    return self.class.universal if empty?
    return self.class.empty if universal?

    complements =
      @ranges.each_with_object([0..]) { |r, comps|
        r.begin.zero? ? comps.shift : comps[-1] = comps[-1].begin..(r.begin - 1)
        comps << ((r.end + 1)..) unless r.end.nil?
      }

    self.class.new(*complements)
  end
  alias ~ complement

  # Returns a new set with elements that strictly exist in both sets.
  def intersect(other)
    i1 = i2 = 0
    intersection = []

    while i1 < @ranges.size && i2 < other.ranges.size
      r1, r2 = @ranges[i1], other.ranges[i2]
      (i1 += 1; next) if r1.end && (r1.end < r2.begin)
      (i2 += 1; next) if r2.end && (r2.end < r1.begin)
      intersection << ([r1.begin, r2.begin].max..[r1.end, r2.end].compact.min)
      r1.end && (r1.end < (r2.end || Float::INFINITY)) ? i1 += 1 : i2 += 1
    end

    self.class.new(*intersection)
  end
  alias & intersect

  def include?(int)
    @ranges.bsearch { |r| r.cover?(int) ? 0 : int <=> r.begin }
  end

  # Returns a new set with elements of this set that are not in the other set.
  def subtract(other)
    return self if empty? || other.empty?
    return self.class.empty if other.universal?
    return ~other if universal?

    i1 = i2 = offset = 0
    diff = []

    while i1 < @ranges.size && i2 < other.ranges.size
      r1, r2 = @ranges[i1], other.ranges[i2]
      r1_end, r2_end = (r1.end || Float::INFINITY), (r2.end || Float::INFINITY)

      if r2_end >= r1.begin
        s_beg = [offset, r1.begin].max
        s_end = [(r2.begin - 1), r1_end].min
        diff << (s_beg..(s_end.infinite? ? nil : s_end)) if s_beg <= s_end
      end

      (i1 += 1) if r1_end <= r2_end
      (i2 += 1; offset = r2_end + 1) if r2_end <= r1_end
    end

    if @ranges[i1]
      if offset <= @ranges[i1].begin
        diff.concat(@ranges[i1..])
      else
        diff << (offset..@ranges[i1].end)
        diff.concat(@ranges[(i1 + 1)..])
      end
    end

    self.class.new(*diff)
  end
  alias - subtract

  def pretty_print(pp)
    pp.object_group(self) do
      pp.text ':'
      ranges.each do |r|
        pp.breakable
        pp.text(r.begin == r.end ? r.begin.to_s : r.to_s)
      end
    end
  end

  def inspect; PP.singleline_pp(self, '') end

  private

  def validate_sort_and_concat(*values)
    return values if values.empty?

    values
      .map! { |v| validate_rangify_and_cap(v) }
      .sort_by!(&:begin)
      .each_with_object([values.shift]) { |range, agg|
        next if agg.last.cover?(range)

        if range.cover?(agg.last)
          agg[-1] = range
        elsif agg.last.end.succ >= range.begin
          agg[-1] = (agg[-1].begin..range.end)
        else
          agg << range
        end
      }
  end

  def validate_rangify_and_cap(val)
    return validate_rangify_and_cap(val..val) if Integer === val
    bad_value!(val) unless Range === val
    bad_value!(val) if [val.begin, val.end].any? { |v| !nil_or_natural?(v) }
    return validate_rangify_and_cap(0..val.end) if val.begin.nil?
    bad_value!(val) if (val.begin == val.end) && val.exclude_end?
    bad_value!(val) if val.end && (val.begin > val.end)
    val.exclude_end? ? (val.begin..(val.end && (val.end - 1))) : val
  end

  def nil_or_natural?(value)
    value.nil? || (value.is_a?(Integer) && value >= 0)
  end

  def bad_value!(value)
    raise ArgumentError, "bad value for #{self.class}: #{value}"
  end
end
