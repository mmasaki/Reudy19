#----------------------------------------------------------------------------
#
# IRCクライアントライブラリ
#
#      Programed by NAKAUE.T (Meister)
#      Modified by Gimite 市川
#      Modified by Glass_saga(glass.saga@gmail.com)
#
#  2003.05.04  Version 1.0.0   使ってくれる人が増えたのでソースを整理
#  2003.05.10  Version 1.1.0   NICK処理追加
#  2003.07.24  Version 1.2.0g  中途半端にマルチチャンネル対応(Gimite)
#  2003.09.27  Version 1.2.1   UltimateIRCdで認証前にPINGが来る問題に対処(Meister)
#                              (thanks for bancho)
#  2003.09.28  Version 1.2.2   文字コード変換を整理(Meister)
#                              外部とのやり取りを行うコードを指定する
#                              (IRCはJISを使うことになっている)
#                              initializeのパラメータが変更になったので注意！
#  2003.09.28  Version 2.0.0   インターフェース整理(Meister)
#                              互換性が低くなったので一気にバージョンを上げる
#  2003.10.01  Version 2.0.1   NICKのバグ修正(Meister)
#  2004.01.01  Version 2.0.2   インスタンス生成後にソケットを渡せるようにした
#  2004.03.03  Version 2.0.3g  接続が切れた時に、IRCC#connectで再接続できるように
#                              IRCエラーを処理するIRCC#on_errorを追加(Gimite)
#  2011.09.09  Version 2 0.4   Ruby1.9に対応(Glass_saga)
#
#
# このソフトウェアはPublic Domain Softwareです。
# 自由に利用・改変して構いません。
# 改変の有無にかかわらず、自由に再配布することが出来ます。
# 作者はこのソフトウェアに関して、全ての権利と全ての義務を放棄します。
#
#----------------------------------------------------------------------------
# IRCプロトコルについてはRFC2810-2813を参照のこと。日本語訳あります。
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

