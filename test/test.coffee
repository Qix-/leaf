should = require 'should'
Leaf = require '../'

it 'should add a handler', ->
  leaf = new Leaf
  leaf.addHandler 'foo', -> 'yep'
  leaf._handler['foo']().should.equal 'yep'

it 'should remove a handler', ->
  leaf = new Leaf
  leaf.removeHandler 'connect'
  (should leaf._handler['connect']).not.be.ok()

it 'should replace a handler', ->
  leaf = new Leaf
  leaf.addHandler 'foo', -> 1234
  leaf.replaceHandler 'foo', -> 2345
  leaf._handler['foo']().should.equal 2345

it 'should have connect and disconnect handlers by default', ->
  leaf = new Leaf
  (should leaf._handler['connect']).be.ok().and.a.Function()
  (should leaf._handler['disconnect']).be.ok().and.a.Function()

it 'should honor useDefaultHandlers=false', ->
  leaf = new Leaf no
  (should leaf._handler).be.ok()
  (Object.keys leaf._handler).length.should.equal 0
  (should leaf._handler['connect']).not.be.ok()
  (should leaf._handler['disconnect']).not.be.ok()

it 'should queue a signal and execute it', (done)->
  signaled = no
  v = 0
  handler = (signal, cb)->
    (should signal).be.ok()
    (should signal.signal).equal 'test-signal'
    (should signal.v).equal 1234
    signaled = yes
    v = signal.v
    cb()

  leaf = new Leaf
  leaf.addHandler 'test-signal', handler
  leaf.signal {signal: 'test-signal', v: 1234}, (err)->
    if err then return done err
    signaled.should.equal yes
    v.should.equal 1234
    done()

it 'should connect to a second leaf', (done)->
  leaf1 = new Leaf
  leaf2 = new Leaf

  leaf1.connect leaf2, (err)->
    if err then return done err
    leaf1._outputs.length.should.equal 1
    leaf1._outputs[0].should.equal leaf2
    leaf2._inputs.length.should.equal 1
    leaf2._inputs[0].should.equal leaf1
    done()

it 'should disconnect from a second leaf', (done)->
  leaf1 = new Leaf
  leaf2 = new Leaf

  leaf1.connect leaf2, (err)->
    if err then return done err
    leaf1.disconnect leaf2, (err)->
      if err then return done err
      leaf1._outputs.length.should.equal 0
      leaf2._inputs.length.should.equal 0
      done()

it 'should not allow-non leafs', ->
  leaf = new Leaf
  (-> leaf.connect 'hello').should.throw 'not a leaf'
  (-> leaf.disconnect 'hello').should.throw 'not a leaf'
  (-> leaf.connect leaf).should.not.throw()
  (-> leaf.disconnect leaf).should.not.throw()

it 'should immediately execute if not busy', ->
  leaf = new Leaf
  leaf2 = new Leaf

  leaf.connect leaf2
  leaf._signals.length.should.equal 0

it 'should not execute if busy', ->
  leaf = new Leaf
  leaf2 = new Leaf

  leaf._busy = yes # never do this :)
  leaf.connect leaf2
  leaf._signals.length.should.equal 1

it 'should error on invalid signal', ->
  leaf = new Leaf
  (-> leaf.signal {}).should.throw 'signal is missing `.signal\' property'

it 'should gracefully ignore bad handlers', (done)->
  leaf = new Leaf
  leaf.signal {signal: 'foobar'}, (err)->
    (should err).not.be.ok()
    done()

it 'should handle wildcard (*) handlers', (done)->
  leaf = new Leaf
  signalValid = no
  signalInvalid = no

  validHandler = (signal, cb)->
    signalValid = yes
    cb()
  invalidHandler = (signal, cb)->
    signalInvalid = yes
    cb()

  leaf.addHandler 'foobar', validHandler
  leaf.addHandler '*', invalidHandler

  leaf.signal {signal: 'foobar'}, (err)->
    if err then return done err
    leaf.signal {signal: 'quxqix'}, (err)->
      if err then return done err
      signalValid.should.equal yes
      signalInvalid.should.equal yes
      done()

it 'should broadcast a signal to all outputs', (done)->
  sig2 = 0
  sig3 = 0
  sig4 = 0

  leaf1 = new Leaf
  leaf2 = new Leaf
  leaf3 = new Leaf
  leaf4 = new Leaf

  leaf2.addHandler 'foobar', (signal, cb)->
    sig2 = signal.n
    setTimeout cb, 10
  leaf3.addHandler 'foobar', (signal, cb)->
    sig3 = signal.n + 100
    @broadcast signal, (err)->
      if err then return cb err
      setTimeout cb, 10
  leaf4.addHandler 'foobar', (signal, cb)->
    sig4 = signal.n * 2
    setTimeout cb, 10

  leaf1.connect leaf2, (err)->
    if err then return done err
    leaf1.connect leaf3, (err)->
      if err then return done err
      leaf3.connect leaf4, (err)->
        if err then return done err
        leaf1.broadcast {signal: 'foobar', n: 1234}, (err)->
          if err then return done err
          sig2.should.equal 1234
          sig3.should.equal 1334
          sig4.should.equal 2468
          done()

it 'should error on duplicate connects', (done)->
  leaf = new Leaf
  leaf.connect leaf, (err)->
    if err then return done err
    (-> leaf.connect leaf).should.throw 'leaf already connected'
    done()

it 'should error on duplicate disconnects', ->
  leaf = new Leaf
  (-> leaf.disconnect leaf).should.throw 'leaf not connected'

it 'should error on duplicate handler add', ->
  leaf = new Leaf
  (-> leaf.addHandler 'connect', (->)).should.throw \
    'handler already registered: connect'

it 'should error on duplicate handler remove', ->
  leaf = new Leaf
  (-> leaf.removeHandler 'foobar', (->)).should.throw \
    'handler not registered: foobar'
