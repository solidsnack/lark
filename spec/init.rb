
require File.dirname(__FILE__) + "/../lib/lark"
require "bacon"
require "mocha/api"
require "mocha/object"

class Bacon::Context
  include Mocha::API
  alias_method :old_it,:it
  def it description,&block
    mocha_setup
    old_it(description,&block)
    mocha_verify
    mocha_teardown
  end
end

