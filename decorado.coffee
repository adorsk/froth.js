root = exports ? this
Decorado = root.Decorado = {}

// Styles registry.
Decorado._styles = {'default': []};

Decorado._getNamespace -> (ns)
    ns = ns ? 'default'
    return Decorado._styles[ns];

Decorado.addStyle -> (style, ns)
  Decorado._styles[ns][style.id] = style;

  };

  // Remove a style from a namespace.
  Decorado.removeStyle = function(styleId, ns){
    ns = Decorado._getNamespace(ns);
    delete Decorado._styles[ns][styleId];
  };

  // Get a style.
  Decorado.getStyle = function(styleId, ns){
    ns = Decorado._getNamespace(ns);
    return Decorado._styles[ns][styleId];
  }

  // Update a style.
  Decorado.setStyle = function(styleId, style, ns){
      Decorado.removeStyle(styleId, ns);
      Decorado.addStyle(style, ns);
  }

  // Compile styles into css.
  Decorado.compile = function(ns){
    // COMPILE GIVEN NAMESPACE, OR ALL NAMESPACES.
  };

  Decorado.compileNamespace = function(ns){
    // COMPILE LOGIC HERE!
  };

  // Decorado.Style class.
  // --------------

  // Create a new style, with defined attributes. A client id (`cid`)
  // is automatically generated and assigned for you.
  var Style = Decorado.Style = function(attributes, options) {
    var defaults;
    var attrs = attributes || {};
    this.attributes = {};
    this._escapedAttributes = {};
    this.cid = _.uniqueId('s');
  };

  // Attach all inheritable methods to the prototype.
  _.extend(Style.prototype, {

    // Get the path to a local asset.
    url_for: function(){
    }

  });


  // Helpers
  // -------

  // Helper function to correctly set up the prototype chain, for subclasses.
  // Similar to `goog.inherits`, but uses a hash of prototype properties and
  // class properties to be extended.
  var extend = function(protoProps, staticProps) {
    var parent = this;
    var child;

    // The constructor function for the new subclass is either defined by you
    // (the "constructor" property in your `extend` definition), or defaulted
    // by us to simply call the parent's constructor.
    if (protoProps && _.has(protoProps, 'constructor')) {
      child = protoProps.constructor;
    } else {
      child = function(){ parent.apply(this, arguments); };
    }

    // Add static properties to the constructor function, if supplied.
    _.extend(child, parent, staticProps);

    // Set the prototype chain to inherit from `parent`, without calling
    // `parent`'s constructor function.
    var Surrogate = function(){ this.constructor = child; };
    Surrogate.prototype = parent.prototype;
    child.prototype = new Surrogate;

    // Add prototype properties (instance properties) to the subclass,
    // if supplied.
    if (protoProps) _.extend(child.prototype, protoProps);

    // Set a convenience property in case the parent's prototype is needed
    // later.
    child.__super__ = parent.prototype;

    return child;
  };

  // Set up inheritance for classes.
  Style.extend = extend;

}).call(this);
