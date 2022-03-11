require 'abnf/elt'

class ABNF
  class Var < Elt
    def initialize(name)
      @name = name
    end
    attr_reader :name

    def each_var(&block) yield @name end
    def subst_var(&block) yield(@name) || self end
  end
end
