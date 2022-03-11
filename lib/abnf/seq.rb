require 'abnf/elt'

class ABNF
  class Seq < Elt
    class << Seq
      alias _new new
    end

    def Seq.new(*elts)
      elts2 = []
      elts.each {|e|
        if e.empty_sequence?
          next
        elsif Seq === e
          elts2.concat e.elts
        elsif e.empty_set?
          return EmptySet
        else
          elts2 << e
        end
      }
      case elts2.length
      when 0; EmptySequence
      when 1; elts2.first
      else; Seq._new(*elts2)
      end
    end

    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def empty_sequence?
      @elts.empty?
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Seq.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
end
