Direct port of python's Twisted Deferred module to coffeescript and thus javascript.

Links:

* [Twisted Docs](http://twistedmatrix.com/documents/8.1.0/api/twisted.internet.defer.Deferred.html)

Installation
============
git://github.com/my8bird/nodejs-twisted-deferreds.git
npm link

Dependencies:

* coffeescript
* nodeunit (for running the tests)

Usage
=====
This is a contrived example that reads the contents of a file, trims the whitespace and prints the result to the console.  If an error occurs then it is logged.



    fs       = require('fs')
    Deferred = require('twisted-deferred').Deferred

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

Future
------
In the future the following shortcut (or similar) will be provided for starting the process.

    d = wrapDeferred(fs.readFile 'path', 'read')
    # d is now a Deferred that callbacks and errbacks can be attached too

Tests
=====
To run the tests ensure that nodeunit is installed.  Then run `run-tests.sh`.

