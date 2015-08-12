{EventEmitter}   = require 'events'
debug            = require('debug')('meshblu-discovery-master:discovery-master')
DeviceDiscoverer = require 'meshblu-device-discoverer'

class DiscoveryMaster extends EventEmitter
  constructor: (@config={}) ->

  start: =>
    debug 'starting device discoverer'
    @discoverer = new DeviceDiscoverer @config
    @discoverer.start()
    @discoverer.on 'device', (device) => @emit 'device', device
    @discoverer.on 'update', (properties) => @emit 'update', properties
    @discoverer.on 'error', (error) => @emit 'error', error

module.exports = DiscoveryMaster
