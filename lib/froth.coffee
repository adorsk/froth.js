# Initial setup.
root = this
oldFroth = root.Froth
Froth = {}
# CommonJS.
if typeof exports != 'undefined'
  Froth = exports
# AMD
else if typeof define == 'function' and define.amd?
  define('froth', [], -> return Froth)
# Plain global variable.
else
  Froth = root.Froth = {}
Froth.noConflict = ->
  root.Froth = oldFroth
  return this


# <grumble>. I wish this was in coffeescript core...
Froth.extend = (dest, objs...) ->
  for obj in objs
    dest[k] = v for k, v of obj
  return dest

Froth.defaultConfig = {
}

# Initial config.
Froth.config = Froth.extend({}, Froth.defaultConfig)

###
Froth.JSONCSS
###
JsonCss = Froth.JsonCss = {}

# Non-recursive tree travesal.
JsonCss.traverse = (tree, getChildrenFn, visitFn, log) ->
  log ?= {}
  nodeObj = {ancestors: [], nodeId: null, data: tree}
  nodeObjs = getChildrenFn(nodeObj)

  while (nodeObjs.length)
    nodeObj = nodeObjs.shift()
    childNodeObjs = getChildrenFn(nodeObj)
    for childNodeObj in childNodeObjs
      nodeObjs.push(childNodeObj)

    visitFn(nodeObj, log)

  return log

# Get child nodes of a JSON CSS node.
# We assume all elements which are objects are children.
JsonCss.getChildren = (nodeObj) ->
  childNodeObjs = []
  for own k, v of nodeObj.data
    if (typeof v == 'object')
      childNodeObjs.push({
        ancestors: nodeObj.ancestors.concat([nodeObj]),
        nodeId: k,
        data: v
      })
  return childNodeObjs

# Visit a JSON CSS node.
# Outputs a CSS string for the given node.
# We assume all non-object elements are style attributes.
JsonCss.visit = (nodeObj, log) ->
  # Get current selector by joining ancestor ids, and appending current id.
  selectorIds = []
  for ancestor in nodeObj.ancestors[1..]
    selectorIds.push(ancestor.nodeId)
  selectorIds.push(nodeObj.nodeId)
  selector = selectorIds.join(' ')

  # ' &' should be replaced with '' to do concatenation.
  selector = selector.replace(' &', '')

  # Get style attributes.
  styleAttrs = {}
  hasStyles = false
  for k, v of nodeObj.data
    if (typeof v != 'object')
      styleAttrs[k] = v
      hasStyles = true

  # If there were styles, create style rule string and
  # add to running css string.
  if hasStyles
    nodeCssStr = JsonCss.formatCssRule(selector, styleAttrs)
    log.cssStr += nodeCssStr

# Format a single css rule.
JsonCss.formatCssRule = (selector, styleAttrs, opts={}) ->
  opts.indent ?= '  '
  opts.linebreak ?= '\n'
  cssStr = ""

  cssStr += selector + " {" + opts.linebreak

  for k, v of styleAttrs
    attrStr = opts.indent + k + ": " + v + ';' + opts.linebreak
    cssStr += attrStr

  cssStr += "}" + opts.linebreak
  return cssStr

# Format a css import.
JsonCss.formatCssImport = (import_, opts={}) ->
  opts.linebreak = opts.linebreak || '\n'
  return "@import url('"  + import_ + "');" + opts.linebreak

# Convert a JSONCSS into a CSS string, using non-recursive traversal.
JsonCss.dumpcss = (jsoncss) ->
  # Initialize CSS String.
  cssStr = ''

  # Handle imports.
  if jsoncss.imports
    for import_ in jsoncss.imports
      cssStr += formatCssImport(import_)
    
  # Handle rules.
  if jsoncss.rules
    traversalLog = {'cssStr': ''}
    JsonCss.traverse(
      jsoncss.rules,
      JsonCss.getChildren,
      JsonCss.visit,
      traversalLog
    )
    cssStr += traversalLog.cssStr

  return cssStr

# Convert CSS to JSONCSS
JsonCss.loadcss = (css) ->
  jsoncss = {
    imports: {},
    rules: {}
  }

  cssom_json = Froth.cssom.parse(css)

  for key, rule of cssom_json.cssRules
    # Handle import rules.
    if rule.href
      jsoncss.imports[rule.href] = {
        media: rule.media
      }
    # Handle normal rules.
    else if rule.selectorText
      selector = Froth.normalizeSelector(rule.selectorText)
      jsoncss.rules[selector] ?= {}
      if rule.style?.length
        style = rule.style
        for i in [0 .. (style.length - 1)]
          styleKey = style[i]
          styleValue = style[styleKey]
          if style._importants[styleKey]
            styleValue += ' !important'
          jsoncss.rules[selector][styleKey] = styleValue

  return jsoncss

# Rewrite urls in a JSONCSS object, 
# using a given set of rewrite rules.
JsonCss.rewriteUrls = (jsoncss, rewriteRules) ->
  JsonCss.rewriteImportUrls(jsoncss, rewriteRules)
  JsonCss.rewriteRuleUrls(jsoncss, rewriteRules)

