#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require $REUDY_DIR+'/reudy_common'

module Gimite

#個々の発言
class Message
  def initialize(fromNick_, body_)
    @fromNick = fromNick_
    @body = body_
  end

  attr_accessor :fromNick,:body
end

#発言ログ
class MessageLog
  include Gimite
  
  @enable_update_check = true
  class << self
    attr_accessor :enable_update_check
  end
  
  def initialize(innerFileName)
    @innerFileName = innerFileName
    @observers = []
    @msgPoses = [] #ファイル上の各行の先頭の位置。
    @outerFile = nil
    @sync = true
    addHeadNoticeToInnerFile unless File.exist?(@innerFileName)
    loadFromInnerFile
    #発言の追加に備えて、内部ファイルを開けっぱなしにする。
    @innerFile = Kernel.open(@innerFileName, File::RDWR | File::APPEND)
    @innerFile.sync = sync
  end
  
  #観察者を追加。
  def addObserver(*observers)
    @observers += observers
  end
  
  #外部ファイルを登録し、外部ファイルの内容を内部データに反映する。
  def updateByOuterFile(outerFileName)
    msg = nil
    isAdded = false
    if size.zero?
      msg = "#{@innerFileName} が有りません。作成します...\n"
      isAdded = true
    elsif MessageLog.enable_update_check && File.mtime(outerFileName) > File.mtime(@innerFileName)
      msg = "#{outerFileName} が変更されたようです。調査中...\n"
    end
    if msg
      warn msg
      syncBak = sync
      sync = false
      #外部ファイルと内部データを比較し、追加が有れば追加する。
      n = 0
      eachMsgInFile(outerFileName) do |fromNick, body|
        if n >= size
          unless isAdded
            warn outerFileName + " に追加されたログを読み込み中..."
            isAdded = true
          end
          warn "#{n+1}行目..." if ((n+1) % 100).zero?
          addMsg(fromNick, body, false)
        else
          warn "#{n+1}行目..." if ((n+1) % 10000).zero?
          break if fromNick != self[n].fromNick || body != self[n].body
        end
        n += 1
      end
      #途中が編集されてたら、内部データを一から作り直す。
      if n < size
        warn "#{outerFileName} の途中が変更されています。内部データを作り直します..."
        clear
        n = 0
        eachMsgInFile(outerFileName) do |fromNick, body|
          warn "#{n+1}行目..." if ((n+1) % 100).zero?
          addMsg(fromNick, body, false)
          n += 1
        end
      end
      sync = syncBak
    end
    #発言の追加に備えて、外部ファイルを開けっぱなしにする。
    @outerFile = open(outerFileName, "a")
    @outerFile.sync = true
  end
  
  #n番目の発言
  def [](n)
    if @msgPoses[n]
      @innerFile.pos = @msgPoses[n]
      line = @innerFile.gets
      line.chomp! if line
      @innerFile.seek(0, IO::SEEK_END)
      return Message.new($1, $2) if line =~ /(.*)\t(.*)/o
    end
    return nil
  end
  
  #発言の数
  def size
    return @msgPoses.size
  end
  
  #発言を追加
  def addMsg(fromNick, body, toOuter = true)
    @innerFile.seek(0, IO::SEEK_END)
    @msgPoses.push(@innerFile.pos)
    @outerFile.print(fromNick + "\t" + body + "\n") if toOuter && @outerFile
    @innerFile.print(fromNick + "\t" + body + "\n")
    @observers.each do |observer|
      observer.onAddMsg
    end
  end
  
  #内部ファイルの出力同期モード。
  def sync
    return @sync
  end
  
  #内部フルの出力同期モードを変更する。
  def sync=(s)
    @sync = s
    @innerFile.sync = s if @innerFile
  end
  
  #ログファイルをクローズ
  def close
    @file.close
  end
  
  private
  
  #内部ファイルの先頭に注意書きを書いとく。
  def addHeadNoticeToInnerFile
    Kernel.open(@innerFileName, "a") do |f|
      f.print <<EOS
※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
※※※※このファイルはロイディ内部で使われるデータです。                      ※※※※
※※※※ログを編集するには、このファイルではなく、log.txtを編集してください。 ※※※※
※※※※このファイルを編集すると、データが壊れます。                          ※※※※
※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
EOS
    end
  end
  
  #ログを内部ファイルからロード。
  def loadFromInnerFile
    Kernel.open(@innerFileName, "a").close #ファイルが無ければ作成。
    Kernel.open(@innerFileName, "r") do |file|
      pos = 0
      while line = file.gets
        line.chomp!
        @msgPoses.push(pos) if line =~ /(.*)\t(.*)/o
        pos = file.pos
      end
    end
  end
  
  #ログファイル内の各発言について繰り返す。
  #ブロックに渡される引数は (発言者,内容)
  def eachMsgInFile(fileName, &block)
    return unless File.exist?(fileName)
    Kernel.open(fileName, "r") do |file|
      file.each_line do |line|
        line.chomp!
        block.call($1, $2) if line =~ /(.*)\t(.*)/o
      end
    end
  end
  
  #内部データをクリア
  def clear
    @observers.each do |observer|
      observer.onClearLog
    end
    @msgPoses.clear
    @innerFile.close if @innerFile
    @innerFile = open(@innerFileName, File::RDWR | File::CREAT | File::TRUNC)
    @innerFile.sync = sync
  end
end

end #module Gimite
