require 'abnf/element'
require 'natset'

class ABNF
  class Term < Element
    attr_reader :natset

    def initialize(natset)
      @natset = natset.empty? ? EmptySet : natset
    end

    def empty_set?
      @natset.empty?
    end

    def useful?(_)
      true
    end

    def each_var(&block) end
    def subst_var(&block) self end
  end
end
