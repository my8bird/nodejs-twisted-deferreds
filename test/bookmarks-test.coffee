assert   = require("assert")
testCase = require('nodeunit').testCase
defer = require('../lib/')

Deferred = defer.Deferred


goodCB = (v) ->
   v.count++
   v

errCB = (err) ->
   err.message.count++
   err


module.exports = testCase(
   setUp: (cb) ->
      @d = new Deferred()
      cb()

   tearDown: (cb) ->
      @d.addBoth (v) ->
         cb()

   'on success all callbacks called': (test)->
      @d = new Deferred()
      @d.addCallback goodCB
      @d.addCallback goodCB

      res = {count: 0}
      @d.callback res
      assert.equal res.count, 2
      test.done()

   'on success errbacks are not called': (test) ->
      @d.addCallback goodCB
      @d.addErrback  goodCB

      res = {count: 0}
      @d.callback res
      assert.equal res.count, 1
      test.done()

   'on failure all errbacks called': (test)->
      @d = new Deferred()
      @d.addErrback errCB
      @d.addErrback errCB
                  
      res = {count: 0}
      @d.errback res
      assert.equal res.count, 2
      test.done()

   'on failure callbacks are not called': (test) ->
      @d.addCallback goodCB
      @d.addErrback  errCB

      res = {count: 0}
      @d.errback res
      assert.equal res.count, 1
      test.done()

   'adding callback after success calls immediatly': (test) ->
      res = {count: 0}
      @d.callback res
      @d.addCallback goodCB
      # notice no async
      assert.equal res.count, 1
      test.done()

   'adding errback after failure calls immediatly': (test) ->
      res = {count: 0}
      @d.errback res
      @d.addErrback errCB
      # notice no async
      assert.equal res.count, 1
      test.done()

   'returning Deferred from callback waits for callback to finish': (test) ->
      @d.addCallback (v) ->
         defer.succeed v.foundInner = true

      res = {}
      @d.callback res

      assert.ok res.foundInner

      test.done()
)

