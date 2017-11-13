require 'pronto'
require 'ffi/aspell'

module Pronto
  class Spell < Runner
    CONFIG_FILE = '.pronto_spell.yml'.freeze
    CONFIG_KEYS = %w(files_to_lint whitelist).freeze

    def files_to_lint
      @files_to_lint || /\.rb$/
    end

    def files_to_lint=(regexp)
      @files_to_lint = regexpify(regexp)
    end

    def whitelist
      @whitelist || []
    end

    def whitelist=(array)
      @whitelist = array.map { |regexp| regexpify(regexp) }
    end

    def run
      return [] if !@patches || @patches.count.zero?

      read_config

      @all_symbols = Symbol.all_symbols

      @patches
        .select { |patch| patch.additions > 0 }
        .select { |patch| should_lint_file?(patch.new_file_full_path) }
        .map { |patch| inspect(patch) }
        .flatten.compact
    end

    private

    def inspect(patch)
      patch.added_lines.map do |line|
        words = line.content.scan(/[0-9a-zA-Z]+/)
        words.uniq
          .select { |word| misspelled?(word) }
          .map { |word| new_message(word, line) }
      end
    end

    def new_message(word, line)
      path = line.patch.delta.new_file[:path]
      level = :info

      suggestions = speller.suggestions(word)
      msg = %("#{word}" might not be spelled correctly.)
      msg << " Spelling suggestions: #{suggestions[0..2].join(', ')}" unless suggestions.empty?

      Message.new(path, line, level, msg, nil, self.class)
    end

    def speller
      @speller ||= begin
        result = FFI::Aspell::Speller.new('en_US')
        result.suggestion_mode = 'fast'
        result
      end
    end

    def read_config
      config_file = File.join(repo_path, CONFIG_FILE)
      return unless File.exist?(config_file)
      config = YAML.load_file(config_file)

      CONFIG_KEYS.each do |config_key|
        next unless config[config_key]
        send("#{config_key}=", config[config_key])
      end
    end

    def misspelled?(word)
      (5..30).cover?(word.length) &&
        word !~ /\A\d+/ &&            # "1234", "1050px"
        !symbol_defined?(word) &&     # "strftime"
        !speller.correct?(word) &&
        !speller.correct?(word.sub(/(e?s|\d+)\z/, '')) &&
        !correct_camel_case?(word) && # "AppleOrange"
        !whitelist.any? { |regexp| regexp =~ word }
    end

    def should_lint_file?(path)
      files_to_lint =~ path.to_s
    end

    def correct_camel_case?(word)
      word = word[0].capitalize + word[1..-1]
      parts = word.scan(/[A-Z][a-z]+|[A-Z]+(?![a-z])/)
      parts.size > 1 && parts.none? { |part| misspelled?(part) }
    end

    def regexpify(regexp)
      regexp.is_a?(Regexp) ? regexp : Regexp.new(regexp, Regexp::IGNORECASE)
    end

    def symbol_defined?(symbol)
      @all_symbols.include?(symbol.to_sym)
    end
  end
end
