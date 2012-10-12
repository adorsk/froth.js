var util = require('should');
var util = require('../util.js');
var jsonCssProcessor = require('../json_css_processor.js');

describe('jsonCssProcessor', function(){

    describe.skip('#simpleRule', function(){
        var expectedResult = util.heredoc(function(){
/*
selector {
  color: blue
}*/ 
        }) + "\n";

        var jsonCss = {
            rules: {
                'selector' : {
                    'color': 'blue'
                }
            }
        };
        var result = jsonCssProcessor.process(jsonCss);
        result.should.eql(expectedResult);
    });


    describe('#nestedRules', function(){
        var expectedResult = util.heredoc(function(){
/*
selector1 selector2 {
  color: blue
}*/ 
        }) + "\n";
        var jsonCss = {
            rules: {
                'selector1': {
                    'selector2': {
                        'color': 'blue'
                    }
                }
            }
        };
        var result = jsonCssProcessor.process(jsonCss);
        result.should.eql(expectedResult);
    });

    describe('#concatenation', function(){
        var expectedResult = util.heredoc(function(){
/*
selector1.selector2 {
  color: blue
}*/ 
        }) + "\n";
        var jsonCss = {
            rules: {
                'selector1': {
                    '&.selector2': {
                        'color': 'blue'
                    }
                }
            }
        };
        var result = jsonCssProcessor.process(jsonCss);
        result.should.eql(expectedResult);
    });
});

