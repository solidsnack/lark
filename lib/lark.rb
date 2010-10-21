require 'redis'

class LarkDBOffline < Exception ; end

module Lark
#  attr_accessor :id

  extend self;

  def configure(options)
    @domain = options[:domain]
    @expire = options[:expire]
    @urls   = options[:urls]
  end

  def domain
    @domain.to_s
  end

  def urls
    if @urls
      @urls
    elsif @url
      [ @url ]
    elsif ENV['LARK_URLS']
      ENV['LARK_URLS'].split(",")
    elsif ENV['LARK_URL']
      [ ENV['LARK_URL'] ]
    else
      [ "redis://127.0.0.1:6379/0" ]
    end
  end

  def dbs
    @dbs ||= urls.map do |url|
      puts "Connecting to #{url}";
      Redis.connect(:url => url)
    end
  end

  def index(group)
    "#{domain}:#{group}:idx"
  end

  ## all the black magic happens here
  ## pool runs the block against all the db's
  ## throws an error if non of them are online
  ## and returns an array of the block results
  ## from the ones who are online

  def pool(&blk)
    dbs.push dbs.shift

    num_errors = 0
    results = []
    begin
      dbs.each do |db|
        begin
          results << blk.call(db)
        rescue Errno::ECONNREFUSED, Timeout::Error => e
          puts "#{e.class}: #{e.message}"
          num_errors += 1
        end
      end
    ensure
      raise LarkDBOffline if num_errors == dbs.size
    end
    results
  end

  def on_expired(&blk)
    @expired = blk;
  end

  def index_search(group)
    pool { |db| db.smembers(index(group)) }.flatten.uniq.sort
  end

  def key(id, group)
    "#{domain}:#{group}:key:#{id}"
  end

  def destroy(id, group)
    pool do |db|
      db.multi do
        db.del key(id, group)
        db.srem index(group), id
      end
    end
    @expired.call(id, group) if @expired
  end

  def clean(group)
    index_search(group).reject { |i| load_data(i, group) }.each { |i| destroy(i, group) } 
  end

  def get_all(group)
    index_search(group).map { |i| load_data(i, group) }
  end

  def load_data(id, group)
    key = key(id, group)
    ## try each db - return when one works without an error
    ## throw an error if all are down
    pool do |db|
      data = db.hgetall(key)
      return data if not data.empty?
    end
    nil
  end

  def save_data(id, group, data)
    key = key(id,group)

    pool do |db|
      db.multi do
        db.hmset *[ key, data.to_a ].flatten
        db.expire key, @expire if @expire
        db.sadd index(group), id
      end
    end
  end

  def get(group)
    get_all(group).select { |i| i }
  end

  class Base
    attr_accessor :id, :group

    def initialize(_id, _group, _data = nil)
      @id      = _id
      @group   = _group
      @data    = _data
      save_data if @data
    end

    def key
      Lark.key(id, group)
    end

    def set(new_data)
      data.merge!(new_data)
      save_data
    end

    def save_data
      data[:created_on] ||= Time.new.to_i
      data[:updated_on] = Time.new.to_i
      data[:id] = id
      Lark.save_data(id, group, data)
    end

    def data
      @data ||= (Lark.load_data(key) || {})
    end

    def destroy
      Lark.destroy(id, group)
    end

    def pool(&blk)
      self.class.pool(&blk)
    end

  end
end
