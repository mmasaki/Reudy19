#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require $REUDY_DIR+'/tango-mgm'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/word_associator'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/similar_searcher5'
require $REUDY_DIR+'/reudy_common'

module Gimite

#人工無能ミチル
class Michiru
  include(Gimite)
  
  def initialize(dir, fixedSettings= {})
    @recentWordsCt = 40 #最近使った単語を何個記憶するか
    @fixedSettings = fixedSettings
    @settingPath = dir + "/setting.txt"
    loadSettings
    puts "単語ロード中..."
    @wordSet = WordSet.new(dir + "/words.txt")
    @log = MessageLog.new(dir + "/log.txt", @autoSave)
    puts "類似検索用データ生成中..."
    @simSearcher = SimilarSearcher.new(dir + "/similar.gdbm", @log)
    @wordSearcher = WordSearcher.new(@wordSet)
    @extractor = WordExtractor.new(14, method(:onAddWord))
    @associator = WordAssociator.new(dir + "/assoc.txt")
    @recentWordStrs = [] #最近使った単語
    @similarNicksMap = {} #Nick→その人の最近の発言の類似発言の発言者のリスト
  end
  
  #設定をファイルからロード
  def loadSettings
    file = Kernel.open(@settingPath)
    @settings = Hash.new
    file.each_line do |line|
      ss = line.chop.split(/\t/, 2)
      @settings[ss[0]] = ss[1]
    end
    file.close
    @fixedSettings.each do |key, val|
      @settings[key] = val
    end
    @myNicks = settings("nicks").split(",")
    @autoSave = settings("disable_auto_saving") != "true"
  end
  
  #チャットクライアントの指定
  attr_writer(:client)
  
  #チャットオブジェクト用の設定
  def settings(key)
    return @settings[key]
  end
  
  #Nickを相手のNickに変える
  def replaceNick(sentence, fromNick)
    nickReg = @myNicks.map{ |x| Regexp.escape(x) }.join("|")
    return sentence.gsub(Regexp.new(nickReg), fromNick)
  end
  
  #「最近使われた単語」を追加
  def addRecentWordStr(wordStr)
    @recentWordStrs.push(wordStr)
    @recentWordStrs.shift if @recentWordStrs.size > @recentWordsCt
  end
  
  #入力語からの連想を発言にする
  def associate
    inputWordStr = @inputWords[rand(@inputWords.size)].str
    assocWordStrs = @associator.associateAll(inputWordStr)
    return nil unless assocWordStrs
    outputWordStr = nil
    for wordStr in assocWordStrs
      unless @recentWordStrs.include?(wordStr)
        outputWordStr = wordStr
        break
      end
    end
    if outputWordStr
      addRecentWordStr(inputWordStr)
      addRecentWordStr(outputWordStr)
      return inputWordStr + "は" + outputWordStr + "です。"
    else
      return nil
    end
  end
  
  #指定の人の中の人を答える
  def innerPeople(nick)
    nicks = @similarNicksMap[nick]
    if !nicks || nicks.size ==  0
      return nick + "の中の人はいません。"
    else
      nicks0 = nicks.uniq.sort.reverse
      str = ""
      for nick0 in nicks0
        ct = nicks.select(){ |x| x == nick0 }.size
        str += format("%s(%d%%) ", nick0, ct * 100 / nicks.size)
      end
      return nick + "の中の人は " + str + "です。"
    end
  end
  
  #学習する
  def study(input)
    @extractor.processLine(input)
    @log.addMsg(@fromNick, input)
  end
  
  #類似発言検索用フィルタ
  def similarFilter(lineN)
    return true
  end
  
  #類似発言データを蓄積する
  def storeSimilarData(fromNick, input)
    data = @simSearcher.searchSimilarMsg(input, method(:similarFilter))
    return unless data
    lineN = data[0]
    nicks = @similarNicksMap[fromNick]
    nicks = [] unless nicks
    nicks.push(@log[lineN].fromNick)
    dprint("類似発言", @log[lineN].fromNick, @log[lineN].body)
    nicks.shift if nicks.size > 10
    @similarNicksMap[fromNick] = nicks
  end
  
  #単語が追加された
  def onAddWord(wordStr)
    if @wordSet.addWord(wordStr, @fromNick)
#      @client.outputInfo("単語「"+wordStr+"」を記憶した。")
      @wordSet.save if @autoSave
    end
  end
  
  #接続を開始した
  def onBeginConnecting
    puts "接続開始..."
  end
  
  #自分が入室した
  def onSelfJoin
  end
  
  #他人が入室した
  def onOtherJoin(fromNick)
  end

  #他人が発言した
  def onOtherSpeak(fromNick, input)
    @fromNick = fromNick
    output = nil #発言
    isCalled = false
    @myNicks.each do |nick|
      isCalled = true if (input.index(nick))
    end
    storeSimilarData(fromNick, input)
    study(input) if settings("disable_studying") != "true"
    @inputWords = @wordSearcher.searchWords(input)
    @inputWords.delete_if{ |word| @myNicks.include?(word.str) }
    if input =~ /([-a-zA-Z0-9_]+)の中の人/
      output = innerPeople($1)
    elsif input =~ /は.*である(。|．)?\s*/
      output = "へぇ〜"
    elsif (isCalled || rand < 0.1) && @inputWords.size > 0
      #相手の単語から連想する
      output = associate
    end
    if isCalled && !output
      #質問が分からなかった場合は、そのまま訊き返す
      output = replaceNick(input, fromNick)
    end
    if output
      @client.speak(output)
    end
  end
end

end #module Gimite
