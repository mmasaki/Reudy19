#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/similar_searcher'
require $REUDY_DIR+'/word_associator'
require $REUDY_DIR+'/wtml_manager'
require $REUDY_DIR+'/attention_decider'
require $REUDY_DIR+'/response_estimator'
require $REUDY_DIR+'/reudy_common'
require 'yaml'

unless Encoding.default_external == __ENCODING__
  STDOUT.set_encoding(Encoding.default_external, __ENCODING__)
  STDERR.set_encoding(Encoding.default_external, __ENCODING__)
  STDIN.set_encoding(Encoding.default_external, __ENCODING__)
end

module Gimite
  class Reudy
    include Gimite
    
    def initialize(dir, fixedSettings = {},db="pstore",mecab=nil)
      @attention = nil
       
      #設定を読み込む。
      @db = db #使用するDBの名前
      if mecab
        begin
          require $REUDY_DIR+'/tango-mecab' #単語の抽出にmecabを使用する
        rescue => ex
          warn ex.message
          require $REUDY_DIR+'/tango-mgm'
        end
      else
        require $REUDY_DIR+'/tango-mgm'
      end
      @fixedSettings = fixedSettings
      @settingPath = dir + '/setting.yml'
      @settings = {}
      loadSettings
      @autoSave = !@settings[:disable_auto_saving]
      
      #働き者のオブジェクト達を作る。
      @log = MessageLog.new(dir + '/log.yml')
      @log.addObserver(self)
      warn "ログロード終了"
      @wordSet = WordSet.new(dir + '/words.yml')
      @wordSearcher = WordSearcher.new(@wordSet)
      @wtmlManager = WordToMessageListManager.new(@wordSet, @log, @wordSearcher)
      @extractor = WordExtractor.new(14, method(:onAddWord))
      @simSearcher = SimilarSearcher.new(dir + '/db', @log,@db)
      @associator = WordAssociator.new(dir + '/assoc.txt')
      @attention = AttentionDecider.new
      @attention.setParameter(attentionParameters)
      @resEst = ResponseEstimator.new(@log, @wordSearcher, method(:isUsableBaseMsg), method(:canAdoptWord))
      warn "単語ロード終了"    
      #その他インスタンス変数の初期化。
      @client = nil
      @lastSpeachInput = nil
      @lastSpeach = nil
      @inputWords = []
      @newInputWords = []
      @recentUnusedCt = 100 #最近n個の発言は対象としない
      @repeatProofCt = 50 #過去n発言で使ったベース発言は再利用しない
      @recentBaseMsgNs = Array.new(@repeatProofCt) #最近使ったベース発言番号
      @thoughtFile = open(dir + "/thought.txt", "a") #思考過程を記録するファイル
      @thoughtFile.sync = true
      
      setWordAdoptBorder
    end
    
    #設定をファイルからロード
    def loadSettings
      File.open(@settingPath) do |file|
        @settings = YAML.load(file)
      end
      @settings.merge!(@fixedSettings)
      #メンバ変数を更新
      @targetNickReg = Regexp.new(@settings[:target_nick] || "", Regexp::IGNORECASE)
      #これにマッチしないNickの発言は、ベース発言として使用不能
      if @settings[:forbidden_nick] && !@settings[:forbidden_nick].empty?
        @forbiddenNickReg = Regexp.new(@settings[:forbidden_nick], Regexp::IGNORECASE)
      else 
        @forbiddenNickReg = /(?!)/o #何にもマッチしない正規表現
      end
      @myNicks = @settings[:nicks] #これにマッチするNickの発言は、ベース発言として使用不能
      @my_nicks_regexp = Regexp.new(@myNicks.map{|n| Regexp.escape(n) }.join("|"))
      changeMode(@settings[:default_mode].to_i) #デフォルトのモードに変更
    end
    
    #チャットクライアントの指定
    attr_accessor :client,:settings
    
    #モードを変更
    def changeMode(mode)
      return false if mode == @mode
      @mode = mode
      @attention.setParameter(attentionParameters) if @attention
      updateStatus
      return true
    end
    
    def updateStatus
      @client.status = ["沈黙", "寡黙", nil, "饒舌"][@mode] if @client
    end
    
    #注目判定器に与えるパラメータ。
    def attentionParameters
      case @mode
        when 0 #沈黙モード。
          return { \
            :min     => 0.001, \
            :max     => 0.001, \
            :default => 0.001, \
            :called  => 0.001, \
            :self    => 0.0,   \
            :ignored => 0.0    \
          }
        when 1 #寡黙モード。
          return { \
            :min     => 0.1, \
            :max     => 0.3, \
            :default => 0.1, \
            :called  => 1.1, \
            :self    => 0.005, \
            :ignored => 0.002 \
          }
        when 2 #通常モード。
          return { \
            :min     => 0.5, \
            :max     => 1.1, \
            :default => 0.5, \
            :called  => 1.1, \
            :self    => 0.3, \
            :ignored => 0.002 \
          }
        when 3 #饒舌モード。
          return { \
            :min     => 0.8, \
            :max     => 1.1, \
            :default => 0.8, \
            :called  => 1.1, \
            :self    => 0.8, \
            :ignored => 0.01  \
          }
        when 4 #必ず応答するモード。
          return { \
            :min     => 1.1, \
            :max     => 1.1, \
            :default => 1.1, \
            :called  => 1.1, \
            :self    => 0.8, \
            :ignored => 0.003  \
          }
      end
    end
    
    #単語がこれより多く出現してたら置換などの対象にしない、という
    #ボーダを求めて@wordAdoptBorderに代入。
    def setWordAdoptBorder
      if @wordSet.words.empty?
        @wordAdoptBorder = 0
      else
        msgCts = @wordSet.words.map{|w| w.mids.size }
        msgCts.sort!
        msgCts.reverse!
        @wordAdoptBorder = msgCts[msgCts.size / 50]
      end
    end
    
    #その単語が置換などの対象になるか
    def canAdoptWord(word)
      word.mids.size < @wordAdoptBorder
    end
    
    #発言をベース発言として使用可能か。
    def isUsableBaseMsg(msgN)
      size = @log.size
      return false if msgN >= size #存在しない発言。
      msg = @log[msgN]
      return unless msg #空行。削除された発言など。
      return false if !@settings[:teacher_mode] && size > @recentUnusedCt && msgN >= size - @recentUnusedCt #発言が新しすぎる。（中の人モードでは無効）
      nick = msg.fromNick
      return false if nick == "!" #自分自身の発言。
      return false if !(nick =~ @targetNickReg) || nick =~ @forbiddenNickReg #この発言者の発言は使えない。
      return false if @recentBaseMsgNs.include?(msgN) #最近そのベース発言を使った。
      return true
    end
    
    #mid番目の発言への返事（と思われる発言）について、[発言番号,返事らしさ]を返す。
    #ただし、ベース発言として使用できるものだけが対象。
    #該当するものが無ければ[nil,0]を返す。
    def responseTo(mid, debug = false)
      if @settings[:teacher_mode]
        if isUsableBaseMsg(mid+1) && @log[mid].fromNick == "!input"
          return [mid+1, 20]
        else
          return [nil, 0]
        end
      else
        return @resEst.responseTo(mid, debug)
      end
    end
    
    #類似発言検索用のフィルタ
    def similarSearchFilter(msgN)
      !responseTo(msgN).first.nil?
    end
    
    #sentence中の自分のNickをtargetに置き換える。
    def replaceMyNicks(sentence, target)
      sentence.gsub(@my_nicks_regexp, target)
    end
    
    #入力文章から既知単語を拾う。
    def pickUpInputWords(input)
      input = replaceMyNicks(input, " ")
      @newInputWords = @wordSearcher.searchWords(input).select{ |w| canAdoptWord(w) } #入力に含まれる単語を列挙
      #入力に単語が無い場合は、時々入力語をランダムに変更
      if @newInputWords.empty? && rand(50).zero?
        word = @wordSet.words.sample
        @newInputWords.push(word) if canAdoptWord(word)
      end
      #連想される単語を追加
      assoc_words = @newInputWords.map{|w| @associator.associate(w.str) }
      assoc_words.compact!
      assoc_words.map!{|s| Word.new(s) }
      @newInputWords.concat(assoc_words)
      #入力語の更新
      unless @newInputWords.empty?
        if rand(5).nonzero?
          @inputWords.replace(@newInputWords)
        else
          @inputWords.concat(@newInputWords)
        end
      end
    end
    
    #「単語を除く文字数」から発言を採用するかを決める。
    #「単語だけ」に等しい発言は採用されにくいようにする。
    #単語が無い発言は確実に採用され、このメソッドは使われない。
    def shouldAdoptSaying(additionalLen)
      case additionalLen
      when 0
        false
      when 1
        rand < 0.125
      when 2, 3
        rand < 0.25
      when 4...7
        rand < 0.75
      else
        true
      end
    end
    
    #inputWords中の単語を含む各発言について、ブロックを繰り返す。
    #ブロックは発言番号を引数に取る。
    #発言の順序はランダム。
    def eachMsgContainingWords(input_words)
      input_words.shuffle.each do |word|
        word.mids.shuffle.each do |mid|
          yield(mid)
        end
      end
    end
    
    #共通の単語を持つ発言と、その返事の発言番号を返す。
    #適切なものが無ければ、[nil, nil]。
    def getBaseMsgUsingKeyword(inputWords)
      maxMid = maxResMid = nil
      maxProb = 0
      i = 0
      eachMsgContainingWords(inputWords) do |mid|
        resMid, prob = responseTo(mid, true)
        if resMid
          if prob > maxProb
            maxMid = mid
            maxResMid = resMid
            maxProb = prob
          end
          i += 1
          break if i >= 5
        end
      end
      dprint("共通単語発言", @log[maxMid].body) if maxMid
      return [maxMid, maxResMid]
    end
    
    #類似発言と、その返事の発言番号を返す。
    #適切なものが無ければ、[nil, nil]。
    def getBaseMsgUsingSimilarity(sentence)
      maxMid = maxResMid = nil
      maxProb = 0
      i = 0
      @simSearcher.eachSimilarMsg(sentence) do |mid|
        resMid, prob = responseTo(mid, true)
        if resMid
          if prob > maxProb
            maxMid = mid
            maxResMid = resMid
            maxProb = prob
          end
          i += 1
          break if i >= 5
        end
      end
      dprint("類似発言", @log[maxMid].body, maxProb) if maxMid
      return [maxMid, maxResMid]
    end
    
    #msgN番の発言を使ったベース発言の文字列。
    def getBaseMsgStr(msg_n)
      str = @log[msg_n].body
      str.replace($1) if str =~ /^(.*)[＜＞]/ && $1.size >= str.size / 2 #文の後半に[＜＞]が有れば、その後ろはカット。
      str
    end
    
    #base内の既知単語をnewWordsで置換したものを返す。
    #toForceがfalseの場合、短すぎる文章になってしまった場合はnilを返す。
    def replaceWords(base, new_words, toForce)
      #baseを単語の前後で分割してpartsにする。
      parts = [base]
      @wordSet.words.each do |word|
        next if word.str.empty?
        if @wordSearcher.hasWord(base, word) && canAdoptWord(word)
          newParts = []
          parts.each_with_index do |part,i|
            if (i % 2).zero?
              word_regexp = /^(.*?)#{Regexp.escape(word.str)}(.*)$/
              while part =~ word_regexp
                newParts.push($1, word.str)
                part = $2
              end
            end
            newParts.push(part)
          end
          parts = newParts
        end
      end
      #先頭から2番目以降の単語の直前でカットしたりしなかったり。
      wordCt =  (parts.size-1) / 2
      if parts.size > 1
        cutPos = rand(wordCt) * 2 + 1
        parts.replace(parts[cutPos..-1].unshift("")) if cutPos > 1
      end
      #単語を除いた文章が短すぎるものはある確率で却下。
      if wordCt.nonzero? && !toForce && !shouldAdoptSaying(sigma(0...parts.size){|i| (i % 2).zero? ? parts[i].size : 0 })
        return nil
      end
      #単語を置換。
      new_words.shuffle.each do |new_word|
        new_word_str = new_word.str
        old_word_str = parts[rand(wordCt)*2+1]
        0.upto(wordCt-1) do |j|
          parts[j*2+1] = new_word_str if parts[j*2+1] == old_word_str
        end
        break if rand < 0.5
      end
      output = parts.join
      #閉じ括弧が残った場合に開き括弧を補う。
      #入れ子になってたりしたら知らない。
      case output
      when /^[^「」]*」/
        output.replace("「#{output}")
      when /^[^（）]*）/
        output.replace("（#{output}")
      when /^[^()]*\)/
        output.replace("(#{output}")
      end
      return output
    end
    
    #自由発言の選び方を記録する。
    def recordThought(pattern, simMid, resMid, words, output)
      @thoughtFile.puts [@log.size-1, pattern, simMid, resMid, words.map{ |w| w.str }.join(","), output].join("\t")
    end
    
    #自由に発言する。
    def speakFreely(fromNick, origInput, mustRespond)
      input = replaceMyNicks(origInput, " ")
      output = nil
      simMsgN, baseMsgN = getBaseMsgUsingSimilarity(input) #まず、類似性を使ってベース発言を求める。
      if !@newInputWords.empty?
        if baseMsgN 
          output = replaceWords(getBaseMsgStr(baseMsgN), @inputWords, mustRespond)
          recordThought(1, simMsgN, baseMsgN, @newInputWords, output) if output
        else 
          simMsgN, baseMsgN = getBaseMsgUsingKeyword(@newInputWords)
          output = getBaseMsgStr(baseMsgN) if baseMsgN
          recordThought(2, simMsgN, baseMsgN, @newInputWords, output) if output
        end
      else
        if baseMsgN 
          output = getBaseMsgStr(baseMsgN)
          unless @wordSearcher.searchWords(output).empty?
            if mustRespond
              output = replaceWords(output, @inputWords, true)
            else
              output = nil
            end
          end
          recordThought(3, simMsgN, baseMsgN, @inputWords, output) if output
        else 
          if mustRespond && !@inputWords.empty?
            simMsgN, baseMsgN = getBaseMsgUsingKeyword(@inputWords) #最新でない入力語も使ってキーワード検索。
            output = getBaseMsgStr(baseMsgN) if baseMsgN
            recordThought(4, simMsgN, baseMsgN, @inputWords, output) if output
          end
        end
      end
      if mustRespond && !output 
        log_size = @log.size
        2000.times do
          msgN = rand(log_size)
          if isUsableBaseMsg(msgN)
            baseMsgN = msgN
            output = getBaseMsgStr(baseMsgN)
            break
          end
        end
      end
      if output
        #最近使ったベース発言を更新
        @recentBaseMsgNs.shift
        @recentBaseMsgNs.push(baseMsgN)
        output = replaceMyNicks(output, fromNick) #発言中の自分のNickを相手のNickに変換
        speak(origInput, output) #実際に発言。
      end
    end
    
    #自由発話として発言する。
    def speak(input, output)
      @lastSpeachInput = input
      @lastSpeach = output
      studyMsg("!", output) #自分の発言を記憶する。
      @client.outputInfo("「#{input}」に反応した。") if @settings[:teacher_mode]
      @attention.onSelfSpeak(@wordSearcher.searchWords(output))
      @client.speak(output)
    end
    
    #定型コマンドを処理。
    #入力が定型コマンドであれば応答メッセージを返す。
    #そうでなければnilを返す。ただし、終了コマンドだったら:exitを返す。
    def processCommand(input)
      if input =~ /設定を更新/
        loadSettings
        return "設定を更新しました。"
      end
      return nil if @settings[:disable_commands] #コマンドが禁止されている場合
      case input
      when /黙れ|黙りなさい|黙ってろ|沈黙モード/
        return changeMode(0) ? "沈黙モードに切り替える。" : ""
      when /寡黙モード/
        return changeMode(1) ? "寡黙モードに切り替える。" : ""
      when /通常モード/
        return changeMode(2) ? "通常モードに切り替える。" : ""
      when /饒舌モード/
        return changeMode(3) ? "饒舌モードに切り替える。" : ""
      when /休んで良いよ|終了しなさい/
        save
        @client.exit
        return :exit
      when /([\x21-\x7e]+)の(?:もの|モノ|物)(?:まね|真似)/ #半角文字を抽出する正規表現
        begin
          @targetNickReg = Regexp.new($1, Regexp::IGNORECASE)
          return "#{$1}のものまねを開始する。"
        rescue RegexpError
          return "正規表現が間違っている。"
        end
      when /(?:もの|モノ|物)(?:まね|真似).*(?:解除|中止|終了|やめろ|やめて)/
        @targetNickReg = /(?!)/
        return "物まねを解除する。"
      end
      if input =~ /覚えさせた|教わった/ && input.include?("誰") && input =~ /「(.+?)」/
        wordStr = $1
        if wordIdx = @wordSet.words.index(Word.new(wordStr))
          author = @wordSet.words[wordIdx].author
          if !author.empty?
            return "#{author}さんに。＞#{wordStr}"
          else
            return "不確定だ。＞#{wordStr}"
          end
        else
          return "その単語は記憶していない。"
        end
      end
      return nil #定型コマンドではない。
    end
    
    #通常の発言を学習。
    def studyMsg(fromNick, input)
      return if @settings[:disable_studying]
      if @settings[:teacher_mode]
        @fromNick = fromNick
        @extractor.processLine(input) #単語の抽出のみ。
      else
        @log.addMsg(fromNick, input)
      end
    end
    
    #学習内容を手動保存
    def save
      @wordSet.save
    end
    
    #ログに発言が追加された。
    def onAddMsg
      msg = @log[-1]
      @fromNick = msg.fromNick unless msg.fromNick == "!"
      @extractor.processLine(msg.body) unless @settings[:teacher_mode] #中の人モードでは、単語の抽出は別にやる。
      #@extractor以外のオブジェクトは自力で@logを監視しているので、
      #ここで何かする必要は無い。
    end
    
    #ログがクリアされた。
    def onClearLog
    end
    
    #単語が追加された
    def onAddWord(wordStr)
      if @wordSet.addWord(wordStr, @fromNick)
        if @client
          @client.outputInfo("単語「#{wordStr}」を記憶した。")
        else
          puts "単語「#{wordStr}」を記憶した。"
        end
        @wordSet.save if @autoSave
      end
    end
    
    #接続を開始した
    def onBeginConnecting
      warn "接続開始..."
    end
    
    #自分が入室した
    def onSelfJoin
      updateStatus
    end
    
    #他人が入室した
    def onOtherJoin(fromNick)
    end
  
    #他人が発言した。
    def onOtherSpeak(from_nick, input, should_ignore = false)
      output = nil #発言。
      called = @myNicks.any?{|n| input.include?(n) }
      output = called ? processCommand(input) : nil
      if output
        @client.speak(output) if output != :exit && !output.empty?
      else #定型コマンドではない。
        @lastSpeach = input
        studyMsg(from_nick, input)
        pickUpInputWords(input)
        prob = @attention.onOtherSpeak(from_nick, input, called)
        dprint("発言率", prob, @attention.to_s) #発言率を求める。
        speakFreely(from_nick, input, prob > 1.0) if (!should_ignore && rand < prob) || prob > 1.0 #自由発話。
      end
    end
    
    #制御発言（infoでの発言）があった。
    def onControlMsg(str)
      return if @settings[:disable_studying] || !@settings[:teacher_mode]
      if str =~ /^(.+)→→(.+)$/
        input = $1
        output = $2
      else
        input = @lastSpeachInput
        output = str
      end
      if input
        @log.addMsg("!input", input)
        @log.addMsg("!teacher", output)
        @client.outputInfo("反応「#{input}→→#{output}」を学習した。" ) if @client
      end
    end
    
    #沈黙がしばらく続いた。
    def onSilent
      prob = @attention.onSilent
      if rand < prob && @lastSpeach
        speakFreely(@fromNick, @lastSpeach, prob > rand * 1.1) #自発発言。
        #自発発言では、発言が無い限り、同じ発言を対象にしつづける。
        #このせいで全然しゃべらなくなるのを防ぐため、時々mustRespondをONにする。
      end
    end
  end
end
