if (typeof define !== 'function') { var define = require('amdefine')(module) }

define(['froth', 'mod1'], function(Froth, mod1){
    console.log("css is: ", Froth.getStylesheet().toCss());
});
