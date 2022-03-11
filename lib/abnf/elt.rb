class ABNF
  class Elt
    # A variable is assumed as not empty set.
    def empty_set?
      false
    end

    # A variable is assumed as not empty sequence.
    def empty_sequence?
      false
    end

    def +(other)
      Seq.new(self, other)
    end

    def |(other)
      Alt.new(self, other)
    end

    def *(n)
      case n
      when Integer
        rep(n, n)
      when Range
        rep(n.first, n.last - (n.exclude_end? ? 1 : 0))
      else
        raise TypeError.new("Integer or Range expected: #{n}")
      end
    end

    def rep(min=0, max=nil, greedy=true)
      Rep.new(self, min, max, greedy)
    end
  end
end
