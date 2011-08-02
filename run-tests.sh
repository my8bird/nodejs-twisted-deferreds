#!/usr/bin/env node
require.paths.unshift(__dirname + '/lib');

var reporter = require('nodeunit').reporters.default;
reporter.run(['test']);
