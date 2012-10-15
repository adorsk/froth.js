# Non-recursive tree travesal.
traverse = (tree, getChildrenFn, visitFn, log) ->
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
jsoncssGetChildrenFn = (nodeObj) ->
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
jsoncssVisitFn = (nodeObj, log) ->
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
    nodeCssStr = formatCssRule(selector, styleAttrs)
    log.cssStr += nodeCssStr

# Format a single css rule.
formatCssRule = (selector, styleAttrs, opts={}) ->
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
formatCssImport = (import_, opts={}) ->
  opts.linebreak = opts.linebreak || '\n'
  return "@import url('"  + import_ + "');" + opts.linebreak

# Convert a JSONCSS into a CSS string, using non-recursive traversal.
dumpcss = (jsoncss) ->

  # Initialize CSS String.
  cssStr = ''

  # Handle imports.
  if jsoncss.imports
    for import_ in jsoncss.imports
      cssStr += formatCssImport(import_)
    
  # Handle rules.
  if jsoncss.rules
    traversalLog = {'cssStr': ''}
    rulesStr = traverse(
      jsoncss.rules,
      jsoncssGetChildrenFn,
      jsoncssVisitFn,
      traversalLog
    )
    cssStr += traversalLog.cssStr

  return cssStr
 
# Define exports.
exports.dumpcss = dumpcss
