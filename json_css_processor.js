// Non-recursive tree travesal.
var traverse = function(tree, getChildrenFn, visitFn, log){
    log = log || {};
    var nodeObj = {ancestors: [], nodeId: '', data: tree};
    var nodeObjs = getChildrenFn(nodeObj)

    while (nodeObjs.length){
        nodeObj = nodeObjs.shift();
        var childNodeObjs = getChildrenFn(nodeObj);
        for (childNodeObj in childNodeObjs){
            nodeObjs.push(childNodeObj);
        }

        visitFn(nodeObj, log);
    }

    return log;
}

// Get child nodes of a JSON CSS node.
// We assume all elements which are objects are children.
var jsonCssGetChildrenFn = function(nodeObj){
    var childNodeObjs = [];
    for (var key in nodeObj.data){
        var val = nodeObj.data[key];
        if (typeof val == 'object'){
            childNodeObjs.push({
                ancestors: nodeObj.ancestors.concat([nodeObj]),
                nodeId: key,
                data: val
            });
        }
    }
    return childNodeObjs;
};

// Visit a JSON CSS node.
// Outputs a CSS string for the given node.
// We assume all non-object elements are style attributes.
var jsonCssVisitFn = function(nodeObj, log){
    // Get current selector by joining ancestor ids.
    var selectorIds = [];
    for (var i in nodeObj.ancestors){
        var ancestor = nodeObj.ancestors[i];
        selectorIds.push(ancestor.nodeId);
    }
    selectorIds.push(nodeObj.nodeId);
    var selector = selectorIds.join('');

    // Get style attributes.
    var styleAttrs = {};
    for (var key in nodeObj.data){
        var val = nodeObj.data[key];
        if (typeof val != 'object'){
            styleAttrs[key] = val;
        }
    }

    // Format css output.
    nodeCssStr = formatCssRule(selector, styleAttrs);

    // Add to ongoing cssStr.
    log.cssStr += nodeCssStr;
};

var formatCssRule = function(selector, styleAttrs, opts){
    opts = opts || {};
    opts.indent = opts.indent || '  ';
    opts.linebreak = opts.linebreak || '\n';
    var cssStr = "";
    cssStr += selector + " {" + opts.linebreak;
    for (var attr in styleAttrs){
        attrStr = opts.indent + attr + ": " + styleAttrs[attr] + opts.linebreak;
        cssStr += attrStr;
    }
    cssStr += "}" + opts.linebreak;
    return cssStr;
};

// Convert a JSONCSS into a CSS string, using non-recursive traversal.
exports.process = function(jsonCss){
    // Initialize CSS String.
    var cssStr = '';

    // Handle imports.
    // @TODO
    
    // Handle rules (if any).
    if (jsonCss.rules){
        var traversalLog = {'cssStr': ''};
        var rulesStr = traverse(
            jsonCss.rules,
            jsonCssGetChildrenFn,
            jsonCssVisitFn,
            traversalLog
        );
        cssStr += traversalLog.cssStr;
    }

    return cssStr;
    
};
