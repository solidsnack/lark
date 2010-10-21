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

  def self.dbs
    @dbs ||= urls.map do |url|
      puts "Connecting to #{url}";
      Redis.connect(:url => url)
    end
  end

  ## all the black magic happens here
  ## pool runs the block against all the db's
  ## throws an error if non of them are online
  ## and returns an array of the block results
  ## from the ones who are online

  def self.pool(&blk)
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

  def load_data
    ## try each db - return when one works without an error
    ## throw an error if all are down
    pool do |db|
      data = db.hgetall(key)
      return data if not data.empty?
    end
    {}
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
    pool do |db|
      db.multi do
        db.hmset *[ key, data.to_a ].flatten
        db.expire key, @expire if @expire
        db.sadd set_key, @id
      end
    end
  end

  def data
    @data ||= load_data
  end

  def destroy
    pool do |db|
      db.multi do
        db.del key
        db.srem set_key, id
      end
    end
    self.class.expired.call(id, @domain);
  end

  def all_ids
    pool { |db| db.smembers(set_key) }.flatten.uniq.sort
  end

  def find_ids(match)
    all_ids.select { |_id| match.match(_id) }
  end

  def find_valid(match)
    all = find_ids(match).map { |_id| Lark.new(_id, @options) }
    valid = all.reject { |l| l.data.empty? }
    invalid = all - valid
    invalid.each { |i| i.destroy }
    valid
  end

  def find(match = //)
    result = {}
    find_valid(match).each { |v| result[v.id] = v.data }
    result
  end

  def pool(&blk)
    self.class.pool(&blk)
  end

end
