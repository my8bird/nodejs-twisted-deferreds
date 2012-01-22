assert = require('assert')

class Failure extends Error
   name = "Failure"
   constructor: (msg) ->
      @message = msg

class AlreadyCalledError extends Failure
   name = "AlreadyCalledError"
class DeferredError extends Failure
   name = "DeferredError"
class TimeoutError extends Failure
   name = "TimeoutError"


logError = (err) ->
   console.error err
   err

exports.succeed = (result)->
   """
   Return a Deferred that has already had '.callback(result)' called.

   This is useful when you're writing synchronous code to an
   asynchronous interface: i.e., some code is calling you expecting a
   Deferred result, but you don't actually need to do anything
   asynchronous. Just return defer.succeed(theResult).

   See L{fail} for a version of this function that uses a failing
   Deferred rather than a successful one.

   @param result: The result to give to the Deferred's 'callback'
      method.

   @rtype: L{Deferred}
   """
   d = new Deferred()
   d.callback(result)
   d


exports.fail = (result=null) ->
   """
   Return a Deferred that has already had '.errback(result)' called.

   See L{succeed}'s docstring for rationale.

   @param result: The same argument that L{Deferred.errback} takes.

   @raise NoCurrentExceptionError: If C{result} is C{null} but there is no
     current exception state.

   @rtype: L{Deferred}
   """
   d = new Deferred()
   d.errback(result)
   d


exports.toDeferred = (func, args...) ->
   d = new Deferred()
   args.push (err, args...) ->
      if err
         d.errback err
      else
         d.callback args...

   func.apply undefined, args
   d


exports.maybeDeferred = (f, args...) ->
   """Invoke a function that may or may not return a deferred.

   Call the given function with the given arguments.  If the returned
   object is a C{Deferred}, return it.  If the returned object is a C{Failure},
   wrap it with C{fail} and return it.  Otherwise, wrap it in C{succeed} and
   return it.  If an exception is raised, convert it to a C{Failure}, wrap it
   in C{fail}, and then return it.

   @type f: Any callable
   @param f: The callable to invoke

   @param args: The arguments to pass to C{f}
   @param kw: The keyword arguments to pass to C{f}

   @rtype: C{Deferred}
   @return: The result of the function call, wrapped in a C{Deferred} if
   necessary.
   """
   try
      result = f.apply(null, args)
   catch ex
      return exports.fail(ex)

   if result instanceof Deferred
      return result
   else if result instanceof Failure
      return fail(result)
   else
      return exports.succeed(result)

   return null

timeout = (deferred) ->
   deferred.errback(new TimeoutError("Callback timed out"))

passthru = (arg) ->
   arg


