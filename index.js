'use strict';

var async = require('async');
var arrayWithout = require('array-without');

function Leaf(useDefaultHandlers) {
	Object.defineProperties(this, {
		_signals: {value: []},
		_handler: {value: {}},
		_busy: {value: false, writable: true}
	});

	if (useDefaultHandlers !== false) {
		Object.defineProperties(this, {
			_outputs: {value: []},
			_inputs: {value: []}
		});
		this.addHandler('connect', leafConnect);
		this.addHandler('disconnect', leafDisconnect);
	}
}

Leaf.prototype = {
	connect: function connect(leaf, cb) {
		assertLeaf(leaf);
		cb = ensureCallback(cb);

		if (this._outputs.indexOf(leaf) === -1) {
			this.signal({signal: 'connect', leaf: leaf}, cb);
		} else {
			return cb('leaf already connected');
		}
	},

	disconnect: function disconnect(leaf, cb) {
		assertLeaf(leaf);
		cb = ensureCallback(cb);

		if (this._outputs.indexOf(leaf) !== -1) {
			this.signal({signal: 'disconnect', leaf: leaf}, cb);
		} else {
			return cb('leaf not connected');
		}
	},

	broadcast: function broadcast(sig, cb) {
		cb = ensureCallback(cb);

		async.each(this._outputs.slice(), function (output, cb) {
			output.signal(sig, cb);
		}, cb);
	},

	signal: function signal(sig, cb) {
		cb = ensureCallback(cb);

		this._signals.unshift([sig, cb]);
		tickLeaf(this);
	},

	addHandler: function addHandler(name, handler) {
		if (name in this._handler) {
			throw new Error('handler already registered: ' + name);
		}

		this.replaceHandler(name, handler);
	},

	removeHandler: function removeHandler(name) {
		if (name in this._handler) {
			delete this._handler[name];
		} else {
			throw new Error('handler not registered: ' + name);
		}
	},

	replaceHandler: function replaceHandler(name, handler) {
		this._handler[name] = handler;
	}
};

function assertLeaf(leaf) {
	if (!(leaf instanceof Leaf)) {
		throw new Error('not a leaf');
	}
}

function tickLeaf(leaf) {
	if (leaf._busy || !leaf._signals.length) {
		return;
	}
	leaf._busy = true;

	var pair = leaf._signals.pop();
	var signal = pair[0];
	var cb = pair[1];

	if (!signal.signal) {
		nextTickLeaf(leaf);
		return cb.call(signal, 'signal is missing `.signal\' property');
	}

	var handler = leaf._handler[signal.signal];
	if (handler === undefined) {
		if ('*' in leaf._handler) {
			handler = leaf._handler['*'];
		} else {
			/*
				we don't error here due to the fact some leafs might be piped
				to from a foreign leaf, and it might only support a few signals.

				we don't want to error out if a stray random unsupported signal
				is found.
			*/
			nextTickLeaf(leaf);
			return cb.call();
		}
	}

	handler.call(leaf, signal, function (err) {
		nextTickLeaf(leaf);
		return cb.call(signal, err);
	});
}

function nextTickLeaf(leaf) {
	leaf._busy = false;
	process.nextTick(function () {
		tickLeaf(leaf);
	});
}

function leafConnect(signal, cb) {
	this._outputs.push(signal.leaf);
	signal.leaf._inputs.push(this);
	cb();
}

function leafDisconnect(signal, cb) {
	arrayWithout.inline(this._outputs, signal.leaf);
	arrayWithout.inline(signal.leaf._inputs, this);
	cb();
}

function ensureCallback(cb) {
	if (!(cb instanceof Function)) {
		return function (err) {
			if (err) {
				err = err instanceof Error ? err : new Error(err);
				throw err;
			}
		};
	}

	return cb;
}

module.exports = Leaf;
