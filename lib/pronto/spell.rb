require 'pronto'
require 'ffi/aspell'

module Pronto
  class Spell < Runner
    def run
      return [] unless @patches

      @patches.select { |patch| patch.additions > 0 }
        .map { |patch| inspect(patch) }
        .flatten.compact
    end

    def inspect(patch)
      patch.added_lines.map do |line|
        words = line.content.scan(/[0-9a-zA-Z]+/)
        words.select { |word| word.length > 4 }
          .uniq
          .select { |word| !speller.correct?(word) }
          .map { |word| new_message(word, line) }
      end
    end

    def new_message(word, line)
      path = line.patch.delta.new_file[:path]
      level = :warning

      suggestions = speller.suggestions(word)
      msg = "#{word} might not be spelled correctly. Spelling suggestions: #{suggestions}"

      Message.new(path, line, level, msg, nil, self.class)
    end

    def speller
      @speller ||= begin
        result = FFI::Aspell::Speller.new('en_US')
        result.suggestion_mode = 'fast'
        result
      end
    end
  end
end
