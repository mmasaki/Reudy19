#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

require $REUDY_DIR+'/reudy_common'
require "psych" #UTF-8をバイナリで書き出さないようにする
require "yaml"

module Gimite
  #個々の発言
  class Message
    def initialize(from_nick, body)
      @fromNick = from_nick
      @body = body
    end
  
    attr_accessor :fromNick,:body
  end
  
  #発言ログ
  class MessageLog
    include Gimite
    
    def initialize(inner_filename)
      @innerFileName = inner_filename
      @observers = []
      File.open(inner_filename) do |f|
        @size = f.lines("\n---").count
      end
    end
  
    attr_accessor :size
    
    #観察者を追加。
    def addObserver(*observers)
      @observers.concat(observers)
    end
  
    #n番目の発言
    def [](n)
      n += @size if n < 0 #末尾からのインデックス
      File.open(@innerFileName) do |f|
        line = f.lines("\n---").find{ f.lineno > n }
        if line && line != "\n---"
          m = YAML.load(line)
          return Message.new(m[:fromNick], m[:body])
        else
          return nil
        end
      end
    end
    
    #発言を追加
    def addMsg(from_nick, body, to_outer = true)
      File.open(@innerFileName, "a") do |f|
        YAML.dump({:fromNick => from_nick, :body => body}, f)
      end
      @size += 1
      @observers.each(&:onAddMsg)
    end
   
    private
    
    #内部データをクリア(デフォルトのログのみ残す)
    def clear
      File.open(@innerFileName, "w") do |f|
        default = f.lines("\n---").select{|s| YAML.load(s)[:fromNick] == "Default" }
        f.rewind
        f.puts default.join
        f.truncate(f.size)
        @size = default.size
      end
    end
  end
end
