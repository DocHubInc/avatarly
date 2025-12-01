require 'spec_helper'

describe Avatarly do
  describe '.generate_avatar' do
    it 'generates avatar for given email address' do
      result = described_class.generate_avatar("hello.world@example.com",
                                               background_color: "#000000")
      assert_image_equality(result, :HW_black_white_32, 34)
    end

    it 'accepts parameters for size, background, vertical_offset and font colors' do
      result = described_class.generate_avatar("hello world",
                                               background_color: "#FFFFFF",
                                               font_color: "#000000",
                                               vertical_offset: 5,
                                               size: 64)

      assert_image_equality(result, :HW_white_black_offset_64, 10)
    end

    context 'accepts parameters for format' do
      it '.png'  do
        result = described_class.generate_avatar("hello.world@example.com",
                                                 format: "png")
        assert_image_format(result, :png)
      end

      it '.jpg' do
        result = described_class.generate_avatar("hello.world@example.com",
                                                 format: "jpeg")
        assert_image_format(result, :jpeg)
      end
    end

    context 'non-email input' do
      it 'uses first letters of first two space separated words' do
        result = described_class.generate_avatar("hello World",
                                                 background_color: "#000000")
        assert_image_equality(result, :HW_black_white_32, 34)
      end

      it 'falls back to dot-separated words when no spaces in input' do
        result = described_class.generate_avatar("hello.World",
                                                 background_color: "#000000")
        assert_image_equality(result, :HW_black_white_32, 34)
      end

      it 'falls back to single-letter avatar when no dots and spaces found' do
        result = described_class.generate_avatar("HelloWorld",
                                                 background_color: "#000000")
        assert_image_equality(result, :H_black_white_32)
      end

      it 'can generate using custom separators' do
        result = described_class.generate_avatar("hfoow",
                                                 background_color: "#000000",
                                                 separator: "foo")
        assert_image_equality(result, :HW_black_white_32, 34)
      end

      it 'does not break if input has leading or trailing space' do
        result = described_class.generate_avatar(" HelloWorld ",
                                                 background_color: "#000000")
        assert_image_equality(result, :H_black_white_32)
      end

      it 'does not break if input has a space and non-word character' do
        result = described_class.generate_avatar("H !",
                                                 background_color: "#000000")
        assert_image_equality(result, :H_black_white_32)
      end

      it 'does not break if input has a dot and non-word character' do
        result = described_class.generate_avatar("H.!",
                                                 background_color: "#000000")
        assert_image_equality(result, :H_black_white_32)
      end

      it 'does not break if input has leading or trailing non-word character' do
        result = described_class.generate_avatar("%HelloWorld!",
                                                 background_color: "#000000")
        assert_image_equality(result, :H_black_white_32)
      end

      it 'does not break if no text found' do
        result = described_class.generate_avatar(nil,
                                                 background_color: "#000000")
        assert_image_equality(result, :black_empty, 38)
      end

      it 'strips leading/trailing whitespace without striping other whitespaces' do
        expect(described_class).to receive(:initials).with('Hello World', {}).and_return 'HW'
        described_class.generate_avatar(' Hello World! ')
      end
    end

    context 'with :lang option for Unicode support' do
      it 'uses UnicodeUtils.upcase with the specified language' do
        # Turkish has special uppercase rules (i → İ, not I)
        # initials() returns lowercase, then UnicodeUtils.upcase is called
        expect(UnicodeUtils).to receive(:upcase).with('i', :tr).and_return('İ')
        described_class.generate_avatar("istanbul", background_color: "#000000", lang: :tr)
      end

      it 'uses language-aware regex for non-word character stripping' do
        # With :lang, uses [[:word:]] which includes Unicode letters
        # Without :lang, uses \w which is ASCII-only
        expect(UnicodeUtils).to receive(:upcase).with('ПС', :uk).and_return('ПС')
        described_class.generate_avatar("Привіт Світ", background_color: "#000000", lang: :uk)
      end
    end

    context 'parse_options' do
      it 'converts string size to integer' do
        opts = described_class.send(:parse_options, size: "64")
        expect(opts[:size]).to eq(64)
        expect(opts[:size]).to be_a(Integer)
      end

      it 'converts string font_size to integer' do
        opts = described_class.send(:parse_options, font_size: "24")
        expect(opts[:font_size]).to eq(24)
        expect(opts[:font_size]).to be_a(Integer)
      end

      it 'converts string vertical_offset to integer' do
        opts = described_class.send(:parse_options, vertical_offset: "5")
        expect(opts[:vertical_offset]).to eq(5)
        expect(opts[:vertical_offset]).to be_a(Integer)
      end

      it 'calculates default font_size as half of size' do
        opts = described_class.send(:parse_options, size: 100)
        expect(opts[:font_size]).to eq(50)
      end

      it 'falls back to default font when custom font does not exist' do
        opts = described_class.send(:parse_options, font: "/nonexistent/path/font.ttf")
        expect(opts[:font]).to eq("#{described_class.root}/assets/fonts/Roboto.ttf")
      end

      it 'keeps custom font when it exists' do
        existing_font = "#{described_class.root}/assets/fonts/Roboto.ttf"
        opts = described_class.send(:parse_options, font: existing_font)
        expect(opts[:font]).to eq(existing_font)
      end
    end

    context 'default random background color' do
      it 'selects a random color from BACKGROUND_COLORS when not specified' do
        opts = described_class.send(:parse_options, {})
        expect(described_class::BACKGROUND_COLORS).to include(opts[:background_color])
      end

      it 'can produce different colors on multiple calls' do
        colors = 10.times.map { described_class.send(:parse_options, {})[:background_color] }
        # With 42 colors and 10 samples, the probability of all sames is negligible
        expect(colors.uniq.size).to be > 1
      end
    end
  end

  describe '.root' do
    it 'returns the project root directory' do
      expect(described_class.root).to eq(File.expand_path('../..', __FILE__).gsub('/spec', ''))
      expect(File.directory?(described_class.root)).to be true
    end
  end

  describe '.lib' do
    it 'returns the lib directory path' do
      expect(described_class.lib).to eq(File.join(described_class.root, 'lib'))
      expect(File.directory?(described_class.lib)).to be true
    end
  end

  describe 'BACKGROUND_COLORS' do
    it 'contains valid hex color codes' do
      described_class::BACKGROUND_COLORS.each do |color|
        expect(color).to match(/^#[0-9a-f]{6}$/i),
          "Expected #{color} to be a valid hex color"
      end
    end

    it 'has a reasonable number of colors for variety' do
      expect(described_class::BACKGROUND_COLORS.length).to be >= 10
    end
  end
end