class IRCC
  def initialize(sock, userinfo, internal_encoding, disp=STDOUT, irc_encoding)
    if sock
      @sock = sock
      @sock.set_encoding(@irc_encoding, @internal_encoding) unless @irc_encoding == @internal_encoding
    end
    @userinfo = userinfo
    @irc_nick = @userinfo['nick']
    @irc_channel = @userinfo['channel'] # 自動でJOINするチャンネル。このチャンネルを抜けると終了する(仕様)
    @channel_key = @userinfo['channel_key'] || ''

    @nicklist = []
    @joined_channel = nil

    @internal_encoding = internal_encoding ? Encoding.find(internal_encoding) : Encoding::UTF_8
    @irc_encoding = irc_encoding ? Encoding.find(irc_encoding) : Encoding::ISO_2022_JP

    @disp = disp
  end

  attr_accessor :sock,:userinfo,:nicklist,:irc_nick,:joined_channel

  # インスタンス生成後のソケット接続
  def connect(sock)
    @sock = sock
    @sock.set_encoding(@irc_encoding, @internal_encoding) unless @irc_encoding == @internal_encoding
    @myprefix = nil
  end

  # メッセージを送信(生)
  def sendmess(mess)
    @sock.print(mess)
    @disp.puts(mess.chop)
  end

  # メッセージの送信(通常のPRIVMSGで)
  def sendpriv(mess="")
    dispmess(">#{@irc_nick}<", mess)
    buff = "PRIVMSG #{@irc_channel} :#{mess}"
    sendmess(buff + "\r\n")
  end

  # メッセージの送信(NOTICEで)
  def sendnotice(mess="")
    dispmess(">#{@irc_nick}<", mess)
    buff = "NOTICE #{@irc_channel} :#{mess}"
    sendmess(buff + "\r\n")
  end

  # 別のチャンネルに移動
  def movechannel(channel)
    old_channel = @irc_channel
    @irc_channel = channel
    #PARTの前にこれを書き換えておかないとQUITしてしまう
    sendmess("PART #{old_channel}\r\n")
    sendmess("JOIN #{@irc_channel} #{@channel_key}\r\n")
  end

  # 終了する(実際にはチャンネルを抜けている)
  def quit
    sendmess("PART #{@irc_channel}\r\n")
  end

  # サーバから受け取ったメッセージを処理
  def on_recv(s)
    s.chomp!
    @disp.puts ">#{s}"

    prefix = ":unknown!unknown@unknown"
    prefix, param = s.split(' ', 2) if s[0..0] == ':'
    nick, prefix = prefix.split('!', 2)
    nick.slice!(0)
    param = s unless param

    param, param2 = param.split(/ :/, 2)
    param = param.split(' ')
    param << param2 if param2

    case param[0]
    when 'PRIVMSG', 'NOTICE' # 通常のメッセージ(NOTICEへのBOTの反応は禁止されている)
      if param[2][1..1] != "\001"
        mess = param[-1]
        if param[1].downcase == @irc_channel.downcase
          on_priv(param[0], nick, mess)
        else
          on_external_priv(param[0], nick, param[1], mess) # 今いるチャンネルの外からの発言
        end
      end
    when '372', '375'    # MOTD(Message Of The Day)
      on_motd(param[-1])
    when '353'      # チャンネル参加メンバーのリスト
      @nicklist += param[-1].gsub(/@/,'').split
    when 'JOIN' # 誰かがチャンネルに参加した
      channel = param[1]
      if @myprefix == prefix
        @joined_channel = channel
        on_myjoin(channel)
      else
        @nicklist |= [nick]
        on_join(nick, channel)
      end
    when 'PART' # 誰かがチャンネルから抜けた
      channel = param[1]
      if @myprefix == prefix
        @nicklist = []
        @joined_channel = nil
        on_mypart(channel)
        # 終了シーケンスだったらQUIT
        sendmess("QUIT\r\n") if param[1].downcase == @irc_channel.downcase
      else
        @nicklist.delete(nick)
        on_part(nick,channel)
      end
    when 'QUIT' # 誰かが終了した
      mess = param[-1]
      if @myprefix == prefix
        @nicklist = []
        on_myquit(mess)
      else
        @nicklist.delete(nick)
        on_quit(nick,mess)
      end
    when 'KICK' # 誰かがチャンネルから蹴られた
      kicker = nick
      channel = param[1]
      nick = param[2]
      mess = param[3]||''
      if nick == @irc_nick
        if param[1].downcase == @irc_channel.downcase
          @nicklist = []
          @joined_channel=nil
        end
        on_mykick(channel,mess,kicker)
        sendmess("QUIT\r\n") if param[1].downcase == @irc_channel.downcase # 蹴られたのでQUIT
      else
        @nicklist.delete(nick)
        on_kick(nick,channel,mess,kicker)
      end
    when 'NICK'     # 誰かがNICKを変更した
      nick_new = param[1]
      @irc_nick = nick_new if nick == @irc_nick
      @nicklist.delete(nick)
      @nicklist |= [nick_new]
      on_nick(nick,nick_new)
    when 'INVITE'     # 誰かが自分を招待した
      on_myinvite(nick,param[-1]) if param[1] == @irc_nick
    when 'PING'     # クライアントの生存確認
      if @myhostname
        sendmess("PONG #{@myhostname} #{param[1]}\r\n")
      else
        # UltimateIRCdではMOTDより前にPINGが来る
        # 正確なクライアントのホスト名が不明なため、適当なPONGを返す
        sendmess("PONG dummy #{param[1]}\r\n")
      end
    when '376','422'    # MOTDの終わり=ログインシーケンスの終わり
      # 自分のprefixを確認するためWHOISを発行
      sendmess("WHOIS #{@irc_nick}\r\n")
    when '311'      # WHOISへの応答
      unless @myprefix
        # 自分のprefixを取得
        @myhostname = param[4]
        @myprefix = "#{param[3]}@#{@myhostname}"
        on_login
      end
    when '433'      # nickが重複した
      on_error('433')  # 正しくは重複しないnickで再度NICKを発行
    when '451'      # 認証されていない
      on_error('451')
      @disp.puts('unknown login sequence!!')
    end
  end

  # 接続確立時の処理
  def on_connect
    @disp.puts "connect"
    dispmess(nil, 'Login...')

    sendmess("PASS #{@userinfo['pass']}\r\n") if @userinfo['pass'] && !@userinfo['pass'].empty?
    sendmess("NICK #{@irc_nick}\r\n")
    sendmess("USER #{@userinfo['user']} 0 * :#{@userinfo['realname']}\r\n")
  end

  # ここから下はオーバーライドする事を想定している

  # メッセージを表示(文字コードは変換しない)
  def dispmess(nick,mess)
    buff = Time.now.strftime('%H:%M:%S ')
    if nick
      buff = "#{buff}#{nick} #{mess}"
    else
      buff = "#{buff}#{mess}"
    end
    @disp.puts buff
  end

  # 接続・認証が完了し、チャンネルにJOINできる
  def on_login
    sendmess("JOIN #{@irc_channel} #{@channel_key}\r\n")
  end

  # MOTD(サーバのログインメッセージ)
  def on_motd(mess)
    dispmess(nil,mess)
  end

  # 通常メッセージ受信時の処理
  def on_priv(type,nick,mess)
    dispmess("<#{nick}>",mess)
  end

  # 今いるチャンネルの外からの通常メッセージ受信時の処理
  def on_external_priv(type,nick,channel,mess)
  end

  # JOIN受信時の処理
  def on_join(nick,channel)
    dispmess(nick,"JOIN #{channel}")
  end

  # PART受信時の処理
  def on_part(nick,channel)
    dispmess(nick,"PART #{channel}")
  end

  # QUIT受信時の処理
  def on_quit(nick,mess)
    dispmess(nick,"QUIT #{mess}")
  end

  # KICK受信時の処理
  def on_kick(nick,channel,mess,kicker)
    dispmess(nick,"KICK #{channel} #{kicker} #{mess}")
  end

  # 自分のJOIN受信時の処理
  def on_myjoin(channel)
    on_join(@irc_nick,channel)
  end

  # 自分のPART受信時の処理
  def on_mypart(channel)
    on_part(@irc_nick,channel)
  end

  # 自分のQUIT受信時の処理
  def on_myquit(mess)
    on_quit(@irc_nick,mess)
  end

  # 自分のKICK受信時の処理
  def on_mykick(channel,mess,kicker)
    on_kick(@irc_nick,channel,mess,kicker)
  end

  # NICK受信時の処理
  def on_nick(nick_old,nick_new)
    dispmess(nick_old,"NICK #{nick_new}")
  end

  # 自分がINVITEされた時の処理
  def on_myinvite(nick,channel)
    dispmess(nick,"INVITE #{channel}")
  end
  
  # エラーの時の処理
  def on_error(code)
    @disp.puts "Error: #{code}"
    sendmess("QUIT\r\n")  # 面倒なので終了にしている
  end
end
