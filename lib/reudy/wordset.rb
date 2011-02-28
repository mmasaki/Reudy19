#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require "fileutils"
require $REUDY_DIR+'/reudy_common'

module Gimite
class Word #単語クラス
  def initialize(s, a = "", m = [])
    @str = s #単語の文字列。
    @author = a #単語を教えた人。
    @mids = m #この単語を含む発言の番号。
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
    @addedWords = []
    if File.exist?(filename)
      File.open(filename) do |f|
        @words = YAML.load(f)
      end
    end
    @words = [] unless @words
  end

  attr_reader :words
  
  #単語を追加
  def addWord(str, author = "")
    word = Word.new(str, author)
    i = 0
    while i < @words.size
      break if str.index(@words[i].str)
      i += 1
    end
    if @words[i] && @words[i].str == str
      return nil
    else
      @words[i, 0]= [word]
      @addedWords.push(word)
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
    @words.each do |word|
      yield(word)
    end
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
      return name unless File.exist?(base+i.to_s)
      i += 1
    end
  end
end

end #module Gimite
