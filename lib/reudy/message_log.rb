#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require $REUDY_DIR+'/reudy_common'
require 'psych' #UTF-8をバイナリで書き出さないようにする
require "yaml"

module Gimite

#個々の発言
class Message
  def initialize(fromNick, body)
    @fromNick = fromNick
    @body = body
  end

  attr_accessor :fromNick,:body
end

#発言ログ
class MessageLog
  include Gimite
  
  def initialize(innerFileName)
    @innerFileName = innerFileName
    @observers = []
    File.open(innerFileName) do |f|
      @size = f.readlines("\n---").size
    end
  end

  attr_accessor :size
  
  #観察者を追加。
  def addObserver(*observers)
    @observers += observers
  end

  #n番目の発言
  def [](n)
    n += @size if n < 0 #末尾からのインデックス
    File.open(@innerFileName) do |f|
      f.each_line("\n---") do |s|
        next if f.lineno <= n
        m = YAML.load(s)
        return Message.new(m[:fromNick], m[:body])
      end
    end
  end
  
  #発言を追加
  def addMsg(fromNick, body, toOuter = true)
    File.open(@innerFileName,"a") do |f|
      f.print YAML.dump({:fromNick => fromNick, :body => body})
    end
    @size += 1
    @observers.each do |observer|
      observer.onAddMsg
    end
  end
 
  private
  
  #内部データをクリア
  def clear
    default = ""
    File.open(@innerFileName) do |f|
      f.each_line("\n---") do |s|
        new_data << s if YAML.load(s)[:fromNick] == "Default"
      end
    end
    File.open(@innerFileName,"w") do |f|
      f.puts default
    end
    File.open(@innerFileName) do |f|
      @size = f.readlines("\n---").size
    end
  end
end

end #module Gimite