JsonCss.rewriteImportUrls = (jsoncss, rewriteRules)->
  for import_ in jsoncss.imports ? []
    import_.href = Froth.rewriteWrappedUrl(import_.href, rewriteRules)

JsonCss.rewriteRuleUrls = (jsoncss, rewriteRules) ->
  for selector, style of jsoncss.rules ? {}
    for attr, value of style
      if typeof value == 'string'
        style[attr] = Froth.rewriteWrappedUrl(value, rewriteRules)

# Rewrite a wrapped url (e.g. a "url(http://foo") string).
Froth.rewriteWrappedUrl = (url, rewriteRules) ->
  return url.replace(Froth.urlRe, (match...) ->
    url = match[2]
    rewrittenUrl = Froth.rewriteUrl(url, rewriteRules)
    return match[1] + rewrittenUrl + match[3]
  )

# Rewrite a url based on the given rewrite rules.
# Last matching rule will be used.
Froth.rewriteUrl = (url, rewriteRules) ->
  # Loop through rules in reverse order until a match is found.
  for i in [rewriteRules.length - 1..0] by -1
    rule = rewriteRules[i]
    rewrittenUrl = url.replace(rule[0], rule[1])
    # If rewritten url differs, we have matched and should return.
    if rewrittenUrl != url
      return rewrittenUrl
  return url

###
Froth.Sheet
###
Froth.Sheet = class Sheet
  constructor: (id, rules={}, imports=[]) ->
    @id = id
    @rules = rules
    @imports = imports

  toCss: =>
    return Froth.JsonCss.dumpcss(this.toJsonCss())

  toJsonCss: =>
    return Froth.toJsonCss(this)

Froth.defaultSheetId = '_froth'
Froth.sheets = {}
Froth.sheets[Froth.defaultSheetId] = new Froth.Sheet(
  Froth.defaultSheetId
)

