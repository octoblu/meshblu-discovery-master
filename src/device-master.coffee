MeshbluHttp   = require 'meshblu-http'
_             = require 'lodash'
debug         = require('debug')('meshblu-discovery-master:device-master')
IDS_BY_TYPE =
  'device:chromecast': 'chromecastName'
  'device:lifx-light': 'lifxId'
  'device:hue-light' : 'hueLightId'
  'device:hue'       : 'hueBridgeId'

DEFAULTS_BY_TYPE =
  'device:chromecast': (properties={}, device) =>
    properties.options.ChromecastName = device.id
    properties
  'device:lifx-light': (properties={}, device) =>
    properties.options = device.device
    properties.options.lightId = device.id
    properties
  'device:hue-light' : (properties={}, device) =>
    properties.options.lightNumber = device.id
    properties.options.ipAddress = device.device.ipAddress
    properties
  'device:hue'       : (properties={}, device) =>
    properties.options.ipAddress = device.id
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

  findDevice: (type, id, callback=->) =>
    debug 'checking if type exists', type: type, id: id
    query = {}
    typeId = IDS_BY_TYPE[type]
    debug 'typeId', typeId
    query[typeId] = id
    query.type = type
    @getDevices query, (error, devices) =>
      debug 'got devices', error
      return callback error, false if error?
      callback null, _.first devices

  findOrCreateDevice: (device={}, callback=->) =>
    @findDevice device.type, device.id, (error, foundDevice) =>
      return callback error if error?
      return callback null, foundDevice if foundDevice?

      @createDevice device, callback

  createDevice: (device={}, callback=->) =>
    {type, id, connector} = device
    properties = @getDefaults device
    properties = DEFAULTS_BY_TYPE[type]?(properties, device)
    debug 'creating device'
    @meshbluHttp.register properties, callback

  destroyDevice: (device={}, callback=->) =>
    debug 'destroying device', device?.uuid
    @meshbluHttp.unregister device, callback

  getDefaults: (device={}) =>
    {type, id, connector} = device
    properties = {}
    properties.name = id
    properties.type = type
    properties.options = {}
    properties.connector = connector
    properties.category = 'device'
    properties.discoveredDevice = device.device
    properties[IDS_BY_TYPE[type]] = id
    properties.discoverWhitelist = ['*', @config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.receiveWhitelist = ['*', @config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.sendWhitelist = ['*', @config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.configureWhitelist = ['*', @config.gatebluUuid, @config.userUuid, @meshbluJSON.uuid]
    properties.owner = @config.userUuid
    properties.gateblu = @config.gatebluUuid
    properties

  update: (query, callback=->)=>
    debug 'updating ', query
    @meshbluHttp.updateDangerously @meshbluJSON.uuid, query, callback

  findGatebluDevice: (uuid, callback=->) =>
    @meshbluHttp.device @config.gatebluUuid, (error, device) =>
      return callback error if error?

      callback null, _.findWhere device.devices, uuid: uuid

  addDevice: (device={}, callback=->) =>
    @findGatebluDevice device.uuid, (error, foundDevice) =>
      return callback error if error?
      return callback null if foundDevice?

      propertiesToPick = ['uuid', 'token', 'name', 'type', 'connector']
      propertiesToPick.push IDS_BY_TYPE[device.type]
      simplifiedDevice = _.pick device, propertiesToPick
      query = $addToSet: devices: simplifiedDevice
      # Add to gateblu
      debug 'adding device to gateblu', @config.gatebluUuid, query
      @meshbluHttp.updateDangerously @config.gatebluUuid, query, callback

module.exports = DeviceMaster
