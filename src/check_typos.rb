
class CheckTypos
  attr_accessor :base_dir, :target_exts, :target_files

  def initialize(base_dir, target_exts, options = {})
    @base_dir = base_dir
    @target_exts = target_exts
    @verbose = options[:verbose]
    @threshold_second = options[:threshold_second] || 300 # 更新時間がこれ以前のものをupdate_fileと認める
    @permitted_word_file = options[:permitted_word_file] || 'permitted_words'

    @target_files = Dir["{base_dir}/**/*.{#{target_exts.join(',')}}"]

    pairs = getWeirdWordsWithoutPermittedWords
    new_permitted_pairs = cofirm(pairs)
    updatePermitPairs(new_permitted_pairs)
  end

  # :force => trueとすると上書きする
  def createNewPermittedWordFile(options = {})
    raise "undefined" # TODO: 後で書く

    raise "permite file is exist so it can be created." if File.exist?(@permitted_word_file) && !options[:force]
    open(@permitted_word_file, "w") do |f|
    end
  end

  private

  #------------------------------------------------
  def getWeirdWordsWithoutPermittedWords
    result = getWeirdPairs - getPermittedPairs
    result.each{|w1, w2| puts "weird_word_without_permit_word:\t#{w1} <-> #{w2}" if @verbose }
    result
  end

  def confirm(pairs)
    pairs.select do |w1, w2|
      print "#{w1} <-> #{w2} |\tpermit this pair? (y/n/q)"
      input = gets.strip
      exit if input == 'q'
      input == 'y'
    end
  end

  def updatePermitPairs(pairs)
    open(@permitted_word_file, "w") do |f|
      (@cache_permit_pairs + pairs).map{|w1, w2| [w1, w2].sort}.sort.uniq.each do |w1, w2|
        f.puts "#{w1}:#{w1}"
      end
    end
  end

  # --------------------------------------------------------
  # TODO: あとでキャッシュ使用型に直す?
  def getAllWords
    getWordsOnUpdatedFiles
  end

  def getWordsOnUpdatedFiles(threshold_second=nil)
    words = []
    target_files.each do |path|
      STDERR.puts "searching: #{path}" if @verbose
      # threshold_secondが指定されていない場合は常にtrue
      if !threshold_second || ((Time.now - threshold_second) < File.mtime(path))
        words += File.path(path).scan(/\w+/)
      end
    end
    words.sort.uniq!
  end

  # wordsのなかでwordとの距離がdistance以下のワードがあればそれを返す
  # 無ければnilを返す
  def getNearestWord(word, words, distance)
    words.find{|w| levenshteinDistance(word, w) <= distance}
  end

  def levenshteinDistance (str1, str2)
   # lenStr1 + 1 行 lenStr2 + 1 列のテーブル d を用意する
   hash = Hash.new

   len1 = str1.length
   len2 = str2.length

   (0..len1-1).to_a.each { |i| hash[ i, 0 ] = i }
   (0..len2-1).to_a.each { |i| hash[ 0, i ] = i }

   (0..len1-1).to_a.each do |i1|
     (0..len2-1).to_a.each do |i2|
       cost = (str1[i1] == str2[i2]) ? 0 : 1
         hash[i1,i2] = [ hash[ i1 - 1, i2     ] + 1,
                         hash[ i1    , i2 - 1 ] + 1,
                         hash[ i1 - 1, i2 - 1 ] + cost
         ].min
     end
   end
   hash[len1-1, len2-1]
  end

  def getWeirdPairs
    all_words = getAllWords
    result = []
    recent_words = getWordsOnUpdatedFiles(@threshold_second)
    recent_words.each do |word|
      nw = getNearestWord(word, recent_words + all_words, 2)
      result << [word, nw].sort if nw
    end
    result.each{|w1, w2| puts "weird_word: #{w1} <-> #{w2}" if @verbose}
    result
  end

  def getPermittedPairs
    @cache_permit_pairs ||= File.read(@permitted_word_file).scan(/^(\w+):(\w+)$/).map{|w1, w2| [w1, w2].sort}
  end
end
