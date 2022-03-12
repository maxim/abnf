require 'abnf/abnf'
require 'abnf/parser'

class ABNF
  CoreRules = ABNF.parse(File.read("#{__dir__}/rfc5234_core_rules.abnf"), true)
end

if $0 == __FILE__
  require 'pp'
  pp ABNF::CoreRules
end
