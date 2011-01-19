#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
begin
  require 'gdbm'
  $NO_GDBM = false
rescue LoadError
  $NO_GDBM = true
end

module Gimite

unless $NO_GDBM
#値が文字列以外でもOKなGDBM（手抜き）
class MarshalGDBM
  def initialize(*args)
    @gdbm = GDBM.new(*args)
  end
  
  def [](key)
    str = @gdbm[key]
    return str && Marshal.load(str).freeze
      #オブジェクトの中身を変更されてもDBに反映できないので、freeze()しておく
  end
  
  def []=(key, value)
    @gdbm[key] = Marshal.dump(value)
  end
  
  def keys
    return @gdbm.keys
  end
  
  def empty?
    return @gdbm.empty?
  end
  
  def clear
    @gdbm.clear
  end
  
  def close
    @gdbm.close
  end
  end

end #if !$NO_GDBM
end #module Gimite

