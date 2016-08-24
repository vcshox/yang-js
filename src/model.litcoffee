# Model - instance of schema-driven data

The `Model` class is where the [Yang](./yang.litcoffee) schema
expression and the data object come together to provide the *adaptive*
and *event-driven* data interactions.

It is typically not instantiated directly, but is generated as a
result of [Yang::eval](./yang.litcoffee#eval-data-opts).

```javascript
var schema = Yang.parse('container foo { leaf a { type uint8; } }');
var model = schema.eval({ foo: { a: 7 } });
// model is { foo: [Getter/Setter] }
// model.foo is { a: [Getter/Setter] }
// model.foo.a is 7
```

The generated `Model` is a hierarchical composition of
[Property](./property.litcoffee) instances. The instance itself uses
`Object.preventExtensions` to ensure no additional properties that are
not known to itself can be added.

## Class Model

    stack      = require 'stacktrace-parser'
    Emitter    = require './emitter'
    XPath      = require './xpath'
    Expression = require './expression'
    Property   = require './property'

    class Model extends Emitter

      constructor: (schema, props={}) ->
        unless schema instanceof Expression
          throw new Error "cannot create a new Model without schema Expression"

        super
        unless schema.kind is 'module'
          schema = (new Expression 'module').extends schema

        prop.join this for k, prop of props when prop.schema in schema.nodes
        new Property schema.tag, this, schema: schema

        Object.defineProperties this,
          '_id': value: schema.tag ? Object.keys(this).join('+')
        Object.preventExtensions this

## Instance-level methods

### on (event)

The `Model` instance is an `EventEmitter` and you can attach various
event listeners to handle events generated by the `Model`:

event | arguments | description
--- | --- | ---
update | (prop, prev) | fired when an update takes place within the data tree
change | (elems...) | fired when the schema is modified
create | (items...) | fired when one or more `list` element is added
delete | (items...) | fired when one or more `list` element is deleted

It also accepts optional XPATH/YPATH expressions which will *filter*
for granular event subscription to specified events from only the
elements of interest.

The event listeners to the `Model` can handle any customized behavior
such as saving to database, updating read-only state, scheduling
background tasks, etc.

This operation is protected from recursion, where operations by the
`callback` may result in the same `callback` being executed multiple
times due to subsequent events triggered due to changes to the
`Model`. Currently, it will allow the same `callback` to be executed
at most two times.

      on: (event, filters..., callback) ->
        unless callback instanceof Function
          throw new Error "must supply callback function to listen for events"
        filters = filters.map (x) => XPath.parse x, @__.schema

        recursive = (name) ->
          seen = {}
          frames = stack.parse(new Error().stack)
          for frame, i in frames when ~frame.methodName.indexOf(name)
            { file, lineNumber, column } = frames[i-1]
            callee = "#{file}:#{lineNumber}:#{column}"
            seen[callee] ?= 0
            if ++seen[callee] > 1
              console.warn "detected recursion for '#{callee}'"
              return true 
          return false

        $$$ = (prop, args...) ->
          if not filters.length or prop.path.contains filters...
            unless recursive('$$$')
              ctx =
                type: event
                model: this
                ts: Date.now()
              callback.apply ctx, [prop].concat args

        super event, $$$

Please refer to [Model Events](../TUTORIAL.md#model-events) section of
the [Getting Started Guide](../TUTORIAL.md) for usage examples.

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        props = @__.find(pattern).props
        return switch
          when not props.length then null
          when props.length > 1 then props
          else props[0]

## Export Model Class

    module.exports = Model
