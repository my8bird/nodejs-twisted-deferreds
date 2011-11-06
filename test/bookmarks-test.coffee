assert   = require("assert")
testCase = require('nodeunit').testCase
fs = require('fs')

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

   'wrapping a method an async method works': (test) ->
      @d = defer.toDeferred(fs.readFile, "path-that-does-not-exist")
      @d.addCallback (contents) ->
         assert.ok False, "Only the errback should have been called."
      @d.addErrback (err) ->
         assert.equal err.errno, 2
         assert.equal err.code, "ENOENT"
      test.done()

   'using maybeDeferred on a value returns that value': (test) ->
      test.expect 1
      @d = defer.maybeDeferred ((x) -> x), 42
      @d.addCallback (x) ->
         test.ok x, 42
         test.done()
      @d.addErrback () ->
         test.ok false, "Errback should not have been called."

   'using maybeDeferred on a deferred returns that deferred': (test) ->
      test.expect 1
      inner = new defer.Deferred
      @d = defer.maybeDeferred ((x)-> inner.callback x), 42
      @d.addCallback (x) ->
         test.ok x, 42
         test.done()
      @d.addErrback () ->
         test.ok false, "Errback should not have been called."

   'using maybeDeferred on a failure calls the errback': (test) ->
      @d = defer.maybeDeferred ((x) -> throw new Error("fail")), 42
      @d.addCallback (x) ->
         test.ok false, "Callback should not have been called."
      @d.addErrback (f) ->
         test.equal f.message.message, "fail"
         test.done()
)

