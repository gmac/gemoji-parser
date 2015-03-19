# coding: utf-8
require 'gemoji-parser'

describe EmojiParser do
  let(:test_unicode) { 'Test 🙈 🙊 🙉 😰 :invalid: 🐠.' }
  let(:test_mixed) { 'Test 🙈 🙊 🙉 :cold_sweat: :invalid: :tropical_fish:.' }
  let(:test_tokens) { 'Test :see_no_evil: :speak_no_evil: :hear_no_evil: :cold_sweat: :invalid: :tropical_fish:.' }

  describe '#emoji_regexp' do
    it 'generates once and remains cached.' do
      first = EmojiParser.emoji_regexp
      second = EmojiParser.emoji_regexp
      expect(first).to be second
    end

    it 'regenerates when called with a :rehash option.' do
      first = EmojiParser.emoji_regexp
      second = EmojiParser.emoji_regexp(rehash: true)
      expect(first).not_to be second
    end
  end

  describe '#parse_unicode' do
    it 'replaces all valid emoji unicode via block transformation.' do
      parsed = EmojiParser.parse_unicode(test_mixed) { |emoji| 'X' }
      expect(parsed).to eq "Test X X X :cold_sweat: :invalid: :tropical_fish:."
    end
  end

  describe '#parse_tokens' do
    it 'replaces all valid emoji tokens via block transformation.' do
      parsed = EmojiParser.parse_tokens(test_tokens) { |emoji| 'X' }
      expect(parsed).to eq "Test X X X X :invalid: X."
    end
  end

  describe '#parse_all' do
    it 'replaces all valid emoji unicode and tokens via block transformation.' do
      parsed = EmojiParser.parse_all(test_mixed) { |emoji| 'X' }
      expect(parsed).to eq "Test X X X X :invalid: X."
    end
  end

  describe '#tokenize' do
    it 'successfully tokenizes all Gemoji unicode aliases.' do
      Emoji.all.each do |emoji|
        emoji.unicode_aliases.each do |u|
          tokenized = EmojiParser.tokenize("Test #{u}")
          expect(tokenized).to eq "Test :#{emoji.name}:"
        end
      end
    end

    it 'replaces all valid emoji unicodes with their token equivalent.' do
      tokenized = EmojiParser.tokenize(test_mixed)
      expect(tokenized).to eq test_tokens
    end
  end

  describe '#detokenize' do
    it 'replaces all valid emoji tokens with their raw unicode equivalent.' do
      tokenized = EmojiParser.detokenize(test_mixed)
      expect(tokenized).to eq test_unicode
    end
  end

  describe '#filepath' do
    let (:test_emoji) { Emoji.find_by_alias('de') }
    let (:test_file) { '1f1e9-1f1ea.png' }

    it 'formats a Gemoji image path as a root location by default.' do
      path = EmojiParser.filepath(test_emoji)
      expect(path).to eq "/#{test_file}"
    end

    it 'formats a Gemoji image path as a custom location (with trailing slash).' do
      images_path = '//fonts.test.com/emoji/'
      path = EmojiParser.filepath(test_emoji, images_path)
      expect(path).to eq "#{images_path}#{test_file}"
    end

    it 'formats a Gemoji image path to a custom location (no trailing slash).' do
      images_path = '//fonts.test.com/emoji'
      path = EmojiParser.filepath(test_emoji, images_path)
      expect(path).to eq "#{images_path}/#{test_file}"
    end
  end
end