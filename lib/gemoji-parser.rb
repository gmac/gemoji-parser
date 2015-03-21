require 'gemoji-parser/version'
require 'gemoji'

module EmojiParser
  extend self

  # Defines the parser's table of emoticons. May be customized!
  # Table is formatted as... { ":-)": :smile }
  attr_writer :emoticons

  def emoticons
    return @emoticons if defined? @emoticons

    @emoticons = {}
    emoticons = {
      angry: ">:-(",
      blush: ":-)",
      cry: ":'(",
      confused: [":-\\", ":-/"],
      disappointed: ":-(",
      kiss: ":-*",
      neutral_face: ":-|",
      monkey_face: ":o)",
      open_mouth: ":-o",
      smiley: "=-)",
      smile: ":-D",
      stuck_out_tongue: [":-p", ":-P", ":-b"],
      stuck_out_tongue_winking_eye: [";-p", ";-P", ";-b"],
      wink: ";-)"
    }

    # Parse all named patterns into a flat hash table,
    # where pattern is the key and its name is the value.
    # all patterns are duplicated with the "-" (nose) omitted.
    emoticons.each_pair do |name, patterns|
      patterns = [patterns] unless patterns.is_a?(Array)
      patterns.each do |pattern| 
        @emoticons[pattern] = name
        @emoticons[pattern.sub(/(?<=:|;|=)-/, '')] = name
      end
    end

    @emoticons
  end

  # DEPRECATED, TODO: remove in v1.2.x
  # - Options: rehash:boolean
  def emoji_regex(opts={})
    puts 'EmojiParser: #emoji_regex is deprecated. Please use #unicode_regex.'
    unicode_regex(opts)
  end

  # Provides a regular expression for matching unicode symbols.
  # - Options: rehash:boolean
  def unicode_regex(opts={})
    return @unicode_regex if defined?(@unicode_regex) && !opts[:rehash]
    patterns = []

    Emoji.all.each do |emoji|
      u = emoji.unicode_aliases.map do |str|
        str.codepoints.map { |c| '\u{%s}' % c.to_s(16).rjust(4, '0') }.join('')
      end
      patterns << unicode_matcher(u)
    end

    @unicode_pattern = patterns.compact.join('|')
    @unicode_regex = Regexp.new("(#{@unicode_pattern})")
  end

  # Provides a regular expression for matching token symbols.
  def token_regex(opts={})
    return @token_regex if defined?(@token_regex)
    @token_pattern = ':([\w+-]+):'
    @token_regex = Regexp.new(@token_pattern)
  end

  # Provides a regular expression for matching emoticon symbols.
  # - Options: rehash:boolean
  def emoticon_regex(opts={})
    return @emoticon_regex if defined?(@emoticon_regex) && !opts[:rehash]
    pattern = emoticons.keys.map { |key| Regexp.escape(key) }.join('|')
    @emoticon_pattern = "(?<=^|\\s)(?:#{ pattern })(?=\\s|$)"
    @emoticon_regex = Regexp.new("(#{@emoticon_pattern})")
  end

  # Generates a regex for matching all symbol sets.
  # - Options: unicode:boolean, tokens:boolean, emoticons:boolean
  def macro_regex(opts={})
    unicode_regex if opts[:unicode]
    token_regex if opts[:tokens]
    emoticon_regex if opts[:emoticons]
    regex = []

    if opts[:emoticons] && opts[:unicode]
      regex << "(?:#{ @emoticon_pattern })"
      regex << @unicode_pattern
    else
      regex << @emoticon_pattern if opts[:emoticons]
      regex << @unicode_pattern if opts[:unicode]
    end

    regex = regex.any? ? "(#{ regex.join('|') })" : ""

    if opts[:tokens]
      if regex.empty?
        regex = @token_pattern
      else
        regex = "(?:#{ @token_pattern })|#{ regex }"
      end
    end

    Regexp.new(regex)
  end

  # Parses all unicode symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_unicode(text)
    text.gsub(unicode_regex) do |match|
      emoji = Emoji.find_by_unicode($1)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all token symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_tokens(text)
    text.gsub(token_regex) do |match|
      emoji = Emoji.find_by_alias($1)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all emoticon symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_emoticons(text)
    text.gsub(emoticon_regex) do |match|
      if emoticons.has_key?($1)
        emoji = Emoji.find_by_alias(emoticons[$1].to_s)
        block_given? && emoji ? yield(emoji) : match
      else
        match
      end
    end
  end

  # DEPRECATED, TODO: remove in v1.2.x
  def parse_all(text)
    puts 'EmojiParser: #parse_all is deprecated. Please use #parse.'
    parse(text, unicode: true, tokens: true)
  end

  # Parses all emoji unicode, tokens, and emoticons within a string.
  # - Block: performs all symbol transformations.
  # - Options: unicode:boolean, tokens:boolean, emoticons:boolean
  def parse(text, opts={})
    if opts.none?
      opts = { unicode: true, tokens: true, emoticons: true }
    elsif opts.one?
      return parse_unicode(text) { |e| yield e } if opts[:unicode]
      return parse_tokens(text) { |e| yield e } if opts[:tokens]
      return parse_emoticons(text) { |e| yield e } if opts[:emoticons]
    end
    text.gsub(macro_regex(opts)) do |match|
      a = defined?($1) ? $1 : nil
      b = defined?($2) ? $2 : nil
      emoji = find(a || b)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Transforms all unicode emoji into token strings.
  def tokenize(text)
    parse_unicode(text) { |emoji| ":#{emoji.name}:" }
  end

  # Transforms all token strings into unicode emoji.
  def detokenize(text)
    parse_tokens(text) { |emoji| emoji.raw }
  end

  # Finds an Emoji::Character instance for an unknown symbol.
  # - symbol: an <Emoji::Character>, emoticon, unicode, or token.
  def find(symbol)
    return symbol if (symbol.is_a?(Emoji::Character))
    symbol = emoticons[symbol].to_s if emoticons.has_key?(symbol)
    Emoji.find_by_alias(symbol) || Emoji.find_by_unicode(symbol) || nil
  end

  # Gets a symbol file reference; optionally with a custom path.
  def filepath(symbol, path=nil)
    emoji = find(symbol)
    return nil unless emoji
    return emoji.image_filename unless path
    "#{ path.sub(/\/$/, '') }/#{ emoji.image_filename.split('/').pop }"
  end

  private

  # Compiles a matcher for unicode patterns.
  # Does fancy formatting for drastically faster matching.
  def unicode_matcher(patterns)
    patterns.sort! { |a, b| b.length - a.length }
    base = patterns.pop
    opts = []
    alts = []

    patterns.reverse_each do |pattern|
      if pattern.start_with?(base)
        opts << pattern.sub(base, '')
      else
        alts << pattern
      end
    end

    base += "(?:#{ opts.join('|') })?" if opts.any?
    alts << base
    alts.join('|') if alts.any?
  end
end