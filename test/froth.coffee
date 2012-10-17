require('./common')
Froth = require('../lib/froth')

describe 'Froth Actions', ->

  # Clear stylesheets after each test.
  afterEach ->
    Froth.reset()

  describe '#Froth.set', ->
    it 'should set rules in the default stylesheet', ->
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules)
      stylesheet = Froth.getStylesheet()
      stylesheet.rules.should.eql(rules)

    it 'should set rules in the given stylesheet', ->
      stylesheetId = 'stylesheet1'
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules, stylesheetId)
      stylesheet = Froth.getStylesheet(stylesheetId)
      stylesheet.rules.should.eql(rules)

    it 'should override rules if they exist', ->
      rules_0 = {
        '.a' : {
          'color': 'blue',
          'width': 100
        },
        '.b' : {
          'color': 'red'
        }
      }
      Froth.set(rules_0)
      rules_1 = {
        '.a' : {
          'color': 'orange'
        }
      }
      Froth.set(rules_1)
      stylesheet = Froth.getStylesheet()
      stylesheet.rules.should.eql({
        '.a' : {
          'color': 'orange'
        },
        '.b' : {
          'color': 'red'
        }
      })


  describe '#Froth.update', ->
    it 'should update rules', ->
      rules_0 = {
        '.a' : {
          'color': 'blue',
          'width': 100,
          'height': 200
        }
      }
      Froth.set(rules_0)
      rules_1 = {
        '.a' : {
          'color' : 'green',
          'width': 50,
          'background-color': 'blue'
        }
      }
      Froth.update(rules_1)
      stylesheet = Froth.getStylesheet()
      stylesheet.rules.should.eql({
        '.a' : {
          'color': 'green',
          'width': 50,
          'background-color': 'blue',
          'height': 200
        }
      })

  describe '#Froth.delete', ->
    it 'should remove rules in the default stylesheet'
    it 'should remove rules in the given stylesheet'
