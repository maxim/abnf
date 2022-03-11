require 'abnf/element'

class ABNF
  class Var < Element
    def initialize(name)
      @name = name
    end
    attr_reader :name

    def useful?(useful_names)
      useful_names[@name]
    end

    def each_var(&block) yield @name end
    def subst_var(&block) yield(@name) || self end
  end
end
