<!DOCTYPE html>

<html>
<head>
<meta charset="UTF-8">

<title>class WallpaperDownloader - RDoc Documentation</title>

<script type="text/javascript">
  var rdoc_rel_prefix = "./";
  var index_rel_prefix = "./";
</script>

<script src="./js/navigation.js" defer></script>
<script src="./js/search.js" defer></script>
<script src="./js/search_index.js" defer></script>
<script src="./js/searcher.js" defer></script>
<script src="./js/darkfish.js" defer></script>

<link href="./css/fonts.css" rel="stylesheet">
<link href="./css/rdoc.css" rel="stylesheet">


<body id="top" role="document" class="class">
<nav role="navigation">
  <div id="project-navigation">
    <div id="home-section" role="region" title="Quick navigation" class="nav-section">
  <h2>
    <a href="./index.html" rel="home">Home</a>
  </h2>

  <div id="table-of-contents-navigation">
    <a href="./table_of_contents.html#pages">Pages</a>
    <a href="./table_of_contents.html#classes">Classes</a>
    <a href="./table_of_contents.html#methods">Methods</a>
  </div>
</div>

    <div id="search-section" role="search" class="project-section initially-hidden">
  <form action="#" method="get" accept-charset="utf-8">
    <div id="search-field-wrapper">
      <input id="search-field" role="combobox" aria-label="Search"
             aria-autocomplete="list" aria-controls="search-results"
             type="text" name="search" placeholder="Search" spellcheck="false"
             title="Type to search, Up and Down to navigate, Enter to load">
    </div>

    <ul id="search-results" aria-label="Search Results"
        aria-busy="false" aria-expanded="false"
        aria-atomic="false" class="initially-hidden"></ul>
  </form>
</div>

  </div>

  

  <div id="class-metadata">
    
    
<div id="parent-class-section" class="nav-section">
  <h3>Parent</h3>

  <p class="link">Object
</div>

    
    
    
<!-- Method Quickref -->
<div id="method-list-section" class="nav-section">
  <h3>Methods</h3>

  <ul class="link-list" role="directory">
    <li ><a href="#method-c-new">::new</a>
    <li ><a href="#method-i-run">#run</a>
  </ul>
</div>

  </div>
</nav>

<main role="main" aria-labelledby="class-WallpaperDownloader">
  <h1 id="class-WallpaperDownloader" class="class">
    class WallpaperDownloader
  </h1>

  <section class="description">
    
<p>The <a href="WallpaperDownloader.html"><code>WallpaperDownloader</code></a> class encapsulates the functionality to download wallpapers from Smashing Magazine based on a specified theme and month.</p>

<p>It handles parsing command-line arguments, validating inputs, fetching wallpaper pages, extracting wallpaper links, and downloading images with respect to rate limits.</p>

  </section>

  <section id="5Buntitled-5D" class="documentation-section">


    <section class="constants-list">
      <header>
        <h3>Constants</h3>
      </header>
      <dl>
        <dt id="SMASHING_BASE_URL">SMASHING_BASE_URL
        <dd><p>The base URL for Smashing Magazine, used to construct full URLs for fetching wallpapers.</p>
      </dl>
    </section>

    <section class="attribute-method-details" class="method-section">
      <header>
        <h3>Attributes</h3>
      </header>

      <div id="attribute-i-logger" class="method-detail">
        <div class="method-heading attribute-method-heading">
          <span class="method-name">logger</span><span
            class="attribute-access-type">[R]</span>
        </div>

        <div class="method-description">
        <p>@return [Logger] The logger instance used for logging messages.</p>
        </div>
      </div>
      <div id="attribute-i-mode" class="method-detail">
        <div class="method-heading attribute-method-heading">
          <span class="method-name">mode</span><span
            class="attribute-access-type">[R]</span>
        </div>

        <div class="method-description">
        <p>@return [String] The mode of operation, either “month” or “category”.</p>
        </div>
      </div>
      <div id="attribute-i-month_input" class="method-detail">
        <div class="method-heading attribute-method-heading">
          <span class="method-name">month_input</span><span
            class="attribute-access-type">[R]</span>
        </div>

        <div class="method-description">
        <p>@return [String] The month input specified by the user in MMYYYY format.</p>
        </div>
      </div>
      <div id="attribute-i-theme" class="method-detail">
        <div class="method-heading attribute-method-heading">
          <span class="method-name">theme</span><span
            class="attribute-access-type">[R]</span>
        </div>

        <div class="method-description">
        <p>@return [String, nil] The theme specified by the user, converted to lowercase.</p>
        </div>
      </div>
    </section>


     <section id="public-class-5Buntitled-5D-method-details" class="method-section">
       <header>
         <h3>Public Class Methods</h3>
       </header>

      <div id="method-c-new" class="method-detail ">
        <div class="method-header">
          <div class="method-heading">
            <span class="method-name">new</span><span
              class="method-args">(args = ARGV)</span>
            <span class="method-click-advice">click to toggle source</span>
          </div>
        </div>

        <div class="method-description">
          <p>Initializes the downloader with command-line arguments.</p>

