require 'abnf/element'

class ABNF
  class Rep < Element
    class << Rep
      alias _new new
    end

    def Rep.new(elt, min=0, max=nil, greedy=true)
      return EmptySeq if min == 0 && max == 0
      return elt if min == 1 && max == 1
      return EmptySeq if elt.empty_sequence?
      if elt.empty_set?
        return min == 0 ? EmptySeq : EmptySet
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
