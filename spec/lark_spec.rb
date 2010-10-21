
require File.dirname(__FILE__) + "/init.rb"

describe 'Lark' do
      before do
        @redis1 = mock()
        @redis2 = mock()
        Lark.stubs(:redis_pool).returns([@redis1, @redis2]);
        @lark = Lark.new "lark", :domain => "domain"
      end

      it 'should locate the data even if the key and data are on different databases' do
        Lark.redis_pool[1].expects(:smembers).returns([ "key1" ])
        Lark.redis_pool[1].expects(:hgetall).with("domain:key1").returns({})
        Lark.redis_pool[0].expects(:smembers).returns([ ])
        Lark.redis_pool[0].expects(:hgetall).with("domain:key1").returns({"foo" => "bar"})

        @lark.find.should.equal({ "key1" => {"foo" => "bar"} })
      end

      # it 'should run delete on old objects' 
      # it 'should invoke a handler when deleting old objects'
      # it 'should fetch data properly when one redis is offline'
      # it 'should raise an exception if all redis are offline'
end
