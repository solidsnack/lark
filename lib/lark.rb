require 'redis'

class LarkDBOffline < Exception ; end

class Lark
  attr_accessor :id

  def self.urls=(urls)
    @urls = urls
  end

  def self.urls
    @urls ||= locate_urls
  end

  def self.locate_urls
    if ENV['LARK_URLS']
      ENV['LARK_URLS'].split(",")
    elsif ENV['LARK_URL']
      [ ENV['LARK_URL'] ]
    else
      [ "redis://127.0.0.1:6379/0" ]
    end
  end

  def self.redis_pool
    @redis_pool ||= urls.map do |url| 
      puts "Connecting to #{url}";
      Redis.connect(:url => url)
    end
  end

  def self.round_robin_redis
    redis_pool.push redis_pool.shift
  end

  def self.on_expired(&blk)
    @expired = blk;
  end

  def self.expired
    @expired
  end

  def initialize(_id, options = {})
    @id = _id
    @options = options
    @domain = options[:domain]
    @expire = options[:expire] 
  end

  def union(&blk)
  end

  def load_data
    ## try each redis - return when one works without an error
    ## throw an error if all are down
    data = nil
    self.class.round_robin_redis.each do |redis|
      begin
        data = redis.hgetall(key)
        break unless data.empty?
      rescue Errno::ECONNREFUSED
      rescue Timeout::Error
      end
    end
    raise LarkDBOffline if data.nil?
    puts "RETURNING DATA: #{data.inspect}"
    data
  end

  def all_redis(&blk)
    ## try all redis - throw an error if none of them worked
    results = []
    self.class.redis_pool.each do |redis|
      begin
        results << blk.call(redis)
      rescue Errno::ECONNREFUSED
      rescue Timeout::Error
      end
    end
    raise LarkDBOffline if results.empty?
    results
  end

  def key
    "#{@domain}:#{@id}"
  end

  def set_key
    "#{@domain}:lark:all"
  end

  def set(new_data)
    puts "SET"
    data.merge!(new_data)
    save_data
  end

  def save_data
    data[:created_on] ||= Time.new.to_i
    data[:domain] ||= @domain
    data[:updated_on] = Time.new.to_i
    all_redis do |redis|
      redis.multi do
        redis.hmset *[ key, data.to_a ].flatten
        redis.expire key, @expire if @expire
        redis.sadd set_key, @id
      end
    end
  end

  def data
    puts "DATA #{@data.inspect}"
    @data ||= load_data
  end

  def valid?
    if data.empty?
      destroy
      false
    else
      true
    end
  end

  def destroy
    all_redis do |redis|
      redis.multi do
        redis.del key
        redis.srem set_key, id
      end
    end
    self.class.expired.call(id, @domain);
  end

  def find_ids(match)
    ## get memebers from all and union
    a1 = all_redis { |redis| redis.smembers(set_key) }
#    puts "A1: #{a1.inspect}"
    a2 = a1.flatten.uniq.select { |_id| match.match(_id) }
#    puts "A2: #{a2.inspect}"
    a2
  end

  def find_valid(match)
    find_ids(match).map { |_id| Lark.new(_id, @options) }.select { |l| l.valid? }
  end

  def find(match = //)
    result = {}
    find_valid(match).each { |v| result[v.id] = v.data }
    result
  end
end
