require 'redis'

class LarkDBOffline < Exception ; end

class Lark
  attr_accessor :id

  def self.urls
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
    @redis_pool.push @redis_pool.shift
  end

  def redis_pool
    self.class.redis_pool
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

  def safe_access(&blk)
    blk.call();
    rescue Errno::ECONNREFUSED
      puts "CON REFUSTED"
    rescue Timeout::Error
      puts "TIMEOUT"
  end

  def load_data
    ## try each redis - return when one works without an error
    ## throw an error if all are down
    data = nil
    redis_pool.each do |redis|
      safe_access do
        data = redis.hgetall(key)
        return data unless data.empty?
      end
    end
    raise LarkDBOffline if data.nil?
    data
  end

  def all_redis(&blk)
    ## try all redis - throw an error if none of them worked
    ## return an array of all the results
    results = []
    redis_pool.each do |redis|
      safe_access do
        results << blk.call(redis)
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

  def all_ids
    all_redis { |redis| redis.smembers(set_key) }.flatten.uniq
  end

  def find_ids(match)
    a = all_ids.select { |_id| match.match(_id) }
    puts "find_ids #{a.inspect}"
    a
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
