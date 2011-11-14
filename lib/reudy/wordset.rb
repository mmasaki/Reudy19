#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

require $REUDY_DIR+'/reudy_common'

module Gimite
  class Word #単語クラス
    def initialize(str, author = "", mids = [])
      @str = str #単語の文字列。
      @author = author #単語を教えた人。
      @mids = mids #この単語を含む発言の番号。
    end
  
    attr_accessor :str,:author,:mids
    
    def ==(other)
      return @str == other.str
    end
    
    def eql?(other)
      return @str == other.str
    end
    
    def hash
      return @str.hash
    end
    
    def <=>(other)
      return @str <=> other.str
    end
    
    def inspect
      return "<Word: \"#{str}\">"
    end
  end
  
  # 単語集
  class WordSet
    include Gimite, Enumerable
    
    def initialize(filename)
      @filename = filename
      @added_words = []
      File.open(filename, File::RDONLY|File::CREAT) do |f|
        @words = YAML.load(f) || []
      end
    end
  
    attr_reader :words
    
    #単語を追加
    def addWord(str, author = "")
      return nil if str.empty?
      i = @words.find_index{|word| str.include?(word.str) }
      if i && @words[i].str == str # 重複する単語があった場合
        return nil
      else
        word = Word.new(str, author)
        if i
          @words.insert(i, word)
        else
          @words.push(word)
        end
        @added_words.push(word)
        return word
      end
    end
    
    #ファイルに保存
    def save
      File.open(@filename, "w") do |f|
        YAML.dump(@words, f)
      end
    end
    
    #単語イテレータ
    def each
      @words.each
    end
    
    #中身をテキスト形式で出力。
    def output(io)
      @words.each do |word|
        io.puts "#{word.str}\t#{word.author}\t#{word.mids.join(",")}"
      end
    end
    
    private
    
    #既存のファイルとかぶらないファイル名を作る。
    def makeNewFileName(base)
      return base unless File.exist?(base)
      i = 2
      loop do
        name = base + i.to_s
        return name unless File.exist?(name)
        i += 1
      end
    end
  end
end
