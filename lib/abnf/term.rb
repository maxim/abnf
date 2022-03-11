require 'abnf/elt'
require 'natset'

class ABNF
  class Term < Elt
    class << Term
      alias _new new
    end

    def Term.new(natset)
      if natset.empty?
        EmptySet
      else
        Term._new(natset)
      end
    end

    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

    def empty_set?
      @natset.empty?
    end

    def each_var(&block) end
    def subst_var(&block) self end
  end
end
