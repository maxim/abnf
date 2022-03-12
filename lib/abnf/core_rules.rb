require 'abnf/abnf'
require 'abnf/parser'

class ABNF
  class << self
    def core_rules
      @core_rules ||=
        parse(File.read("#{__dir__}/rfc5234_core_rules.abnf"), true)
    end
  end
end

if $0 == __FILE__
  require 'pp'
  pp ABNF.core_rules
end
