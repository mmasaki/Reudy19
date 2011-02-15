#encoding: utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント

module Gimite
#デバッグ出力
def dprint(caption, *objs)
  objs.map! do |obj|
    obj.inspect
  end
  warn("caption : #{objs.join("/")}")
end

#contの全ての要素に対してpredが真を返すか。
def for_all?(cont, &pred)
  cont.each do |item|
    return false unless pred.call(item)
  end
  return true
end

#contの中にpredが真を返す要素が存在するか。
def there_exists?(cont, &pred)
  cont.each do |item|
    return true if pred.call(item)
  end
  return false
end

def sigma(range, &block)
  sum = nil
  range.each do |v|
    sum = sum ? (sum+block.call(v)) : block.call(v)
  end
  return sum
end

module_function(:dprint, :for_all?, :there_exists?, :sigma)
end #module Gimite

