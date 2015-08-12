'use strict';
{EventEmitter}  = require 'events'
_               = require 'lodash'
meshbluJSON     = require('./meshblu.json')
DiscoveryMaster = require './src/discovery-master.coffee'
DeviceMaster    = require './src/device-master.coffee'
debug           = require('debug')('meshblu-discovery-master:index')

MESSAGE_SCHEMA =
  type: 'object'
  properties: {}

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    searchInterval:
      type: 'number',
      required: true
      default: 60 * 1000
    gatebluUuid:
      type: 'string'
      required: true
    userUuid:
      type: 'string'
      required: true

class Plugin extends EventEmitter
  constructor: ->
    debug 'starting plugin...'
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA
    @isStarted = false

  updateDevice: (properties={})=>
    deviceMaster = new DeviceMaster meshbluJSON, @options
    query = $set: properties
    deviceMaster.update query, (error) => debug 'updateDevice', error

  emitError: (error) =>
    debug 'emitting error', error
    @emit 'message',
      devices: '*'
      topic: 'error'
      payload:
        error: error

  addDevice: (device={}) =>
    # Do Something
    debug 'device', device
    {type, id, connector} = device
    @deviceMaster.exists type, id, (error, exists)=>
      debug 'exists ', error: error, exists: exists
      return debug 'error', error if error?
      return debug 'device already exists' if exists
      @deviceMaster.createDevice type, id, connector, (error, createdDevice) =>
        debug 'created device', createdDevice
        return debug 'error', error if error?
        @deviceMaster.addDevice createdDevice, (error) =>
          return debug 'error', error if error?
          debug 'added device to gateblu'

  onMessage: (message) =>
    payload = message.payload
    debug 'onMessage', payload

  startDiscovery: =>
    debug 'starting discovery'
    @isStarted = true
    @deviceMaster = new DeviceMaster meshbluJSON, @options
    @discoverer = new DiscoveryMaster @config
    @discoverer.start()
    @discoverer.on 'error', @emitError
    @discoverer.on 'device', @addDevice
    @discoverer.on 'update', @updateDevice

  onConfig: (device) =>
    debug 'on config'
    @config = device
    @setOptions device.options

  setOptions: (options={}) =>
    defaults =
      searchInterval: 60 * 1000
    @options = _.defaults {}, options, defaults
    return console.error 'no user uuid' unless options.userUuid?
    return console.error 'no gateblu uuid' unless options.gatebluUuid?
    return console.log "options are the same", @options, options if @isStarted && _.isEqual @options, options
    debug 'set options', @options
    @startDiscovery()

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