class Deferred
   """This is a callback which will be put off until later.

   Why do we want this? Well, in cases where a function in a threaded
   program would block until it gets a result, for Twisted it should
   not block. Instead, it should return a Deferred.

   This can be implemented for protocols that run over the network by
   writing an asynchronous protocol for twisted.internet. For methods
   that come from outside packages that are not under our control, we use
   threads (see for example L{twisted.enterprise.adbapi}).

   For more information about Deferreds, see doc/howto/defer.html or
   U{http://twistedmatrix.com/projects/core/documentation/howto/defer.html}
   """
   constructor: () ->
      @callbacks = []
      @called = 0
      @paused = 0
      @timeoutCall = null

      # Are we currently running a user-installed callback?  Meant to prevent
      # recursive running of callbacks when a reentrant call to add a callback is
      # used.
      @_runningCallbacks = false

   addCallbacks: (callback, callbackArgs=null, errback=passthru, errbackArgs=null) =>
      """
      Add a pair of callbacks (success and error) to this Deferred.

      These will be executed when the 'master' callback is run.
      """
      cbs =
         'success': [callback, callbackArgs],
         'error':   [errback, errbackArgs]
      @callbacks.push(cbs)

      if @called
         @_runCallbacks()
      @

   addCallback: (callback, args...) =>
     """
     Convenience method for adding just a callback.

     See L{addCallbacks}.
     """
     @addCallbacks(callback, callbackArgs=args)

   addErrback: (errback, args...) ->
     """
     Convenience method for adding just an errback.

     See L{addCallbacks}.
     """
     @addCallbacks(passthru, null, errback, errbackArgs=args)

   addBoth: (callback, args...) =>
     """
     Convenience method for adding a single callable as both a callback
     and an errback.

     See L{addCallbacks}.
     """
     @addCallbacks(callback, callbackArgs=args, callback, errbackArgs=args)

   chainDeferred: (d) =>
     """
     Chain another Deferred to this Deferred.

     This method adds callbacks to this Deferred to call d's callback or
     errback, as appropriate. It is merely a shorthand way of performing
     the following::

      @addCallbacks(d.callback, undefined, d.errback, undefined)

     When you chain a deferred d2 to another deferred d1 with
     d1.chainDeferred(d2), you are making d2 participate in the callback
     chain of d1. Thus any event that fires d1 will also fire d2.
     However, the converse is B{not} true; if d2 is fired d1 will not be
     affected.
     """
     @addCallback(d.callback, undefined, d.errback, undefined)

   callback: (result) =>
     """
     Run all success callbacks that have been added to this Deferred.

     Each callback will have its result passed as the first
     argument to the next; this way, the callbacks act as a
     'processing chain'. Also, if the success-callback returns a Failure
     or raises an Exception, processing will continue on the *error*-
     callback chain.
     """
     @_startRunCallbacks(result)

   errback: (fail=null) =>
     """
     Run all error callbacks that have been added to this Deferred.

     Each callback will have its result passed as the first argument to the
     next; this way, the callbacks act as a 'processing chain'. Also, if the
     error-callback returns a non-Failure or doesn't raise an Exception,
     processing will continue on the *success*-callback chain.

     If the argument that's passed to me is not a failure.Failure instance, it
     will be embedded in one. If no argument is passed, a failure.Failure
     instance will be created based on the current traceback stack.
     """
     f = if fail instanceof Failure then fail else new Failure(fail)

     @_startRunCallbacks(f)

   pause: () =>
      """
      Stop processing on a Deferred until L{unpause}() is called.
      """
      @paused++

   unpause: () ->
      """
      Process all callbacks made since L{pause}() was called.
      """
      @paused--
      if @paused == 0 and @called
         @_runCallbacks()

   _continue: (result) =>
      @result = result
      @unpause()

   _startRunCallbacks: (result) =>
      if @called
         throw new AlreadyCalledError()

      @called = true
      @result = result
      if @timeoutCall
         try
            @timeoutCall.cancel()
         catch ex
            throw ex

         @timeoutCall = undefined

      @_runCallbacks()

   _runCallbacks: () =>
      if @_runningCallbacks
         # Don't recursively run callbacks
         return

      if not @paused
         while @callbacks.length > 0
            next_cb = @callbacks.shift()
            key = if @result instanceof Failure then 'error' else 'success'
            caller = next_cb[key]
            console.log(caller)
            callback = caller[0]
            args = caller[1] or []
            try
               @_runningCallbacks = true
               try
                  console.log(args)
                  args.splice(0, 0, @result)
                  if callback
                     @result = callback.apply(null, args)
               catch ex
                  console.log(ex)
                  throw ex
               finally
                  @_runningCallbacks = false

               if @result instanceof Deferred
                  # note: this will cause _runCallbacks to be called
                  # recursively if @result already has a result.
                  # This shouldn't cause any problems, since there is no
                  # relevant state in this stack frame at this point.
                  # The recursive call will continue to process
                  # @callbacks until it is empty, then return here,
                  # where there is no more work to be done, so this call
                  # will return as well.
                  @pause()
                  @result.addBoth(@_continue.bind(@))
                  break
            catch ex
               @result = new Failure(ex)

exports.Deferred = Deferred

exports.DeferredList = (deferreds) ->
   deferred = new Deferred()
   done = deferred.callback.bind(deferred)

   res = []
   for i of  deferreds
      d = deferreds[i]

      d.addCallback (v) ->
         res.push([null, v])

         if deferreds.length == res.length
            done res

      d.addErrback (err) ->
         # Since there has been an error switch over to the errback when done
         done = deferred.errback.bind(deferred)

         # Store the error
         res.push([err, null])

         # See if we are done now
         if deferreds.length == res.length
            done res

   return deferred