<p>args - An array of command-line arguments (default: ARGV).</p>

          <div class="method-source-code" id="new-source">
            <pre><span class="ruby-comment"># File script.rb, line 48</span>
<span class="ruby-keyword">def</span> <span class="ruby-identifier ruby-title">initialize</span>(<span class="ruby-identifier">args</span> = <span class="ruby-constant">ARGV</span>)
  <span class="ruby-identifier">options</span> = <span class="ruby-identifier">parse_options</span>(<span class="ruby-identifier">args</span>)
  <span class="ruby-ivar">@month_input</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:month</span>]
  <span class="ruby-ivar">@theme</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:theme</span>]&amp;.<span class="ruby-identifier">downcase</span>
  <span class="ruby-ivar">@mode</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:mode</span>] <span class="ruby-operator">||</span> <span class="ruby-string">&#39;month&#39;</span> <span class="ruby-comment"># Default to &#39;month&#39; mode</span>
  <span class="ruby-ivar">@output_mutex</span> = <span class="ruby-constant">Mutex</span>.<span class="ruby-identifier">new</span> <span class="ruby-comment"># To display the output to the console</span>
  <span class="ruby-ivar">@max_threads</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:max_threads</span>] <span class="ruby-operator">||</span> <span class="ruby-value">5</span>  <span class="ruby-comment"># Allow setting max_threads</span>
  <span class="ruby-ivar">@request_delay</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:request_delay</span>] <span class="ruby-operator">||</span> <span class="ruby-value">1.0</span>  <span class="ruby-comment"># Default to 1 second</span>

  <span class="ruby-comment"># Parse and validate the resolution</span>
  <span class="ruby-keyword">if</span> <span class="ruby-identifier">options</span>[<span class="ruby-value">:resolution</span>]
    <span class="ruby-identifier">res_match</span> = <span class="ruby-identifier">options</span>[<span class="ruby-value">:resolution</span>].<span class="ruby-identifier">match</span>(<span class="ruby-regexp">/^(\d+)x(\d+)$/</span>)
    <span class="ruby-keyword">if</span> <span class="ruby-identifier">res_match</span>
      <span class="ruby-ivar">@resolution</span> = [<span class="ruby-identifier">res_match</span>[<span class="ruby-value">1</span>].<span class="ruby-identifier">to_i</span>, <span class="ruby-identifier">res_match</span>[<span class="ruby-value">2</span>].<span class="ruby-identifier">to_i</span>]
    <span class="ruby-keyword">else</span>
      <span class="ruby-identifier">raise</span> <span class="ruby-constant">ArgumentError</span>, <span class="ruby-string">&#39;Invalid resolution format. Please use WIDTHxHEIGHT (e.g., 1920x1080).&#39;</span>
    <span class="ruby-keyword">end</span>
  <span class="ruby-keyword">else</span>
    <span class="ruby-ivar">@resolution</span> = <span class="ruby-keyword">nil</span>
  <span class="ruby-keyword">end</span>

  <span class="ruby-comment"># Ensure directories exist</span>
  <span class="ruby-constant">FileUtils</span>.<span class="ruby-identifier">mkdir_p</span>(<span class="ruby-string">&#39;logs&#39;</span>)
  <span class="ruby-constant">FileUtils</span>.<span class="ruby-identifier">mkdir_p</span>(<span class="ruby-string">&#39;wallpapers&#39;</span>)

  <span class="ruby-comment"># Initialize the logger correctly</span>
  <span class="ruby-ivar">@logger</span> = <span class="ruby-constant">Logger</span>.<span class="ruby-identifier">new</span>(<span class="ruby-constant">File</span>.<span class="ruby-identifier">join</span>(<span class="ruby-string">&#39;logs&#39;</span>, <span class="ruby-string">&#39;wallpaper_downloader.log&#39;</span>)) <span class="ruby-comment"># Append logs to the file</span>

  <span class="ruby-ivar">@request_limiter</span> = <span class="ruby-constant">RequestLimiter</span>.<span class="ruby-identifier">new</span>(<span class="ruby-ivar">@request_delay</span>) <span class="ruby-comment"># Delay between requests</span>

  <span class="ruby-ivar">@robots</span> = <span class="ruby-constant">Robots</span>.<span class="ruby-identifier">new</span>(<span class="ruby-string">&#39;MyWallpaperDownloader/1.0&#39;</span>)  <span class="ruby-comment"># Initialize the robots.txt parser</span>

  <span class="ruby-ivar">@file_mutex</span> = <span class="ruby-constant">Mutex</span>.<span class="ruby-identifier">new</span>  <span class="ruby-comment"># Mutex for file operations</span>
  <span class="ruby-ivar">@log_mutex</span> = <span class="ruby-constant">Mutex</span>.<span class="ruby-identifier">new</span>   <span class="ruby-comment"># Mutex for logging</span>
<span class="ruby-keyword">end</span></pre>
          </div>
        </div>


      </div>

    </section>

     <section id="public-instance-5Buntitled-5D-method-details" class="method-section">
       <header>
         <h3>Public Instance Methods</h3>
       </header>

      <div id="method-i-run" class="method-detail ">
        <div class="method-header">
          <div class="method-heading">
            <span class="method-name">run</span><span
              class="method-args">()</span>
            <span class="method-click-advice">click to toggle source</span>
          </div>
        </div>

        <div class="method-description">
          <p>Runs the wallpaper downloader, orchestrating the fetching and downloading of wallpapers.</p>

<p>This method initializes the process by validating inputs, constructing URLs, fetching wallpapers, and handling the download process.</p>

          <div class="method-source-code" id="run-source">
            <pre><span class="ruby-comment"># File script.rb, line 91</span>
<span class="ruby-keyword">def</span> <span class="ruby-identifier ruby-title">run</span>
  <span class="ruby-constant">Thread</span>.<span class="ruby-identifier">abort_on_exception</span> = <span class="ruby-keyword">true</span>  <span class="ruby-comment"># Ensure exceptions in threads are not ignored</span>

  <span class="ruby-identifier">validate_inputs</span>
  <span class="ruby-identifier">urls</span> = <span class="ruby-identifier">construct_urls</span>

  <span class="ruby-identifier">wallpapers</span> = <span class="ruby-identifier">fetch_and_extract_wallpapers</span>(<span class="ruby-identifier">urls</span>)

  <span class="ruby-keyword">if</span> <span class="ruby-identifier">wallpapers</span>.<span class="ruby-identifier">empty?</span>
    <span class="ruby-identifier">logger</span>.<span class="ruby-identifier">info</span> <span class="ruby-string">&#39;No wallpapers found matching the specified theme.&#39;</span>
    <span class="ruby-keyword">return</span>
  <span class="ruby-keyword">end</span>

  <span class="ruby-identifier">download_wallpapers</span>(<span class="ruby-identifier">wallpapers</span>)
  <span class="ruby-identifier">logger</span>.<span class="ruby-identifier">info</span> <span class="ruby-string">&#39;Download completed.&#39;</span>
<span class="ruby-keyword">rescue</span> <span class="ruby-constant">OpenURI</span><span class="ruby-operator">::</span><span class="ruby-constant">HTTPError</span> <span class="ruby-operator">=&gt;</span> <span class="ruby-identifier">e</span>
  <span class="ruby-identifier">logger</span>.<span class="ruby-identifier">error</span> <span class="ruby-node">&quot;Failed to fetch wallpapers page: #{e.message}&quot;</span>
  <span class="ruby-identifier">exit</span> <span class="ruby-value">1</span>
<span class="ruby-keyword">end</span></pre>
          </div>
        </div>


      </div>

    </section>

  </section>
</main>


<footer id="validator-badges" role="contentinfo">
  <p><a href="https://validator.w3.org/check/referer">Validate</a>
  <p>Generated by <a href="https://ruby.github.io/rdoc/">RDoc</a> 6.5.0.
  <p>Based on <a href="http://deveiate.org/projects/Darkfish-RDoc/">Darkfish</a> by <a href="http://deveiate.org">Michael Granger</a>.
</footer>

