require 'abnf/element'

class ABNF
  class Alt < Element
    attr_reader :elts

    class << self
      def from_elements(*elts)
        result = elts.each_with_object([]) { |e, result|
          next if e.empty_set?

          if Alt === e
            result.concat e.elts
          elsif Term === e && Term === result.last
            result[-1] = Term.new(result.last.natset + e.natset)
          else
            result << e
          end
        }

        case result.size
        when 0; EmptySet
        when 1; result.first
        else; new(*result)
        end
      end
    end

    def initialize(*elts)
      @elts = elts
    end

    def empty_set?
      @elts.empty?
    end

    def useful?(useful_names)
      @elts.any? { |e| e.useful?(useful_names) }
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block)
      self.class.from_elements(*@elts.map {|elt| elt.subst_var(&block)})
    end
  end
end
