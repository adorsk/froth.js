# Initial setup.
root = this
oldFroth = root.Froth
Froth = {}
if typeof exports != 'undefined'
  Froth = exports
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
  bundling: {
    baseRewriteUrl: '',
    bundleDir: 'bundled_assets'
  }
}

# Initial config.
Froth.config = Froth.extend({}, Froth.defaultConfig)

# Include CSS Parser (from https://github.com/NV/CSSOM)
# @TODO: inline this for min.js build.
cssom = require('./contrib/cssom.min.js')

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
JsonCss.dumpcss = (jsonCss) ->

  # Initialize CSS String.
  cssStr = ''

  # Handle imports.
  if jsonCss.imports
    for import_ in jsonCss.imports
      cssStr += formatCssImport(import_)
    
  # Handle rules.
  if jsonCss.rules
    traversalLog = {'cssStr': ''}
    rulesStr = JsonCss.traverse(
      jsonCss.rules,
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

  cssom_json = cssom.parse(css)

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

###
Froth.Stylesheet
###
Froth.Stylesheet = class Stylesheet
  constructor: (id, rules={}, imports=[]) ->
    @id = id
    @rules = rules
    @imports = imports

  toCss: =>
    return Froth.JsonCss.dumpcss(this)

Froth.defaultStylesheetId = '_froth'
Froth.stylesheets = {}
Froth.stylesheets[Froth.defaultStylesheetId] = new Froth.Stylesheet(
  Froth.defaultStylesheetId
)


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

# Convert Froth JSON to JSON CSS.
# Froth JSON is a superset of Froth JSONCSS, but it allows nesting and 
# a few shorthand conveniences like '&'.
Froth.frothJsonToJsonCss = (frothJson={}) ->

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
      log.jsoncss.rules[selector] ?= {}
      Froth.extend(log.jsoncss.rules[selector], styleAttrs)

  # Walk the given input tree , and return a JSONCSS object.
  log = {
    jsoncss: {
      rules: {}, 
      imports: {}
    }
  }
  Froth.df_walk(frothJson, getChildNodes, visitNode, log)
  return log.jsoncss
  

###
Froth actions.
###

Froth.getStylesheet = (stylesheetId) ->
  stylesheetId ?= Froth.defaultStylesheetId
  # Create stylesheet if it does not exist.
  Froth.stylesheets[stylesheetId] ?= new Froth.Stylesheet(stylesheetId)
  return Froth.stylesheets[stylesheetId]

# Common code for set/get.
Froth._set_update_common = (data, stylesheetId) ->
  stylesheet = Froth.getStylesheet(stylesheetId)
  #@ Todo: handle any rules format, not just Froth JSON.
  jsoncss = Froth.frothJsonToJsonCss(data)
  return [stylesheet, jsoncss]


# Set rules.
# @TODO: implement parent context, for appending to a given parent.
# Or perhaps make that a method of the Rule.
Froth.set = (rules, stylesheetId) ->
  [stylesheet, jsoncss] = Froth._set_update_common(rules, stylesheetId)
  # Replace existing rules in the stylesheet.
  for selector, styles of jsoncss.rules
    stylesheet.rules[selector] = styles

# Update rules.
Froth.update = (rules, stylesheetId) ->
  [stylesheet, jsoncss] = Froth._set_update_common(rules, stylesheetId)
  # Update existing rules in the stylesheet.
  for selector, styles of jsoncss.rules
    Froth.extend(stylesheet.rules[selector], styles)

# Add imports.
Froth.addImports = (imports, stylesheetId) ->
  stylesheet = Froth.getStylesheet(stylesheetId)
  for import_ in imports
    stylesheet.imports.push(import_)

# Delete rules.
Froth.delete = ->
  console.log('delete')

# Clear all stylesheets.
Froth.reset = ->
  Froth.stylesheets = {}
  Froth.config = Froth.extend({}, Froth.defaultConfig)
