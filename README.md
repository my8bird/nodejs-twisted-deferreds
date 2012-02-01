[![Build Status](https://secure.travis-ci.org/my8bird/nodejs-twisted-deferreds.png?branch=master)](http://travis-ci.org/my8bird/nodejs-twisted-deferreds)


Direct port of python's Twisted Deferred module to coffeescript and thus javascript.

Links:

* [Twisted Docs](http://twistedmatrix.com/documents/8.1.0/api/twisted.internet.defer.Deferred.html)

Installation
============
    git clone git://github.com/my8bird/nodejs-twisted-deferreds.git 
    cd nodejs-twisted-deferreds
    (sudo) npm link

Dependencies:

* coffeescript
* nodeunit (for running the tests)

Usage
=====
This is a contrived example that reads the contents of a file, trims the whitespace and prints the result to the console.  If an error occurs then it is logged.



    fs    = require('fs')
    defer = require('twisted-deferred')
    Deferred = defer.Deferred

    # Create Deferred instance that will track the steps
    d = new Deferred()

    # Add a step that cleans the content
    d.addCallback (content) ->
        return content.trim()

    # Add a step that uses the cleaned content
    d.addCallback (cleanedContent) ->
        console.log cleanedContent

    # If there is an error at any step make sure it is logged.
    d.addErrback (err) ->
        console.error err

    # Grab the content from the file and start the procedure
    fs.readFile "path", "r", (err, data) ->
        if err
            d.errback err
        else
            d.callback data

It is also possible to wrap existing async code using the toDeferred method:
    d = defer.toDeferred(fs.readFile, "path")
    d.addCallback (content) ->
       console.log content
    d.addErrback (err) ->
       # log err


Tests
=====
To run the tests ensure that nodeunit is installed.  Then run `run-tests.sh`.

