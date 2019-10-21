# frozen_string_literal: true

require 'spec_helper'

module Pronto
  describe Spell do
    subject(:spell) { described_class.new(patches) }

    let(:patches) { [patch] }

    let(:patch) do
      double('Patch', additions: 1, added_lines: added_lines)
    end

    let(:added_lines) do
      [
        double(
          'AddedLine',
          content: patch_content, patch: line_patch, commit_sha: 'abc23'
        )
      ]
    end

    let(:patch_content) { 'helllo woorld!' }
    let(:line_patch) { double('LinePatch', delta: line_patch_delta) }
    let(:line_patch_delta) { double('Delta', new_file: { file_path: 'some/path.txt' }) }
    let(:spelling_config) { {} }

    before do
      allow(spell).to receive(:spelling_config)
        .and_return(spelling_config)

      allow(spell).to receive(:repo_path)
        .and_return('/home/developer/projects/pronto-spell')
    end

    describe '#run' do
      subject(:lint_messages) { spell.run.map(&:msg) }

      context 'patches are nil' do
        let(:patches) { nil }

        it { is_expected.to be_empty }
      end

      context 'no patches' do
        let(:patches) { [] }

        it { is_expected.to be_empty }
      end

      context 'with misspelled words' do
        it 'returns list of misspeled words' do
          expect(lint_messages).to eq [
            '"helllo" might not be spelled correctly. ' \
              'Spelling suggestions: hell lo, hell-lo, hello',

            '"woorld" might not be spelled correctly. ' \
              'Spelling suggestions: world, wold, whorled'
          ]
        end
      end

      context 'with camel cased words' do
        let(:patch_content) { 'CamelWithhWrrrongGrammar' }

        it 'validates each word separately' do
          expect(lint_messages).to eq [
            '"Withh" might not be spelled correctly. ' \
              'Spelling suggestions: With, Withe, Wither',

            '"Wrrrong" might not be spelled correctly. ' \
              'Spelling suggestions: Wrong, Wrung, Wring'
          ]
        end
      end

      context 'with words consisting of capital letters only' do
        let(:patch_content) { 'LOOOK_AT_ME_I_AM_SHOWTING' }

        it 'validates each word separately' do
          expect(lint_messages).to eq [
            '"LOOOK" might not be spelled correctly. ' \
              'Spelling suggestions: LOO OK, LOO-OK, LOOK',

            '"SHOWTING" might not be spelled correctly. ' \
              'Spelling suggestions: SHOW TING, SHOW-TING, SHOOTING'
          ]
        end
      end

      context 'with words which contain numbers' do
        let(:patch_content) { '2coool4skool' }

        it 'lints words and ignores number part' do
          expect(lint_messages).to eq [
            '"coool" might not be spelled correctly. '\
              'Spelling suggestions: cool, Colo, coil',

            '"skool" might not be spelled correctly. '\
              'Spelling suggestions: skoal, school, skill'
          ]
        end
      end

      context 'with ignored words' do
        let(:spelling_config) do
          { 'ignored_words' => ['HaXoR'] }
        end

        let(:patch_content) { 'it feels good to be a haxor' }

        it 'does not complain about words included in personal dictionary' do
          expect(lint_messages).to be_empty
        end
      end

      context 'with keywords in config' do
        let(:spelling_config) do
          { 'keywords' => ['context', 'it'] }
        end

        context 'when the patch content contains one of the keywords' do
          let(:patch_content) { 'context "helllo the tsetir"' }

            it 'returns the list of misspeled words' do
              expect(lint_messages).to eq [
                '"helllo" might not be spelled correctly. ' \
                  'Spelling suggestions: hell lo, hell-lo, hello',

                '"tsetir" might not be spelled correctly. ' \
                  'Spelling suggestions: testier, tester, taster'
              ]
            end
        end

        context 'when the patch content does not contain any keywords' do
          let(:patch_content) { 'helllo the tsetir' }

          it 'does not complain' do
            expect(lint_messages).to be_empty
          end
        end
      end
    end
  end
end
