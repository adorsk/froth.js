exports.heredoc = function(func) {
    // get function code as string
    var hd = func.toString();
    
    // remove { /* using a regular expression
    hd = hd.replace(/(^.*\{\s*\/\*\s*)/g, '');
    
    // remove */ } using a regular expression
    hd = hd.replace(/(\s*\*\/\s*\}.*)$/g, '');
    
    // return output
    return hd;
}
