MeshbluHttp   = require 'meshblu-http'
_             = require 'lodash'
debug         = require('debug')('meshblu-discovery-master:device-master')
IDS_BY_TYPE =
  'device:chromecast': 'chromecastName'
  'device:lifx-light': 'lifxId'
  'device:hue-light' : 'hueLightId'
  'device:hue'       : 'hueBridgeId'

DEFAULTS_BY_TYPE =
  'device:chromecast': (properties={}, id) =>
    properties.options.ChromecastName = id
    properties
  'device:lifx-light': (properties={}, id) =>
    properties.options.lightId = id
    properties
  'device:hue-light' : (properties={}, id) =>
    properties.options.lightNumber = id
    properties
  'device:hue'       : (properties={}, id) =>
    properties.options.ipAddress = id
    properties

class DeviceMaster
  constructor: (@meshbluJSON={}, @config={}) ->
    debug 'meshblu creds', @meshbluJSON
    @meshbluHttp = new MeshbluHttp @meshbluJSON

  getDevices: (query={}, callback=->) =>
    query.owner = @config.userUuid
    debug 'getting devices', query
    @meshbluHttp.devices query, (error, result) =>
      return callback error if error?
      devices = result.devices || []
      callback null, devices

  exists: (type, id, callback=->) =>
    debug 'checking if type exists', type: type, id: id
    query = {}
    typeId = IDS_BY_TYPE[type]
    debug 'typeId', typeId
    query[typeId] = id
    query.type = type
    @getDevices query, (error, devices) =>
      debug 'got devices', error
      return callback error, false if error?
      callback null, !!_.size devices

  createDevice: (type, id, connector, callback=->) =>
    properties = @getDefaults type, id, connector
    properties = DEFAULTS_BY_TYPE[type]?(properties, id)
    debug 'creating device'
    @meshbluHttp.register properties, callback

  getDefaults: (type, id, connector) =>
    properties = {}
    properties.name = id
    properties.type = type
    properties.options = {}
    properties.connector = connector
    properties.category = 'device'
    properties[IDS_BY_TYPE[type]] = id
    properties.discoverWhitelist = [@config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.receiveWhitelist = [@config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.sendWhitelist = [@config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.configureWhitelist = [@config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.owner = @config.userUuid
    properties.gateblu = @config.gatebluUuid
    properties

  update: (query, callback=->)=>
    debug 'updating ', query
    @meshbluHttp.updateDangerously @meshbluJSON.uuid, query, callback

  addDevice: (device={}, callback=->) =>
    propertiesToPick = ['uuid', 'token', 'name', 'type', 'connector']
    propertiesToPick.push IDS_BY_TYPE[device.type]
    simplifiedDevice = _.pick device, propertiesToPick
    query = $push: devices: simplifiedDevice
    # Add to gateblu
    debug 'adding device to gateblu', @config.gatebluUuid, query
    @meshbluHttp.updateDangerously @config.gatebluUuid, query, callback

module.exports = DeviceMaster
