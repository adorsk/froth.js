if (typeof define !== 'function') { var define = require('amdefine')(module) }

define(['require', 'froth'], function(req, Froth){
    console.log(req.toUrl('./'));
    Froth.set({
        'body': {
            'background-color': 'blue'
        }
    });
});
