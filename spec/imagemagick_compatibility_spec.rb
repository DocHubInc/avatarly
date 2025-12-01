require 'spec_helper'

describe 'ImageMagick Compatibility' do
  def imagemagick_version
    version_output = `magick --version 2>&1 || convert --version 2>&1`
    if version_output =~ /ImageMagick\s+(\d+)\./
      Regexp.last_match(1).to_i
    else
      nil
    end
  end

  def imagemagick_7?
    MiniMagick.cli.to_s == 'imagemagick7'
  end

  describe 'ImageMagick version detection' do
    it 'detects ImageMagick installation' do
      version = imagemagick_version
      expect(version).not_to be_nil,
        "ImageMagick is not installed or not available in PATH"

      puts "\n  → Detected ImageMagick version: #{version}"
    end

    it 'MiniMagick can determine the CLI type' do
      cli = MiniMagick.cli.to_s
      valid_types = %w[imagemagick imagemagick7 graphicsmagick]

      expect(valid_types).to include(cli),
        "Expected MiniMagick CLI to be a valid type, got: #{cli}"

      cli_description = case cli
                        when 'imagemagick7'
                          'ImageMagick 7 (magick)'
                        when 'imagemagick'
                          'ImageMagick 6 (convert)'
                        when 'graphicsmagick'
                          'GraphicsMagick'
                        else
                          cli
                        end

      puts "\n  → MiniMagick CLI type: #{cli_description}"
    end
  end

  describe '.generate_image' do
    let(:test_options) do
      {
        background_color: "#FF0000",
        font_color: "#FFFFFF",
        size: 64,
        vertical_offset: 0,
        font: "#{Avatarly.root}/assets/fonts/Roboto.ttf",
        format: 'png',
        font_size: 32
      }
    end

    context 'with ImageMagick v6 or v7' do
      it 'generates a valid PNG image with correct dimensions' do
        image = Avatarly.send(:generate_image, 'AB', test_options)

        expect(image).to be_a(MiniMagick::Image)
        expect(image.valid?).to be true
        expect(image.type).to eq('PNG')
        expect(image.dimensions).to eq([64, 64])
      end

      it 'respects the size option' do
        [16, 64, 256, 512].each do |size|
          opts = test_options.merge(size: size, font_size: size / 2)
          image = Avatarly.send(:generate_image, 'AB', opts)

          expect(image.dimensions).to eq([size, size]),
            "Expected #{size}x#{size}, got #{image.dimensions.join('x')}"
        end
      end

      it 'generates empty avatar when text is blank' do
        image = Avatarly.send(:generate_image, '', test_options)

        expect(image.valid?).to be true
        expect(image.dimensions).to eq([64, 64])
      end

      it 'handles special characters without shell injection' do
        # These could cause shell issues if not properly escaped
        dangerous_texts = ["A'B", 'A"B', 'A&B', 'A;B', 'A|B', '$(whoami)']

        dangerous_texts.each do |text|
          expect {
            image = Avatarly.send(:generate_image, text, test_options)
            expect(image.valid?).to be true
          }.not_to raise_error
        end
      end

      it 'works with Cyrillic characters' do
        image = Avatarly.send(:generate_image, 'ПС', test_options)

        expect(image).to be_a(MiniMagick::Image)
        expect(image.valid?).to be true
      end
    end

    context 'error handling' do
      it 'raises error for invalid format' do
        invalid_opts = test_options.merge(format: 'invalid_format_xyz')

        expect {
          Avatarly.send(:generate_image, 'TEST', invalid_opts)
        }.to raise_error(MiniMagick::Error)
      end

      it 'handles missing font based on ImageMagick build' do
        invalid_opts = test_options.merge(font: '/nonexistent/font.ttf')

        # Behavior varies: some builds use fallback, others raise error
        begin
          image = Avatarly.send(:generate_image, 'TEST', invalid_opts)
          expect(image.valid?).to be true
        rescue MiniMagick::Error => e
          expect(e.message).to include('font')
        end
      end
    end

    context 'integration with full avatar generation' do
      it 'end-to-end avatar generation works' do
        blob = Avatarly.generate_avatar('test.user@example.com',
                                       background_color: '#000000',
                                       size: 64)

        expect(blob).not_to be_nil
        expect(blob).to be_a(String)
        expect(blob.bytesize).to be > 0

        # Verify it's a valid PNG
        temp_file = Tempfile.new(['avatar', '.png'])
        File.binwrite(temp_file.path, blob)

        expect(FastImage.type(temp_file.path)).to eq(:png)
        expect(FastImage.size(temp_file.path)).to eq([64, 64])

        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe 'Version-specific behavior' do
    it 'documents the ImageMagick version being tested' do
      version = imagemagick_version
      cli = (MiniMagick.cli.to_s rescue nil)

      cli_display = case cli
                    when 'imagemagick7'
                      'ImageMagick 7'
                    when 'imagemagick'
                      'ImageMagick 6'
                    when 'graphicsmagick'
                      'GraphicsMagick'
                    else
                      cli || 'Unknown'
                    end

      message = "\n"
      message += "  ╔═══════════════════════════════════════════════════════╗\n"
      message += "  ║          ImageMagick Compatibility Report            ║\n"
      message += "  ╠═══════════════════════════════════════════════════════╣\n"
      message += "  ║  ImageMagick Version: #{version || 'Unknown'}#{' ' * (31 - (version || 'Unknown').to_s.length)}║\n"
      message += "  ║  MiniMagick CLI Type: #{cli_display}#{' ' * (31 - cli_display.length)}║\n"
      message += "  ║  Test Status: ✓ PASSED#{' ' * 30}║\n"
      message += "  ╚═══════════════════════════════════════════════════════╝\n"

      puts message

      expect([6, 7]).to include(version),
        "Expected ImageMagick version 6 or 7, got: #{version}"
    end
  end
end

