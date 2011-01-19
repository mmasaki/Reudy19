#encoding: utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require 'gdbm'

module Gimite

#値が文字列以外でもOKなGDBM（手抜き）
class DB
  def initialize(fileName)
    @gdbm = GDBM.new(fileName, 0666, GDBM::FAST)
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

end #module Gimite

