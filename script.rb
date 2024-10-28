#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'date'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'thread'
require 'logger'
require 'robots'  # For robots.txt parsing
require 'fileutils'
require 'fastimage'


##
# The WallpaperDownloader class encapsulates the functionality to download wallpapers
# from Smashing Magazine based on a specified theme and month.
#
# It handles parsing command-line arguments, validating inputs, fetching wallpaper
# pages, extracting wallpaper links, and downloading images with respect to rate limits.
class WallpaperDownloader
  ##
  # The base URL for Smashing Magazine, used to construct full URLs for fetching wallpapers.
  SMASHING_BASE_URL = 'https://www.smashingmagazine.com'

  ##
  # @return [String] The month input specified by the user in MMYYYY format.
  attr_reader :month_input

  ##
  # @return [String, nil] The theme specified by the user, converted to lowercase.
  attr_reader :theme

  ##
  # @return [String] The mode of operation, either "month" or "category".
  attr_reader :mode

  ##
  # @return [Logger] The logger instance used for logging messages.
  attr_reader :logger


  ##
  # Initializes the downloader with command-line arguments.
  #
  # args - An array of command-line arguments (default: ARGV).
  def initialize(args = ARGV)
    options = parse_options(args)
    @month_input = options[:month]
    @theme = options[:theme]&.downcase
    @mode = options[:mode] || 'month' # Default to 'month' mode
    @output_mutex = Mutex.new # To display the output to the console
    @max_threads = options[:max_threads] || 5  # Allow setting max_threads
    @request_delay = options[:request_delay] || 1.0  # Default to 1 second

    # Parse and validate the resolution
    if options[:resolution]
      res_match = options[:resolution].match(/^(\d+)x(\d+)$/)
      if res_match
        @resolution = [res_match[1].to_i, res_match[2].to_i]
      else
        raise ArgumentError, 'Invalid resolution format. Please use WIDTHxHEIGHT (e.g., 1920x1080).'
      end
    else
      @resolution = nil
    end

    # Ensure directories exist
    FileUtils.mkdir_p('logs')
    FileUtils.mkdir_p('wallpapers')

    # Initialize the logger correctly
    @logger = Logger.new(File.join('logs', 'wallpaper_downloader.log')) # Append logs to the file

    @request_limiter = RequestLimiter.new(@request_delay) # Delay between requests

    @robots = Robots.new('MyWallpaperDownloader/1.0')  # Initialize the robots.txt parser

    @file_mutex = Mutex.new  # Mutex for file operations
    @log_mutex = Mutex.new   # Mutex for logging
  end



  ##
  # Runs the wallpaper downloader, orchestrating the fetching and downloading of wallpapers.
  #
  # This method initializes the process by validating inputs, constructing URLs,
  # fetching wallpapers, and handling the download process.
  def run
    Thread.abort_on_exception = true  # Ensure exceptions in threads are not ignored

    validate_inputs
    urls = construct_urls

    wallpapers = fetch_and_extract_wallpapers(urls)

    if wallpapers.empty?
      logger.info 'No wallpapers found matching the specified theme.'
      return
    end

    download_wallpapers(wallpapers)
    logger.info 'Download completed.'
  rescue OpenURI::HTTPError => e
    logger.error "Failed to fetch wallpapers page: #{e.message}"
    exit 1
  end

  private

  ##
  # Parses command-line options and returns a hash of the parsed options.
  #
  # @param args [Array<String>] The array of command-line arguments.
  # @return [Hash] A hash containing the parsed options.
  def parse_options(args)
    opts = {}
    OptionParser.new do |parser|
      parser.banner = 'Usage: script.rb [options]'

      parser.on('-m', '--month MMYYYY', 'Specify the month and year (e.g., 102024 for October 2024)') do |v|
        opts[:month] = v
      end

      parser.on('-t', '--theme THEME', 'Specify the theme (e.g., "nature")') do |v|
        opts[:theme] = v.downcase
      end

      parser.on('-r', '--resolution WxH', 'Specify the resolution (e.g., "1920x1080")') do |v|
        opts[:resolution] = v
      end

      parser.on('--mode MODE', 'Specify the mode: "month" or "category" (default: "month")') do |v|
        opts[:mode] = v.downcase
      end

      parser.on('--threads N', Integer, 'Specify the number of threads to use') do |v|
        opts[:max_threads] = v
      end

      parser.on('--delay SECONDS', Float, 'Specify the delay between requests in seconds') do |v|
        opts[:request_delay] = v
      end

      parser.on('-h', '--help', 'Prints this help') do
        puts parser
        exit
      end
    end.parse!(args)

    opts
  end


  ##
  # Validates the user inputs to ensure required options are provided and valid.
  #
  # @raise [ArgumentError] If required options are missing or invalid.
  def validate_inputs
    if theme.nil?
      raise ArgumentError, 'Theme option is required.'
    end

    if mode == 'month' && month_input.nil?
      raise ArgumentError, 'Month option is required in "month" mode.'
    end

    unless %w[month category].include?(mode)
      raise ArgumentError, 'Invalid mode. Please choose "month" or "category".'
    end
  end

  ##
  # Parses the month input into a Date object.
  #
  # month_str - A string representing the month and year in MMYYYY format.
  #
  # Returns a Date object.
  def parse_date(month_str)
    Date.strptime(month_str, '%m%Y')
  rescue ArgumentError
    raise ArgumentError, 'Invalid month format. Please use MMYYYY.'
  end

  ##
  # Constructs the URLs to fetch based on the current mode of operation.
  #
  # @return [Array<String>] An array of URLs to fetch wallpapers from.
  # @raise [ArgumentError] If the mode is invalid.
  def construct_urls
    case mode
    when 'month'
      target_date = parse_date(month_input)
      [construct_month_url(target_date)]
    when 'category'
      construct_category_urls
    else
      raise ArgumentError, 'Invalid mode.'
    end
  end

  ##
  # Constructs the URL for the specified month.
  #
  # target_date - A Date object representing the target month.
  #
  # Returns a URL string.
  def construct_month_url(target_date)
    publication_date = target_date.prev_month
    target_month_name = target_date.strftime('%B').downcase
    publication_month_str = publication_date.strftime('%m')
    publication_year = publication_date.year

    url = "#{SMASHING_BASE_URL}/#{publication_year}/#{publication_month_str}/" \
      "desktop-wallpaper-calendars-#{target_month_name}-#{target_date.year}/"
    logger.info "Fetching wallpapers from #{url}"
    url
  end

  ##
  # Constructs URLs for all categories.
  #
  # Returns an array of URLs.
  def construct_category_urls
    category_url = "#{SMASHING_BASE_URL}/category/wallpapers/"
    logger.info "Fetching wallpapers from #{category_url}"

    html_pages = fetch_all_category_pages(category_url)
    collect_article_links(html_pages)
  end

  ##
  # Fetches and extracts wallpapers using multi-threading.
  #
  # urls - An array of URLs to fetch and parse.
  #
  # Returns an array of wallpapers.
  def fetch_and_extract_wallpapers(urls)
    wallpapers = []
    queue = Queue.new
    urls.each { |url| queue << url }

    threads = []
    @max_threads.times do
      threads << Thread.new do
        until queue.empty?
          url = nil
          begin
            url = queue.pop(true)
          rescue ThreadError
            break
          end

          html = fetch_wallpapers_page(url)
          extracted = extract_wallpapers(html, theme, url)
          @output_mutex.synchronize { wallpapers.concat(extracted) }
        end
      end
    end
    threads.each(&:join)
    wallpapers
  end

  ##
  # Fetches the content of a wallpapers page.
  #
  # url - The URL of the page to fetch.
  #
  # Returns the HTML content as a string.
  def fetch_wallpapers_page(url)
    # Respect robots.txt
    unless @robots.allowed?(url)
      logger.error "Access to #{url} is disallowed by robots.txt"
      return ''
    end

    @request_limiter.wait
    URI.open(url, 'User-Agent' => 'MyWallpaperDownloader/1.0').read
  rescue OpenURI::HTTPError => e
    logger.error "Failed to fetch #{url}: #{e.message}"
    raise
  end

  ##
  # Fetches all pages in a category.
  #
  # url - The base URL of the category.
  #
  # Returns an array of HTML content strings.
  def fetch_all_category_pages(url)
    pages = []
    loop do
      logger.info "Fetching page: #{url}"
      html = fetch_wallpapers_page(url)
      break if html.empty?

      pages << html
      doc = Nokogiri::HTML(html)
      next_link = doc.at_css('a.next')
      break unless next_link

      url = URI.join(SMASHING_BASE_URL, next_link['href']).to_s
    end
    pages
  end

  ##
  # Collects article links from HTML pages.
  #
  # html_pages - An array of HTML content strings.
  #
  # Returns an array of article URLs.
  def collect_article_links(html_pages)
    article_links = []
    html_pages.each do |html|
      doc = Nokogiri::HTML(html)
      doc.css('h2 a, h3 a').each do |a|
        href = a['href']
        next unless href.include?('/desktop-wallpaper-calendars-')

        full_url = URI.join(SMASHING_BASE_URL, href).to_s
        article_links << full_url
      end
    end
    article_links.uniq
  end

  ##
  # Extracts wallpapers from HTML content.
  #
  # html - The HTML content as a string.
  # theme - The theme to filter wallpapers by.
  # base_url - The base URL for resolving relative links.
  #
  # Returns an array of wallpapers.
  def extract_wallpapers(html, theme, base_url)
    doc = Nokogiri::HTML(html)
    wallpapers = []

    doc.css('h2, h3').each do |heading|
      title = heading.text.strip.downcase
      next unless title.include?(theme.downcase)

      links = collect_links(heading, base_url)
      next if links.empty?

      wallpapers << { title: title, links: links }
    end

    wallpapers
  end

  ##
  # Collects image links from a heading element.
  #
  # heading - A Nokogiri element representing the heading.
  # base_url - The base URL for resolving relative links.
  #
  # Returns an array of image URLs.
  def collect_links(heading, base_url)
    links = []
    sibling = heading.next_element

    while sibling && !sibling.name.match(/^h[23]$/)
      sibling.css('a').each do |a|
        href = a['href']
        next unless href&.match(/\.(jpg|png)$/)

        full_href = URI.join(base_url, href).to_s
        links << full_href
      end
      sibling = sibling.next_element
    end

    links.uniq
  end

  ##
  # Downloads wallpapers using multi-threading.
  #
  # wallpapers - An array of wallpapers to download.
  def download_wallpapers(wallpapers)
    @download_queue = Queue.new

    wallpapers.each do |wallpaper|
      @log_mutex.synchronize { logger.info "Downloading wallpapers for: #{wallpaper[:title]}" }
      wallpaper[:links].each do |link|
        @download_queue << { title: wallpaper[:title], link: link }
      end
    end

    threads = []

    @max_threads.times do
      threads << Thread.new do
        until @download_queue.empty?
          task = nil
          begin
            task = @download_queue.pop(true)
          rescue ThreadError
            break
          end

          download_image(task[:title], task[:link])
        end
      end
    end

    threads.each(&:join)

    # Clean up temporary directory
    FileUtils.rm_rf('temp_downloads')
    @log_mutex.synchronize { logger.info 'Temporary files cleaned up.' }
  end

  ##
  # Downloads a single image and saves it in the appropriate directory.
  #
  # title - The title of the wallpaper.
  # link - The URL of the image to download.
  def download_image(title, link)
    filename = File.basename(URI.parse(link).path)
    safe_title = title.gsub(/\W+/, '_')

    # Determine the resolution early from the filename
    res_match = filename.match(/(\d+)x(\d+)/)
    resolution = if res_match
                   "#{res_match[1]}x#{res_match[2]}"
                 else
                   'unknown_resolution'
                 end

    # Construct the final file path
    dir_name = File.join('wallpapers', resolution)
    final_filepath = File.join(dir_name, "#{safe_title}_#{filename}")

    # Check if the file already exists before downloading
    if File.exist?(final_filepath)
      @log_mutex.synchronize { logger.info "  Skipped (already exists): #{final_filepath}" }
      return
    end

    temp_dir = 'temp_downloads'
    FileUtils.mkdir_p(temp_dir)
    temp_filepath = File.join(temp_dir, "#{safe_title}_#{filename}")

    @log_mutex.synchronize { logger.info "  Downloading #{filename} to #{dir_name}" }

    begin
      @request_limiter.wait
      URI.open(link, 'User-Agent' => 'MyWallpaperDownloader/1.0') do |image|
        File.open(temp_filepath, 'wb') do |file|
          file.write(image.read)
        end
      end

      # Get image dimensions
      dimensions = FastImage.size(temp_filepath)
      if dimensions
        resolution = "#{dimensions[0]}x#{dimensions[1]}"
      else
        # Use resolution from filename if available
        if res_match
          resolution = "#{res_match[1]}x#{res_match[2]}"
          @log_mutex.synchronize { logger.warn "    Used resolution from filename for #{filename}" }
        else
          resolution = 'unknown_resolution'
          @log_mutex.synchronize { logger.warn "    Could not determine dimensions for #{filename}" }
        end
      end

      # If a resolution is specified, skip the image if it doesn't match
      if @resolution
        image_resolution = resolution.split('x').map(&:to_i)
        unless image_resolution == @resolution
          @log_mutex.synchronize { logger.info "    Skipping #{filename} (resolution #{resolution} does not match #{@resolution.join('x')})" }
          File.delete(temp_filepath) if File.exist?(temp_filepath)
          return
        end
      end

      # Update dir_name and final_filepath in case resolution changed
      dir_name = File.join('wallpapers', resolution)
      final_filepath = File.join(dir_name, "#{safe_title}_#{filename}")

      @file_mutex.synchronize do
        FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)

        if File.exist?(final_filepath)
          @log_mutex.synchronize { logger.info "  Skipped (already exists): #{final_filepath}" }
          File.delete(temp_filepath)
          return
        end

        # Move the file to the final directory
        FileUtils.mv(temp_filepath, final_filepath)
        @log_mutex.synchronize { logger.info "    Saved to #{final_filepath}" }
      end
    rescue SocketError => e
      @log_mutex.synchronize { logger.error "    Network error while downloading #{link}: #{e.message}" }
      File.delete(temp_filepath) if File.exist?(temp_filepath)
      # Continue to the next image without raising an exception
    rescue OpenURI::HTTPError => e
      @log_mutex.synchronize { logger.error "    Failed to download #{link}: #{e.message}" }
      File.delete(temp_filepath) if File.exist?(temp_filepath)
      # Continue to the next image without raising an exception
    rescue StandardError => e
      @log_mutex.synchronize { logger.error "    Error processing #{filename}: #{e.message}" }
      File.delete(temp_filepath) if File.exist?(temp_filepath)
    end
  end


end



##
# The RequestLimiter class manages the rate of HTTP requests to ensure
# that a specified delay is maintained between consecutive requests.
#
# This is useful for complying with website rate limits and avoiding
# being blocked due to excessive requests.
class RequestLimiter


  def initialize(delay)
    @delay = delay
    @last_request_time = Time.at(1)
    @mutex = Mutex.new
  end

  ##
  # Waits until the delay has passed since the last request.
  def wait
    @mutex.synchronize do
      now = Time.now
      elapsed = now - @last_request_time
      if elapsed < @delay
        sleep(@delay - elapsed)
      end
      @last_request_time = Time.now
    end
  end
end

# Execute the script only if it's run directly
if __FILE__ == $PROGRAM_NAME
  begin
    WallpaperDownloader.new.run
  rescue ArgumentError => e
    puts e.message
    exit 1
  rescue OpenURI::HTTPError => e
    puts e.message
    exit 1
  end
end
