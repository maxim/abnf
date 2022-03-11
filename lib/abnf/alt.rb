require 'abnf/elt'

class ABNF
  class Alt < Elt
    class << Alt
      alias _new new
    end

    def Alt.new(*elts)
      elts2 = []
      elts.each {|e|
        if e.empty_set?
          next
        elsif Alt === e
          elts2.concat e.elts
        elsif Term === e
          if Term === elts2.last
            elts2[-1] = Term.new(elts2.last.natset + e.natset)
          else
            elts2 << e
          end
        else
          elts2 << e
        end
      }
      case elts2.length
      when 0; EmptySet
      when 1; elts2.first
      else; Alt._new(*elts2)
      end
    end

    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def empty_set?
      @elts.empty?
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Alt.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
end
