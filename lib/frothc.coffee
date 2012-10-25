Froth = require('./froth.coffee')
fs = require('fs')
path = require('path')
wrench = require('wrench')
util = require('util')
request = require('request')
$ = require('jquery')
md5 = require('./md5')

Frothc = exports

Frothc._fetchedUrls = {}

# Set default options.
Frothc.defaultOptions= {
  consolidateSheets: true,
  printTo: 'stdout',
  outputDir: null,
  baseRewriteUrl: '',
  bundle: false,
  bundleDir: 'bundled_assets',
  bundleBaseUrl: null
}

# Helper functions for predictably unique filenames.
Frothc.uniqueFilename = (url) ->
  filename = url.replace(/.*\//, '')
  filenameParts = filename.split('.')
  urlHash = md5.hex_md5(url)
  filenameParts.splice(filenameParts.length-1, 0, urlHash)
  return filenameParts.join('.')

Frothc.compile = (ctx, opts={}) ->
  # Use Froth global as default context if none given.
  ctx ?= Frothc.ctx
  
  # Merge defaults with provided options.
  opts = Froth.extend(Frothc.defaultOptions, opts)

  # If using output dir...
  if opts.outputDir
    # Create output dir if it does not exist.
    if not fs.existsSync(opts.outputDir)
      wrench.mkdirSyncRecursive(opts.outputDir)

    # If bundling...
    if opts.bundle
      # If bundle dir is relative...
      if opts.bundleDir?.match(Froth.relativeUrlRe)
        # If bundleBaseUrl is not set...
        if not opts.bundleBaseUrl?
          # Make bundleBaseUrl match outputDir name + bundleDir
          opts.bundleBaseUrl = path.join(path.basename(opts.outputDir), opts.bundleDir)
        # Make bundleDir be relative to output dir.
        opts.bundleDir = path.join(opts.outputDir, opts.bundleDir)

  deferred = $.Deferred()

  # Convert sheets to JSONCSS.
  jsonCssObjs = []
  for id, sheet of ctx.sheets
    jsonCssObjs.push(sheet.toJsonCss())

  # If bundling assets, process accordingly.
  if opts.bundle
    # Make the bundle dir.
    wrench.mkdirSyncRecursive(opts.bundleDir)
    bundleDeferred = Frothc.bundleJsonCssObjs(jsonCssObjs, opts)
  else
    bundleDeferred = $.Deferred()
    bundleDeferred.resolve(jsonCssObjs)

  # After bundling is complete...
  bundleDeferred.done (bundledJsonCssObjs) ->
    # Compile the css documents for each sheet.
    cssDocs = {}
    for jsonCss in bundledJsonCssObjs
      cssDocs[jsonCss.id] = Froth.JsonCss.dumpcss(jsonCss)

    # Initialize outputs.
    outputs = {}
    # If consolidating, consolidate into one output.
    if opts.consolidateSheets
      consolidatedCssTexts = []
      for id, cssText of cssDocs
        consolidatedCssTexts.push(cssText)
      consolidatedCssText = consolidatedCssTexts.join("\n")
      outputs = {'__consolidated__' : consolidatedCssText}
    # Use separate outputs.
    else
      outputs[id] = cssDocs

    # If using output dir...
    if opts.outputDir
      # Save each output to the output dir.
      for id, cssText of outputs
        # Set filename as outputDir + id.
        filename = path.join(opts.outputDir, id + '.css')
        # Special consolidated file.
        if id == '__consolidated__'
          filename = path.join(opts.outputDir, 'consolidated.css')
        # Write css text to file.
        fs.writeFile(filename, cssText, (err) ->
          if err
            console.error("Error writing file: '%s', error was: %o", filename, err)
            deferred.reject(err)
        )

    # If printing...
    if opts.printTo
      # Conslidate to one document.
      consolidatedOutputs = (cssText for id, cssText of outputs).join("\n")
      if opts.printTo == 'stdout'
        process.stdout.write(consolidatedOutputs)
      # Write to file for given filename.
      else if typeof opts.printTo == 'string'
        fs.writeFileSync(opts.consolidateTo, consolidatedOutputs)
      # Write to stream.
      else if opts.printTo.write?
        opts.printTo.write(consolidatedOutputs)

    # Resolve deferred.
    deferred.resolve()
 
  bundleDeferred.fail () ->
    console.log('failed', arguments)

  return deferred

# Bundle multiple JsonCss objects.
# Returns a promise that resolves when all assets have been resolved and fetched.
# Data passed to resolve method will be JsonCss with values modified
# to reflect bundled assets.
Frothc.bundleJsonCssObjs = (jsonCssObjs, opts={}) ->
  deferred = $.Deferred()
  deferreds = []

  # Bundle each jsoncss object.
  for jsonCss in jsonCssObjs
    jsonCssDeferred = Frothc.bundleJsonCss(jsonCss, opts)
    deferreds.push(jsonCssDeferred)

  promise = $.when(deferreds...)
  promise.done (bundledJsonCssObjs...) ->
    deferred.resolve(bundledJsonCssObjs)
  promise.fail ->
    deferred.reject()
  return deferred

# Bundle a single JsonCss object.
Frothc.bundleJsonCss = (jsonCss, opts={}) ->
  deferred = $.Deferred()
  deferreds = []

  # Initialize a bundled JsonCss object.
  bundledJsonCss = {
    id: jsonCss.id,
    imports: [],
    rules: {}
  }

  # Process imports.
  # @TODO: later, add handling for inlining.
  for import_ in jsonCss.imports ? []
    # Get the import's url.
    url = import_.href
    # Bundle the asset referred to by the url.
    [processedUrl, urlDeferred] = processUrlForBundling(url, opts)
    deferreds.push(urlDeferred)
    # Add a copy of the import w/ the new url to the
    # bundled sheet.
    processedImport = Froth.extend({}, import_, {
      href: processedUrl
    })
    bundledJsonCss.imports.push(processedImport)

  # Process urls in values.
  #@TODO: later, combine this w/ Froth.rewriteWrappedUrl?
  # generic processWrappedUrl func that takes a callable?
  for selector, style of jsonCss.rules ? {}
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
    # Save processed rule to bundled sheet.
    bundledJsonCss.rules[selector] = style

  promise = $.when(deferreds...)
  promise.done ->
    deferred.resolve(bundledJsonCss)
  promise.fail ->
    deferred.reject(arguments)

  return deferred

# Process a url for bundling.
processUrlForBundling = (url, opts={}) ->

  deferred = $.Deferred()

  # Rewrite the url per the rewrite rules.
  url = Froth.rewriteUrl(url, opts.bundleRewrites ? [])

  # If we should fetch the url (per includes and excludes).
  if shouldFetchUrl(
    url,
    {includes: opts.bundleIncludes, excludes: opts.bundleExcludes}
  )
    # If the url has not been fetched, fetch it and write to the
    # the target dir.
    if not Frothc._fetchedUrls[url]
      # Get asset filename.
      # We use a hash code on the url to avoid clobbering files with the same name.
      filename = Frothc.uniqueFilename(url)
      
      # Fetch the url.
      srcStream = getStreamForUrl(url)
      targetPath = opts.bundleDir + '/' + filename
      targetStream = fs.createWriteStream(targetPath)

      onError = ->
        console.error("Unable to bundle asset '%s', error: '%j'", url, arguments)
        if opts.bundleFailOnError?
          deferred.reject(arguments)
        else
          deferred.resolve()

      srcStream.once 'open', (srcFd) ->
        targetStream.once 'open', (targetfd) ->
          util.pump srcStream, targetStream, (error) ->
            if error
              onError()
            else
              deferred.resolve()

      srcStream.once 'error', -> onError('src',url, arguments)
      targetStream.once 'error', -> onError('target', targetPath, arguments)

      assetUrl = opts.bundleBaseUrl + '/' + filename
      Frothc._fetchedUrls[url] = assetUrl
    
    # Replace url with asset url (if exists).
    url = Frothc._fetchedUrls[url] ? url

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
