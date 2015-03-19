require 'gemoji-parser/version'
require 'gemoji'

module EmojiParser
  extend self

  # Generates a regular expression for matching emoji unicodes.
  # Call with "rehash: true" to regenerate the cached regex.
  def emoji_regexp(opts = {})
    return @emoji_regexp if defined?(@emoji_regexp) && !opts[:rehash]
    patterns = []

    Emoji.all.each do |emoji|
      u = emoji.unicode_aliases.map do |str|
        str.codepoints.map { |c| '\u{%s}' % c.to_s(16).rjust(4, '0') }.join('')
      end
      # Append unicode patterns longest first for broader match:
      patterns.concat u.sort! { |a, b| b.length - a.length }
    end

    @emoji_regexp = Regexp.new("(#{patterns.join('|')})")
  end

  # Parses all unicode emoji characters within a string.
  # Provide a block that performs the character transformation.
  def parse_unicode(text)
    text.gsub(emoji_regexp) do |match|
      emoji = Emoji.find_by_unicode($1)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all emoji tokens within a string.
  # Provide a block that performs the token transformation.
  def parse_tokens(text)
    text.gsub(/:([\w+-]+):/) do |match|
      emoji = Emoji.find_by_alias($1.to_s)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all emoji unicodes and tokens within a string.
  # Provide a block that performs all transformations.
  def parse_all(text)
    text = parse_unicode(text) { |emoji| yield(emoji) }
    parse_tokens(text) { |emoji| yield(emoji) }
  end

  # Transforms all unicode emoji into token strings.
  def tokenize(text)
    parse_unicode(text) { |emoji| ":#{emoji.name}:" }
  end

  # Transforms all token strings into unicode emoji.
  def detokenize(text)
    parse_tokens(text) { |emoji| emoji.raw }
  end

  # Generates a custom emoji file path.
  def filepath(emoji, path='/')
    [path.sub(/\/$/, ''), emoji.image_filename.split('/').pop].join('/')
  end
end