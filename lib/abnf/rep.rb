require 'abnf/elt'

class ABNF
  class Rep < Elt
    class << Rep
      alias _new new
    end

    def Rep.new(elt, min=0, max=nil, greedy=true)
      return EmptySequence if min == 0 && max == 0
      return elt if min == 1 && max == 1
      return EmptySequence if elt.empty_sequence?
      if elt.empty_set?
        return min == 0 ? EmptySequence : EmptySet
      end
      Rep._new(elt, min, max, greedy)
    end

    def initialize(elt, min=0, max=nil, greedy=true)
      @elt = elt
      @min = min
      @max = max
      @greedy = greedy
    end
    attr_reader :elt, :min, :max, :greedy

    def useful?(useful_names)
      @min == 0 ? true : @elt.useful?(useful_names)
    end

    def each_var(&block) @elt.each_var(&block) end
    def subst_var(&block) Rep.new(@elt.subst_var(&block), min, max, greedy) end
  end
end
