var util = require('should');
var util = require('../util.js');
var jsonCssProcessor = require('../json_css_processor.js');

describe('jsonCssProcessor', function(){
    describe('#simpleRule', function(){
        var simpleRule = {
            'selector' : {
                'color': 'blue'
            }
        };
        var jsonCss = {rules: simpleRule};

        var expectedResult = util.heredoc(function(){
/*
selector {
  color: blue
}*/ 
        }) + "\n";
        console.log(expectedResult);
        var result = jsonCssProcessor.process(jsonCss);
        result.should.eql(expectedResult);
    });
});

