#encoding:utf-8
#!/usr/bin/ruby
#----------------------------------------------------------------------------
#Copyright (C) 2003 mita-K, NAKAUE.T (Meister), Gimite 市川
#
# mita-Kの単語取得ライブラリ
#
#      Original works by mita-K
#      Extended by Gimite/Meister
#
#  2003.06.06                 勝手にクラス化(Meister)
#                             基本的に文字コードに依存しないように、
#                             一部ソースの文字コード(SJIS)に依存
#  2003.06.22                 Gimite版と統合(Meister)
#                             語尾の除去等の処理は単純な候補除外フィルタに変更した
#                             現在の実装では文字列を総当りで調べるため、
#                             わざわざ語尾を除外した単語を作らなくとも
#                             同じものが他の候補に含まれている
#  2003.06.23                 Gimite版の機能を追加移植(Gimite)
#                             ひらがな交じりの語をほとんど抽出できない問題を修正
#                             単語抽出時の禁則処理を追加
#                             単語抽出時の語末のゴミの除去を追加
#                             非ひらがなの2文字以上の連続が無い語は原則として対象外に
#                             checkWordCand()に渡すprestrとpoststrを配列から文字列に変更
#                             主語っぽいものの検出を強化
#                             EUC用に書き換えたので、必要に応じて戻してください…
#
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# 文中から単語(らしき文字列)を探し出す
class WordExtractor
  # コンストラクタ
  # WordExtractor(単語候補リストを保持する長さ,単語追加時のコールバック)
  def initialize(candlistlength=7,onaddword=nil)
    # 単語候補のリスト
    @candList=Array.new(candlistlength,[])
    @onAddWord=onaddword
  end

  def candList; @candList; end

  # 単語候補のリストを整理して返す
  def getCandList
    return @candList.flatten.compact.uniq
  end

  # 単語として適切かどうか判定する
  # 主語っぽい語などの特例には適用しない
  # 不適だとnilを返す
  def wordFilter1(word)
    return nil unless word # 論外(^_^;
    case word
    when /^.$/o # 一文字だけ
      return nil
    when /^[ぁ-んー]+$/o # 平仮名だけ
      return nil
    when /[^ぁ-んー][^ぁ-ん]/o # 非ひらがなの2文字以上の連続を含まない
      return nil
    when /[^ぁ-ん][のとな]$/o # 助詞っぽいものを含む
      return nil
    when /^.+が/o, /^.+は/o # 先頭以外に「が」「は」を含む
      return nil
    else 
      return word
    end
  end

  # 単語として適切かどうか判定する
  # 主語っぽいなどの特例にも適用する
  # 不適だとnilを返す
  def wordFilter2(word)
    return nil unless word # 論外(^_^;
    case word
    when /^$/o, /^[　 ]/o, /[　 ]$/o # 空白類
      return nil
    when /^[ぁ-んァ-ンー]$/o # かな一文字だけ
      return nil
    when /^[ぁ-んー−][ぁ-んー−]$/o   # ひらがな2文字
      return nil
    when /^[-.\/+*:;,~_|&'"`()0-9]+$/o # 数値・記号だけ
      return nil
    when /[、。．，！？（）・…‾−＿：；]/o,/[＜＞「」『』【】〔〕]/o,/[〜＃→←↑←⇔⇒◎—¬Д⌒]/o,/[()]/o # 記号を含む
      return nil
    when /^[,]/o,/^[ーをんぁぃぅぇぉゃゅょっ]/o,/^[ー−ヲンァィゥェォャュョッヶヵ]/o,/^[ぁ-ん][^ぁ-ん]/o # あり得ない文字から始まっている
      return nil
    # HTMLの文字参照
    when /&[#a-zA-Z0-9]+;/o
      return nil
    else
      return word
    end
  end

  # 単語として適切かどうか判定する
  # 前後の文字列も参考にする
  # 不適だとnilを返す
  def checkWordCand(word,prestr='',poststr='')
    if prestr == nil
      prestr = ''
      poststr = ''
    end
    word = word.clone

    # 以下の2条件に当てはまった場合は一部の禁則を免除する
    if (prestr =~ /[、。．，！？（）・…]$/o || prestr == '') \
     &&(poststr =~ /^[はが]([^ぁ-ん]|$)/o) \
     &&((word+poststr[0..0]) !~ /(では|だが|には|のが)$/o) \
     &&(word =~ /^[ぁ-んー]+$/o || word =~ /^[^ぁ-ん]/o) \
     &&(word.length >= 6)
      # 主語っぽいもの：{句読点系or文頭}〜[はが]{ひらがな以外}
      # （ただし「では」「だが」「には」「のが」となるものを除く）
      # Ruby 1.6にはjlengthがないので適当に逃げている
    elsif (prestr =~ /[＞＜]$/o)&&(poststr == '')
      # 文末の「＞〜」や「＜〜」
    else
      word = wordFilter1(word)
    end
    return wordFilter2(word)
  end
  
  # 文字列を単語として追加べきかを判定する
  # 追加すべき単語（wordとは異なる場合も）またはnil（不適）を返す
  def checkWord(word)
    # 語末のゴミの除去
    while word =~ /^(.+)(とか|しなさい|ですか?|のよう|だから|する|って|という|して|したい?|まで|しなさい|ですか?|のよう|せず|される?|には|させる?|しか|ました|できる?)$/o \
        || word =~ /^([^ぁ-ん]+)[しだすともにを]$/o
      word = $1
    end
    case word
    when /^[ぁ-んァ-ンー]$/o,/^[ぁ-んー ][ぁ-んー－]$/o  # 禁則
      return nil
    when /ない|って|った|てる|んな|いる|から|とは|れる|れて|れる|れた|ます|いう|れば|のは|しい|にな|んで|なる|しく|を|だと|たと|られ
        くて|のか|だけ|いた|えて|れが|いと|され|うが|える|ため|ある|こと|して|する|だよ|した|ので|しま|なの|です|なん|でき|とか
        ような|だろう/o,/[^ぁ-ん][でにを]/o,/っ$/o #単語候補時に除外されてるはずだが、語末のゴミの除去で現れた可能性が有るのでもう1度
      return nil
    else
      return word
    end
  end

  # 文字列から単語侯補を獲得する
  # 主にマルチバイト文字列(日本語文字列)用だが、
  # 一応シングルバイト文字列を食わせても大丈夫なはず
  def extractCands(s)
    result = []

    ss = s.split(//)

    # 英数字の連続を結合する
    (ss.size-2).downto(0) {|i| ss[i] += ss.delete_at(i+1) if (ss[i] =~ /[-_0-9a-zA-Z]$/o)&&(ss[i+1] =~ /[-_0-9a-zA-Z]$/o)}
    # カタカナの連続を結合する
    (ss.size-2).downto(0) {|i| ss[i] += ss.delete_at(i+1) if (ss[i] =~ /[ー−ァ-ン]$/o)&&(ss[i+1]=~/[ー−ァ-ン]$/o)}

    (0...ss.size).each do |i|
      (i...ss.size).each do |j|
        cand = checkWordCand(ss[i..j].join,ss[0...i].join,ss[j+1...ss.size].join)
        result << cand if cand
      end
    end
#    dprint("単語候補", result)

    return result
  end


  # 単語リスト中の包含関係にあるものを削除して単語リストを最適化する
  def optimizeWordList(wordcand)
    (0...(wordcand.length-1)).each do |i|
      next unless wordcand[i]
      ((i+1)...wordcand.length).each do |j|
        next unless wordcand[j]
        if wordcand[j].include?(wordcand[i])
          wordcand[i] = nil
          break
        end
        wordcand[j] = nil if wordcand[i].include?(wordcand[j])
      end
    end
    wordcand.compact!

    return wordcand
  end

  # 文中で使われている単語を取得
  def extractWords(line,words=[])

    # 単語侯補が文章中に使われてたら単語にする
    wordcand = getCandList.reject {|word| !line.include?(word)}

    # 新しく加わる単語同士に包含関係があったら短いほうを消去する
    ## 例えば「なると」という単語が登録される時に
    ## 「なる」「ると」が同時に単語と認識されてしまうのを防ぐ。
    wordcand = optimizeWordList(wordcand)
    
    # 禁則処理
    wordcand2 = []
    wordcand.each do |word|
      word2 = checkWord(word)
      wordcand2.push(word2) if word2
    end

    # 新しい単語を本当に単語として認定する。
    ## ただしダブる場合は片方を消す。
    words = words | wordcand2

    if @onAddWord
      words.each {|w| @onAddWord.call(w)}
    end

    return words
  end

  # 多バイト文字またはシングルバイト文字だけからなる文字列を切り出す
  # $KCODEが適切に設定されていなければならない
  # 0,2,4・・・番目がシングルバイト文字の文字列
  def splitByCharType(s)
    result = []

    issingle = true
    word = ''
    s.split(//).each{|c|
      if issingle != (c.size == 1)
        result << word
        word = ''
      end
      word += c
      issingle = (c.size == 1)
    }
    result << word unless word.empty?

    return result
  end

  # 単語侯補のリストを更新する
  def renewCandList(line)
    newlist = []
    wordlist = splitByCharType(line)
    (0...wordlist.size).each do |i|
      if i % 2 == 0
        wordlist[i].split(' ').each do |w|
          newlist << w if checkWordCand(w)
        end
      else
        newlist += extractCands(wordlist[i])
      end
    end

    @candList.shift
    @candList << newlist
  end

  # 単語侯補のリストを更新する
  # (シングルバイト文字列の事前分離を行わないバージョン)
  def renewCandList2(line)
    @candList.shift
    @candList << extractCands(line)
  end

  # 単語取得・単語候補リスト更新を1行分処理する
  def processLine(line)
    words = extractWords(line)
    renewCandList(line)
    return words
  end

  #デバッグ出力
  def dprint(caption, obj)
    print(caption + ": " + obj.inspect, "\n")
  end
end
