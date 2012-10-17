var requirejs = require('requirejs');
requirejs.config({
    baseUrl: __dirname + '/js',
    nodeRequire: require,
    paths: {
        'froth': '/home/adorsk/projects/froth.js/lib/froth'
    },
    shim: {
        'froth': {
            exports: 'Froth'
        }
    }
});

requirejs(['app', 'froth'], function(app, Froth){
    console.log("froth is: ", Froth);
});


