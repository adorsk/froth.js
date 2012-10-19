Froth = require('./froth.coffee')
fs = require('fs')
wrench = require('wrench')
util = require('util')
request = require('request')
$ = require('jquery')

frothc = exports

frothc._fetchedUrls = {}

# Helper functions for predictably unique filenames.
frothc.hashCode = (str) ->
  hash = 0
  if not str.length
    return hash
  else
    for i in [0..str.length-1]
      char = str.charCodeAt(i)
      hash = ((hash<<5)-hash)+char
      hash = hash & hash
  return hash

frothc.uniqueFilename = (url) ->
  filename = url.replace(/.*\//, '')
  filenameParts = filename.split('.')
  urlHash = frothc.hashCode(url)
  filenameParts.splice(filenameParts.length-1, urlHash 
  return filenameParts.join('.')

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
# Returns a promise that resolves when all assets have been resolved and fetched.
# Assumes stylesheet rules have been converted to 
# flat JSONCSS.
frothc.bundleAssets = (opts={}) ->
  deferred = $.Deferred()
  deferreds = []
  # For each stylesheet...
  for id, stylesheet of Froth.stylesheets
    [bundledStylesheet, deferred] = frothc.bundleStylesheet(stylesheet, opts)
    deferreds.push(deferred)
  promise = $.when(deferreds...)
  promise.done ->
    deferred.resolve(arguments)
  promise.fail ->
    deferred.reject(arguments)
  return deferred

# Bundle a stylesheet.
frothc.bundleStylesheet = (stylesheet, opts={}) ->
  deferred = $.Deferred()
  deferreds = []
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
  for selector, style of stylesheet.rules ? {}
    for attr, value of style
      if typeof value == 'string'
        style[attr] = value.replace(
          /(url\(["'])(.*?)(["']\))/g, (match...) ->
            url = match[2]
            [processedUrl, urlDeferred] = processUrlForBundling(url, opts)
            deferreds.push(urlDeferred)
            # Wrap the url in its original 'url(...)' context.
            return match[1] + processedUrl + match[3]
        )
  promise = $.when(deferreds...)
  promise.done ->
    deferred.resolve(arguments)
  promise.fail ->
    deferred.reject(arguments)

  return [bundledStylesheet, deferred]

# Process a url for bundling.
processUrlForBundling = (url, opts={}) ->

  deferred = $.Deferred()

  # Rewrite the url per the rewrite rules.
  url = rewriteUrl(url, Froth.config.bundling.rewrites ? [])

  # If we should fetch the url (per includes and excludes).
  if shouldFetchUrl(url, Froth.config.bundling)
    # If the url has not been fetched, fetch it and write to the
    # the target dir.
    if not frothc._fetchedUrls[url]
      # Get asset filename.
      # We use a hash code on the url to avoid clobbering files with the same name.
      filename = frothc.uniqueFilename(url)
      
      # Fetch the url.
      srcStream = getStreamForUrl(url)
      targetPath = Froth.config.bundling.bundleDir + '/' + filename
      targetStream = fs.createWriteStream(targetPath)

      srcStream.once 'open', (srcFd) ->
        targetStream.once 'open', (targetfd) ->
          util.pump srcStream, targetStream, ->
            srcStream.destroy()
            targetStream.destroy()
            deferred.resolve()

      onError = ->
        deferred.reject(arguments)
      srcStream.on 'error', onError
      targetStream.on 'error', onError

      assetUrl = Froth.config.bundling.baseUrl + '/' + filename
      frothc._fetchedUrls[url] = assetUrl
    
    # Replace url with asset url (if exists).
    url = frothc._fetchedUrls[url] ? url

  return [url, deferred]

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
