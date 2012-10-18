Froth = require('./froth')
fs = require('fs')
wrench = require('wrench')
util = require('util')

frothc = exports

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
frothc.bundleAssets = ->
  # For each stylesheet...
  for id, stylesheet of Froth.stylesheets
    # Process urls in values.
    for selector, style of stylesheet.rules
      for attr, value of style
        if typeof value == 'string'
          style[attr] = value.replace(
            /(url\(["'])(.*?)(["']\))/g,
            processUrlForBundling
          )

# Process a url for bundling.
processUrlForBundling = (match...) ->
  # The url will be the 2nd match element.
  url = match[2]
  # Extract the path from the url.
  # Use the first rewrite rule we find that matches.
  condition = null
  key = null
  foundRule = false
  rewriteRules = Froth.config.bundling.rewriteRules ? []
  for condition, rewrite of rewriteRules
    condition = new RegExp(condition)
    if url.match(condition)
      foundRule = true
      break
  # If we found a rule...
  if foundRule
    # Generate asset's relative path
    sourceRelPath = url.replace(condition, '')
    targetRelPath = rewrite.targetKey + "/" + sourceRelPath

    # Fetch the asset and put it in the target dir.
    sourceAbsPath = rewrite.sourceDir + '/' + sourceRelPath
    targetAbsPath = Froth.config.bundling.bundleDir + '/' + targetRelPath
    targetAbsDir = targetAbsPath.replace(/[^\/]*$/, '')
    wrench.mkdirSyncRecursive(targetAbsDir)
    cpfile(sourceAbsPath, targetAbsPath)
    
    # Rewrite the url.
    url = Froth.config.bundling.baseRewriteUrl + '/' + targetRelPath

    # Rewrap url in "url('')"
    url = match[1] + url + match[3]

  return url

# <grumble> I wish this was in node.js core...
cpfile = (src, dest) ->
  srcStream = fs.createReadStream(src)
  destStream = fs.createWriteStream(dest)
  destStream.once 'open', (fd) ->
    util.pump srcStream, destStream, ->
      srcStream.close()
      destStream.close()
