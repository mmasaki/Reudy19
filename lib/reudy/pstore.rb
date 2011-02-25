#encoding: utf-8
require 'pstore'

module Gimite

class DB
  def initialize(*args)
    @db = PStore.new($REUDY_DIR+"/db")
  end
  
  def [](key)
    t = nil
    @db.transaction do
      t = @db[key]
    end
    return t
  end
  
  def []=(key, value)
    @db.transaction do
      @db[key] = value
    end
  end
  
  def keys
    t = nil
    @db.transaction do
      t = @db.roots
    end
    return t
  end
  
  def empty?
    @db.transaction do
      return @db.roots.empty?
    end
  end
  
  def clear
    @db.transaction do
      @db.roots.each do |key|
        @db.delete(key)
      end
    end
  end
  
  def close
  end
end

end #module Gimite

