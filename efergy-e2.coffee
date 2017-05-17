module.exports = (env) ->
  Promise = env.require 'bluebird'
  M = env.matcher
  events = env.require 'events'
  exec = Promise.promisify(require("child_process").exec)
  spawn = require('child_process').spawn
  settled = (promise) -> Promise.settle([promise])

  class rtl433 extends events.EventEmitter
    constructor: (framework,config) ->
      @config = config
      @framework = framework
      env.logger.debug("Launching rtl_433")
      env.logger.debug @config.binPath, "-f #{@config.freq}", "-R 36","-q"
      proc = spawn(@config.binPath,["-f #{@config.freq}", '-R 36','-q'])

      proc.stdout.setEncoding('utf8')
      proc.stderr.setEncoding('utf8')

      proc.stdout.on('data',(data) =>
        lines = data.split(/(\r?\n)/g)
        @_dataReceived(line) for line in lines when line.trim() isnt ''
      )

      proc.stderr.on('data',(data) =>
        lines = data.split(/(\r?\n)/g)
        env.logger.warn line for line in lines when line.trim() isnt ''
      )

      proc.on('close',(code) =>
        if code!=0
          env.logger.error "rtl_433 returned", code
      )

    _dataReceived: (data) ->
      env.logger.debug data
      datas = {};
      datas = data.split(",")

      # "time","model","id","current","interval","battery","learn"
      if datas.length = 7 and datas[0] != "time"
        result = {
            "sensorId": datas[2],
            "ampere": parseFloat datas[3],
            "battery": parseInt datas[5]
        }
        @emit('power', result)

  Promise.promisifyAll(rtl433.prototype)

  class EfergyE2 extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      @rtl433 = new rtl433(@framework, @config)

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("EfergyE2Sensor", {
        configDef: deviceConfigDef.EfergyE2Sensor, 
        createCallback: (config, lastState) => return new EfergyE2Sensor(config, lastState,@rtl433)
      })

  plugin = new EfergyE2()
  
  class EfergyE2Sensor extends env.devices.Sensor

    constructor: (@config, lastState, @rtl433) ->
      @name = config.name
      @id = config.id
      @sensorId = config.sensorId
      @_voltage = parseFloat(config.volt)

      @_ampere = lastState?.ampere?.value
      @_watt = lastState?.watt?.value
      @_lowBattery = lastState?.lowBattery?.value

      @attributes = {}

      @attributes.watt = {
        description: "the messured Wattage"
        type: "number"
        unit: 'W'
        acronym: 'Power'
      }
      
      @attributes.lowBattery = {
        description: "Battery status"
        type: "boolean"
        labels: ["low", 'ok']
        icon:
          noText: true
          mapping: {
            'icon-battery-filled': false
            'icon-battery-empty': true
          }
      }


      @rtl433.on("power", (result) =>
        if result.sensorId is @config.sensorId
          env.logger.debug "power <- " , result
          @_ampere = result.ampere
          @emit "ampere", @_ampere
          @_watt = @_voltage*@_ampere
          @emit "watt", @_watt
          @_lowBattery = result.battery<1
          @emit "lowBattery", @_lowBattery
      )
      super()
      
    getWatt: -> Promise.resolve @_watt
    getBattery: -> Promise.resolve @_batterystat
    getAmpere: -> Promise.resolve @_ampere
    getLowBattery: -> Promise.resolve @_lowBattery

  return plugin