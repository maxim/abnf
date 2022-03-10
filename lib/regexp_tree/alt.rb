class RegexpTree
  class Alt < RegexpTree
    PRECEDENCE = 2
    attr_reader :rs

    def initialize(rs)
      @rs = rs
    end

    def empty_set?
      @rs.empty?
    end

    def case_insensitive?
      @rs.all? {|r| r.case_insensitive?}
    end

    def multiline_insensitive?
      @rs.all? {|r| r.multiline_insensitive?}
    end

    def downcase
      Alt.new(@rs.map {|r| r.downcase})
    end

    def pretty_format(out)
      if @rs.empty?
        out.text '(?!)'
      else
        out.group {
          @rs.each_with_index {|r, i|
            unless i == 0
              out.text '|'
              out.breakable ''
            end
            r.parenthesize(Alt).pretty_format(out)
          }
        }
      end
    end
  end
end
