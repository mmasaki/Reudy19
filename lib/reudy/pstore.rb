#Copyright (C) 2011 Glass_saga <glass.saga@gmail.com>
require 'pstore'

module Gimite
  class DB
    def initialize(filename)
      @db = PStore.new(filename)
    end
    
    def [](key)
      @db.transaction do
        return @db[key]
      end
    end
    
    def []=(key, value)
      @db.transaction do
        @db[key] = value
      end
    end
    
    def keys
      @db.transaction do
        return @db.roots
      end
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
    
    def close; end
  end
end
