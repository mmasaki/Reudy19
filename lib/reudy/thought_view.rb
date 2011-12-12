$REUDY_DIR= "." unless defined?($REUDY_DIR)

require "./message_log"
require "ostruct"
require "erb"

module Gimite
  log = MessageLog.new(ARGV[0] + "/log.dat")
  
  data = []
  File.open(ARGV[0] + "/thought.txt") do |f|
    f.each_line do |line|
      line.chomp!
      fields = line.split(/\t/)
      r = OpenStruct.new
      (r.input_mid, r.pattern, r.sim_mid, r.res_mid) = fields[0...4].map(&:to_i)
      (r.words_str, r.output) = fields[4...6]
      r.input = log[r.input_mid].body
      r.messages = []
      (r.sim_mid...r.sim_mid+6).each do |mid|
        m = OpenStruct.new
        m.nick = log[mid].fromNick
        m.body = log[mid].body
        m.is_sim = mid == r.sim_mid
        m.is_res = mid == r.res_mid
        r.messages.push(m)
      end
      data.push(r)
    end
  end
  
  extend(ERB::Util)
  
  template = File.open("thought_view.html").read
  ERB.new(template).run(binding)
end
