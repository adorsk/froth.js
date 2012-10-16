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

###
Froth.Context
###
Froth.Context = class Context
  styles: {}

  compile: =>
    console.log('compile')
    compiled_css = {}
    for styleId, style of this.styles
      compiled_css[styleId] = Froth.JsonCss.dumpcss(style)
    console.log("compiled_css: %j", compiled_css)
    # TODO: clean this up! Need better detection here.
    if window
      for styleId, compiledStyle of compiled_css
        styleEl = window.document.createElement("style")
        styleEl.type = "text/css"
        styleEl.innerHTML = compiledStyle
        window.document.head.appendChild(styleEl)

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
    attrStr = opts.indent + k + ": " + v + opts.linebreak
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
