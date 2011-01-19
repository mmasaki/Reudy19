#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require 'pstore'
$NO_GDBM = false

module Gimite

unless $NO_GDBM
#値が文字列以外でもOKなGDBM（手抜き）
class DB
  def initialize(*args)
    @db = PStore.new("db")
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
    t = nil
    @db.transaction do
      t = @db.roots.empty?
    end
    return t
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

end #if !$NO_GDBM
end #module Gimite

