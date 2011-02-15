#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require "fileutils"
require $REUDY_DIR+'/reudy_common'

module Gimite
class Word #単語クラス
  #注：このクラスのインスタンスはMarshalで保存されるので、
  #    気軽にインスタンス変数名を変えない事。
  def initialize(s, a = "", m = [])
    @str = s #単語の文字列。
    @author = a #単語を教えた人。
    @mids = m #この単語を含む発言の番号。
  end
  
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

  attr_accessor :str,:author,:mids
end

# 単語集
class WordSet
  include Gimite
  
  include Enumerable
  
  def initialize(innerFileName)
    @innerFileName = innerFileName
    @outerFileName = nil
    @innerFileTime = nil
    @addedWords = []
    if File.exist?(@innerFileName)
      @innerFileTime = File.mtime(@innerFileName)
      Kernel.open(@innerFileName, "r") do |file|
        @words = Marshal.load(file)
      end
    else
      @words = []
    end
  end
  
  #外部ファイルを登録し、外部ファイルの内容を内部データに反映する。
  def updateByOuterFile(outerFileName, wtmlManager)
    @outerFileName = outerFileName
    return if !File.exists?(@outerFileName) || (@innerFileTime && @innerFileTime >= File.mtime(@outerFileName))
    warn "@outerFileName が変更されたようです。単語を読み込み中..."
    addedWords = @addedWords
    @addedWords.clear
    isOldFormat = false
    n = 0
    Kernel.open(@outerFileName, "r") do |file|
      file.each_line do |str|
        #外部ファイル中の単語を追加する。
        #内部データに有って外部ファイルに無い単語については、現バージョンでは何もしていないので注意。
        #data[1], data[2]はVer.3.04以前のデータを引き継ぐために使われる。
        str.chomp!
        next if str.empty?
        warn "#{n+1}語目..." if ((n+1) % 100).zero?
        word = addWord(str)
        if word
          warn "単語「#{word.str}」を追加中..."
          wtmlManager.attachMsgList(word)
        end
        n += 1
      end
    end
    @addedWords = addedWords  #initializeとupdateByOuterFileの間に追加された単語を外部ファイルに保存。
    save
  end
  
  #単語を追加
  def addWord(str, author= "")
    word = Word.new(str, author)
    i = 0
    size = @words.size
    while i < size
      break if str.include?(@words[i].str)
      i += 1
    end
    if @words[i] && @words[i].str == str
      return nil
    else
      @words[i, 0] = [word]
      @addedWords.push(word)
      return word
    end
  end
  
  #ファイルに保存
  def save
    if @outerFileName
      Kernel.open(@outerFileName, "a") do |file|
        @addedWords.each do |word|
          file.puts word.str
        end
      end
      @addedWords.clear
    end
    Kernel.open(@innerFileName, "w") do |file|
      Marshal.dump(@words, file)
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
      io.print word.str, "\t", word.author, "\t", word.mids.join(","), "\n"
    end
  end
  
  attr_reader :words
  
  private
  
  #既存のファイルとかぶらないファイル名を作る。
  def makeNewFileName(base)
    return base unless File.exist?(base)
    i = 2
    loop do
      return name unless File.exist?(base+i)
      i += 1
    end
  end
end

end #module Gimite
