
require File.dirname(__FILE__) + "/init.rb"

describe 'Lark' do
      before do
        @lark = Lark.new "lark", :domain => "domain"
        @db1 = mock()
        @db2 = mock()
        Lark.stubs(:dbs).returns([@db1, @db2]);
      end

      it 'should locate the data even if the key and data are on different databases' do
        @db1.expects(:smembers).returns([ "key1" ])
        @db1.expects(:hgetall).with("domain:key1").returns({})
        @db2.expects(:smembers).returns([ ])
        @db2.expects(:hgetall).with("domain:key1").returns({"foo" => "bar"})

        @lark.find.should.equal({ "key1" => {"foo" => "bar"} })
      end

      it 'should get the union of the ids on each server' do
        @db1.expects(:smembers).returns([ "a", "b" ])
        @db2.expects(:smembers).returns([ "b", "c" ])
        @lark.all_ids.should.equal ["a","b","c"]
      end

      # it 'should run delete on old objects'
      # it 'should invoke a handler when deleting old objects'
      # it 'should fetch data properly when one redis is offline'
      # it 'should raise an exception if all redis are offline'
end
