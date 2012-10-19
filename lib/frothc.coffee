Froth = require('./froth')
fs = require('fs')
wrench = require('wrench')
util = require('util')
request = require('request')
sync = require('sync')

frothc = exports

frothc._fetchedUrls = {}

frothc.compile = (opts={}) ->
  # Define default options.
  default_opts = {
    'consolidateTo': 'stdout'
  }
  # Merge defaults with provided options.
  opts = Froth.merge(default_opts, opts)

  # Convert stylesheet rules from Froth JSON to JSONCSS.
  for id, stylesheet of Froth.stylesheets
    stylesheet.rules = Froth.frothJsonToJsonCss(stylesheet.rules)

  # If bundling assets, process accordingly.
  # if Froth.config.bundleAssets
  if true
    bundleAssets()

  # Compile the css documents for each stylesheet.
  cssDocs = {}
  for id, stylesheet of Froth.stylesheets
    cssDocs[id] = stylesheet.toCss()

  # Consolidate into one file if specified.
  if opts.consolidateTo
    consolidatedDoc = (cssDoc for id, cssDoc of cssDocs).join("\n")
    if opts.consolidateTo == 'stdout'
      process.stdout.write(consolidatedDoc)
    else if typeof opts.consolidateTo == 'string'
      # @TODO: open file here.
      console.log('foo')
    else if opts.consolidateTo.write
      opts.consolidateTo.write(consolidatedDoc)

# Bundle assets.
# Assumes stylesheet rules have been converted to 
# flat JSONCSS.
frothc.bundleAssets = (opts={}) ->
  # For each stylesheet...
  for id, stylesheet of Froth.stylesheets
    bundledStylesheet = frothc.bundleStylesheet(stylesheet, opts)

# Bundle a stylesheet.
frothc.bundleStylesheet = (stylesheet, opts={}) ->
  # Create a bundled sheet which will merge
  # the stylesheet's imports, and the stylesheet's own rules.
  bundledStylesheet = new Froth.Stylesheet()
  bundledStylesheet.id = stylesheet.id + '__bundled'

  # For each import...
  for import_ in stylesheet.imports ? []
    # If import href matches RewriteRule...
    if 1
      1
      # Get the import's path.
      # If the import has not been bundled...
        # Fetch the import source.
        # Create a new stylesheet from the source.
        # Bundle the imported stylesheet.
      # Get the bundled import.
      # Add the bundled stylesheet's rules to the main bundled sheet.
    # Otherwise...
    else
      # Add the import to the bundled stylsheet's imports.
      1

  # Process urls in values.
  for selector, style of stylesheet.rules ? []
    for attr, value of style
      if typeof value == 'string'
        style[attr] = value.replace(
          /(url\(["'])(.*?)(["']\))/g, (match...) ->
            url = match[2]
            processedUrl = processUrlForBundling(url, opts)
            # Wrap the url in its original 'url(...)' context.
            return match[1] + processedUrl + match[3]
        )

# Process a url for bundling.
processUrlForBundling = (url, opts={}) ->

  # Rewrite the url per the rewrite rules.
  url = rewriteUrl(url, Froth.config.bundling.rewrites ? [])

  # If we should fetch the url (per includes and excludes).
  if shouldFetchUrl(url, Froth.config.bundling)
    # If the url has not been fetched, fetch it and write to the
    # the target dir.
    if not frothc._fetchedUrls[url]
      # Get asset filename.
      filename = url.replace(/.*\//, '')
      # Generate safe target path.
      # @TODO: implement safe file naming to avoid clobbering duplicate names.
      srcStream = getStreamForUrl(url)
      targetPath = Froth.config.bundling.bundleDir + '/' + filename
      targetStream = fs.createWriteStream(targetPath)

      # Synchronous fetch.
      if opts.sync
        srcStream.once.sync 'open', (srcFd) ->
          targetStream.once.sync 'open', (targetfd) ->
            util.pump.sync srcStream, targetStream, ->
              srcStream.close()
              targetStream.close()
        
      # Asynchronous fetch.
      else
        srcStream.once 'open', (srcFd) ->
          targetStream.once 'open', (targetfd) ->
            util.pump srcStream, targetStream, ->
              srcStream.close()
              targetStream.close()

      assetUrl = Froth.config.bundling.baseUrl + '/' + filename
      frothc._fetchedUrls[url] = assetUrl
    
    # Replace url with asset url (if exists).
    url = frothc._fetchedUrls[url] ? url

  return url

# Determine whether a url should be fetched, as per
# opts.includes and opts.excludes.
# opts.includes takes precendence over excludes.
shouldFetchUrl = (url, opts={}) ->
  includes = opts.includes ? []
  excludes = opts.excludes ? []

  for inc in includes
    if url.match(inc)
      return true

  for exc in excludes
    if url.match(exc)
      return false

  return true

# Get readStream for the given url.
getStreamForUrl = (url) ->
  if url.match(/^http:\/\//)
    return request(url)
  else
    return fs.createReadStream(url)

# Rewrite a url based on the given rewrite rules.
# Last matching rule will be used.
rewriteUrl = (url, rules) ->
  # Loop through rules in reverse order until a match is found.
  for i in [rules.length - 1..0] by -1
    rule = rules[i]
    rewrittenUrl = url.replace(rule[0], rule[1])
    # If rewritten url differs, we have matched and shoul return.
    if rewrittenUrl != url
      return rewrittenUrl
  # Return the original url if no match was found.
  return url
