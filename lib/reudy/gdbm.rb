#encoding: utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>
require 'gdbm'

module Gimite
  #値が文字列以外でもOKなGDBM（手抜き）
  class DB
    def initialize(file_name)
      @gdbm = GDBM.new(file_name, 0666, GDBM::FAST)
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
      @gdbm.keys
    end
    
    def empty?
      @gdbm.empty?
    end
    
    def clear
      @gdbm.clear
    end
    
    def close
      @gdbm.close
    end
  end
end
