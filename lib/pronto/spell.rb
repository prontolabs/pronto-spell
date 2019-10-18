# frozen_string_literal: true

require 'pronto'
require 'ffi/aspell'

module Pronto
  class Spell < Runner
    CONFIG_FILE = '.pronto_spell.yaml'

    def ignored_words
      @ignored_words ||= begin
        words = (spelling_config['ignored_words'] || []).map(&:downcase)
        Set.new(words)
      end
    end

    def keywords
      @keywords ||= begin
        words = (spelling_config['keywords'] || []).map(&:downcase)
        Set.new(words)
      end
    end

    def run
      return [] if !@patches || @patches.count.zero?

      @patches
        .select { |patch| patch.additions.positive? }
        .map { |patch| inspect(patch) }
        .flatten.compact
    end

    private

    def inspect(patch)
      patch.added_lines.map do |line|
        if keywords.to_a.any? && !%r{#{keywords.to_a.join('|')}}.match(line.content)
          next
        end

        words = line.content.scan(/([A-Z]{2,})|([A-Z]{0,1}[a-z]+)/)
          .flatten.compact.uniq

        words
          .select { |word| misspelled?(word) }
          .map { |word| new_message(word, line) }
      end
    end

    def new_message(word, line)
      path = line.patch.delta.new_file[:path]
      level = :warning

      suggestions = speller.suggestions(word)

      msg = %("#{word}" might not be spelled correctly.)
      if suggestions.any?
        suggestions_text = suggestions[0..max_suggestions_number - 1].join(', ')
        msg += " Spelling suggestions: #{suggestions_text}"
      end

      Message.new(path, line, level, msg, nil, self.class)
    end

    def speller
      @speller ||= FFI::Aspell::Speller.new(
        language, 'sug-mode': suggestion_mode
      )
    end

    def spelling_config
      @spelling_config ||= begin
        config_path = File.join(repo_path, CONFIG_FILE)
        File.exist?(config_path) ? YAML.load_file(config_path) : {}
      end
    end

    def language
      spelling_config['language'] || 'en_US'
    end

    def suggestion_mode
      spelling_config['suggestion_mode'] || 'fast'
    end

    def min_word_length
      spelling_config['min_word_length'] || 5
    end

    def max_word_length
      spelling_config['max_word_length'] || Float::INFINITY
    end

    def max_suggestions_number
      spelling_config['max_suggestions_number'] || 3
    end

    def misspelled?(word)
      lintable_word?(word) && !speller.correct?(word)
    end

    def lintable_word?(word)
      (min_word_length..max_word_length).cover?(word.length) &&
        !ignored_words.include?(word.downcase)
    end
  end
end