Froth.urlRe = /(url\(["'])(.*?)(["']\))/g


###
Misc. Helpers
@TODO: refactor & organize.
###

# Normalizes a selector by collapsing whitespace and ordering
# composite selectors.
Froth.normalizeSelector = (selector) ->
  re = /\s*([^\s\>]+|\>)\s*/g
  tokens = []
  while match = re.exec(selector)
    tokens.push(match[1])
  normalized_tokens = []
  token_re = /((\.|\#)?[^\.\#]+)/g
  for token in tokens
    ids = []
    classes = []
    others = []
    while match = token_re.exec(token)
      subtoken = match[1]
      if subtoken[0] == '#'
        ids.push(subtoken)
      else if subtoken[0] == '.'
        classes.push(subtoken)
      else
        others.push(subtoken)
    ordered_subtokens = others.sort().concat(ids.sort()).concat(classes.sort())
    normalized_tokens.push(ordered_subtokens.join(''))
  return normalized_tokens.join(' ')

# Util function to non-recursively walk a tree, depth-first.
Froth.df_walk = (tree, getChildNodesFn, visitFn, log) ->
  log ?= {}
  rootNode = {ancestors: [], nodeId: null, data: tree}
  nodes = getChildNodesFn(rootNode)
  while (nodes.length)
    node = nodes.shift()
    childNodes = getChildNodesFn(node)
    for childNode in childNodes
      nodes.push(childNode)

    visitFn(node, log)

  return log


# Convert generic (frothJson or css text) to JSONCSS.
Froth.toJsonCss = (data) ->
  # Handle css text.
  if typeof data == 'string'
    return Froth.JsonCss.loadcss(data)

  # Handle frothJson.
  else if typeof data == 'object'
    return Froth.frothJsonToJsonCss(data)

# Convert Froth JSON rules to JSON CSS rules.
# Froth JSON is a superset of Froth JSONCSS, but it allows nesting and 
# a few shorthand conveniences like '&' in rules.
Froth.frothJsonRulesToJsonCssRules = (frothJsonRules={}) ->

  # Function to get child nodes.
  getChildNodes = (node) ->
    childNodes = []
    for own k, v of node.data
      if typeof v == 'object'
        childNodes.push({
          ancestors: node.ancestors.concat([node]),
          nodeId: k,
          data: v
        })
    return childNodes

  # Function to convert a Froth JSON node to a Froth JSONCSS node.
  # Will merge style attributes into any previously defined JSONCSS nodes stored
  # log.jsoncss .
  visitNode = (node, log) ->
    # Get current selector by joining ancestor ids, and appending current id.
    selectorIds = []
    for ancestor in node.ancestors[1..]
      selectorIds.push(ancestor.nodeId)
    selectorIds.push(node.nodeId)
    selector = selectorIds.join(' ')

    # ' &' should be replaced with '' to do concatenation.
    selector = selector.replace(' &', '')

    selector = Froth.normalizeSelector(selector)

    # Get style attributes.
    styleAttrs = {}
    hasStyles = false
    for k, v of node.data
      if (typeof v != 'object')
        styleAttrs[k] = v
        hasStyles = true

    # If there were styles, create style rule string and
    # add to running css string.
    if hasStyles
      log.rules[selector] ?= {}
      Froth.extend(log.rules[selector], styleAttrs)

  # Walk the given input tree , and return a JSONCSS object.
  log = {
    rules: {}
  }
  Froth.df_walk(frothJsonRules, getChildNodes, visitNode, log)
  return log.rules
  
# Convert Froth JSON to JSON CSS.
Froth.frothJsonToJsonCss = (frothJson={}) ->
    # Initialize jsoncss object.
    jsoncss = {
      id: frothJson.id,
      imports: (import_ for import_ in frothJson.imports ? [])
    }

    # Convert rules.
    jsoncss.rules = Froth.frothJsonRulesToJsonCssRules(frothJson.rules)

    return jsoncss

###
Froth actions.
###

Froth.getSheet = (sheetId) ->
  sheetId ?= Froth.defaultSheetId
  # Create sheet if it does not exist.
  Froth.sheets[sheetId] ?= new Froth.Sheet(sheetId)
  return Froth.sheets[sheetId]
#
# Common code for set/get.
#
# @TODO: change this to be set/get for just rules.
Froth._set_update_common = (rules, sheetId) ->
  sheet = Froth.getSheet(sheetId)

  jsoncssRules = {}

  # Handle CSS text.
  if typeof rules == 'string'
    jsoncss = JsonCss.loadcss(rules)
    jsoncssRules = jsoncss.rules

  # Handle FrothJson rules.
  else if typeof rules == 'object'
    jsoncssRules = Froth.frothJsonRulesToJsonCssRules(rules)

  return [sheet, jsoncssRules]

# Set rules.
# @TODO: implement parent context, for appending to a given parent.
# Or perhaps make that a method of the Rule.
Froth.set = (rules, sheetId) ->
  [sheet, jsoncssRules] = Froth._set_update_common(rules, sheetId)
  # Replace existing rules in the sheet.
  for selector, styles of jsoncssRules
    sheet.rules[selector] = styles

# Update rules.
Froth.update = (rules, sheetId) ->
  [sheet, jsoncssRules] = Froth._set_update_common(rules, sheetId)
  # Update existing rules in the sheet.
  for selector, styles of jsoncssRules
    Froth.extend(sheet.rules[selector], styles)

# Add imports.
Froth.addImports = (imports, sheetId) ->
  sheet = Froth.getSheet(sheetId)
  for import_ in imports ? []
    sheet.imports.push(import_)

# Delete rules.
Froth.delete = ->
  console.log('delete')

# Clear all sheets.
Froth.resetSheets = ->
  Froth.sheets = {}

Froth.resetConfig = ->
  Froth.config = Froth.extend({}, Froth.defaultConfig)

# Inject sheets into DOM document.
Froth.inject = (sheetIds) ->
  if not window? or not document?
    return
  if not sheetIds
    sheetIds = [Froth.defaultSheetId]
  else if not (sheetIds instanceof Array)
    if sheetIds == 'all'
      sheetIds = []
      for sheetId, sheet of Froth.sheets
        sheetIds.push(sheetId)
    else
      sheetIds = [sheetIds]

  for sheetId in sheetIds
    sheet = Froth.sheets[sheetId]
    cssText = sheet.toCss()
    cssEl = document.createElement('style')
    cssEl.id = sheetId + '_css'
    cssEl.type = 'text/css'
    if (cssEl.styleSheet)
      cssEl.styleSheet.cssText = cssText
    else
      cssEl.appendChild(document.createTextNode(cssText))

    document.getElementsByTagName("head")[0].appendChild(cssEl)

# Include a froth module.
Froth.addModule = (frothMod) ->
  # Merge config.
  #@TODO

  # Convert sheets to JsonCss.
  jsoncssSheets = {}
  for sheetId, sheetData of frothMod.sheets
    jsoncssSheets[sheetId] = Froth.toJsonCss(sheetData)

  # Rewrite relative urls per module's baseUrl, if given.
  rewriteRules = []
  if frothMod.config?.baseUrl?
    baseUrlRewriteRule = [
      /^[^(http:\/\/|\/)](.*)/,
      (match) ->
        rewrittenUrl = frothMod.config.baseUrl + match
        return rewrittenUrl
    ]
    rewriteRules.push(baseUrlRewriteRule)
  for sheetId, jsoncss of jsoncssSheets
    JsonCss.rewriteUrls(jsoncss, rewriteRules)

  # Merge module's sheets.
  for sheetId, jsoncss of jsoncssSheets
    Froth.set(jsoncss.rules, sheetId)
    Froth.addImports(jsoncss.imports, sheetId)

# Extend config.
Froth.extendConfig = (targetConfig, srcConfigs...) ->
  #@TODO: implement this.
  return targetConfig

# Include CSS Parser (from https://github.com/NV/CSSOM)
Froth.cssom = require('./contrib/cssom.min.js')

# Define Froth for AMD.

