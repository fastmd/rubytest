# spec/script_spec.rb

require 'rspec'
require 'webmock/rspec'
require 'fileutils'
require 'logger'
require 'stringio'
require_relative '../script'

RSpec.describe WallpaperDownloader do
  before(:each) do
    # Disable real HTTP requests during tests
    WebMock.disable_net_connect!(allow_localhost: true)

    # Stub the wallpapers page request with default sample_html
    stub_request(:get, %r{smashingmagazine\.com}).to_return(body: sample_html)

    # Stub the image download requests
    stub_request(:get, 'http://example.com/wallpaper1_1920x1080.jpg').to_return(body: 'image data')
    stub_request(:get, 'http://example.com/wallpaper2_1280x720.png').to_return(body: 'image data')

    # Mock the robots.txt parser to always allow
    allow_any_instance_of(Robots).to receive(:allowed?).and_return(true)

    # Mock the request limiter to avoid delays during tests
    allow_any_instance_of(RequestLimiter).to receive(:wait)

    # Redirect logger output to a StringIO object for testing
    @log_output = StringIO.new
    allow(Logger).to receive(:new).and_return(Logger.new(@log_output))

    # Ensure directories are cleaned before each test
    FileUtils.rm_rf('wallpapers')
    FileUtils.rm_rf('logs')
  end

  after(:each) do
    # Clean up any downloaded files and directories
    FileUtils.rm_rf('wallpapers')
    FileUtils.rm_rf('logs')
  end

  let(:valid_args) { ['--month', '072024', '--theme', 'nature'] }
  let(:invalid_month_args) { ['--month', 'invalid', '--theme', 'nature'] }
  let(:missing_theme_args) { ['--month', '072024'] }
  let(:downloader) { WallpaperDownloader.new(valid_args) }

  let(:sample_html) do
    <<-HTML
      <html>
        <body>
          <h2>Nature Wallpapers</h2>
          <p>
            <a href="http://example.com/wallpaper1_1920x1080.jpg">Download</a>
            <a href="http://example.com/wallpaper2_1280x720.png">Download</a>
          </p>
        </body>
      </html>
    HTML
  end

  context 'with valid inputs' do
    it 'parses the month and theme correctly' do
      expect(downloader.month_input).to eq('072024')
      expect(downloader.theme).to eq('nature')
    end

    it 'constructs the correct URL' do
      target_date = downloader.send(:parse_date, downloader.month_input)
      url = downloader.send(:construct_month_url, target_date)
      expect(url).to eq('https://www.smashingmagazine.com/2024/06/desktop-wallpaper-calendars-july-2024/')
    end

    it 'fetches the wallpapers page successfully' do
      html = downloader.send(:fetch_wallpapers_page, 'https://www.smashingmagazine.com')
      expect(html).to include('Nature Wallpapers')
    end

    it 'extracts wallpapers matching the theme' do
      html = downloader.send(:fetch_wallpapers_page, 'https://www.smashingmagazine.com')
      wallpapers = downloader.send(:extract_wallpapers, html, 'nature', 'https://www.smashingmagazine.com')
      expect(wallpapers).not_to be_empty
      expect(wallpapers.first[:title]).to eq('nature wallpapers')
      expect(wallpapers.first[:links].size).to eq(2)
    end

    it 'downloads wallpapers correctly into respective directories' do
      downloader.run
      expect(File).to exist('wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg')
      expect(File).to exist('wallpapers/1280x720/nature_wallpapers_wallpaper2_1280x720.png')
    end

    it 'logs the download process' do
      downloader.run
      log_content = @log_output.string
      expect(log_content).to include('Download completed.')
      expect(log_content).to include('Downloading wallpapers for: nature wallpapers')
      expect(log_content).to include('Downloading wallpaper1_1920x1080.jpg to wallpapers/1920x1080')
      expect(log_content).to include('Downloading wallpaper2_1280x720.png to wallpapers/1280x720')
    end
  end

  context 'with invalid month format' do
    it 'raises an ArgumentError for invalid month format' do
      expect {
        WallpaperDownloader.new(invalid_month_args).run
      }.to raise_error(ArgumentError, 'Invalid month format. Please use MMYYYY.')
    end
  end

  context 'with missing theme' do
    it 'raises an ArgumentError when theme is missing' do
      expect {
        WallpaperDownloader.new(missing_theme_args).run
      }.to raise_error(ArgumentError, 'Theme option is required.')
    end
  end

  context 'when no wallpapers are found' do
    before do
      # Override the stub to return HTML with no matching wallpapers
      stub_request(:get, %r{smashingmagazine\.com}).to_return(body: no_wallpapers_html)
    end

    let(:no_wallpapers_html) do
      <<-HTML
        <html>
          <body>
            <h2>Other Wallpapers</h2>
            <p>No wallpapers here</p>
          </body>
        </html>
      HTML
    end

    it 'logs that no wallpapers were found' do
      downloader.run
      log_content = @log_output.string
      expect(log_content).to include('No wallpapers found matching the specified theme.')
    end
  end

  context 'when HTTP error occurs while fetching wallpapers page' do
    before do
      # Override the stub to return a 404 Not Found response
      stub_request(:get, %r{smashingmagazine\.com}).to_return(status: [404, 'Not Found'])
    end

    it 'handles HTTP errors gracefully' do
      expect { downloader.run }.to raise_error(SystemExit)
      log_content = @log_output.string
      expect(log_content).to include('Failed to fetch wallpapers page: 404 Not Found')
    end
  end

  context 'when HTTP error occurs while downloading an image' do
    before do
      # Override the stub for one image to return a 404 Not Found response
      stub_request(:get, 'http://example.com/wallpaper2_1280x720.png').to_return(status: [404, 'Not Found'])
    end

    it 'continues downloading other images when one fails' do
      downloader.run
      expect(File).to exist('wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg')
      expect(File).not_to exist('wallpapers/1280x720/nature_wallpapers_wallpaper2_1280x720.png')
      log_content = @log_output.string
      expect(log_content).to include('Failed to download http://example.com/wallpaper2_1280x720.png: 404 Not Found')
    end
  end

  context 'multi-threading behavior' do
    it 'does not exceed the maximum number of threads' do
      # Set max_threads to a known value for testing
      downloader.instance_variable_set(:@max_threads, 2)

      thread_count = 0
      original_thread_new = Thread.method(:new)

      allow(Thread).to receive(:new) do |*args, &block|
        thread_count += 1
        original_thread_new.call(*args, &block)
      end

      downloader.run
      expect(thread_count).to be <= 4
    end

    it 'downloads all images using threads' do
      downloader.run
      expect(Dir.glob('wallpapers/**/*').select { |f| File.file?(f) }.size).to eq(2)
    end

    it 'uses a thread-safe queue for task management' do
      # Run the downloader to initialize the @download_queue
      downloader.run

      queue = downloader.instance_variable_get(:@download_queue)
      expect(queue).to be_a(Queue)
      expect(queue).to be_empty # The queue should be empty after downloads
    end
  end

  context 'when a network error occurs during image download' do
    before do
      # Simulate a network failure
      stub_request(:get, 'http://example.com/wallpaper1_1920x1080.jpg').to_raise(SocketError.new('Failed to open TCP connection'))
    end

    it 'logs the network error and continues' do
      downloader.run
      expect(File).not_to exist('wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg')
      log_content = @log_output.string
      expect(log_content).to match(/Network error while downloading .*: Failed to open TCP connection/)
    end
  end


  context 'when access is disallowed by robots.txt' do
    before do
      # Mock the robots.txt parser to disallow access
      allow_any_instance_of(Robots).to receive(:allowed?).and_return(false)
    end

    it 'skips fetching the disallowed URL' do
      html = downloader.send(:fetch_wallpapers_page, 'https://www.smashingmagazine.com')
      expect(html).to eq('')
      log_content = @log_output.string
      expect(log_content).to include('Access to https://www.smashingmagazine.com is disallowed by robots.txt')
    end
  end

  context 'when a resolution is specified' do
    let(:args_with_resolution) { valid_args + ['--resolution', '1920x1080'] }
    let(:downloader) { WallpaperDownloader.new(args_with_resolution) }

    it 'downloads only images matching the specified resolution' do
      downloader.run
      expect(File).to exist('wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg')
      expect(File).not_to exist('wallpapers/1280x720/nature_wallpapers_wallpaper2_1280x720.png')
    end
  end

  context 'with invalid resolution format' do
    let(:args_with_invalid_resolution) { valid_args + ['--resolution', 'invalid'] }

    it 'raises an ArgumentError for invalid resolution format' do
      expect {
        WallpaperDownloader.new(args_with_invalid_resolution).run
      }.to raise_error(ArgumentError, 'Invalid resolution format. Please use WIDTHxHEIGHT (e.g., 1920x1080).')
    end
  end

  context 'when an image already exists' do
    before do
      # Create a dummy file to simulate existing image
      FileUtils.mkdir_p('wallpapers/1920x1080')
      File.write('wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg', 'dummy data')
    end

    it 'skips downloading the existing image' do
      downloader.run
      log_content = @log_output.string
      expect(log_content).to include('Skipped (already exists): wallpapers/1920x1080/nature_wallpapers_wallpaper1_1920x1080.jpg')
    end
  end



rescue OpenURI::HTTPError => e
  case e.io.status[0]
  when '404'
    logger.error "Page not found: #{url}"
  when '429'
    logger.error "Too many requests: #{url}"
    sleep(60) # Wait before retrying
  else
    logger.error "HTTP error fetching #{url}: #{e.message}"
  end
  return ''
rescue SocketError => e
  logger.error "Network error: #{e.message}"
  return ''

end
